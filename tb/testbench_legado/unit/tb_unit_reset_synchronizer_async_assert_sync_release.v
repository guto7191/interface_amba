`timescale 1ns/1ps
// Teste unitario do reset_synchronizer (MAS §5.1, VP §3.1).
// T-U-RST-001..003. T-U-RST-004 (reset durante operacao) usa a controladora e o modelo da SRAM.
module tb_unit_reset_synchronizer_async_assert_sync_release;

    reg  clk = 1'b0;
    reg  clk_en = 1'b1;               // permite parar o clock (T-U-RST-001)
    reg  async_reset_n = 1'b1;
    wire aresetn;

    always #10 if (clk_en) clk = ~clk;   // 50 MHz

    reset_synchronizer dut (.clk(clk), .async_reset_n(async_reset_n), .aresetn(aresetn));

    // controladora + buffer + modelo, para T-U-RST-004 (reset durante operacao)
    reg  [31:0] ram_addr = 0, ram_write_data = 0;
    reg  [3:0]  ram_wr = 0;
    reg         ram_wr_req = 0, ram_rd = 0;
    wire        ram_accept, ram_ack;
    wire [31:0] ram_read_data;
    wire [19:0] sram_addr;
    wire [15:0] sram_data_out, sram_data_in;
    wire        sram_data_out_en, sram_oe_n, sram_we_n, sram_lb_n, sram_ub_n, sram_ce_n;
    wire [19:0] SRAM_ADDR;
    wire [15:0] SRAM_DQ;
    wire        SRAM_OE_N, SRAM_WE_N, SRAM_LB_N, SRAM_UB_N, SRAM_CE_N;
    wire [31:0] sram_errors, sram_access_count, sram_we_pulses;

    sram_controller ctl (
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
    sram_is61wv102416_behavioral_model u_sram (
        .addr(SRAM_ADDR), .dq(SRAM_DQ), .ce_n(SRAM_CE_N), .oe_n(SRAM_OE_N), .we_n(SRAM_WE_N),
        .lb_n(SRAM_LB_N), .ub_n(SRAM_UB_N), .sample_clk(clk),
        .errors(sram_errors), .access_count(sram_access_count), .we_pulse_count(sram_we_pulses));

    `include "common/testbench_case_runner_utils.vh"

    integer edges = 0;                // bordas de subida de clk desde o inicio
    always @(posedge clk) edges = edges + 1;

    reg saw_fall = 1'b0;              // aresetn caiu (T-U-RST-003)
    always @(negedge aresetn) saw_fall = 1'b1;

    integer edges_mark, n;

    // mantem o reset por alguns ciclos e solta, deixando aresetn estabilizar em 1
    task reset_and_settle;
        begin
            clk_en = 1'b1;
            async_reset_n = 1'b0;
            repeat (3) @(posedge clk);
            async_reset_n = 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        if (run_this("T-U-RST-001")) begin
            // Objetivo: o assert e assincrono. Estimulo: clock parado; KEY[0] -> 0.
            // Esperado: aresetn -> 0 sem esperar borda de clock. Checagem: observacao direta. Bloq.
            case_begin("T-U-RST-001", "Bloq");
            reset_and_settle;
            check(aresetn === 1'b1, "aresetn deveria estar em 1 antes do teste");
            clk_en = 1'b0;
            #100;
            edges_mark = edges;
            async_reset_n = 1'b0;
            #1;
            check(aresetn === 1'b0, "aresetn nao caiu com o clock parado");
            check(edges == edges_mark, "houve borda de clock durante o assert");
            async_reset_n = 1'b1;
            case_end;
        end

        if (run_this("T-U-RST-002")) begin
            // Objetivo: o deassert e sincrono e atrasado em 2 ciclos. Estimulo: clock ativo;
            // KEY[0] -> 1 entre bordas. Esperado: aresetn -> 1 exatamente 2 bordas depois.
            case_begin("T-U-RST-002", "Bloq");
            clk_en = 1'b1;
            async_reset_n = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk); #3;
            async_reset_n = 1'b1;
            n = 0;
            while (aresetn !== 1'b1 && n < 10) begin
                @(posedge clk); #1;
                n = n + 1;
            end
            check(n == 2, "deassert deveria levar exatamente 2 bordas");
            case_end;
        end

        if (run_this("T-U-RST-003")) begin
            // Objetivo: pulso mais curto que um ciclo e capturado. Estimulo: KEY[0] -> 0 por
            // 5 ns (periodo 20 ns), fora da borda. Esperado: aresetn -> 0; reset nao e perdido.
            case_begin("T-U-RST-003", "Bloq");
            reset_and_settle;
            saw_fall = 1'b0;
            @(posedge clk); #7;
            async_reset_n = 1'b0;
            #5;
            async_reset_n = 1'b1;
            #1;
            check(saw_fall, "o pulso de 5 ns foi perdido");
            n = 0;
            while (aresetn !== 1'b1 && n < 10) begin
                @(posedge clk); #1;
                n = n + 1;
            end
            check(n == 2, "apos o pulso, aresetn deveria voltar em 2 bordas");
            case_end;
        end

        if (run_this("T-U-RST-004")) begin
            // Objetivo: reset durante a operacao. Estimulo: com a FSM em S_WR_LOW, afirma o
            // reset (12 ns apos WE_N descer, >= tPWE1). Esperado: todos os registradores
            // observaveis voltam ao valor inicial. Checagem: comparacao de estado. Bloq.
            case_begin("T-U-RST-004", "Bloq");
            reset_and_settle;
            ram_addr <= 32'h100; ram_wr <= 4'b1111; ram_wr_req <= 1'b1;
            ram_write_data <= 32'hAAAA_BBBB;
            @(posedge clk);
            while (!ram_accept) @(posedge clk);
            ram_wr_req <= 1'b0; ram_wr <= 4'b0000;
            while (ctl.state_q != 3'd3) @(negedge clk);        // S_WR_LOW, 10 ns dentro
            #2;
            check(sram_we_n === 1'b0, "WE_N deveria estar ativo antes do reset");
            async_reset_n = 1'b0;
            #1;
            check(ctl.state_q === 3'd0, "FSM deveria voltar a S_IDLE");
            check(sram_we_n === 1'b1 && sram_oe_n === 1'b1, "WE_N e OE_N deveriam ficar inativos");
            check(sram_data_out_en === 1'b0, "data_out_en deveria ficar inativo");
            check(ram_ack === 1'b0 && ctl.ack_q === 1'b0, "ack deveria ser zerado");
            check(ctl.wr_q === 4'b0000 && ctl.data_lo_q === 16'h0000, "contexto da requisicao deveria ser zerado");
            check(u_sram.cnt_a01 == 0, "A-SRAM-01 disparou");
            async_reset_n = 1'b1;
            repeat (4) @(posedge clk);
            case_end;
        end

        final_result("tb_unit_reset_synchronizer");
        $finish;
    end

    initial begin
        #1_000_000;
        $display("RESULT: FAIL tb_unit_reset_synchronizer (timeout)");
        $finish;
    end
endmodule
