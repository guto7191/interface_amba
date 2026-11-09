// COPIA de tb/testbench_legado/common/axi_protocol_checker.v (commit 6580acf, 2026-11-08).
// Copia propria do ambiente UVM, independente do legado; mudancas no original nao sao propagadas.
`timescale 1ns/1ps
// Monitor passivo de protocolo AXI (lado subordinado). Conta violacoes em "errors".
//
// AXI4_FULL = 0 (padrao): checagens AXI4-Lite originais. As portas AXI4 completas podem ficar
//                         desconectadas, pois nada delas e usado.
// AXI4_FULL = 1:          acrescenta as extensoes E-01..E-10 (VP §2.2). Cada uma tem contador
//                         proprio cnt_e01..cnt_e10, somado em "errors" junto das checagens base.
//
// Definicoes das extensoes (VP §2.2, interpretacao fechada na v0.3):
//   E-01  R ou B com ID que nao tem burst pendente e nao acabou de concluir um (ID desconhecido).
//         Como o burst atendido e sempre o mais antigo do ID, resposta fora de ordem do mesmo ID
//         aparece como divergencia de beat/rlast (E-02/E-03) e de dados (scoreboard).
//   E-02  beat de R em excesso: burst do ID acabou de ser concluido e chega mais um beat.
//   E-03  rlast precoce (antes do ultimo beat) ou ausente (no ultimo beat).
//   E-04  wlast precoce ou ausente em relacao ao awlen; ou W com contagem diferente de awlen+1.
//   E-05  BVALID antes de o wlast do burst correspondente ter sido aceito.
//   E-06  burst cruza fronteira de 4 KB.
//   E-07  segunda resposta B para o mesmo burst.
//   E-08  ha burst pendente e nenhum handshake em RESP_TIMEOUT ciclos (deadlock).
//   E-09  rresp muda dentro de um mesmo burst de leitura.
//   E-10  wstrb ativa lane fora das permitidas por AxSIZE e addr[1:0] (subconjunto, v0.3).
module axi_protocol_checker #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter TIMEOUT      = 200,
    parameter AXI4_FULL    = 0,
    parameter RESP_TIMEOUT = 2000
)(
    input aclk,
    input aresetn,
    input [ADDR_WIDTH-1:0]   awaddr,
    input                    awvalid,
    input                    awready,
    input [DATA_WIDTH-1:0]   wdata,
    input [DATA_WIDTH/8-1:0] wstrb,
    input                    wvalid,
    input                    wready,
    input [1:0]              bresp,
    input                    bvalid,
    input                    bready,
    input [ADDR_WIDTH-1:0]   araddr,
    input                    arvalid,
    input                    arready,
    input [DATA_WIDTH-1:0]   rdata,
    input [1:0]              rresp,
    input                    rvalid,
    input                    rready,
    output reg [31:0]        errors,

    // Portas AXI4 completas (usadas so com AXI4_FULL = 1)
    input [3:0]              awid,
    input [7:0]              awlen,
    input [2:0]              awsize,
    input [1:0]              awburst,
    input                    wlast,
    input [3:0]              bid,
    input [3:0]              arid,
    input [7:0]              arlen,
    input [2:0]              arsize,
    input [1:0]              arburst,
    input [3:0]              rid,
    input                    rlast
);
    // valores do ciclo anterior
    reg                    p_awv, p_awr, p_wv, p_wr, p_bv, p_br, p_arv, p_arr, p_rv, p_rr;
    reg [ADDR_WIDTH-1:0]   p_awaddr, p_araddr;
    reg [DATA_WIDTH-1:0]   p_wdata, p_rdata;
    reg [DATA_WIDTH/8-1:0] p_wstrb;
    reg [1:0]              p_bresp, p_rresp;

    // handshakes concluidos desde o reset
    integer aw_cnt, w_cnt, b_cnt, ar_cnt, r_cnt;
    // ciclos esperando READY
    integer aw_to, w_to, ar_to;

    // ---------------- estado das extensoes AXI4 ----------------
    localparam QD = 16;                       // profundidade da fila por ID

    integer cnt_e01, cnt_e02, cnt_e03, cnt_e04, cnt_e05;
    integer cnt_e06, cnt_e07, cnt_e08, cnt_e09, cnt_e10;

    // leitura: fila de bursts pendentes por ID
    reg [7:0] rq_len   [0:16*QD-1];
    integer   rq_head  [0:15];
    integer   rq_cnt   [0:15];
    integer   r_beat   [0:15];               // beats ja recebidos do burst na frente
    reg [1:0] r_resp0  [0:15];               // rresp do primeiro beat do burst na frente
    reg       r_done   [0:15];               // burst do ID acabou de ser concluido (para E-02)

    // escrita: historico circular de AW e contagem de W por burst
    reg [7:0]  aw_len_h  [0:255];
    reg [2:0]  aw_size_h [0:255];
    reg [3:0]  aw_id_h   [0:255];
    reg [31:0] aw_addr_h [0:255];
    reg [8:0]  w_cnt_h   [0:255];            // beats do burst de W concluido (wlast aceito)
    integer    aw_total, w_done, w_cur;      // AWs aceitos, bursts de W concluidos, beat corrente
    integer    b_pend   [0:15];              // bursts com wlast aceito e B ainda nao entregue
    integer    aw_out   [0:15];              // AWs sem B entregue
    reg        b_done   [0:15];              // B do ID acabou de ser entregue (para E-07)

    integer    idle_cycles;                  // ciclos sem handshake com burst pendente
    integer    i;
    integer    rd_out_total;

    initial begin
        errors = 0;
        aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
        aw_to = 0; w_to = 0; ar_to = 0;
        p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
        p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
        cnt_e01 = 0; cnt_e02 = 0; cnt_e03 = 0; cnt_e04 = 0; cnt_e05 = 0;
        cnt_e06 = 0; cnt_e07 = 0; cnt_e08 = 0; cnt_e09 = 0; cnt_e10 = 0;
        clear_axi4_state;
    end

    task err(input [8*48-1:0] msg);
        begin
            errors = errors + 1;
            $display("CHECKER FAIL @%0t: %0s", $time, msg);
        end
    endtask

    // erro de extensao: incrementa o contador proprio e o total
    task errn(input integer n, input [8*48-1:0] msg);
        begin
            case (n)
                1:  cnt_e01 = cnt_e01 + 1;
                2:  cnt_e02 = cnt_e02 + 1;
                3:  cnt_e03 = cnt_e03 + 1;
                4:  cnt_e04 = cnt_e04 + 1;
                5:  cnt_e05 = cnt_e05 + 1;
                6:  cnt_e06 = cnt_e06 + 1;
                7:  cnt_e07 = cnt_e07 + 1;
                8:  cnt_e08 = cnt_e08 + 1;
                9:  cnt_e09 = cnt_e09 + 1;
                default: cnt_e10 = cnt_e10 + 1;
            endcase
            errors = errors + 1;
            $display("CHECKER FAIL E-%02d @%0t: %0s", n, $time, msg);
        end
    endtask

    task clear_axi4_state;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                rq_head[i] = 0; rq_cnt[i] = 0; r_beat[i] = 0; r_resp0[i] = 2'b00; r_done[i] = 1'b0;
                b_pend[i] = 0; aw_out[i] = 0; b_done[i] = 1'b0;
            end
            aw_total = 0; w_done = 0; w_cur = 0; idle_cycles = 0;
        end
    endtask

    // bytes lanes permitidas para o beat n do burst k de escrita (MAS §5.6 / IHI0022E §A3.4.1)
    function [3:0] lanes_mask(input [31:0] start, input [2:0] size, input integer n);
        reg [31:0] nb, aligned, beat_addr;
        integer    lower, upper, b;
        begin
            nb      = 32'd1 << size;
            aligned = start & ~(nb - 32'd1);
            if (n == 0) begin
                lower = start[1:0];
                upper = aligned[1:0] + nb - 1;
            end else begin
                beat_addr = aligned + n * nb;
                lower     = beat_addr[1:0];
                upper     = lower + nb - 1;
            end
            lanes_mask = 4'b0000;
            for (b = 0; b < 4; b = b + 1)
                if (b >= lower && b <= upper) lanes_mask[b] = 1'b1;
        end
    endfunction

    // E-06: burst INCR cruzando 4 KB
    task check_4kb(input [31:0] start, input [7:0] len, input [2:0] size);
        reg [31:0] nb, aligned, last;
        begin
            nb      = 32'd1 << size;
            aligned = start & ~(nb - 32'd1);
            last    = aligned + ((len + 32'd1) << size) - 32'd1;
            if (start[31:12] != last[31:12]) errn(6, "burst cruza fronteira de 4 KB");
        end
    endtask

    // fecha o burst da frente da fila de leitura de um ID
    task pop_read_burst(input [3:0] id);
        begin
            rq_head[id] = (rq_head[id] + 1) % QD;
            rq_cnt[id]  = rq_cnt[id] - 1;
            r_beat[id]  = 0;
            r_done[id]  = 1'b1;
        end
    endtask

    // incrementa b_pend quando AW e W do mesmo burst ja foram vistos
    task burst_complete(input integer k);
        begin
            b_pend[aw_id_h[k % 256]] = b_pend[aw_id_h[k % 256]] + 1;
        end
    endtask

    integer    id_i, beat_i, exp_len, qidx;
    reg [3:0]  mask_i;
    reg        new_b;

    always @(posedge aclk) begin
        if (!aresetn) begin
            // saidas VALID devem estar em 0 durante o reset
            if (bvalid !== 1'b0) err("BVALID alto durante reset");
            if (rvalid !== 1'b0) err("RVALID alto durante reset");
            aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
            aw_to = 0; w_to = 0; ar_to = 0;
            p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
            p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
            clear_axi4_state;
        end else begin
            // X nos controles
            if ((^{awready, wready, arready, bvalid, rvalid}) === 1'bx) err("X em saida de controle do subordinado");
            if ((^{awvalid, wvalid, arvalid, bready, rready}) === 1'bx) err("X em controle do mestre");
            if (bvalid && ((^bresp) === 1'bx))            err("BRESP com X");
            if (rvalid && ((^{rresp, rdata}) === 1'bx))   err("RRESP/RDATA com X");
            if (bvalid && bresp == 2'b01)                 err("EXOKAY sem suporte a acesso exclusivo");
            if (rvalid && rresp == 2'b01)                 err("EXOKAY sem suporte a acesso exclusivo");

            // estabilidade do mestre: VALID sobe e fica ate READY, payload constante
            if (p_awv && !p_awr) begin
                if (!awvalid)               err("AWVALID caiu antes de AWREADY");
                else if (awaddr !== p_awaddr) err("AWADDR mudou com AWVALID pendente");
            end
            if (p_wv && !p_wr) begin
                if (!wvalid)                err("WVALID caiu antes de WREADY");
                else if (wdata !== p_wdata || wstrb !== p_wstrb) err("WDATA/WSTRB mudou com WVALID pendente");
            end
            if (p_arv && !p_arr) begin
                if (!arvalid)               err("ARVALID caiu antes de ARREADY");
                else if (araddr !== p_araddr) err("ARADDR mudou com ARVALID pendente");
            end
            // estabilidade do subordinado
            if (p_bv && !p_br) begin
                if (!bvalid)                err("BVALID caiu antes de BREADY");
                else if (bresp !== p_bresp) err("BRESP mudou com BVALID pendente");
            end
            if (p_rv && !p_rr) begin
                if (!rvalid)                err("RVALID caiu antes de RREADY");
                else if (rdata !== p_rdata || rresp !== p_rresp) err("RDATA/RRESP mudou com RVALID pendente");
            end

            // causalidade: resposta so depois dos handshakes de entrada
            // (em AXI4 completo, R tem varios beats por AR: a causalidade de R e feita por E-01..E-03)
            if (bvalid && !(b_cnt < aw_cnt && b_cnt < w_cnt)) err("BVALID sem AW e W aceitos");
            if (!AXI4_FULL && rvalid && !(r_cnt < ar_cnt))    err("RVALID sem AR aceito");

            // ================= extensoes AXI4 (E-01..E-10) =================
            if (AXI4_FULL) begin

                // ---- canal B: checa a apresentacao de uma nova resposta (antes de processar W/AW) ----
                new_b = bvalid && (!p_bv || p_br);
                if (new_b) begin
                    if (b_pend[bid] == 0) begin
                        if (aw_out[bid] > 0)    errn(5, "BVALID antes do wlast do burst");
                        else if (b_done[bid])   errn(7, "segunda resposta B para o mesmo burst");
                        else                    errn(1, "BID sem burst de escrita pendente");
                    end
                end
                if (bvalid && bready) begin
                    if (b_pend[bid] > 0) begin
                        b_pend[bid] = b_pend[bid] - 1;
                        aw_out[bid] = aw_out[bid] - 1;
                        b_done[bid] = 1'b1;
                    end
                end

                // ---- canal AW ----
                if (awvalid && awready) begin
                    check_4kb(awaddr, awlen, awsize);
                    aw_len_h [aw_total % 256] = awlen;
                    aw_size_h[aw_total % 256] = awsize;
                    aw_id_h  [aw_total % 256] = awid;
                    aw_addr_h[aw_total % 256] = awaddr;
                    aw_out[awid]  = aw_out[awid] + 1;
                    b_done[awid]  = 1'b0;
                    // W deste burst ja terminou antes do AW?
                    if (w_done > aw_total) begin
                        if (w_cnt_h[aw_total % 256] != awlen + 1)
                            errn(4, "contagem de beats de W diferente de awlen+1");
                        burst_complete(aw_total);
                    end
                    aw_total = aw_total + 1;
                end

                // ---- canal W ----
                if (wvalid && wready) begin
                    if (aw_total > w_done) begin
                        exp_len = aw_len_h[w_done % 256];
                        if (wlast && w_cur != exp_len)       errn(4, "wlast precoce");
                        if (!wlast && w_cur >= exp_len)      errn(4, "wlast ausente no ultimo beat");
                        mask_i = lanes_mask(aw_addr_h[w_done % 256], aw_size_h[w_done % 256], w_cur);
                        if ((wstrb & ~mask_i) != 0)
                            errn(10, "wstrb ativa lane fora da permitida por AxSIZE");
                    end
                    w_cur = w_cur + 1;
                    if (wlast) begin
                        w_cnt_h[w_done % 256] = w_cur;
                        if (aw_total > w_done) burst_complete(w_done);
                        w_done = w_done + 1;
                        w_cur  = 0;
                    end
                end

                // ---- canal AR ----
                // (processado depois de R no mesmo ciclo, mais abaixo)

                // ---- canal R ----
                if (rvalid && rready) begin
                    if (rq_cnt[rid] == 0) begin
                        if (r_done[rid]) errn(2, "beat de R em excesso");
                        else             errn(1, "RID sem burst de leitura pendente");
                    end else begin
                        qidx    = rid * QD + rq_head[rid];
                        exp_len = rq_len[qidx];
                        beat_i  = r_beat[rid];
                        if (beat_i == 0) r_resp0[rid] = rresp;
                        else if (rresp !== r_resp0[rid]) errn(9, "rresp mudou dentro do burst");
                        if (rlast && beat_i != exp_len) begin
                            errn(3, "rlast precoce");
                            pop_read_burst(rid);
                        end else if (!rlast && beat_i == exp_len) begin
                            errn(3, "rlast ausente no ultimo beat");
                            pop_read_burst(rid);
                        end else if (rlast) begin
                            pop_read_burst(rid);
                        end else begin
                            r_beat[rid] = beat_i + 1;
                            r_done[rid] = 1'b0;
                        end
                    end
                end

                // ---- canal AR ----
                if (arvalid && arready) begin
                    check_4kb(araddr, arlen, arsize);
                    qidx = arid * QD + ((rq_head[arid] + rq_cnt[arid]) % QD);
                    rq_len[qidx]   = arlen;
                    rq_cnt[arid]   = rq_cnt[arid] + 1;
                    r_done[arid]   = 1'b0;
                end

                // ---- E-08: deadlock de resposta ----
                rd_out_total = 0;
                for (id_i = 0; id_i < 16; id_i = id_i + 1)
                    rd_out_total = rd_out_total + rq_cnt[id_i] + aw_out[id_i];
                if ((awvalid && awready) || (wvalid && wready) || (arvalid && arready) ||
                    (rvalid && rready) || (bvalid && bready) || rd_out_total == 0)
                    idle_cycles = 0;
                else
                    idle_cycles = idle_cycles + 1;
                if (idle_cycles > RESP_TIMEOUT) begin
                    errn(8, "burst pendente sem resposta (deadlock)");
                    idle_cycles = 0;
                end
            end

            // contagem de handshakes
            if (awvalid && awready) aw_cnt = aw_cnt + 1;
            if (wvalid  && wready)  w_cnt  = w_cnt  + 1;
            if (bvalid  && bready)  b_cnt  = b_cnt  + 1;
            if (arvalid && arready) ar_cnt = ar_cnt + 1;
            if (rvalid  && rready)  r_cnt  = r_cnt  + 1;

            // timeout de aceitacao (deadlock)
            aw_to = (awvalid && !awready) ? aw_to + 1 : 0;
            w_to  = (wvalid  && !wready)  ? w_to  + 1 : 0;
            ar_to = (arvalid && !arready) ? ar_to + 1 : 0;
            if (aw_to > TIMEOUT) begin err("timeout AWREADY"); aw_to = 0; end
            if (w_to  > TIMEOUT) begin err("timeout WREADY");  w_to  = 0; end
            if (ar_to > TIMEOUT) begin err("timeout ARREADY"); ar_to = 0; end

            p_awv = awvalid; p_awr = awready; p_awaddr = awaddr;
            p_wv  = wvalid;  p_wr  = wready;  p_wdata = wdata; p_wstrb = wstrb;
            p_bv  = bvalid;  p_br  = bready;  p_bresp = bresp;
            p_arv = arvalid; p_arr = arready; p_araddr = araddr;
            p_rv  = rvalid;  p_rr  = rready;  p_rdata = rdata; p_rresp = rresp;
        end
    end
endmodule
