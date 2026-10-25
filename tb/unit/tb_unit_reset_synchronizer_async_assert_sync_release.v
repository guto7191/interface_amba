`timescale 1ns/1ps
// Teste unitario do reset_synchronizer (MAS §5.1, VP §3.1).
// T-U-RST-001..003. T-U-RST-004 (reset durante operacao) e acrescentado com a controladora.
module tb_unit_reset_synchronizer_async_assert_sync_release;

    reg  clk = 1'b0;
    reg  clk_en = 1'b1;               // permite parar o clock (T-U-RST-001)
    reg  async_reset_n = 1'b1;
    wire aresetn;

    always #10 if (clk_en) clk = ~clk;   // 50 MHz

    reset_synchronizer dut (.clk(clk), .async_reset_n(async_reset_n), .aresetn(aresetn));

    `include "tb/common/testbench_case_runner_utils.vh"

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

        final_result("tb_unit_reset_synchronizer");
        $finish;
    end

    initial begin
        #1_000_000;
        $display("RESULT: FAIL tb_unit_reset_synchronizer (timeout)");
        $finish;
    end
endmodule
