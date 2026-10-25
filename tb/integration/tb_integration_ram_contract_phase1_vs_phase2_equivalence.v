`timescale 1ns/1ps
// T-I-RAM-007 (VP §3.5): o mesmo roteiro em Fase 1 e Fase 2 deve dar resultados funcionais
// IDENTICOS; so os ciclos diferem. Valida o contrato ram_* como contrato: se as duas
// divergirem funcionalmente, o contrato da MAS §3.2 esta incompleto.
//
// Este arquivo roda UMA fase (parametro PHASE) e grava build/ram007_p<PHASE>.txt com todas as
// respostas observadas. As transacoes sao SEQUENCIAIS (uma de cada vez), para que o resultado
// nao dependa da temporizacao. O alvo "test_i_equiv" do Makefile compila e roda as duas fases e
// compara os arquivos com cmp.
`define AXI4_MASTER_TASKS
module tb_integration_ram_contract_phase1_vs_phase2_equivalence;
    parameter PHASE = 2;
    parameter N_TXN = 300;
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

    `include "tb/common/testbench_case_runner_utils.vh"
    `include "tb/common/axi_master_tasks.vh"
    `include "tb/common/axi4_random_transaction_generator.vh"

    integer fd, t, k, region;
    reg [8*64-1:0] fname;

    initial begin
        $sformat(fname, "build/ram007_p%0d.txt", PHASE);
        fd = $fopen(fname, "w");
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        if (run_this("T-I-RAM-007")) begin
            // Fase 1 e Fase 2 dao resultados funcionais identicos. Estimulo: 300 transacoes
            // sequenciais (burst, strobes, tamanhos, IDs, algumas em erro), semente fixa.
            // Esperado: mesmo arquivo de respostas nas duas fases. Bloq.
            case_begin("T-I-RAM-007", "Bloq");
            gen_seed = 32'h0007_0007;
            g_allow_bad = 1;
            region = 8192;
            for (t = 0; t < N_TXN; t = t + 1) begin
                gen_txn_params(region, 15);
                if (g_is_write) begin
                    gen_write_payload;
                    axi_write_burst(g_addr, g_id, g_len, 2'b01, g_size, 0, 0, 0);
                    $fdisplay(fd, "W id=%0h addr=%08h len=%0d size=%0d bresp=%0d", g_id, g_addr, g_len, g_size, last_bresp);
                end else begin
                    axi_read_burst(g_addr, g_id, g_len, 2'b01, g_size, 0, 0);
                    $fdisplay(fd, "R id=%0h addr=%08h len=%0d size=%0d", g_id, g_addr, g_len, g_size);
                    for (k = 0; k <= g_len; k = k + 1)
                        $fdisplay(fd, "  beat %0d resp=%0d data=%08h", k, r_resp_buf[k], r_data_buf[k]);
                end
            end
            // varredura final da memoria: imagem completa da regiao usada
            for (t = 0; t < region; t = t + 64) begin
                axi_read_burst(t, 4'h0, 8'd15, 2'b01, 3'd2, 0, 0);
                for (k = 0; k <= 15; k = k + 1)
                    $fdisplay(fd, "M %08h %08h", t + k*4, r_data_buf[k]);
            end
            $fclose(fd);
            repeat (10) @(posedge aclk);
            check(chk_errors == 0 && master_errors == 0, "violacao de protocolo AXI");
            check(sram_errors == 0, "violacao de temporizacao da SRAM");
            $display("INFO: T-I-RAM-007 PHASE=%0d gravou %0s", PHASE, fname);
            case_end;
        end

        final_result("tb_integration_ram_contract_phase1_vs_phase2_equivalence");
        $finish;
    end

    initial begin
        #200_000_000;
        $display("RESULT: FAIL tb_integration_ram_contract_phase1_vs_phase2_equivalence (timeout)");
        $finish;
    end
endmodule
