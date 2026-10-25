`timescale 1ns/1ps
// Sistema: arbitragem leitura/escrita (decisao D5, nao normativa; VP §3.8): T-S-ARB-001..003.
// Estes casos verificam uma DECISAO DE PROJETO, nao a norma (severidade ajustavel).
`define TB_NAME "tb_system_read_write_round_robin_arbitration"
`define AXI4_MASTER_TASKS
module tb_system_read_write_round_robin_arbitration;
    `include "tb/system/system_testbench_harness.vh"

    // ---------------- monitor das requisicoes aceitas pela controladora ----------------
    // sequencia de sentidos: 'W' ou 'R', na ordem em que ram_* aceita comandos
    wire req_accept_w = dut.u_axi_sram.ram_accept_w &
                        (dut.u_axi_sram.ram_rd_w | dut.u_axi_sram.ram_wr_req_w);
    reg [7:0] dir_seq [0:4095];
    integer   dir_n = 0;
    always @(posedge aclk) begin
        if (!aresetn) dir_n = 0;
        else if (req_accept_w && dir_n < 4096) begin
            dir_seq[dir_n] = dut.u_axi_sram.ram_rd_w ? "R" : "W";
            dir_n = dir_n + 1;
        end
    end

    integer done_w, done_r, snap_w, snap_r, snap_taken;
    integer i, n, run, max_run;
    integer t_ar, t_lat;
    integer t_w_end;

    always @(posedge aclk) begin
        if (!snap_taken && (done_w + done_r) >= 100) begin
            snap_taken = 1; snap_w = done_w; snap_r = done_r;
        end
    end

    initial begin
        done_w = 0; done_r = 0; snap_taken = 0; snap_w = 0; snap_r = 0;
        reset_system;

        if (run_this("T-S-ARB-001")) begin
            // Ausencia de inanicao: carga saturada simultanea, 100 escritas e 100 leituras de
            // len=0, ambos os canais sempre com VALID alto. Esperado: AMBOS os sentidos
            // completam e nenhum fica abaixo de 40% das transacoes concluidas. Checagem:
            // contagem por sentido. Ajust.
            sys_begin("T-S-ARB-001", "Ajust");
            done_w = 0; done_r = 0; snap_taken = 0;
            for (i = 0; i < 100; i = i + 1) sb_preload_word(32'h0000_2000 + i*4, 32'h0E00_0000 + i);
            fork
                begin : escritas
                    for (n = 0; n < 100; n = n + 1) begin
                        do_write(32'h0000_1000 + n*4, 4'h1, 8'd0, 3'd2, 32'h0F00_0000 + n, 0, 0, 0);
                        done_w = done_w + 1;
                    end
                end
                begin : leituras
                    for (i = 0; i < 100; i = i + 1) begin
                        do_read(32'h0000_2000 + i*4, 4'h2, 8'd0, 3'd2, 0, 0);
                        done_r = done_r + 1;
                    end
                end
            join
            $display("INFO: T-S-ARB-001 nas primeiras 100 conclusoes: escritas=%0d leituras=%0d", snap_w, snap_r);
            check(done_w == 100 && done_r == 100, "algum sentido nao completou (inanicao)");
            check(snap_w >= 40 && snap_r >= 40, "um dos sentidos ficou abaixo de 40%");
            sys_end(0);
        end

        if (run_this("T-S-ARB-002")) begin
            // Latencia de cauda sob burst longo: burst de escrita len=255 em curso; leitura
            // isolada chega no meio. Esperado: a leitura E atendida (apos o fim do burst, pois a
            // arbitragem e por comando, MAS §5.4.4). MEDE a latencia e a registra; nao reprova
            // por latencia alta. Checagem: medicao de ciclos entre arvalid e rvalid. Ajust.
            sys_begin("T-S-ARB-002", "Ajust");
            sb_preload_word(32'h0000_6000, 32'h1111_2222);
            fork
                begin : escrita_longa
                    do_write(32'h0000_4000, 4'h1, 8'd255, 3'd2, 32'h1000_0000, 0, 0, 0);
                    t_w_end = cycle_count;
                end
                begin : leitura_isolada
                    repeat (500) @(posedge aclk);             // no meio da escrita longa
                    t_ar = cycle_count;
                    do_read(32'h0000_6000, 4'h2, 8'd0, 3'd2, 0, 0);
                    t_lat = cycle_count - t_ar;
                end
            join
            check(r_data_buf[0] === 32'h1111_2222, "a leitura isolada nao foi atendida corretamente");
            $display("INFO: T-S-ARB-002 PHASE=%0d LATENCY=%0d ciclos (leitura emitida no ciclo 500 de um burst de 256 beats)", PHASE, t_lat);
            sys_end(0);
        end

        if (run_this("T-S-ARB-003")) begin
            // Alternancia sob carga leve: leituras e escritas isoladas alternadas. Esperado:
            // nenhum sentido e postergado mais de um comando. Checagem: observacao da sequencia
            // de comandos aceitos por ram_*. Ajust.
            sys_begin("T-S-ARB-003", "Ajust");
            for (i = 0; i < 10; i = i + 1) sb_preload_word(32'h0000_2100 + i*4, 32'h1200_0000 + i);
            fork
                begin
                    for (n = 0; n < 10; n = n + 1)
                        do_write(32'h0000_1100 + n*4, 4'h3, 8'd0, 3'd2, 32'h1300_0000 + n, 0, 0, 0);
                end
                begin
                    for (i = 0; i < 10; i = i + 1)
                        do_read(32'h0000_2100 + i*4, 4'h4, 8'd0, 3'd2, 0, 0);
                end
            join
            run = 1; max_run = 1;
            for (i = 1; i < dir_n; i = i + 1) begin
                if (dir_seq[i] == dir_seq[i-1]) run = run + 1; else run = 1;
                if (run > max_run) max_run = run;
            end
            $write("INFO: T-S-ARB-003 sequencia de comandos aceitos: ");
            for (i = 0; i < dir_n; i = i + 1) $write("%0s", dir_seq[i]);
            $write("  (maior sequencia do mesmo sentido = %0d)\n", max_run);
            check(dir_n == 20, "deveriam ser 20 comandos aceitos");
            check(max_run <= 2, "um sentido foi postergado por mais de um comando");
            sys_end(0);
        end

        final_result("tb_system_read_write_round_robin_arbitration");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("RESULT: FAIL tb_system_read_write_round_robin_arbitration (timeout)");
        $finish;
    end
endmodule
