`timescale 1ns/1ps
// Sistema: ordenacao de respostas por ID (R-03, normativo; VP §3.7): T-S-ORD-001..004.
// Respostas de um mesmo ID voltam na ordem de emissao; IDs distintos podem se intercalar.
`define TB_NAME "tb_system_axi4_response_ordering_by_id"
`define AXI4_MASTER_TASKS
module tb_system_axi4_response_ordering_by_id;
    `include "system/system_testbench_harness.vh"

    integer i, k;
    integer seen [0:15];                 // beats ja vistos por ID
    reg [31:0] addr_of_id [0:15][0:7];   // enderecos emitidos, por ID, em ordem

    initial begin
        reset_system;

        if (run_this("T-S-ORD-001")) begin
            // Mesmo ID, ordem preservada: 4 leituras com arid = 4'h3 em enderecos distintos,
            // todas emitidas antes de qualquer rready. Esperado: respostas na ordem exata de
            // emissao. Checagem: E-01; scoreboard com fila. Bloq.
            sys_begin("T-S-ORD-001", "Bloq");
            for (i = 0; i < 4; i = i + 1) sb_preload_word(32'h0000_0100 * (i + 1), 32'h0A00_0000 + i);
            fork
                begin
                    for (i = 0; i < 4; i = i + 1)
                        ar_send_burst(32'h0000_0100 * (i + 1), 4'h3, 8'd0, 2'b01, 3'd2, 0);
                end
                begin
                    repeat (120) @(posedge aclk);              // so depois de os 4 AR estarem em voo
                    collect_r_beats(4);
                end
            join
            for (i = 0; i < 4; i = i + 1) begin
                check(cb_id[i] === 4'h3, "rid incorreto");
                check(cb_data[i] === 32'h0A00_0000 + i, "resposta fora da ordem de emissao");
            end
            sys_end(0);
        end

        if (run_this("T-S-ORD-002")) begin
            // IDs distintos podem intercalar: leituras alternando arid entre 4'h1 e 4'h2.
            // Esperado: qualquer intercalacao e valida; dentro de cada ID a ordem e mantida.
            // Checagem: E-01. Bloq.
            sys_begin("T-S-ORD-002", "Bloq");
            for (i = 0; i < 8; i = i + 1) sb_preload_word(32'h0000_0200 + i*4, 32'h0B00_0000 + i);
            fork
                begin
                    for (i = 0; i < 8; i = i + 1)
                        ar_send_burst(32'h0000_0200 + i*4, (i % 2) ? 4'h2 : 4'h1, 8'd0, 2'b01, 3'd2, 0);
                end
                begin
                    repeat (150) @(posedge aclk);
                    collect_r_beats(8);
                end
            join
            seen[1] = 0; seen[2] = 0;
            for (i = 0; i < 8; i = i + 1) begin
                // o n-esimo beat do ID 1 deve ser o dado do n-esimo AR emitido com ID 1 (0,2,4,6)
                if (cb_id[i] == 4'h1) begin
                    check(cb_data[i] === 32'h0B00_0000 + 2*seen[1], "ordem violada dentro do ID 1");
                    seen[1] = seen[1] + 1;
                end else begin
                    check(cb_id[i] == 4'h2, "rid inesperado");
                    check(cb_data[i] === 32'h0B00_0000 + 2*seen[2] + 1, "ordem violada dentro do ID 2");
                    seen[2] = seen[2] + 1;
                end
            end
            check(seen[1] == 4 && seen[2] == 4, "faltaram beats de algum ID");
            sys_end(0);
        end

        if (run_this("T-S-ORD-003")) begin
            // bid e rid corretos: escritas e leituras com 4 IDs distintos. Esperado: bid e rid
            // casam com o awid/arid da transacao. Checagem: comparacao direta (as tasks do
            // mestre conferem bid/rid e contam em master_errors). Bloq.
            sys_begin("T-S-ORD-003", "Bloq");
            for (i = 0; i < 4; i = i + 1)
                do_write(32'h0000_0300 + i*32'h10, i[3:0], 8'd1, 3'd2, 32'h0C00_0000 + (i << 8), 0, 0, 0);
            for (i = 0; i < 4; i = i + 1)
                do_read(32'h0000_0300 + i*32'h10, 4'h4 + i[3:0], 8'd1, 3'd2, 0, 0);
            check(master_errors == 0, "bid/rid nao casam com o ID da transacao");
            sys_end(0);
        end

        if (run_this("T-S-ORD-004")) begin
            // ID preservado sob carga: 16 transacoes entrelacadas, IDs de 4'h0 a 4'hF.
            // Esperado: nenhuma troca de ID. Checagem: E-01. Bloq.
            sys_begin("T-S-ORD-004", "Bloq");
            cov_idmode = 2;
            for (i = 0; i < 16; i = i + 1) sb_preload_word(32'h0000_0400 + i*4, 32'h0D00_0000 + i);
            fork
                begin
                    for (i = 0; i < 16; i = i + 1)
                        ar_send_burst(32'h0000_0400 + i*4, i[3:0], 8'd0, 2'b01, 3'd2, 0);
                end
                begin
                    repeat (150) @(posedge aclk);
                    collect_r_beats(16);
                end
            join
            for (i = 0; i < 16; i = i + 1) begin
                check(cb_data[i] === 32'h0D00_0000 + cb_id[i], "dado de um ID chegou com outro ID");
            end
            check(chk.cnt_e01 == 0, "E-01");
            sys_end(0);
        end

        final_result("tb_system_axi4_response_ordering_by_id");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("RESULT: FAIL tb_system_axi4_response_ordering_by_id (timeout)");
        $finish;
    end
endmodule
