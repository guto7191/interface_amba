`timescale 1ns/1ps
// Teste unitario do sram_io_buffer (MAS §5.2) e do mapeamento LB_N/UB_N (VP §3.2).
// T-U-IOB-001..003 testam o buffer sozinho; T-U-IOB-004..006 usam controladora + modelo
// (e fecham a pendencia P-01 da MAS).
module tb_unit_sram_io_buffer_tristate_and_lane_mapping;

    reg clk = 1'b0, aresetn = 1'b1;
    always #10 clk = ~clk;

    // ---------------- buffer isolado (IOB-001..003) ----------------
    reg  [15:0] iso_out = 16'h0000;
    reg         iso_out_en = 1'b0;
    wire [15:0] iso_in;
    wire [15:0] ISO_DQ;
    reg  [15:0] ext_val = 16'h0000;
    reg         ext_en = 1'b0;                       // driver externo (faz o papel da SRAM)
    assign ISO_DQ = ext_en ? ext_val : 16'bz;

    sram_io_buffer u_iob_iso (
        .addr_i(20'h0), .data_out_i(iso_out), .data_out_en_i(iso_out_en), .data_in_o(iso_in),
        .oe_n_i(1'b1), .we_n_i(1'b1), .lb_n_i(1'b1), .ub_n_i(1'b1), .ce_n_i(1'b0),
        .SRAM_ADDR(), .SRAM_DQ(ISO_DQ), .SRAM_OE_N(), .SRAM_WE_N(),
        .SRAM_LB_N(), .SRAM_UB_N(), .SRAM_CE_N());

    // ---------------- controladora + buffer + modelo (IOB-004..006) ----------------
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

    initial begin
        #1 aresetn = 1'b0;
        repeat (3) @(posedge clk);
        aresetn <= 1'b1;
        repeat (2) @(posedge clk);

        if (run_this("T-U-IOB-001")) begin
            // Objetivo: alta impedancia em leitura. Estimulo: data_out_en = 0 e a "SRAM" dirige.
            // Esperado: o buffer nao dirige DQ; data_in reflete o estimulo externo. Bloq.
            case_begin("T-U-IOB-001", "Bloq");
            iso_out = 16'hFFFF; iso_out_en = 1'b0;
            ext_val = 16'h1234; ext_en = 1'b1; #5;
            check(iso_in === 16'h1234, "data_in deveria refletir o valor imposto externamente");
            ext_en = 1'b0; #5;
            check(ISO_DQ === 16'bz, "DQ deveria estar em Z com data_out_en = 0");
            case_end;
        end

        if (run_this("T-U-IOB-002")) begin
            // Objetivo: dirige em escrita. Estimulo: data_out_en = 1, data_out = A5A5.
            // Esperado: SRAM_DQ = A5A5. Bloq.
            case_begin("T-U-IOB-002", "Bloq");
            iso_out = 16'hA5A5; iso_out_en = 1'b1; #5;
            check(ISO_DQ === 16'hA5A5, "DQ deveria valer A5A5");
            iso_out_en = 1'b0;
            case_end;
        end

        if (run_this("T-U-IOB-003")) begin
            // Objetivo: alta impedancia em idle. Estimulo: sem acesso ativo.
            // Esperado: SRAM_DQ = Z. Bloq.
            case_begin("T-U-IOB-003", "Bloq");
            iso_out_en = 1'b0; ext_en = 1'b0; #5;
            check(ISO_DQ === 16'bz, "DQ deveria estar em Z em idle");
            case_end;
        end

        if (run_this("T-U-IOB-004")) begin
            // Objetivo: sem contencao no turnaround. Estimulo: leitura -> escrita com o modelo
            // dirigindo. Esperado: nenhum ciclo com os dois lados dirigindo; >= 1 ciclo entre
            // OE_N subir e data_out_en subir. Checagem: A-SRAM-06 e deteccao de X. Bloq.
            case_begin("T-U-IOB-004", "Bloq");
            reset_dut; mon_clear;
            u_sram.mem_poke(w16(32'h100), 16'h5A5A);
            ram_read(32'h100);
            ram_write(32'h104, 4'b1111, 32'h1357_9BDF);
            wait_acks(2);
            check(t_dout_en_rise - t_oe_rise >= 20.0, "menos de 1 ciclo de folga no turnaround");
            check(u_sram.cnt_a06 == 0, "A-SRAM-06 (contencao) disparou");
            check(dq_x_cycles == 0, "X em SRAM_DQ");
            case_end;
        end

        if (run_this("T-U-IOB-005")) begin
            // Objetivo: mapeamento LB/UB, byte baixo (pendencia P-01). Estimulo: wstrb = 0001,
            // dado 000000FF. Esperado: so mem[addr][7:0] alterado; [15:8] preservado. Bloq.
            case_begin("T-U-IOB-005", "Bloq");
            reset_dut; mon_clear;
            u_sram.mem_poke(w16(32'h200), 16'h1234);
            ram_write(32'h200, 4'b0001, 32'h0000_00FF);
            wait_acks(1);
            check(u_sram.mem_peek(w16(32'h200)) === 16'h12FF, "so o byte [7:0] deveria mudar (LB/UB trocados?)");
            case_end;
        end

        if (run_this("T-U-IOB-006")) begin
            // Objetivo: mapeamento LB/UB, byte alto. Estimulo: wstrb = 0010, dado 0000FF00.
            // Esperado: so mem[addr][15:8] alterado. Bloq.
            case_begin("T-U-IOB-006", "Bloq");
            reset_dut; mon_clear;
            u_sram.mem_poke(w16(32'h210), 16'h1234);
            ram_write(32'h210, 4'b0010, 32'h0000_FF00);
            wait_acks(1);
            check(u_sram.mem_peek(w16(32'h210)) === 16'hFF34, "so o byte [15:8] deveria mudar (LB/UB trocados?)");
            case_end;
        end

        final_result("tb_unit_sram_io_buffer");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("RESULT: FAIL tb_unit_sram_io_buffer (timeout)");
        $finish;
    end
endmodule
