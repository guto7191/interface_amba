`timescale 1ns/1ps
// Teste unitario do axi_address_decoder (MAS §4.3, §5.3; VP §3.3), T-U-DEC-001..008.
// O lado m_axi_* e um subordinado falso que conta os comandos que recebe: "a SRAM nao e
// acessada" significa contagem zero la. O checker (AXI4_FULL=1) confere o lado do mestre.
`define AXI4_MASTER_TASKS
module tb_unit_axi_address_decoder_range_and_size_errors;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg aclk = 1'b0, aresetn = 1'b1;
    always #10 aclk = ~aclk;

    // ---------------- lado do mestre (dirigido pelas tasks) ----------------
    reg  [31:0] awaddr = 0;  reg [3:0] awid = 0;  reg [7:0] awlen = 0;  reg [2:0] awsize = 3'd2;
    reg  [1:0]  awburst = 2'b01;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0;  reg wlast = 0, wvalid = 0;  wire wready;
    wire [3:0]  bid;  wire [1:0] bresp;  wire bvalid;  reg bready = 0;
    reg  [31:0] araddr = 0;  reg [3:0] arid = 0;  reg [7:0] arlen = 0;  reg [2:0] arsize = 3'd2;
    reg  [1:0]  arburst = 2'b01;  reg arvalid = 0;  wire arready;
    wire [3:0]  rid;  wire [31:0] rdata;  wire [1:0] rresp;  wire rlast, rvalid;  reg rready = 0;

    // ---------------- lado do subordinado ----------------
    wire [3:0]  m_awid, m_arid, m_bid, m_rid;
    wire [31:0] m_awaddr, m_araddr, m_wdata, m_rdata;
    wire [7:0]  m_awlen, m_arlen;
    wire [2:0]  m_awsize, m_arsize;
    wire [1:0]  m_awburst, m_arburst, m_bresp, m_rresp;
    wire [3:0]  m_wstrb;
    wire        m_awvalid, m_awready, m_wlast, m_wvalid, m_wready, m_bvalid, m_bready;
    wire        m_arvalid, m_arready, m_rlast, m_rvalid, m_rready;

    axi_address_decoder dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awid(awid), .s_axi_awaddr(awaddr), .s_axi_awlen(awlen), .s_axi_awsize(awsize),
        .s_axi_awburst(awburst), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bid(bid), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_arid(arid), .s_axi_araddr(araddr), .s_axi_arlen(arlen), .s_axi_arsize(arsize),
        .s_axi_arburst(arburst), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rid(rid), .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .m_axi_awid(m_awid), .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen), .m_axi_awsize(m_awsize),
        .m_axi_awburst(m_awburst), .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb), .m_axi_wlast(m_wlast),
        .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready),
        .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_arid(m_arid), .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen), .m_axi_arsize(m_arsize),
        .m_axi_arburst(m_arburst), .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp), .m_axi_rlast(m_rlast),
        .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready));

    reg [3:0] stub_gap = 4'd0;
    reg [7:0] stub_resp_delay = 8'd0;
    wire [31:0] ar_count, aw_count, w_beats;

    axi4_downstream_subordinate_stub stub (
        .aclk(aclk), .aresetn(aresetn), .ready_gap(stub_gap), .resp_delay(stub_resp_delay),
        .awid(m_awid), .awaddr(m_awaddr), .awlen(m_awlen), .awsize(m_awsize),
        .awvalid(m_awvalid), .awready(m_awready),
        .wdata(m_wdata), .wstrb(m_wstrb), .wlast(m_wlast), .wvalid(m_wvalid), .wready(m_wready),
        .bid(m_bid), .bresp(m_bresp), .bvalid(m_bvalid), .bready(m_bready),
        .arid(m_arid), .araddr(m_araddr), .arlen(m_arlen), .arsize(m_arsize),
        .arvalid(m_arvalid), .arready(m_arready),
        .rid(m_rid), .rdata(m_rdata), .rresp(m_rresp), .rlast(m_rlast),
        .rvalid(m_rvalid), .rready(m_rready),
        .ar_count(ar_count), .aw_count(aw_count), .w_beats(w_beats));

    wire [31:0] chk_errors;
    axi_protocol_checker #(.AXI4_FULL(1), .RESP_TIMEOUT(2000)) chk (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .errors(chk_errors),
        .awid(awid), .awlen(awlen), .awsize(awsize), .awburst(awburst), .wlast(wlast),
        .bid(bid), .arid(arid), .arlen(arlen), .arsize(arsize), .arburst(arburst),
        .rid(rid), .rlast(rlast));

    `include "common/testbench_case_runner_utils.vh"
    `include "common/axi_master_tasks.vh"
    `include "common/fsm_transition_coverage_monitor.vh"

    // cobertura de arcos das duas FSMs (7 arcos legais cada)
    localparam S_IDLE = 0, S_PASS = 1, S_ERR = 2;
    integer fi;
    initial begin
        for (fi = 0; fi < 2; fi = fi + 1) begin
            fsm_arc_legal(fi, S_IDLE, S_IDLE);  fsm_arc_legal(fi, S_IDLE, S_PASS);
            fsm_arc_legal(fi, S_IDLE, S_ERR);   fsm_arc_legal(fi, S_PASS, S_PASS);
            fsm_arc_legal(fi, S_PASS, S_IDLE);  fsm_arc_legal(fi, S_ERR,  S_ERR);
            fsm_arc_legal(fi, S_ERR,  S_IDLE);
        end
    end
    always @(posedge aclk) begin
        fsm_arc_sample(0, {6'b0, dut.rd_state_q});
        fsm_arc_sample(1, {6'b0, dut.wr_state_q});
    end

    integer chk_base = 0;      // erros do checker anteriores ao caso (o contador e cumulativo)

    task reset_dut;
        begin
            aresetn <= 1'b0;
            awvalid <= 1'b0; wvalid <= 1'b0; arvalid <= 1'b0; bready <= 1'b0; rready <= 1'b0;
            stub_gap <= 4'd0; stub_resp_delay <= 8'd0;
            repeat (3) @(posedge aclk);
            aresetn <= 1'b1;
            repeat (2) @(posedge aclk);
            master_errors = 0;
            chk_base = chk_errors;
        end
    endtask

    // preenche os buffers de W com n+1 beats
    integer wi;
    task fill_w(input integer n);
        begin
            for (wi = 0; wi <= n; wi = wi + 1) begin
                w_data_buf[wi] = 32'hD000_0000 + wi;
                w_strb_buf[wi] = 4'b1111;
            end
        end
    endtask

    integer k;

    initial begin
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        if (run_this("T-U-DEC-001")) begin
            // Primeiro endereco valido: AR em 0x0000_0000, len=0. Esperado: encaminha ao
            // subordinado; rresp = OKAY. Checagem: contagem de comandos encaminhados. Bloq.
            case_begin("T-U-DEC-001", "Bloq"); reset_dut;
            axi_read_burst(32'h0000_0000, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0);
            check(ar_count == 1, "AR valido deveria ser encaminhado");
            check(r_resp_buf[0] === 2'b00, "rresp deveria ser OKAY");
            check(master_errors == 0 && chk_errors == chk_base, "erro de protocolo");
            case_end;
        end

        if (run_this("T-U-DEC-002")) begin
            // Ultimo endereco valido (fronteira exata): AR em 0x001F_FFFC, len=0. OKAY. Bloq.
            case_begin("T-U-DEC-002", "Bloq"); reset_dut;
            axi_read_burst(32'h001F_FFFC, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0);
            check(ar_count == 1, "AR valido deveria ser encaminhado");
            check(r_resp_buf[0] === 2'b00, "rresp deveria ser OKAY");
            check(master_errors == 0 && chk_errors == chk_base, "erro de protocolo");
            case_end;
        end

        if (run_this("T-U-DEC-003")) begin
            // Primeiro endereco invalido (fronteira exata): AR em 0x0020_0000, len=0. Esperado:
            // NAO encaminha; rresp = DECERR (2'b11); a SRAM nao e acessada. Bloq.
            case_begin("T-U-DEC-003", "Bloq"); reset_dut;
            axi_read_burst(32'h0020_0000, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0);
            check(ar_count == 0, "AR invalido nao deveria ser encaminhado");
            check(r_resp_buf[0] === 2'b11, "rresp deveria ser DECERR");
            check(master_errors == 0 && chk_errors == chk_base, "erro de protocolo");
            case_end;
        end

        if (run_this("T-U-DEC-004")) begin
            // Endereco muito acima da faixa: AR em 0xFFFF_FFFC. DECERR; sem acesso. Bloq.
            case_begin("T-U-DEC-004", "Bloq"); reset_dut;
            axi_read_burst(32'hFFFF_FFFC, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0);
            check(ar_count == 0, "AR invalido nao deveria ser encaminhado");
            check(r_resp_buf[0] === 2'b11, "rresp deveria ser DECERR");
            case_end;
        end

        if (run_this("T-U-DEC-005")) begin
            // Drenagem de burst de leitura em erro: AR em 0x0040_0000, len=15. Esperado:
            // exatamente 16 beats de R, todos DECERR, rlast so no 16o. Checagem: E-02, E-03, E-09.
            // Ajust.
            case_begin("T-U-DEC-005", "Ajust"); reset_dut;
            axi_read_burst(32'h0040_0000, 4'h3, 8'd15, 2'b01, 3'd2, 0, 0);
            check(ar_count == 0, "AR invalido nao deveria ser encaminhado");
            for (k = 0; k < 16; k = k + 1) check(r_resp_buf[k] === 2'b11, "beat sem DECERR");
            check(master_errors == 0, "rid/rlast incorretos (rlast so no 16o beat)");
            check(chk.cnt_e02 == 0 && chk.cnt_e03 == 0 && chk.cnt_e09 == 0, "E-02/E-03/E-09");
            case_end;
        end

        if (run_this("T-U-DEC-006")) begin
            // Drenagem de burst de escrita em erro: AW em 0x0040_0000, len=15, 16 beats de W.
            // Esperado: os 16 beats consumidos; UMA resposta B com DECERR. Checagem: E-04, E-07.
            // Ajust.
            case_begin("T-U-DEC-006", "Ajust"); reset_dut;
            fill_w(15);
            axi_write_burst(32'h0040_0000, 4'h4, 8'd15, 2'b01, 3'd2, 0, 0, 0);
            check(aw_count == 0 && w_beats == 0, "burst invalido nao deveria chegar ao subordinado");
            check(last_bresp === 2'b11, "bresp deveria ser DECERR");
            check(master_errors == 0, "bid incorreto ou W nao consumido");
            check(chk.cnt_e04 == 0 && chk.cnt_e07 == 0, "E-04/E-07");
            case_end;
        end

        if (run_this("T-U-DEC-007")) begin
            // Burst que comeca valido e termina fora: AR em 0x001F_FFF0, len=15 (termina em
            // 0x0020_002C no VP; com 4 bytes por beat o ultimo byte e 0x0020_002F). Esperado:
            // burst inteiro rejeitado com DECERR (MAS §4.3). Ajust.
            // Este estimulo cruza a fronteira de 4 KB em 0x0020_0000, entao o checker acusa
            // E-06 (violacao do mestre, MAS §4.4): e esperado e nao entra no veredito do caso.
            case_begin("T-U-DEC-007", "Ajust"); reset_dut;
            axi_read_burst(32'h001F_FFF0, 4'h5, 8'd15, 2'b01, 3'd2, 0, 0);
            check(ar_count == 0, "burst que cruza o fim da faixa nao deveria ser encaminhado");
            for (k = 0; k < 16; k = k + 1) check(r_resp_buf[k] === 2'b11, "beat sem DECERR");
            check(chk.cnt_e09 == 0, "E-09 (rresp consistente no burst)");
            case_end;
        end

        if (run_this("T-U-DEC-008")) begin
            // O canal nao trava apos erro: burst em erro seguido de burst valido. Esperado: o
            // valido e atendido normalmente. Checagem: E-08 (sem timeout). Bloq.
            case_begin("T-U-DEC-008", "Bloq"); reset_dut;
            axi_read_burst(32'h0040_0000, 4'h3, 8'd15, 2'b01, 3'd2, 0, 0);
            axi_read_burst(32'h0000_0100, 4'h6, 8'd3, 2'b01, 3'd2, 0, 0);
            check(ar_count == 1, "o burst valido deveria ser encaminhado");
            for (k = 0; k < 4; k = k + 1) check(r_resp_buf[k] === 2'b00, "burst valido deveria dar OKAY");
            check(r_data_buf[3] === 32'h0000_010C, "dado do 4o beat do burst valido");
            check(master_errors == 0 && chk.cnt_e08 == 0, "canal travou");
            case_end;
        end

        if (run_this("T-U-DEC-COBERTURA")) begin
            // Apoio a cobertura de arcos (VP §4.2), sem ID proprio no VP: SLVERR por AxSIZE,
            // PASSTHROUGH com subordinado lento e ordem com bursts em voo (R-03).
            case_begin("T-U-DEC-COBERTURA", "Bloq"); reset_dut;

            // AxSIZE ilegal -> SLVERR na leitura e na escrita; nada chega ao subordinado
            axi_read_burst(32'h0000_0100, 4'h1, 8'd3, 2'b01, 3'd3, 0, 0);
            for (k = 0; k < 4; k = k + 1) check(r_resp_buf[k] === 2'b10, "leitura com size ilegal deveria dar SLVERR");
            fill_w(3);
            axi_write_burst(32'h0000_0100, 4'h2, 8'd3, 2'b01, 3'd3, 0, 0, 0);
            check(last_bresp === 2'b10, "escrita com size ilegal deveria dar SLVERR");
            // DECERR tem precedencia sobre SLVERR
            axi_read_burst(32'h0040_0000, 4'h1, 8'd0, 2'b01, 3'd3, 0, 0);
            check(r_resp_buf[0] === 2'b11, "DECERR deveria ter precedencia sobre SLVERR");
            check(ar_count == 0 && aw_count == 0 && w_beats == 0, "comando ilegal chegou ao subordinado");

            // subordinado lento: o decoder passa por PASSTHROUGH; dados nos beats corretos
            stub_gap <= 4'd3;
            @(posedge aclk);
            axi_read_burst(32'h0000_0200, 4'h7, 8'd3, 2'b01, 3'd2, 0, 1);
            for (k = 0; k < 4; k = k + 1) check(r_data_buf[k] === 32'h0000_0200 + 4*k, "dado com subordinado lento");
            fill_w(3);
            axi_write_burst(32'h0000_0200, 4'h8, 8'd3, 2'b01, 3'd2, 0, 1, 0);
            check(last_bresp === 2'b00, "escrita com subordinado lento deveria dar OKAY");
            stub_gap <= 4'd0;
            @(posedge aclk);

            // ordem: um AR valido em voo (resposta lenta) e logo um AR invalido do MESMO ID.
            // O erro so pode sair depois da resposta valida.
            stub_resp_delay <= 8'd20;
            @(posedge aclk);
            ar_send_burst(32'h0000_0300, 4'h9, 8'd0, 2'b01, 3'd2, 0);
            ar_send_burst(32'h0040_0000, 4'h9, 8'd1, 2'b01, 3'd2, 0);
            r_recv_burst(8'd0, 4'h9, 0);
            check(r_resp_buf[0] === 2'b00, "a resposta valida deveria sair antes do erro");
            r_recv_burst(8'd1, 4'h9, 0);
            check(r_resp_buf[0] === 2'b11 && r_resp_buf[1] === 2'b11, "o erro deveria sair depois");
            // idem na escrita
            fill_w(0);
            fork
                aw_send_burst(32'h0000_0300, 4'hA, 8'd0, 2'b01, 3'd2, 0);
                w_send_burst(8'd0, 0);
            join
            fork
                aw_send_burst(32'h0040_0000, 4'hA, 8'd0, 2'b01, 3'd2, 0);
                w_send_burst(8'd0, 0);
            join
            b_recv_id(4'hA, 0);
            check(last_bresp === 2'b00, "o B valido deveria sair antes do erro");
            b_recv_id(4'hA, 0);
            check(last_bresp === 2'b11, "o B de erro deveria sair depois");
            stub_resp_delay <= 8'd0;

            // erro de leitura com rready intermitente (ERROR_DRAIN -> ERROR_DRAIN)
            axi_read_burst(32'h0040_0000, 4'hB, 8'd7, 2'b01, 3'd2, 0, 1);
            check(master_errors == 0, "rid/rlast incorretos com rready intermitente");

            repeat (5) @(posedge aclk);
            check(chk_errors == chk_base && master_errors == 0, "erros de protocolo no caso de cobertura");
            fsm_arc_missing = 0;
            fsm_arc_report(0, "decoder leitura");
            fsm_arc_report(1, "decoder escrita");
            check(fsm_arc_missing == 0, "arcos nao visitados");
            case_end;
        end

        final_result("tb_unit_axi_address_decoder");
        $finish;
    end

    initial begin
        #20_000_000;
        $display("RESULT: FAIL tb_unit_axi_address_decoder (timeout)");
        $finish;
    end
endmodule
