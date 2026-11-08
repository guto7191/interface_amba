`timescale 1ns/1ps
// Sistema: robustez (VP §3.11): T-S-ROB-001..007.
// ROB-005 e o estresse pseudoaleatorio (semente via +SEED=<n>, impressa no log). ROB-006 e o
// mesmo caso repetido com 10 sementes pelo alvo "test_s_rob_seeds" do Makefile.
`define TB_NAME "tb_system_robustness_reset_and_random_stress"
`define AXI4_MASTER_TASKS
module tb_system_robustness_reset_and_random_stress;
    parameter N_ROB = 5000;
    `include "system/system_testbench_harness.vh"

    integer i, k, it, mode, off, rb_mark, wb_mark;
    integer awd, ard, wp, rp, bd;
    integer old_or_new_bad, new_words;
    reg [31:0] wa, ra;  reg [7:0] wl, rl;  reg [2:0] ws, rs;  reg [3:0] wid, rid_l;
    integer offs [0:4];
    reg [31:0] w32;
    reg [15:0] hw;

    // ajusta g_id ao modo de ID declarado em cov_idmode (0 unico, 1 dois alternados, 2 dezesseis)
    task pick_id;
        begin
            if (cov_idmode == 0)      g_id = 4'h0;
            else if (cov_idmode == 1) g_id = 4'h1 + rnd(2);
        end
    endtask

    // ---------------- reset do sistema no meio de uma transacao ----------------
    task pulse_reset_and_recover;
        begin
            KEY[0] = 1'b0;
            master_idle;
            repeat (3) @(posedge aclk);
            KEY[0] = 1'b1;
            repeat (4) @(posedge aclk);
            while (aresetn !== 1'b1) @(posedge aclk);
            repeat (2) @(posedge aclk);
            master_errors = 0;
        end
    endtask

    // le um burst e, no 4o beat de R, aplica o reset 'delay' ns depois da borda do clock
    task read_interrupted_by_reset(input integer delay_ns);
        begin
            rb_mark = rb_cnt;
            fork : leitura_ou_reset
                begin : leitura
                    do_read(32'h0000_1000, 4'h1, 8'd15, 3'd2, 0, 0);
                end
                begin : gatilho
                    while (rb_cnt < rb_mark + 4) @(posedge aclk);
                    #(delay_ns);
                    pulse_reset_and_recover;
                end
            join_any
            disable leitura_ou_reset.leitura;
            disable leitura_ou_reset.gatilho;
            master_idle;
            while (aresetn !== 1'b1) @(posedge aclk);
            repeat (4) @(posedge aclk);
        end
    endtask

    initial begin
        gen_seed = seed_value;
        offs[0] = 1; offs[1] = 5; offs[2] = 9; offs[3] = 13; offs[4] = 17;
        reset_system;

        if (run_this("T-S-ROB-001")) begin
            // Reset no meio de burst de leitura: reset no beat 4 de um burst len=15. Esperado:
            // sem travamento; apos o reset, nova transacao e atendida. Checagem: E-08; checker. Bloq.
            sys_begin("T-S-ROB-001", "Bloq");
            for (i = 0; i < 16; i = i + 1) sb_preload_word(32'h0000_1000 + i*4, 32'h4000_0000 + i);
            read_interrupted_by_reset(1);
            do_read(32'h0000_1000, 4'h2, 8'd0, 3'd2, 0, 0);
            check(r_data_buf[0] === 32'h4000_0000, "leitura apos o reset retornou dado errado");
            check(chk.cnt_e08 == 0, "E-08 (travamento)");
            sys_end(0);
        end

        if (run_this("T-S-ROB-002")) begin
            // Reset no meio de burst de escrita: reset durante o pulso de WE_N, depois do 4o beat
            // de W (12 ns apos WE_N descer, >= tPWE1). Esperado: SRAM nao corrompida alem dos
            // beats em curso; o sistema se recupera. Checagem: scoreboard apos ressincronizar a
            // regiao; A-SRAM-01. Bloq.
            sys_begin("T-S-ROB-002", "Bloq");
            for (i = 0; i < 16; i = i + 1) sb_preload_word(32'h0000_0800 + i*4, 32'hC0DE_0000 + i);
            wb_mark = wb_cnt;
            fill_payload(32'h0000_0800, 8'd15, 3'd2, 32'hD0D0_0000);
            for (i = 0; i < 16; i = i + 1) w_data_buf[i] = 32'hD0D0_0000 + i;
            fork : escrita_ou_reset
                begin : escrita
                    axi_write_burst(32'h0000_0800, 4'h3, 8'd15, 2'b01, 3'd2, 0, 0, 0);
                end
                begin : gatilho
                    while (wb_cnt < wb_mark + 4) @(posedge aclk);
                    @(negedge SRAM_WE_N);
                    #12;
                    pulse_reset_and_recover;
                end
            join_any
            disable escrita_ou_reset.escrita;
            disable escrita_ou_reset.gatilho;
            master_idle;
            while (aresetn !== 1'b1) @(posedge aclk);
            repeat (4) @(posedge aclk);
            // nenhuma palavra pode ter valor "terceiro"; alem dos primeiros beats, nada mudou
            old_or_new_bad = 0; new_words = 0;
            for (i = 0; i < 16; i = i + 1) begin
                hw = u_sram.mem_peek(((32'h0000_0800 + i*4) >> 1));
                w32[15:0] = hw;
                hw = u_sram.mem_peek(((32'h0000_0800 + i*4) >> 1) + 1);
                w32[31:16] = hw;
                if (w32 === (32'hD0D0_0000 + i)) new_words = new_words + 1;
                if (w32 !== (32'hC0DE_0000 + i) && w32 !== (32'hD0D0_0000 + i)) old_or_new_bad = old_or_new_bad + 1;
                if (i >= 6) check(w32 === 32'hC0DE_0000 + i, "palavra alem dos beats em curso foi alterada");
            end
            check(old_or_new_bad == 0, "alguma palavra nao e nem o valor antigo nem o novo");
            $display("INFO: T-S-ROB-002 PHASE=%0d palavras novas=%0d de 16 (a escrita foi interrompida no meio do burst)", PHASE, new_words);
            check(new_words > 0 && new_words < 16, "o reset nao interrompeu a escrita no meio do burst");
            sb_resync_from_sram(32'h0000_0800, 64);
            do_read(32'h0000_0800, 4'h4, 8'd15, 3'd2, 0, 0);          // recupera: nova transacao atendida
            check(u_sram.cnt_a01 == sram_base, "A-SRAM-01 disparou");
            sys_end(0);
        end

        if (run_this("T-S-ROB-003")) begin
            // Reset assincrono ao clock: reset afirmado fora da borda, em varios deslocamentos
            // (1, 5, 9, 13 e 17 ns apos a borda). Esperado: recuperacao consistente em todos.
            // Checagem: repeticao com deslocamento variavel. Bloq.
            sys_begin("T-S-ROB-003", "Bloq");
            for (i = 0; i < 16; i = i + 1) sb_preload_word(32'h0000_1000 + i*4, 32'h4100_0000 + i);
            for (k = 0; k < 5; k = k + 1) begin
                read_interrupted_by_reset(offs[k]);
                do_read(32'h0000_1004, 4'h2, 8'd0, 3'd2, 0, 0);
                check(r_data_buf[0] === 32'h4100_0001, "sistema nao se recuperou do reset");
                check(chk.cnt_e08 == 0, "E-08 (travamento)");
            end
            sys_end(0);
        end

        if (run_this("T-S-ROB-004")) begin
            // Posicao nao inicializada: leitura em endereco nunca escrito. Esperado: retorna
            // 32'hDEADDEAD (MAS/VP §2.1.2). Checagem: scoreboard. Inform.
            sys_begin("T-S-ROB-004", "Inform");
            do_read(32'h0010_0000, 4'h1, 8'd0, 3'd2, 0, 0);
            check(r_data_buf[0] === 32'hDEAD_DEAD, "posicao nao escrita deveria ler DEADDEAD");
            sys_end(0);
        end

        if (run_this("T-S-ROB-005")) begin
            // Estresse pseudoaleatorio: N_ROB transacoes aleatorias (tipo, endereco, len,
            // wstrb, id, atrasos), com ~8% fora da faixa ou com AxSIZE ilegal e pares
            // leitura+escrita concorrentes em regioes disjuntas. Semente fixa registrada no log.
            // Esperado: zero erros de checker, de scoreboard e do modelo da SRAM; ao final, a
            // memoria inteira da SRAM igual ao modelo de referencia. Bloq.
            sys_begin("T-S-ROB-005", "Bloq");
            cov_idmode = 2;
            g_allow_bad = 1;
            $display("INFO: T-S-ROB-005 SEED=%0d N=%0d PHASE=%0d", seed_value, N_ROB, PHASE);
            // prelude: bursts longos (len=63 e len=255), nao sorteados com frequencia
            cov_rdy = 0;
            do_write(32'h0000_0000, 4'h1, 8'd63,  3'd2, 32'h5000_0000, 0, 0, 0);
            do_read (32'h0000_0000, 4'h1, 8'd63,  3'd2, 0, 0);
            do_write(32'h0000_0400, 4'h2, 8'd255, 3'd2, 32'h5100_0000, 0, 0, 0);
            do_read (32'h0000_0400, 4'h2, 8'd255, 3'd2, 0, 0);
            for (it = 0; it < N_ROB; it = it + 1) begin
                mode = rnd(10);
                awd = rnd(4); ard = rnd(4); wp = rnd(3); rp = rnd(3); bd = rnd(3);
                cov_idmode = rnd(3);                               // modo de ID desta transacao
                if (mode < 6) begin                                // transacao unica
                    gen_txn_params(16384, 255);
                    if (g_expect_err == 0 && rnd(100) < 12)         // zona "fim da faixa"
                        g_addr = 32'h001F_F000 + (g_addr & 32'hFFF);
                    pick_id;
                    if (g_is_write) begin
                        cov_rdy = wp;
                        gen_write_payload;
                        axi_write_burst(g_addr, g_id, g_len, 2'b01, g_size, awd, wp, bd);
                    end else begin
                        cov_rdy = rp;
                        axi_read_burst(g_addr, g_id, g_len, 2'b01, g_size, ard, rp);
                    end
                end else begin                                     // par concorrente, regioes disjuntas
                    gen_txn_params(8192, 255);
                    pick_id;
                    wa = g_addr; wl = g_len; ws = g_size; wid = g_id;
                    gen_write_payload;                             // payload da escrita (usa g_*)
                    gen_txn_params(8192, 255);
                    pick_id;
                    ra = g_addr; rl = g_len; rs = g_size; rid_l = g_id;
                    if (ra < 32'h0020_0000) ra = ra + 32'd8192;    // leitura na outra regiao
                    rp = wp;                                       // um unico rotulo de READY por par
                    cov_rdy = wp;
                    fork
                        axi_write_burst(wa, wid, wl, 2'b01, ws, awd, wp, bd);
                        axi_read_burst (ra, rid_l, rl, 2'b01, rs, ard, rp);
                    join
                end
            end
            repeat (200) @(posedge aclk);
            sb_compare_all_memory;
            $display("INFO: T-S-ROB-005 SEED=%0d escritas=%0d leituras=%0d beats W=%0d R=%0d erros: chk=%0d sb=%0d sram=%0d",
                     seed_value, sb_wr_bursts, sb_rd_bursts, sb_wr_beats, sb_rd_beats,
                     chk_errors - chk_base, sb_errors - sb_base, sram_errors - sram_base);
            sys_end(0);
        end

        if (run_this("T-S-ROB-007")) begin
            // Enderecos nas bordas da faixa: acessos em 0x0, 0x1F_FFF8, 0x1F_FFFC e vizinhos,
            // e em 0x20_0000 (fora da faixa). Esperado: comportamento correto; sem aliasing:
            // a escrita em 0x20_0000 (DECERR) nao altera 0x0. Checagem: scoreboard. Bloq.
            sys_begin("T-S-ROB-007", "Bloq");
            do_write(32'h0000_0000, 4'h1, 8'd0, 3'd2, 32'h7000_0001, 0, 0, 0);
            do_write(32'h0000_0004, 4'h1, 8'd0, 3'd2, 32'h7000_0002, 0, 0, 0);
            do_write(32'h001F_FFF8, 4'h2, 8'd1, 3'd2, 32'h7100_0001, 0, 0, 0);     // termina em 0x1FFFFF
            do_write(32'h001F_FFFC, 4'h2, 8'd0, 3'd2, 32'h7200_0001, 0, 0, 0);
            do_write(32'h0020_0000, 4'h3, 8'd0, 3'd2, 32'hBAD0_BAD0, 0, 0, 0);     // DECERR
            check(last_bresp === 2'b11, "escrita fora da faixa deveria dar DECERR");
            do_read(32'h0000_0000, 4'h1, 8'd1, 3'd2, 0, 0);                         // 0x0 e 0x4
            check(r_data_buf[0] !== 32'hBAD0_BAD0, "aliasing: 0x20_0000 apareceu em 0x0");
            do_read(32'h001F_FFF8, 4'h2, 8'd1, 3'd2, 0, 0);
            do_read(32'h0020_0000, 4'h3, 8'd0, 3'd2, 0, 0);
            check(r_resp_buf[0] === 2'b11, "leitura fora da faixa deveria dar DECERR");
            do_read(32'hFFFF_FFFC, 4'h3, 8'd0, 3'd2, 0, 0);
            check(r_resp_buf[0] === 2'b11, "leitura em 0xFFFFFFFC deveria dar DECERR");
            sys_end(0);
        end

        final_result("tb_system_robustness_reset_and_random_stress");
        $finish;
    end

    initial begin
        #3_000_000_000;
        $display("RESULT: FAIL tb_system_robustness_reset_and_random_stress (timeout)");
        $finish;
    end
endmodule
