`timescale 1ns/1ps
// Fumaca funcional da Fase 1 (sram_controller_baseline) contra o modelo da SRAM.
// Roda os casos funcionais compartilhados com a Fase 2 (sram_controller_functional_cases.vh),
// SEM as checagens de numero de ciclos (a FSM da IP e mais lenta por projeto, MAS §7.1).
// Fora deste TB: T-U-CTL-012 (arcos da FSM nova) e T-U-CTL-013 (depende dos estados da Fase 2).
module tb_unit_sram_controller_baseline_phase1_smoke;

    reg clk = 1'b0, aresetn = 1'b1;
    always #10 clk = ~clk;

    reg  [31:0] ram_addr = 0, ram_write_data = 0;
    reg  [3:0]  ram_wr = 0;
    reg         ram_wr_req = 0, ram_rd = 0;
    wire        ram_accept, ram_ack;
    wire [31:0] ram_read_data;

    wire [31:0] sram_address;
    wire [15:0] sram_data_out, sram_data_in;
    wire [1:0]  sram_be_n;
    wire        sram_data_out_en, sram_oe_n, sram_we_n, sram_cs_n;
    wire        sram_lb_n = sram_be_n[0];    // MAS §3.3: bit 0 da IP = byte baixo
    wire        sram_ub_n = sram_be_n[1];
    wire [19:0] SRAM_ADDR;
    wire [15:0] SRAM_DQ;
    wire        SRAM_OE_N, SRAM_WE_N, SRAM_LB_N, SRAM_UB_N, SRAM_CE_N;

    // esperas em 1 (MAS §6.2, L-05)
    sram_controller_baseline dut (
        .clk_i(clk), .rst_i(~aresetn),
        .ram_addr_i(ram_addr), .ram_wr_i(ram_wr), .ram_wr_req_i(ram_wr_req), .ram_rd_i(ram_rd),
        .ram_write_data_i(ram_write_data), .sram_data_in_i(sram_data_in),
        .ram_accept_o(ram_accept), .ram_ack_o(ram_ack), .ram_read_data_o(ram_read_data),
        .sram_address_o(sram_address), .sram_data_out_o(sram_data_out),
        .sram_data_out_en_o(sram_data_out_en), .sram_oe_n_o(sram_oe_n), .sram_cs_n_o(sram_cs_n),
        .sram_be_n_o(sram_be_n), .sram_we_n_o(sram_we_n));
    defparam dut.WRITE_WAIT_CYCLES = 4'd1;
    defparam dut.READ_WAIT_CYCLES  = 4'd1;
    defparam dut.WRITE_HOLD_CYCLES = 4'd1;

    sram_io_buffer u_iob (
        .addr_i(sram_address[19:0]), .data_out_i(sram_data_out), .data_out_en_i(sram_data_out_en),
        .data_in_o(sram_data_in), .oe_n_i(sram_oe_n), .we_n_i(sram_we_n),
        .lb_n_i(sram_lb_n), .ub_n_i(sram_ub_n), .ce_n_i(sram_cs_n),
        .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_CE_N(SRAM_CE_N));

    wire [31:0] sram_errors, sram_access_count, sram_we_pulses;
    sram_is61wv102416_behavioral_model u_sram (
        .addr(SRAM_ADDR), .dq(SRAM_DQ), .ce_n(SRAM_CE_N), .oe_n(SRAM_OE_N), .we_n(SRAM_WE_N),
        .lb_n(SRAM_LB_N), .ub_n(SRAM_UB_N), .sample_clk(clk),
        .errors(sram_errors), .access_count(sram_access_count), .we_pulse_count(sram_we_pulses));

    `include "tb/common/testbench_case_runner_utils.vh"
    `include "tb/unit/sram_controller_functional_cases.vh"

    task reset_dut;
        begin
            aresetn <= 1'b0;
            ram_wr_req <= 1'b0; ram_rd <= 1'b0; ram_wr <= 4'b0;
            repeat (3) @(posedge clk);
            aresetn <= 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        #1 aresetn = 1'b0;
        repeat (3) @(posedge clk);
        aresetn <= 1'b1;
        repeat (2) @(posedge clk);

        if (run_this("T-U-CTL-001")) t_u_ctl_001;
        if (run_this("T-U-CTL-002")) t_u_ctl_002;
        if (run_this("T-U-CTL-003")) t_u_ctl_003;
        if (run_this("T-U-CTL-004")) t_u_ctl_004;
        if (run_this("T-U-CTL-005")) t_u_ctl_005;
        if (run_this("T-U-CTL-006")) t_u_ctl_006;
        if (run_this("T-U-CTL-007")) t_u_ctl_007;
        if (run_this("T-U-CTL-008")) t_u_ctl_008;
        if (run_this("T-U-CTL-009")) t_u_ctl_009;
        if (run_this("T-U-CTL-010")) t_u_ctl_010;
        if (run_this("T-U-CTL-011")) t_u_ctl_011;

        final_result("tb_unit_sram_controller_baseline_phase1_smoke");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_unit_sram_controller_baseline_phase1_smoke (timeout)");
        $finish;
    end
endmodule
