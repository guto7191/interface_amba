`timescale 1ns/1ps
// Sistema: desempenho em ciclos por beat de 32 bits (R-17, decisao D3; VP §3.9):
// T-S-PERF-001..003. T-S-PERF-004 (comparacao Fase 1 x Fase 2) e montado por
// scripts/generate_verification_report.sh a partir das linhas "INFO: T-S-PERF-xxx PHASE=..".
// Os limites sao da Fase 2 (meta de R-17: <= 6 ciclos/beat; meta de projeto: leitura 2,
// escrita 4). Na Fase 1 os valores sao apenas medidos e registrados.
`define TB_NAME "tb_system_throughput_cycles_per_beat"
`define AXI4_MASTER_TASKS
module tb_system_throughput_cycles_per_beat;
    `include "tb/system/system_testbench_harness.vh"

    integer t0, t1, cyc, i;
    integer cpb_x100, mbps;

    initial begin
        reset_system;

        if (run_this("T-S-PERF-001")) begin
            // Ciclos por beat em leitura: burst de leitura len=63, rready sempre alto.
            // Esperado (Fase 2): <= 6 ciclos por beat em regime (meta: 2); o teste FALHA se exceder 6.
            // Checagem: ciclos totais / 64 beats. Ajust.
            sys_begin("T-S-PERF-001", "Ajust");
            for (i = 0; i < 64; i = i + 1) sb_preload_word(32'h0000_1000 + i*4, 32'h2000_0000 + i);
            t0 = cycle_count;
            do_read(32'h0000_1000, 4'h1, 8'd63, 3'd2, 0, 0);
            t1 = cycle_count;
            cyc = t1 - t0;
            cpb_x100 = (cyc * 100) / 64;
            $display("INFO: T-S-PERF-001 PHASE=%0d CYCLES=%0d BEATS=64 CYCLES_PER_BEAT_X100=%0d", PHASE, cyc, cpb_x100);
            if (PHASE == 2) check(cpb_x100 <= 600, "leitura: mais de 6 ciclos por beat (R-17)");
            sys_end(0);
        end

        if (run_this("T-S-PERF-002")) begin
            // Ciclos por beat em escrita: burst de escrita len=63, sem atrasos.
            // Esperado (Fase 2): <= 6 ciclos por beat (meta: 4). Checagem: medicao. Ajust.
            sys_begin("T-S-PERF-002", "Ajust");
            t0 = cycle_count;
            do_write(32'h0000_2000, 4'h1, 8'd63, 3'd2, 32'h2100_0000, 0, 0, 0);
            t1 = cycle_count;
            cyc = t1 - t0;
            cpb_x100 = (cyc * 100) / 64;
            $display("INFO: T-S-PERF-002 PHASE=%0d CYCLES=%0d BEATS=64 CYCLES_PER_BEAT_X100=%0d", PHASE, cyc, cpb_x100);
            if (PHASE == 2) check(cpb_x100 <= 600, "escrita: mais de 6 ciclos por beat (R-17)");
            sys_end(0);
        end

        if (run_this("T-S-PERF-003")) begin
            // Vazao agregada: ~1000 beats mistos (63 bursts de 16 beats, escrita e leitura
            // alternadas). Esperado (Fase 2): >= 33 MB/s (equivale a 6 ciclos/beat); registra o
            // valor medido. MB/s = 200 * beats / ciclos (50 MHz, 4 bytes por beat). Ajust.
            sys_begin("T-S-PERF-003", "Ajust");
            for (i = 0; i < 64; i = i + 1) sb_preload_word(32'h0000_3000 + i*4, 32'h2200_0000 + i);
            t0 = cycle_count;
            for (i = 0; i < 63; i = i + 1) begin
                if (i % 2 == 0) do_write(32'h0000_3000 + (i % 4)*32'h40, 4'h1, 8'd15, 3'd2, 32'h2300_0000 + i, 0, 0, 0);
                else            do_read (32'h0000_3000 + (i % 4)*32'h40, 4'h1, 8'd15, 3'd2, 0, 0);
            end
            t1 = cycle_count;
            cyc  = t1 - t0;
            mbps = (200 * 63 * 16) / cyc;
            $display("INFO: T-S-PERF-003 PHASE=%0d CYCLES=%0d BEATS=%0d MB_PER_S=%0d", PHASE, cyc, 63*16, mbps);
            if (PHASE == 2) check(mbps >= 33, "vazao abaixo de 33 MB/s (R-17)");
            sys_end(0);
        end

        final_result("tb_system_throughput_cycles_per_beat");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("RESULT: FAIL tb_system_throughput_cycles_per_beat (timeout)");
        $finish;
    end
endmodule
