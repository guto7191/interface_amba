`timescale 1ns/1ps
// Testes negativos das assertivas A-SRAM-01..08 do modelo da SRAM (VP §4.3).
//
// ATENCAO - LOGICA INVERTIDA: cada caso viola uma assertiva DE PROPOSITO.
// O caso passa quando a assertiva alvo DISPARA (contador > 0) e as demais NAO disparam.
// Se a assertiva nao disparar, ela esta morta e o caso falha.
module tb_negative_sram_model_timing_assertions;

    reg  [19:0] addr   = 20'h00000;
    reg         ce_n   = 1'b0;
    reg         oe_n   = 1'b1;
    reg         we_n   = 1'b1;
    reg         lb_n   = 1'b0;
    reg         ub_n   = 1'b0;
    reg         sample_clk = 1'b0;
    reg  [15:0] tb_dq  = 16'h0000;
    reg         tb_dq_en = 1'b0;
    wire [15:0] dq;
    wire [31:0] errors, access_count, we_pulse_count;

    assign dq = tb_dq_en ? tb_dq : 16'bz;

    sram_is61wv102416_behavioral_model u_sram (
        .addr(addr), .dq(dq), .ce_n(ce_n), .oe_n(oe_n), .we_n(we_n),
        .lb_n(lb_n), .ub_n(ub_n), .sample_clk(sample_clk),
        .errors(errors), .access_count(access_count), .we_pulse_count(we_pulse_count));

    `include "tb/common/testbench_case_runner_utils.vh"

    // contadores das 8 assertivas, lidos por indice
    function integer cnt(input integer n);
        case (n)
            1: cnt = u_sram.cnt_a01;  2: cnt = u_sram.cnt_a02;
            3: cnt = u_sram.cnt_a03;  4: cnt = u_sram.cnt_a04;
            5: cnt = u_sram.cnt_a05;  6: cnt = u_sram.cnt_a06;
            7: cnt = u_sram.cnt_a07;  default: cnt = u_sram.cnt_a08;
        endcase
    endfunction

    integer snap [1:8];
    integer k;

    task snapshot;
        begin for (k = 1; k <= 8; k = k + 1) snap[k] = cnt(k); end
    endtask

    // PASS quando a assertiva "alvo" subiu e nenhuma outra subiu
    task expect_only(input integer alvo);
        begin
            for (k = 1; k <= 8; k = k + 1) begin
                if (k == alvo) check(cnt(k) > snap[k],  "assertiva alvo NAO disparou (esta morta?)");
                else           check(cnt(k) == snap[k], "outra assertiva disparou junto");
            end
        end
    endtask

    // volta o barramento ao repouso valido e deixa passar um tempo longo
    task idle;
        begin
            tb_dq_en = 1'b0; oe_n = 1'b1; we_n = 1'b1; addr = 20'h00000;
            lb_n = 1'b0; ub_n = 1'b0;
            #100;
        end
    endtask

    initial begin
        #50;

        // ---- A-SRAM-01: pulso de WE_N de 5 ns (< tPWE1 = 8 ns) ----
        if (run_this("T-N-A-SRAM-01")) begin
            case_begin("T-N-A-SRAM-01", "Bloq"); idle; snapshot;
            addr = 20'h00005; tb_dq = 16'h1234; tb_dq_en = 1'b1; #30;
            we_n = 1'b0; #5; we_n = 1'b1; #20;
            expect_only(1); case_end;
        end

        // ---- A-SRAM-02: duas quedas de WE_N separadas por 9 ns (< tWC = 10 ns) ----
        if (run_this("T-N-A-SRAM-02")) begin
            case_begin("T-N-A-SRAM-02", "Bloq"); idle; snapshot;
            addr = 20'h00006; tb_dq = 16'h4321; tb_dq_en = 1'b1; #30;
            we_n = 1'b0; #8; we_n = 1'b1; #1; we_n = 1'b0; #8; we_n = 1'b1; #20;
            expect_only(2); case_end;
        end

        // ---- A-SRAM-03: dado muda 3 ns antes da subida de WE_N (< tSD = 6 ns) ----
        if (run_this("T-N-A-SRAM-03")) begin
            case_begin("T-N-A-SRAM-03", "Bloq"); idle; snapshot;
            addr = 20'h00007; tb_dq = 16'h1111; tb_dq_en = 1'b1; #30;
            we_n = 1'b0; #10; tb_dq = 16'h2222; #3; we_n = 1'b1; #20;
            expect_only(3); case_end;
        end

        // ---- A-SRAM-04: endereco muda no meio do pulso de WE_N ----
        if (run_this("T-N-A-SRAM-04")) begin
            case_begin("T-N-A-SRAM-04", "Bloq"); idle; snapshot;
            addr = 20'h00008; tb_dq = 16'h3333; tb_dq_en = 1'b1; #30;
            we_n = 1'b0; #10; addr = 20'h00009; #10; we_n = 1'b1; #20;
            expect_only(4); case_end;
        end

        // ---- A-SRAM-05: amostra 5 ns depois da troca de endereco (< tAA = 10 ns) ----
        if (run_this("T-N-A-SRAM-05")) begin
            case_begin("T-N-A-SRAM-05", "Bloq"); idle; snapshot;
            oe_n = 1'b0; #50;
            addr = 20'h0000A; #5; sample_clk = 1'b1; #1; sample_clk = 1'b0; #50;
            expect_only(5); case_end;
        end

        // ---- A-SRAM-06: o testbench dirige dq enquanto o modelo le (contencao) ----
        if (run_this("T-N-A-SRAM-06")) begin
            case_begin("T-N-A-SRAM-06", "Bloq"); idle; snapshot;
            addr = 20'h0000B; oe_n = 1'b0; #30;
            tb_dq = 16'h0000; tb_dq_en = 1'b1; #20;
            expect_only(6); case_end;
        end

        // ---- A-SRAM-07: endereco com X durante uma leitura ----
        if (run_this("T-N-A-SRAM-07")) begin
            case_begin("T-N-A-SRAM-07", "Bloq"); idle; snapshot;
            addr = 20'hxxxxx; oe_n = 1'b0; #30;
            expect_only(7); case_end;
        end

        // ---- A-SRAM-08: oe_n e we_n ativos ao mesmo tempo ----
        if (run_this("T-N-A-SRAM-08")) begin
            case_begin("T-N-A-SRAM-08", "Bloq"); idle; snapshot;
            addr = 20'h0000C; oe_n = 1'b0; we_n = 1'b0; #20;
            oe_n = 1'b1; we_n = 1'b1; #20;
            expect_only(8); case_end;
        end

        final_result("tb_negative_sram_model_timing_assertions");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_negative_sram_model_timing_assertions (timeout)");
        $finish;
    end
endmodule
