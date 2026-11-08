`timescale 1ns/1ps
// Integracao do contrato ram_* (MAS §3.2; VP §3.5) com o subordinado completo
// (axi_interface_subordinate_sram + sram_io_buffer + modelo da SRAM) - "montagem A".
// T-I-RAM-001, 003, 005, 006 e T-U-RST-005. T-I-RAM-002 e 004 (precisam negar accept e reter
// respostas) estao em tb_integration_ram_contract_backpressure_with_stub.v (montagem B).
// Assertivas de contrato ficam ativas o tempo todo (regras 2, 3 e 4).
`define AXI4_MASTER_TASKS
module tb_integration_ram_contract_handshake_and_ordering;
    parameter PHASE = 2;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg aclk = 1'b0, aresetn = 1'b1;
    always #10 aclk = ~aclk;

    reg  [31:0] awaddr = 0;  reg [3:0] awid = 0;  reg [7:0] awlen = 0;  reg [2:0] awsize = 3'd2;
    reg  [1:0]  awburst = 2'b01;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0;  reg wlast = 0, wvalid = 0;  wire wready;
    wire [3:0]  bid;  wire [1:0] bresp;  wire bvalid;  reg bready = 0;
    reg  [31:0] araddr = 0;  reg [3:0] arid = 0;  reg [7:0] arlen = 0;  reg [2:0] arsize = 3'd2;
    reg  [1:0]  arburst = 2'b01;  reg arvalid = 0;  wire arready;
    wire [3:0]  rid;  wire [31:0] rdata;  wire [1:0] rresp;  wire rlast, rvalid;  reg rready = 0;

    wire [19:0] sram_addr;
    wire [15:0] sram_data_out, sram_data_in;
    wire        sram_data_out_en, sram_oe_n, sram_we_n, sram_lb_n, sram_ub_n, sram_ce_n;
    wire [19:0] SRAM_ADDR;
    wire [15:0] SRAM_DQ;
    wire        SRAM_OE_N, SRAM_WE_N, SRAM_LB_N, SRAM_UB_N, SRAM_CE_N;

    axi_interface_subordinate_sram #(.PHASE(PHASE)) dut (
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
        .sram_addr(sram_addr), .sram_data_out(sram_data_out), .sram_data_out_en(sram_data_out_en),
        .sram_data_in(sram_data_in), .sram_oe_n(sram_oe_n), .sram_we_n(sram_we_n),
        .sram_lb_n(sram_lb_n), .sram_ub_n(sram_ub_n), .sram_ce_n(sram_ce_n));

    sram_io_buffer u_iob (
        .addr_i(sram_addr), .data_out_i(sram_data_out), .data_out_en_i(sram_data_out_en),
        .data_in_o(sram_data_in), .oe_n_i(sram_oe_n), .we_n_i(sram_we_n),
        .lb_n_i(sram_lb_n), .ub_n_i(sram_ub_n), .ce_n_i(sram_ce_n),
        .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_CE_N(SRAM_CE_N));

    wire [31:0] sram_errors, sram_access_count, sram_we_pulses;
    sram_is61wv102416_behavioral_model u_sram (
        .addr(SRAM_ADDR), .dq(SRAM_DQ), .ce_n(SRAM_CE_N), .oe_n(SRAM_OE_N), .we_n(SRAM_WE_N),
        .lb_n(SRAM_LB_N), .ub_n(SRAM_UB_N), .sample_clk(aclk),
        .errors(sram_errors), .access_count(sram_access_count), .we_pulse_count(sram_we_pulses));

    wire [31:0] chk_errors;
    axi_protocol_checker #(.AXI4_FULL(1), .RESP_TIMEOUT(5000)) chk (
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

    // ---------------- monitor do contrato ram_* (sinais internos do wrapper) ----------------
    wire        c_accept = dut.ram_accept_w;
    wire        c_ack    = dut.ram_ack_w;
    wire        c_req    = dut.ram_rd_w | dut.ram_wr_req_w;

    integer acc_n = 0, ack_n = 0;           // requisicoes aceitas / acks
    integer excl_viol = 0;                  // ram_wr_req e ram_rd juntos (regra 3)
    integer stab_viol = 0;                  // requisicao mudou sem accept (regra 2)
    integer over_ack = 0;                   // mais acks do que requisicoes aceitas (regra 4)
    integer pend_cycles = 0, max_pend = 0;  // espera por accept (regra 7)
    reg [31:0] p_addr, p_wdata;  reg [3:0] p_wr;  reg p_rd, p_wr_req, p_pend;
    reg [31:0] ack_data [0:1023];

    always @(posedge aclk) begin
        if (aresetn) begin
            if (dut.ram_wr_req_w && dut.ram_rd_w) excl_viol = excl_viol + 1;
            if (p_pend && (dut.ram_addr_w !== p_addr || dut.ram_wr_w !== p_wr || dut.ram_rd_w !== p_rd ||
                dut.ram_wr_req_w !== p_wr_req || dut.ram_write_data_w !== p_wdata)) stab_viol = stab_viol + 1;
            if (c_req && c_accept) begin acc_n = acc_n + 1; pend_cycles = 0; end
            else if (c_req)        begin pend_cycles = pend_cycles + 1; if (pend_cycles > max_pend) max_pend = pend_cycles; end
            if (c_ack) begin ack_data[ack_n % 1024] = dut.ram_read_data_w; ack_n = ack_n + 1; end
            if (ack_n > acc_n) over_ack = over_ack + 1;
        end
        p_pend = c_req && !c_accept;
        p_addr = dut.ram_addr_w; p_wr = dut.ram_wr_w; p_rd = dut.ram_rd_w;
        p_wr_req = dut.ram_wr_req_w; p_wdata = dut.ram_write_data_w;
    end

    // ---------------- helpers ----------------
    integer chk_base = 0;
    function [19:0] w16(input [31:0] byte_addr);   // palavra de 16 bits (metade baixa)
        w16 = {byte_addr[20:2], 1'b0};
    endfunction

    task reset_dut;
        begin
            aresetn <= 1'b0;
            awvalid <= 1'b0; wvalid <= 1'b0; arvalid <= 1'b0; bready <= 1'b0; rready <= 1'b0;
            repeat (3) @(posedge aclk);
            aresetn <= 1'b1;
            repeat (2) @(posedge aclk);
            acc_n = 0; ack_n = 0; excl_viol = 0; stab_viol = 0; over_ack = 0; max_pend = 0;
            master_errors = 0; chk_base = chk_errors;
        end
    endtask

    task settle;        // espera o sistema ficar ocioso
        begin repeat (40) @(posedge aclk); end
    endtask

    task contract_ok;
        begin
            check(excl_viol == 0, "regra 3: ram_wr_req e ram_rd juntos");
            check(stab_viol == 0, "regra 2: requisicao instavel sem accept");
            check(over_ack == 0, "regra 4: mais acks que requisicoes aceitas");
            check(chk_errors == chk_base && master_errors == 0, "violacao no lado AXI");
            check(sram_errors == 0, "violacao de temporizacao da SRAM");
        end
    endtask

    integer i, n;
    integer wi;
    task fill_w(input integer len, input [31:0] base);
        begin
            for (wi = 0; wi <= len; wi = wi + 1) begin
                w_data_buf[wi] = base + wi;
                w_strb_buf[wi] = 4'b1111;
            end
        end
    endtask

    // ---------------- RST-005: sem glitch na conversao de polaridade ----------------
    integer rst_ev_a = 0, rst_ev_w = 0, rst_mismatch = 0;
    always @(aresetn)    rst_ev_a = rst_ev_a + 1;
    always @(dut.rst_w)  rst_ev_w = rst_ev_w + 1;
    always @(aresetn or dut.rst_w) begin
        #0.001;
        if (dut.rst_w !== ~aresetn) rst_mismatch = rst_mismatch + 1;
    end

    initial begin
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        if (run_this("T-I-RAM-001")) begin
            // Handshake basico: requisicoes isoladas de leitura e escrita. Esperado: toda
            // requisicao aceita recebe exatamente um ram_ack. Checagem: acks = aceitas. Bloq.
            case_begin("T-I-RAM-001", "Bloq"); reset_dut;
            for (i = 0; i < 4; i = i + 1) begin
                fill_w(0, 32'hC000_0000 + i);
                axi_write_burst(32'h0000_0100 + i*4, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0, 0);
            end
            for (i = 0; i < 4; i = i + 1)
                axi_read_burst(32'h0000_0100 + i*4, 4'h2, 8'd0, 2'b01, 3'd2, 0, 0);
            settle;
            check(acc_n == 8, "deveriam ser 8 requisicoes aceitas");
            check(ack_n == acc_n, "acks diferente de requisicoes aceitas");
            contract_ok;
            case_end;
        end

        if (run_this("T-I-RAM-003")) begin
            // Ordem das respostas: 8 requisicoes com enderecos distintos e identificaveis.
            // Esperado: ram_ack devolve os dados na ordem exata de emissao. Bloq.
            case_begin("T-I-RAM-003", "Bloq"); reset_dut;
            for (i = 0; i < 8; i = i + 1) begin
                u_sram.mem_poke(w16(32'h400 + i*4),     16'hA000 + i);
                u_sram.mem_poke(w16(32'h400 + i*4) + 1, 16'hB000 + i);
            end
            axi_read_burst(32'h0000_0400, 4'h3, 8'd7, 2'b01, 3'd2, 0, 0);
            settle;
            check(ack_n == 8, "deveriam ser 8 acks");
            for (i = 0; i < 8; i = i + 1) begin
                check(ack_data[i] === {16'hB000 + i[15:0], 16'hA000 + i[15:0]}, "ram_read_data fora de ordem");
                check(r_data_buf[i] === {16'hB000 + i[15:0], 16'hA000 + i[15:0]}, "rdata AXI fora de ordem");
            end
            contract_ok;
            case_end;
        end

        if (run_this("T-I-RAM-005")) begin
            // Exclusividade leitura/escrita: carga simultanea nos dois canais. Esperado:
            // ram_wr_req e ram_rd nunca no mesmo ciclo (assertiva continua, regra 3). Bloq.
            case_begin("T-I-RAM-005", "Bloq"); reset_dut;
            fill_w(15, 32'hE000_0000);
            fork
                axi_write_burst(32'h0000_1000, 4'h4, 8'd15, 2'b01, 3'd2, 0, 0, 0);
                axi_read_burst (32'h0000_2000, 4'h5, 8'd15, 2'b01, 3'd2, 0, 0);
            join
            settle;
            check(acc_n == 32, "deveriam ser 32 requisicoes (16 + 16)");
            check(ack_n == acc_n, "acks diferente de requisicoes aceitas");
            contract_ok;
            case_end;
        end

        if (run_this("T-I-RAM-006")) begin
            // Sem negacao indefinida: carga continua. Esperado: toda requisicao e aceita em
            // no maximo 50 ciclos (regra 7). Checagem: timeout. Bloq.
            case_begin("T-I-RAM-006", "Bloq"); reset_dut;
            for (n = 0; n < 50; n = n + 1) begin
                fill_w(3, 32'hF000_0000 + n*16);
                fork
                    axi_write_burst(32'h0000_3000 + (n % 8)*16, 4'h6, 8'd3, 2'b01, 3'd2, 0, 0, 0);
                    axi_read_burst (32'h0000_4000 + (n % 8)*16, 4'h7, 8'd3, 2'b01, 3'd2, 0, 0);
                join
            end
            settle;
            check(ack_n == acc_n, "acks diferente de requisicoes aceitas");
            check(max_pend <= 50, "requisicao esperou mais de 50 ciclos por ram_accept");
            $display("INFO: T-I-RAM-006 max_pend=%0d ciclos, %0d requisicoes", max_pend, acc_n);
            contract_ok;
            case_end;
        end

        if (run_this("T-U-RST-005")) begin
            // Conversao de polaridade: varia aresetn. Esperado: rst_i = ~aresetn, sem glitch
            // (mesmo numero de eventos nos dois sinais). Observacao direta. Bloq.
            case_begin("T-U-RST-005", "Bloq"); reset_dut;
            rst_ev_a = 0; rst_ev_w = 0; rst_mismatch = 0;
            for (i = 0; i < 5; i = i + 1) begin
                #(13 + i*7);
                aresetn = 1'b0;
                #(25 + i*3);
                aresetn = 1'b1;
            end
            repeat (3) @(posedge aclk);
            check(rst_mismatch == 0, "rst_i diferente de ~aresetn");
            check(rst_ev_a == rst_ev_w, "numero de eventos diferente (glitch)");
            check(rst_ev_a == 10, "deveriam ser 10 eventos (5 pulsos)");
            case_end;
        end

        final_result("tb_integration_ram_contract_handshake_and_ordering");
        $finish;
    end

    initial begin
        #50_000_000;
        $display("RESULT: FAIL tb_integration_ram_contract_handshake_and_ordering (timeout)");
        $finish;
    end
endmodule
