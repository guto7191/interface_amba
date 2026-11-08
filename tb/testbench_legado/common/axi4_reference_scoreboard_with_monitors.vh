// Scoreboard de referencia do subordinado AXI4 (VP §2.4), incluido dentro do modulo do TB.
//
// Mantem um modelo da memoria POR BYTE (2 MB), independente do modelo da SRAM e do RTL, e
// observa os cinco canais passivamente (monitores). O scoreboard e a autoridade sobre DADOS; o
// checker (axi_protocol_checker) e a autoridade sobre PROTOCOLO. Os dois ficam ativos juntos.
//
// Regras (VP §2.4):
//  1. Escrita atualiza o modelo byte a byte conforme wstrb; byte com strobe 0 nao muda. A
//     atualizacao ocorre no handshake de B (ponto em que o mestre ve a escrita concluida) e so
//     para bursts cuja resposta esperada e OKAY.
//  2. Toda leitura e comparada contra o modelo; divergencia imprime endereco, esperado,
//     recebido e beat.
//  3. Posicao nunca escrita vale 32'hDEADDEAD (bytes AD,DE,AD,DE em little-endian).
//  5. Numa leitura, so as lanes validas do beat (size e addr[1:0]) entram na comparacao; as
//     demais seguem a decisao D12 (dado replicado) e a norma nao lhes da valor.
// A resposta esperada (OKAY/SLVERR/DECERR) e calculada por expected_resp, de forma independente
// do decoder.
//
// Chama cov_write_beat / cov_read_burst do coletor de cobertura (incluir antes este arquivo).
// Requisitos do modulo que inclui: aclk, aresetn (wire), sinais AXI do mestre/subordinado com os
// nomes de axi_master_tasks.vh. Pressupoe testes que NAO leem e escrevem o mesmo endereco em
// concorrencia (a ordem entre os dois canais nao e definida pelo AXI).

`include "common/axi4_beat_address_and_lane_functions.vh"

localparam SB_SLOTS = 64;

reg [7:0] sb_mem [0:2097151];
integer   sb_errors = 0;
integer   sb_init_i;
initial begin
    for (sb_init_i = 0; sb_init_i < 2097152; sb_init_i = sb_init_i + 1)
        sb_mem[sb_init_i] = sb_init_i[0] ? 8'hDE : 8'hAD;
end

// ---------------- escritas ----------------
reg [31:0] sbw_addr   [0:SB_SLOTS-1];
reg [7:0]  sbw_len    [0:SB_SLOTS-1];
reg [2:0]  sbw_size   [0:SB_SLOTS-1];
reg [3:0]  sbw_id     [0:SB_SLOTS-1];
integer    sbw_exp    [0:SB_SLOTS-1];
reg        sbw_wdone  [0:SB_SLOTS-1];
reg        sbw_commit [0:SB_SLOTS-1];
reg [31:0] sbw_data   [0:SB_SLOTS*256-1];
reg [3:0]  sbw_strb   [0:SB_SLOTS*256-1];
integer    sbw_aw_n, sbw_w_burst, sbw_w_beat, sbw_oldest;

// ---------------- leituras (fila de bursts por ID) ----------------
reg [31:0] sbr_addr [0:SB_SLOTS-1];
reg [7:0]  sbr_len  [0:SB_SLOTS-1];
reg [2:0]  sbr_size [0:SB_SLOTS-1];
integer    sbr_exp  [0:SB_SLOTS-1];
integer    sbr_n;
integer    sbr_q    [0:16*16-1];
integer    sbr_qh   [0:15];
integer    sbr_qn   [0:15];
integer    sbr_beat [0:15];

integer    sb_wr_bursts = 0, sb_rd_bursts = 0, sb_rd_beats = 0, sb_wr_beats = 0;
integer    sb_i, sb_j, sb_slot, sb_n, sb_b, sb_found, sb_exp_l;
reg [31:0] sb_ba, sb_wbase;
reg [3:0]  sb_lm;

task sb_clear_queues;
    begin
        sbw_aw_n = 0; sbw_w_burst = 0; sbw_w_beat = 0; sbw_oldest = 0; sbr_n = 0;
        for (sb_i = 0; sb_i < SB_SLOTS; sb_i = sb_i + 1) begin
            sbw_wdone[sb_i] = 1'b0; sbw_commit[sb_i] = 1'b1;
        end
        for (sb_i = 0; sb_i < 16; sb_i = sb_i + 1) begin
            sbr_qh[sb_i] = 0; sbr_qn[sb_i] = 0; sbr_beat[sb_i] = 0;
        end
    end
endtask

initial sb_clear_queues;

task sb_fail(input [8*64-1:0] msg);
    begin
        sb_errors = sb_errors + 1;
        $display("SCOREBOARD FAIL @%0t: %0s", $time, msg);
    end
endtask

// bursts pendentes (escritas sem B + leituras sem rlast)
function integer sb_pending;
    input dummy;
    integer p, q;
    begin
        p = 0;
        for (q = 0; q < 16; q = q + 1) p = p + sbr_qn[q];
        sb_pending = p + (sbw_aw_n - sbw_oldest);
    end
endfunction

// ---------------- API usada pelos testes ----------------
// escreve uma palavra de 32 bits direto no modelo e no modelo da SRAM (sem passar pelo DUT)
task sb_preload_word(input [31:0] byte_addr, input [31:0] data);
    begin
        sb_wbase = byte_addr & 32'hFFFF_FFFC;
        sb_mem[sb_wbase]     = data[7:0];
        sb_mem[sb_wbase + 1] = data[15:8];
        sb_mem[sb_wbase + 2] = data[23:16];
        sb_mem[sb_wbase + 3] = data[31:24];
        u_sram.mem_poke({sb_wbase[20:2], 1'b0}, data[15:0]);
        u_sram.mem_poke({sb_wbase[20:2], 1'b1}, data[31:16]);
    end
endtask

// reaproveita o conteudo REAL da SRAM como verdade para uma regiao (apos reset no meio de burst)
task sb_resync_from_sram(input [31:0] byte_start, input integer nbytes);
    reg [15:0] hw;
    integer    off;
    begin
        for (off = 0; off < nbytes; off = off + 2) begin
            hw = u_sram.mem_peek((byte_start + off) >> 1);
            sb_mem[byte_start + off]     = hw[7:0];
            sb_mem[byte_start + off + 1] = hw[15:8];
        end
    end
endtask

// compara a memoria inteira do modelo da SRAM com o scoreboard
task sb_compare_all_memory;
    reg [15:0] hw;
    integer    w, bad;
    begin
        bad = 0;
        for (w = 0; w < 1048576; w = w + 1) begin
            hw = u_sram.mem_peek(w);
            if (hw[7:0] !== sb_mem[2*w] || hw[15:8] !== sb_mem[2*w + 1]) begin
                if (bad < 5) $display("SCOREBOARD FAIL: memoria diverge em byte %08h: SRAM=%04h modelo=%02h%02h",
                                      2*w, hw, sb_mem[2*w + 1], sb_mem[2*w]);
                bad = bad + 1;
            end
        end
        if (bad != 0) sb_fail("memoria da SRAM diverge do modelo de referencia");
    end
endtask

// ---------------- monitores passivos ----------------
always @(posedge aclk) begin
    if (!aresetn) begin
        sb_clear_queues;
    end else begin
        // ---- AW ----
        if (awvalid && awready) begin
            sb_slot = sbw_aw_n % SB_SLOTS;
            sbw_addr[sb_slot] = awaddr;  sbw_len[sb_slot] = awlen;
            sbw_size[sb_slot] = awsize;  sbw_id[sb_slot]  = awid;
            sbw_exp[sb_slot]  = expected_resp(awaddr, awlen, awsize);
            sbw_commit[sb_slot] = 1'b0;
            sbw_aw_n = sbw_aw_n + 1;
        end
        // ---- W ----
        if (wvalid && wready) begin
            sb_slot = sbw_w_burst % SB_SLOTS;
            sbw_data[sb_slot*256 + sbw_w_beat] = wdata;
            sbw_strb[sb_slot*256 + sbw_w_beat] = wstrb;
            sbw_w_beat = sbw_w_beat + 1;
            sb_wr_beats = sb_wr_beats + 1;
            if (wlast) begin
                sbw_wdone[sb_slot] = 1'b1;
                sbw_w_burst = sbw_w_burst + 1;
                sbw_w_beat  = 0;
            end
        end
        // ---- B: confirma a resposta e efetiva a escrita no modelo ----
        if (bvalid && bready) begin
            sb_found = -1;
            for (sb_j = sbw_oldest; sb_j < sbw_aw_n && sb_found < 0; sb_j = sb_j + 1)
                if (!sbw_commit[sb_j % SB_SLOTS] && sbw_id[sb_j % SB_SLOTS] === bid) sb_found = sb_j;
            if (sb_found < 0) begin
                sb_fail("B de um ID sem escrita pendente");
            end else begin
                sb_slot = sb_found % SB_SLOTS;
                if (!sbw_wdone[sb_slot]) sb_fail("B antes de o wlast do burst ser aceito");
                if (bresp !== sbw_exp[sb_slot][1:0]) begin
                    sb_errors = sb_errors + 1;
                    $display("SCOREBOARD FAIL @%0t: bresp=%0d esperado=%0d (addr=%08h)", $time, bresp, sbw_exp[sb_slot], sbw_addr[sb_slot]);
                end
                for (sb_n = 0; sb_n <= sbw_len[sb_slot]; sb_n = sb_n + 1)
                    cov_write_beat(sbw_addr[sb_slot], sbw_len[sb_slot], sbw_size[sb_slot], sbw_strb[sb_slot*256 + sb_n]);
                if (sbw_exp[sb_slot] == 0) begin
                    for (sb_n = 0; sb_n <= sbw_len[sb_slot]; sb_n = sb_n + 1) begin
                        sb_ba = axi_beat_addr(sbw_addr[sb_slot], sbw_size[sb_slot], sb_n);
                        for (sb_b = 0; sb_b < 4; sb_b = sb_b + 1)
                            if (sbw_strb[sb_slot*256 + sb_n][sb_b])
                                sb_mem[(sb_ba & 32'hFFFF_FFFC) + sb_b] = sbw_data[sb_slot*256 + sb_n][8*sb_b +: 8];
                    end
                end
                sbw_commit[sb_slot] = 1'b1;
                sbw_wdone[sb_slot]  = 1'b0;
                sb_wr_bursts = sb_wr_bursts + 1;
                while (sbw_oldest < sbw_aw_n && sbw_commit[sbw_oldest % SB_SLOTS]) sbw_oldest = sbw_oldest + 1;
            end
        end
        // ---- R: compara resposta, ID e dados (so lanes validas) ----
        if (rvalid && rready) begin
            if (sbr_qn[rid] == 0) begin
                sb_fail("R de um ID sem leitura pendente");
            end else begin
                sb_slot = sbr_q[rid*16 + sbr_qh[rid]];
                sb_n    = sbr_beat[rid];
                sb_rd_beats = sb_rd_beats + 1;
                if (rresp !== sbr_exp[sb_slot][1:0]) begin
                    sb_errors = sb_errors + 1;
                    $display("SCOREBOARD FAIL @%0t: rresp=%0d esperado=%0d (addr=%08h beat=%0d)", $time, rresp, sbr_exp[sb_slot], sbr_addr[sb_slot], sb_n);
                end
                if (sbr_exp[sb_slot] == 0) begin
                    sb_ba = axi_beat_addr(sbr_addr[sb_slot], sbr_size[sb_slot], sb_n);
                    sb_lm = lane_mask(sbr_addr[sb_slot], sbr_size[sb_slot], sb_n);
                    for (sb_b = 0; sb_b < 4; sb_b = sb_b + 1)
                        if (sb_lm[sb_b] && rdata[8*sb_b +: 8] !== sb_mem[(sb_ba & 32'hFFFF_FFFC) + sb_b]) begin
                            sb_errors = sb_errors + 1;
                            $display("SCOREBOARD FAIL @%0t: addr=%08h beat=%0d lane=%0d esperado=%02h recebido=%02h",
                                     $time, sb_ba, sb_n, sb_b, sb_mem[(sb_ba & 32'hFFFF_FFFC) + sb_b], rdata[8*sb_b +: 8]);
                        end
                end
                if (sb_n == sbr_len[sb_slot]) begin           // ultimo beat do burst
                    sbr_qh[rid]   = (sbr_qh[rid] + 1) % 16;
                    sbr_qn[rid]   = sbr_qn[rid] - 1;
                    sbr_beat[rid] = 0;
                    sb_rd_bursts  = sb_rd_bursts + 1;
                end else begin
                    sbr_beat[rid] = sb_n + 1;
                end
            end
        end
        // ---- AR (depois de R: um AR no mesmo ciclo nao pode ser respondido no mesmo ciclo) ----
        if (arvalid && arready) begin
            sb_slot = sbr_n % SB_SLOTS;
            sbr_addr[sb_slot] = araddr;  sbr_len[sb_slot] = arlen;  sbr_size[sb_slot] = arsize;
            sbr_exp[sb_slot]  = expected_resp(araddr, arlen, arsize);
            cov_read_burst(araddr, arlen, arsize);
            sbr_q[arid*16 + ((sbr_qh[arid] + sbr_qn[arid]) % 16)] = sb_slot;
            sbr_qn[arid] = sbr_qn[arid] + 1;
            sbr_n = sbr_n + 1;
        end
    end
end
