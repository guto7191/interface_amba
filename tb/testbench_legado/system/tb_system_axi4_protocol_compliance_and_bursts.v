`timescale 1ns/1ps
// Sistema: conformidade AXI4 e bursts (VP §3.6): T-S-AXI-001..015 e T-S-4KB-001.
// DUT completo (de2_115_top) + modelo da SRAM + checker E-01..E-10 + scoreboard. Cada caso
// termina em sys_end: checker, scoreboard e modelo da SRAM sem erros e sem bursts pendentes.
`define TB_NAME "tb_system_axi4_protocol_compliance_and_bursts"
`define AXI4_MASTER_TASKS
module tb_system_axi4_protocol_compliance_and_bursts;
    `include "system/system_testbench_harness.vh"

    integer i, k, p, len_i, e06_base;
    integer t_wlast = 0, t_bfirst = 0;
    reg     b_seen = 1'b0;

    // marca o ciclo do wlast aceito e do primeiro bvalid (T-S-AXI-012)
    always @(posedge aclk) begin
        if (!aresetn) begin b_seen = 1'b0; t_wlast = 0; t_bfirst = 0; end
        else begin
            if (wvalid && wready && wlast) t_wlast = cycle_count;
            if (bvalid && !b_seen) begin b_seen = 1'b1; t_bfirst = cycle_count; end
        end
    end

    // compara os dados lidos com os escritos (buffers w_data_buf -> r_data_buf)
    task check_readback(input [7:0] len, input [255:0] who);
        integer n;
        begin
            for (n = 0; n <= len; n = n + 1)
                check(r_data_buf[n] === w_data_buf[n], "dado lido diferente do escrito");
        end
    endtask

    initial begin
        reset_system;

        if (run_this("T-S-AXI-001")) begin
            // Handshake AW/W/B: escrita simples, len=0, sem atrasos. Esperado: transacao
            // completa; bresp = OKAY. Checagem: checker completo. Bloq.
            sys_begin("T-S-AXI-001", "Bloq");
            do_write(32'h0000_0100, 4'h1, 8'd0, 3'd2, 32'hA1B2_C3D4, 0, 0, 0);
            check(last_bresp === 2'b00, "bresp deveria ser OKAY");
            sys_end(0);
        end

        if (run_this("T-S-AXI-002")) begin
            // Handshake AR/R: leitura simples, len=0. Esperado: rresp = OKAY; rlast = 1. Bloq.
            sys_begin("T-S-AXI-002", "Bloq");
            sb_preload_word(32'h0000_0100, 32'h1234_5678);
            do_read(32'h0000_0100, 4'h1, 8'd0, 3'd2, 0, 0);
            check(r_resp_buf[0] === 2'b00, "rresp deveria ser OKAY");
            check(r_data_buf[0] === 32'h1234_5678, "dado lido incorreto");
            sys_end(0);
        end

        if (run_this("T-S-AXI-003")) begin
            // READY intermitente do mestre: rready/bready oscilando (padrao 1010). Esperado:
            // nenhum dado perdido; sem violacao de estabilidade. Checagem: E-01..E-09; scoreboard. Bloq.
            sys_begin("T-S-AXI-003", "Bloq");
            cov_rdy = 1;
            do_write(32'h0000_0200, 4'h2, 8'd7, 3'd2, 32'h0300_0000, 0, 1, 1);
            do_read (32'h0000_0200, 4'h2, 8'd7, 3'd2, 0, 1);
            check_readback(8'd7, "AXI-003");
            sys_end(0);
        end

        if (run_this("T-S-AXI-004")) begin
            // W antes de AW: wvalid sobe 5 ciclos antes de awvalid (len=3). Esperado: transacao
            // completa (canais independentes). Checagem: checker. Bloq.
            sys_begin("T-S-AXI-004", "Bloq");
            do_write(32'h0000_0300, 4'h3, 8'd3, 3'd2, 32'h0400_0000, 5, 0, 0);
            do_read (32'h0000_0300, 4'h3, 8'd3, 3'd2, 0, 0);
            check_readback(8'd3, "AXI-004");
            sys_end(0);
        end

        if (run_this("T-S-AXI-005")) begin
            // Burst de 2 beats: escrita e leitura com len=1. Esperado: dados corretos; rlast no
            // 2o beat. Checagem: E-02, E-03; scoreboard. Bloq.
            sys_begin("T-S-AXI-005", "Bloq");
            do_write(32'h0000_1000, 4'h4, 8'd1, 3'd2, 32'h0500_0000, 0, 0, 0);
            do_read (32'h0000_1000, 4'h4, 8'd1, 3'd2, 0, 0);
            check_readback(8'd1, "AXI-005");
            sys_end(0);
        end

        if (run_this("T-S-AXI-006")) begin
            // Burst de 4 beats: len=3. Esperado: 4 beats; dados corretos. Checagem: E-02, E-03. Bloq.
            sys_begin("T-S-AXI-006", "Bloq");
            do_write(32'h0000_1100, 4'h4, 8'd3, 3'd2, 32'h0600_0000, 0, 0, 0);
            do_read (32'h0000_1100, 4'h4, 8'd3, 3'd2, 0, 0);
            check_readback(8'd3, "AXI-006");
            sys_end(0);
        end

        if (run_this("T-S-AXI-007")) begin
            // Burst de 16 beats: len=15. Esperado: 16 beats. Checagem: E-02, E-03. Bloq.
            // Repetido com os tres padroes de READY do mestre (cobertura rdy x len=15).
            sys_begin("T-S-AXI-007", "Bloq");
            for (p = 0; p < 3; p = p + 1) begin
                cov_rdy = p;
                do_write(32'h0000_1200 + p*32'h100, 4'h4, 8'd15, 3'd2, 32'h0700_0000 + p, 0, p, p);
                do_read (32'h0000_1200 + p*32'h100, 4'h4, 8'd15, 3'd2, 0, p);
                check_readback(8'd15, "AXI-007");
            end
            sys_end(0);
        end

        if (run_this("T-S-AXI-008")) begin
            // Burst maximo de 256 beats: len=255, endereco alinhado que nao cruza 4 KB.
            // Esperado: 256 beats; rlast no 256o. Checagem: E-02, E-03, E-06. Bloq.
            sys_begin("T-S-AXI-008", "Bloq");
            do_write(32'h0000_2000, 4'h5, 8'd255, 3'd2, 32'h0800_0000, 0, 0, 0);
            do_read (32'h0000_2000, 4'h5, 8'd255, 3'd2, 0, 0);
            check_readback(8'd255, "AXI-008");
            check(chk.cnt_e06 == e06_base, "cruzamento de 4 KB indevido");
            sys_end(0);
        end

        if (run_this("T-S-AXI-009")) begin
            // Bursts consecutivos: 10 bursts de len=7 em sequencia. Esperado: todos completos,
            // sem interferencia entre eles. Checagem: checker; scoreboard. Bloq.
            sys_begin("T-S-AXI-009", "Bloq");
            for (i = 0; i < 10; i = i + 1)
                do_write(32'h0000_3000 + i*32'h20, i[3:0], 8'd7, 3'd2, 32'h0900_0000 + (i << 16), 0, 0, 0);
            for (i = 0; i < 10; i = i + 1) begin
                do_read(32'h0000_3000 + i*32'h20, i[3:0], 8'd7, 3'd2, 0, 0);
                for (k = 0; k < 8; k = k + 1)
                    check(r_data_buf[k] === ((32'h0900_0000 + (i << 16)) ^ (k * 32'h0101_0101) ^ (k << 3)), "burst consecutivo corrompido");
            end
            sys_end(0);
        end

        if (run_this("T-S-AXI-010")) begin
            // RLAST em burst de 1 beat: len=0. Esperado: rlast = 1 no unico beat (a task do
            // mestre confere rlast; erro vira master_errors). Checagem: E-03. Bloq.
            sys_begin("T-S-AXI-010", "Bloq");
            do_read(32'h0000_0400, 4'h6, 8'd0, 3'd2, 0, 0);
            check(master_errors == 0, "rlast incorreto em burst de 1 beat");
            sys_end(0);
        end

        if (run_this("T-S-AXI-011")) begin
            // RLAST nao precoce: len=7. Esperado: rlast = 0 nos beats 1 a 7 e 1 no 8o. Checagem: E-03. Bloq.
            sys_begin("T-S-AXI-011", "Bloq");
            do_read(32'h0000_0400, 4'h6, 8'd7, 3'd2, 0, 0);
            check(master_errors == 0, "rlast precoce ou ausente");
            sys_end(0);
        end

        if (run_this("T-S-AXI-012")) begin
            // BVALID apos WLAST: escrita len=7 com atraso no ultimo beat de W. Esperado: bvalid so
            // depois de o wlast ser aceito. Checagem: E-05, E-07. Bloq.
            sys_begin("T-S-AXI-012", "Bloq");
            fill_payload(32'h0000_0500, 8'd7, 3'd2, 32'h0C00_0000);
            fork
                aw_send_burst(32'h0000_0500, 4'h7, 8'd7, 2'b01, 3'd2, 0);
                begin : w_lento
                    for (k = 0; k <= 7; k = k + 1) begin
                        if (k == 7) repeat (20) @(posedge aclk);      // atraso no ultimo beat
                        wdata <= w_data_buf[k]; wstrb <= w_strb_buf[k]; wlast <= (k == 7); wvalid <= 1'b1;
                        @(posedge aclk);
                        while (!wready) @(posedge aclk);
                        wvalid <= 1'b0; wlast <= 1'b0;
                    end
                end
                b_recv_id(4'h7, 0);
            join
            check(t_bfirst > t_wlast, "bvalid antes de o wlast ser aceito");
            check(chk.cnt_e05 == 0 && chk.cnt_e07 == 0, "E-05/E-07");
            sys_end(0);
        end

        if (run_this("T-S-AXI-013")) begin
            // FIXED e WRAP tratados como INCR (R-14): awburst = 2'b00 e 2'b10. Esperado:
            // comportamento identico a INCR (documentado, nao corrigido). Informativo.
            sys_begin("T-S-AXI-013", "Inform");
            for (p = 0; p < 2; p = p + 1) begin
                fill_payload(32'h0000_0600 + p*32'h40, 8'd3, 3'd2, 32'h0D00_0000 + p);
                axi_write_burst(32'h0000_0600 + p*32'h40, 4'h8, 8'd3, (p == 0) ? 2'b00 : 2'b10, 3'd2, 0, 0, 0);
                axi_read_burst (32'h0000_0600 + p*32'h40, 4'h8, 8'd3, (p == 0) ? 2'b00 : 2'b10, 3'd2, 0, 0);
                check_readback(8'd3, "AXI-013");
            end
            sys_end(0);
        end

        if (run_this("T-S-AXI-014")) begin
            // wstrb parcial em burst: len=3, strobes variando por beat. Esperado: so os bytes com
            // strobe alterados. Checagem: scoreboard byte a byte. Bloq.
            // Dois bursts cobrem os seis padroes (0000, 0001, 0011, 0110, 1100, 1111).
            sys_begin("T-S-AXI-014", "Bloq");
            for (k = 0; k < 8; k = k + 1) sb_preload_word(32'h0000_0700 + k*4, 32'hAAAA_5555 + k);
            w_strb_buf[0] = 4'b0001; w_strb_buf[1] = 4'b0110; w_strb_buf[2] = 4'b1100; w_strb_buf[3] = 4'b1111;
            for (k = 0; k < 4; k = k + 1) w_data_buf[k] = 32'hF0F0_0000 + k*32'h0001_0101;
            axi_write_burst(32'h0000_0700, 4'h9, 8'd3, 2'b01, 3'd2, 0, 0, 0);
            w_strb_buf[0] = 4'b0000; w_strb_buf[1] = 4'b0011; w_strb_buf[2] = 4'b0110; w_strb_buf[3] = 4'b1111;
            for (k = 0; k < 4; k = k + 1) w_data_buf[k] = 32'h0F0F_0000 + k*32'h0101_0001;
            axi_write_burst(32'h0000_0710, 4'h9, 8'd3, 2'b01, 3'd2, 0, 0, 0);
            do_read(32'h0000_0700, 4'h9, 8'd3, 3'd2, 0, 0);
            do_read(32'h0000_0710, 4'h9, 8'd3, 3'd2, 0, 0);
            sys_end(0);
        end

        if (run_this("T-S-AXI-015")) begin
            // Leitura e escrita no mesmo endereco: escrita seguida de leitura em 0x1000.
            // Esperado: a leitura retorna o valor escrito. Checagem: scoreboard. Bloq.
            sys_begin("T-S-AXI-015", "Bloq");
            do_write(32'h0000_1000, 4'hA, 8'd0, 3'd2, 32'h5A5A_1234, 0, 0, 0);
            do_read (32'h0000_1000, 4'hA, 8'd0, 3'd2, 0, 0);
            check(r_data_buf[0] === w_data_buf[0], "leitura nao retornou o valor escrito");
            sys_end(0);
        end

        if (run_this("T-S-4KB-001")) begin
            // Deteccao de cruzamento de 4 KB: arlen=255 em 0x0000_0F00 (cruza a fronteira).
            // Esperado: o CHECKER acusa a violacao (responsabilidade do mestre, MAS §4.4).
            // Checagem: E-06. PASSA quando E-06 dispara e nenhuma outra extensao dispara. Bloq.
            sys_begin("T-S-4KB-001", "Bloq");
            e06_base = chk.cnt_e06;
            do_read(32'h0000_0F00, 4'h1, 8'd255, 3'd2, 0, 0);
            check(chk.cnt_e06 > e06_base, "E-06 nao disparou: o checker nao detecta cruzamento de 4 KB");
            check(chk.cnt_e01 == 0 && chk.cnt_e02 == 0 && chk.cnt_e03 == 0 && chk.cnt_e04 == 0 &&
                  chk.cnt_e05 == 0 && chk.cnt_e07 == 0 && chk.cnt_e08 == 0 && chk.cnt_e09 == 0 &&
                  chk.cnt_e10 == 0, "outra assertiva disparou junto");
            sys_end(1);
        end

        if (run_this("T-S-AXI-COBERTURA")) begin
            // Apoio a cobertura funcional (VP §4.1), sem ID proprio no VP: varre
            // tamanho x len{0,3} x tipo e as zonas de endereco (inicio, meio, fim, fora da faixa).
            sys_begin("T-S-AXI-COBERTURA", "Bloq");
            for (p = 0; p < 3; p = p + 1)
                for (len_i = 0; len_i < 2; len_i = len_i + 1) begin
                    cov_idmode = (p == 0) ? 0 : 1;
                    do_write(32'h0000_0800 + p*32'h40 + len_i*32'h10, p[3:0], len_i ? 8'd3 : 8'd0, p[2:0], 32'h1100_0000, 0, 0, 0);
                    do_read (32'h0000_0800 + p*32'h40 + len_i*32'h10, p[3:0], len_i ? 8'd3 : 8'd0, p[2:0], 0, 0);
                end
            cov_idmode = 2;
            for (p = 0; p < 16; p = p + 1) begin
                do_write(32'h001F_F000 + p*4, p[3:0], 8'd0, 3'd2, 32'h1200_0000 + p, 0, 0, 0);
                do_read (32'h001F_F000 + p*4, p[3:0], 8'd0, 3'd2, 0, 0);
            end
            do_read (32'h0020_0000, 4'h1, 8'd0, 3'd2, 0, 0);       // zona "out" (DECERR)
            sys_end(0);
        end

        final_result("tb_system_axi4_protocol_compliance_and_bursts");
        $finish;
    end

    initial begin
        #200_000_000;
        $display("RESULT: FAIL tb_system_axi4_protocol_compliance_and_bursts (timeout)");
        $finish;
    end
endmodule
