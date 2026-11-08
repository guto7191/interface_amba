`timescale 1ns/1ps
// Teste unitario do sram_controller (Fase 2) contra o modelo comportamental da SRAM.
// VP §3.4: T-U-CTL-001..013. Casos 001..011 vem de sram_controller_functional_cases.vh.
`define CHECK_CYCLES
module tb_unit_sram_controller_pipelined_phase2;

    reg clk = 1'b0, aresetn = 1'b1;
    always #10 clk = ~clk;                               // 50 MHz

    // driver do contrato ram_*
    reg  [31:0] ram_addr = 0, ram_write_data = 0;
    reg  [3:0]  ram_wr = 0;
    reg         ram_wr_req = 0, ram_rd = 0;
    wire        ram_accept, ram_ack;
    wire [31:0] ram_read_data;

    // lado da SRAM
    wire [19:0] sram_addr;
    wire [15:0] sram_data_out, sram_data_in;
    wire        sram_data_out_en, sram_oe_n, sram_we_n, sram_lb_n, sram_ub_n, sram_ce_n;
    wire [19:0] SRAM_ADDR;
    wire [15:0] SRAM_DQ;
    wire        SRAM_OE_N, SRAM_WE_N, SRAM_LB_N, SRAM_UB_N, SRAM_CE_N;

    sram_controller dut (
        .aclk(clk), .aresetn(aresetn),
        .ram_addr(ram_addr), .ram_wr(ram_wr), .ram_wr_req(ram_wr_req), .ram_rd(ram_rd),
        .ram_size(3'd2), .ram_write_data(ram_write_data),
        .ram_accept(ram_accept), .ram_ack(ram_ack), .ram_read_data(ram_read_data),
        .sram_addr_o(sram_addr), .sram_data_out_o(sram_data_out),
        .sram_data_out_en_o(sram_data_out_en), .sram_data_in_i(sram_data_in),
        .sram_oe_n_o(sram_oe_n), .sram_we_n_o(sram_we_n),
        .sram_lb_n_o(sram_lb_n), .sram_ub_n_o(sram_ub_n), .sram_ce_n_o(sram_ce_n));

    sram_io_buffer u_iob (
        .addr_i(sram_addr), .data_out_i(sram_data_out), .data_out_en_i(sram_data_out_en),
        .data_in_o(sram_data_in), .oe_n_i(sram_oe_n), .we_n_i(sram_we_n),
        .lb_n_i(sram_lb_n), .ub_n_i(sram_ub_n), .ce_n_i(sram_ce_n),
        .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_CE_N(SRAM_CE_N));

    wire [31:0] sram_errors, sram_access_count, sram_we_pulses;
    sram_is61wv102416_behavioral_model u_sram (
        .addr(SRAM_ADDR), .dq(SRAM_DQ), .ce_n(SRAM_CE_N), .oe_n(SRAM_OE_N), .we_n(SRAM_WE_N),
        .lb_n(SRAM_LB_N), .ub_n(SRAM_UB_N), .sample_clk(clk),
        .errors(sram_errors), .access_count(sram_access_count), .we_pulse_count(sram_we_pulses));

    `include "common/testbench_case_runner_utils.vh"
    `include "common/fsm_transition_coverage_monitor.vh"
    `include "unit/sram_controller_functional_cases.vh"

    task reset_dut;
        begin
            aresetn <= 1'b0;
            ram_wr_req <= 1'b0; ram_rd <= 1'b0; ram_wr <= 4'b0;
            repeat (3) @(posedge clk);
            aresetn <= 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    // cobertura de arcos da FSM (MAS §5.5.2): 14 arcos legais
    localparam S_IDLE = 0, S_RD_LOW = 1, S_RD_HIGH = 2, S_WR_LOW = 3,
               S_WR_LOW_HOLD = 4, S_WR_HIGH = 5, S_WR_HIGH_HOLD = 6;
    initial begin
        fsm_arc_legal(0, S_IDLE,         S_IDLE);
        fsm_arc_legal(0, S_IDLE,         S_RD_LOW);
        fsm_arc_legal(0, S_IDLE,         S_WR_LOW);
        fsm_arc_legal(0, S_IDLE,         S_WR_HIGH);
        fsm_arc_legal(0, S_RD_LOW,       S_RD_HIGH);
        fsm_arc_legal(0, S_RD_HIGH,      S_RD_LOW);
        fsm_arc_legal(0, S_RD_HIGH,      S_IDLE);
        fsm_arc_legal(0, S_WR_LOW,       S_WR_LOW_HOLD);
        fsm_arc_legal(0, S_WR_LOW_HOLD,  S_WR_HIGH);
        fsm_arc_legal(0, S_WR_LOW_HOLD,  S_IDLE);
        fsm_arc_legal(0, S_WR_HIGH,      S_WR_HIGH_HOLD);
        fsm_arc_legal(0, S_WR_HIGH_HOLD, S_WR_LOW);
        fsm_arc_legal(0, S_WR_HIGH_HOLD, S_WR_HIGH);
        fsm_arc_legal(0, S_WR_HIGH_HOLD, S_IDLE);
    end
    always @(posedge clk) fsm_arc_sample(0, {5'b0, dut.state_q});

    task t_u_ctl_012;   // Cobertura de transicoes
        begin
            // Objetivo: exercitar todos os arcos da FSM. Estimulo: sequencia roteirizada.
            // Esperado: toda transicao da tabela da MAS §5.5.2 visitada. Bloq.
            case_begin("T-U-CTL-012", "Bloq");
            reset_dut; mon_clear;
            ram_read(32'h800);                                   // IDLE->RD_LOW->RD_HIGH->IDLE
            wait_acks(1);
            ram_read(32'h804); ram_read(32'h808);                // RD_HIGH->RD_LOW (pipeline)
            wait_acks(3);
            ram_write(32'h810, 4'b1111, 32'h1);                  // IDLE->WR_LOW->..->WR_HIGH_HOLD->IDLE
            wait_acks(4);
            ram_write(32'h814, 4'b0011, 32'h2);                  // WR_LOW_HOLD->IDLE
            wait_acks(5);
            ram_write(32'h818, 4'b1100, 32'h3);                  // IDLE->WR_HIGH
            wait_acks(6);
            ram_write(32'h81C, 4'b1111, 32'h4);                  // WR_HIGH_HOLD->WR_LOW
            ram_write(32'h820, 4'b1111, 32'h5);
            wait_acks(8);
            ram_write(32'h824, 4'b1111, 32'h6);                  // WR_HIGH_HOLD->WR_HIGH
            ram_write(32'h828, 4'b1100, 32'h7);
            wait_acks(10);
            ram_write(32'h82C, 4'b0000, 32'h8);                  // IDLE->IDLE (escrita nula)
            wait_acks(11);
            repeat (5) @(posedge clk);
            fsm_arc_missing = 0;
            fsm_arc_report(0, "sram_controller");
            check(fsm_arc_missing == 0, "arcos da FSM nao visitados");
            case_end;
        end
    endtask

    task t_u_ctl_013;   // Reset no meio do acesso
        begin
            // Objetivo: reset durante WR_LOW. Estimulo: reset 12 ns apos WE_N descer em
            // WR_LOW. Esperado: we_n, oe_n e data_out_en inativos; SRAM nao
            // corrompida alem do alvo; A-SRAM-01 limpa. Bloq.
            case_begin("T-U-CTL-013", "Bloq");
            reset_dut; mon_clear;
            u_sram.mem_poke(w16(32'h900),     16'h1111);
            u_sram.mem_poke(w16(32'h900) + 1, 16'h2222);
            u_sram.mem_poke(w16(32'h908),     16'h3333);
            ram_write(32'h900, 4'b1111, 32'hAAAA_BBBB);
            while (dut.state_q != 3'd3) @(negedge clk);          // 10 ns dentro de S_WR_LOW
            #2;                                                   // 12 ns de pulso (>= tPWE1)
            check(dut.state_q == 3'd3 && sram_we_n === 1'b0, "reset deveria cair com WE_N ativo");
            aresetn <= 1'b0;
            #1;
            check(sram_we_n === 1'b1 && sram_oe_n === 1'b1 && sram_data_out_en === 1'b0,
                  "pinos de controle deveriam ficar inativos no reset");
            repeat (3) @(posedge clk);
            aresetn <= 1'b1;
            repeat (3) @(posedge clk);
            check(u_sram.mem_peek(w16(32'h908)) === 16'h3333, "posicao nao relacionada foi corrompida");
            check(u_sram.mem_peek(w16(32'h900) + 1) === 16'h2222, "metade alta nao deveria ter sido escrita");
            check(u_sram.cnt_a01 == 0, "A-SRAM-01 disparou");
            check(dq_x_cycles == 0, "X em SRAM_DQ");
            case_end;
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
        if (run_this("T-U-CTL-012")) t_u_ctl_012;
        if (run_this("T-U-CTL-013")) t_u_ctl_013;

        final_result("tb_unit_sram_controller_pipelined_phase2");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_unit_sram_controller_pipelined_phase2 (timeout)");
        $finish;
    end
endmodule
