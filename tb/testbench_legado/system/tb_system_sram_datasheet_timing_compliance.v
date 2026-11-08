`timescale 1ns/1ps
// Sistema: conformidade com a temporizacao da folha de dados da SRAM (R-12; VP §3.10):
// T-S-SRAM-001..005. Compilado com SRAM_T_AA = 12.0 (alvo test_s_sram_pessimistic), o mesmo
// arquivo faz o T-S-SRAM-006 (margem com temporizacao pessimista).
// Cada caso exige que as assertivas A-SRAM do modelo NAO disparem.
`define TB_NAME "tb_system_sram_datasheet_timing_compliance"
`define AXI4_MASTER_TASKS
module tb_system_sram_datasheet_timing_compliance;
    `include "system/system_testbench_harness.vh"

    integer i, c01, c02, c03, c04, c05;

    task snap_counts;
        begin
            c01 = u_sram.cnt_a01; c02 = u_sram.cnt_a02; c03 = u_sram.cnt_a03;
            c04 = u_sram.cnt_a04; c05 = u_sram.cnt_a05;
        end
    endtask

    initial begin
        gen_seed = seed_value;
        reset_system;

        if (run_this("T-S-SRAM-001")) begin
            // Nenhuma violacao em leitura: 100 leituras aleatorias. Esperado: zero disparos de
            // A-SRAM-05 (amostragem antes de tAA). Checagem: contador do modelo. Bloq.
            sys_begin("T-S-SRAM-001", "Bloq");
            snap_counts;
            for (i = 0; i < 100; i = i + 1) begin
                g_allow_bad = 0;
                gen_txn_params(8192, 3);
                do_read(g_addr & 32'hFFFF_FFFC, i[3:0], 8'd0, 3'd2, 0, 0);
            end
            check(u_sram.cnt_a05 == c05, "A-SRAM-05 disparou (leitura amostrada antes de tAA)");
            sys_end(0);
        end

        if (run_this("T-S-SRAM-002")) begin
            // Nenhuma violacao em escrita: 100 escritas aleatorias. Esperado: zero disparos de
            // A-SRAM-01 a 04. Checagem: contadores. Bloq.
            sys_begin("T-S-SRAM-002", "Bloq");
            snap_counts;
            for (i = 0; i < 100; i = i + 1) begin
                g_allow_bad = 0;
                gen_txn_params(8192, 3);
                do_write(g_addr & 32'hFFFF_FFFC, i[3:0], 8'd0, 3'd2, {$random(gen_seed)}, 0, 0, 0);
            end
            check(u_sram.cnt_a01 == c01 && u_sram.cnt_a02 == c02 && u_sram.cnt_a03 == c03 &&
                  u_sram.cnt_a04 == c04, "A-SRAM-01..04 dispararam");
            sys_end(0);
        end

        if (run_this("T-S-SRAM-003")) begin
            // Pulso de WE_N suficiente: escritas em regime de burst (len=31). Esperado: todo
            // pulso >= tPWE1 (8 ns). Checagem: A-SRAM-01. Bloq.
            sys_begin("T-S-SRAM-003", "Bloq");
            snap_counts;
            do_write(32'h0000_1000, 4'h1, 8'd31, 3'd2, 32'h3000_0000, 0, 0, 0);
            check(u_sram.cnt_a01 == c01, "A-SRAM-01 disparou (pulso de WE_N curto)");
            $display("INFO: T-S-SRAM-003 PHASE=%0d pulsos de WE_N=%0d, violacoes de largura=%0d",
                     PHASE, u_sram.we_pulse_count, u_sram.cnt_a01 - c01);
            sys_end(0);
        end

        if (run_this("T-S-SRAM-004")) begin
            // Setup de dado suficiente: escritas com dado mudando entre beats (0x5555AAAA /
            // 0xAAAA5555). Esperado: dado estavel por >= tSD (6 ns) antes da subida de we_n.
            // Checagem: A-SRAM-03. Bloq.
            sys_begin("T-S-SRAM-004", "Bloq");
            snap_counts;
            for (i = 0; i < 32; i = i + 1) begin
                w_data_buf[i] = (i % 2) ? 32'hAAAA_5555 : 32'h5555_AAAA;
                w_strb_buf[i] = 4'b1111;
            end
            axi_write_burst(32'h0000_1100, 4'h1, 8'd31, 2'b01, 3'd2, 0, 0, 0);
            check(u_sram.cnt_a03 == c03, "A-SRAM-03 disparou (setup de dado curto)");
            sys_end(0);
        end

        if (run_this("T-S-SRAM-005")) begin
            // Endereco estavel durante a escrita: burst de escrita. Esperado: o endereco nao
            // muda com we_n ativo. Checagem: A-SRAM-04. Bloq.
            sys_begin("T-S-SRAM-005", "Bloq");
            snap_counts;
            do_write(32'h0000_1200, 4'h1, 8'd31, 3'd2, 32'h3100_0000, 0, 0, 0);
            check(u_sram.cnt_a04 == c04, "A-SRAM-04 disparou (endereco mudou durante o pulso)");
            sys_end(0);
        end

        final_result("tb_system_sram_datasheet_timing_compliance");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("RESULT: FAIL tb_system_sram_datasheet_timing_compliance (timeout)");
        $finish;
    end
endmodule
