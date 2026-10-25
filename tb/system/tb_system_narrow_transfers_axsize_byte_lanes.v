`timescale 1ns/1ps
// Sistema: transferencias estreitas (AxSIZE) ponta a ponta (R-19, R-20, R-21; VP §3.13.3):
// T-S-SZ-001..007, mais T-S-SZ-D12 (apoio: replicacao nas lanes nao usadas, decisao D12).
// Origem: norma AXI4 (IHI0022E §A3.4.1 e §A3.4.3), exceto SZ-005 (decisao D11) e SZ-D12.
`define TB_NAME "tb_system_narrow_transfers_axsize_byte_lanes"
`define AXI4_MASTER_TASKS
module tb_system_narrow_transfers_axsize_byte_lanes;
    `include "tb/system/system_testbench_harness.vh"

    integer i, n, a0;
    reg [7:0]  b;
    reg [31:0] expw;

    // byte da lane 'l' de uma palavra
    function [7:0] lane_byte(input [31:0] w, input integer l);
        lane_byte = w[8*l +: 8];
    endfunction

    initial begin
        reset_system;

        if (run_this("T-S-SZ-001")) begin
            // Reproduz a Figura A3-8 da norma: arsize=0, arlen=4, araddr=0x0, barramento de 32
            // bits. Esperado: 5 beats lendo os bytes 0x0..0x4; o byte do beat N na lane
            // (N-1) mod 4 (N a partir de 1); o 5o beat volta a lane 0. Checagem: scoreboard por
            // lane. Bloq.
            sys_begin("T-S-SZ-001", "Bloq");
            sb_preload_word(32'h0, 32'h4433_2211);          // bytes 0..3 = 11 22 33 44
            sb_preload_word(32'h4, 32'h8877_6655);          // bytes 4..7 = 55 66 77 88
            do_read(32'h0, 4'h1, 8'd4, 3'd0, 0, 0);
            for (n = 0; n < 5; n = n + 1) begin
                b = 8'h11 + 8'h11*n;                         // byte n da memoria
                check(lane_byte(r_data_buf[n], n % 4) === b, "byte do beat na lane errada (Fig. A3-8)");
            end
            sys_end(0);
        end

        if (run_this("T-S-SZ-002")) begin
            // Burst de halfwords: arsize=1, arlen=3, araddr=0x1000. Esperado: 4 beats em 0x1000,
            // 0x1002, 0x1004 e 0x1006; lanes alternando [15:0] e [31:16]. Checagem: scoreboard por
            // lane. Bloq.
            sys_begin("T-S-SZ-002", "Bloq");
            sb_preload_word(32'h1000, 32'hBBBB_AAAA);
            sb_preload_word(32'h1004, 32'hDDDD_CCCC);
            do_read(32'h1000, 4'h1, 8'd3, 3'd1, 0, 0);
            check(r_data_buf[0][15:0]  === 16'hAAAA, "beat 0 deveria vir em [15:0]");
            check(r_data_buf[1][31:16] === 16'hBBBB, "beat 1 deveria vir em [31:16]");
            check(r_data_buf[2][15:0]  === 16'hCCCC, "beat 2 deveria vir em [15:0]");
            check(r_data_buf[3][31:16] === 16'hDDDD, "beat 3 deveria vir em [31:16]");
            sys_end(0);
        end

        if (run_this("T-S-SZ-003")) begin
            // Burst de escrita de bytes: awsize=0, awlen=3, awaddr=0x1000, wstrb rotacionando
            // 0001 -> 0010 -> 0100 -> 1000. Esperado: so o byte alvo de cada beat alterado na
            // SRAM. Checagem: scoreboard byte a byte. Bloq.
            sys_begin("T-S-SZ-003", "Bloq");
            sb_preload_word(32'h1000, 32'hFFFF_FFFF);
            for (i = 0; i < 4; i = i + 1) begin
                w_data_buf[i] = (32'hA0 + i) << (8*i);
                w_strb_buf[i] = 4'b0001 << i;
            end
            axi_write_burst(32'h1000, 4'h1, 8'd3, 2'b01, 3'd0, 0, 0, 0);
            do_read(32'h1000, 4'h1, 8'd0, 3'd2, 0, 0);
            check(r_data_buf[0] === 32'hA3A2_A1A0, "bytes escritos incorretos");
            sys_end(0);
        end

        if (run_this("T-S-SZ-004")) begin
            // Escrita estreita nao altera vizinhos: awsize=0 em 0x1001, dado 0xFF. Esperado:
            // 0x1000, 0x1002 e 0x1003 preservados. Checagem: scoreboard. Bloq.
            sys_begin("T-S-SZ-004", "Bloq");
            sb_preload_word(32'h1000, 32'h4433_2211);
            w_data_buf[0] = 32'h0000_FF00;                   // o dado vai na lane do endereco (lane 1)
            w_strb_buf[0] = 4'b0010;
            axi_write_burst(32'h1001, 4'h1, 8'd0, 2'b01, 3'd0, 0, 0, 0);
            do_read(32'h1000, 4'h1, 8'd0, 3'd2, 0, 0);
            check(r_data_buf[0] === 32'h4433_FF11, "vizinhos do byte escrito foram alterados");
            sys_end(0);
        end

        if (run_this("T-S-SZ-005")) begin
            // Tamanho ilegal rejeitado: arsize = 3'b011 (8 bytes), arlen = 3. Esperado: SLVERR
            // nos 4 beats; rlast no ultimo; a SRAM NAO e acessada. Checagem: E-09; contador de
            // acessos a SRAM. Ajust (D11).
            sys_begin("T-S-SZ-005", "Ajust");
            a0 = u_sram.access_count;
            do_read(32'h2000, 4'h1, 8'd3, 3'd3, 0, 0);
            for (i = 0; i < 4; i = i + 1) check(r_resp_buf[i] === 2'b10, "beat deveria ser SLVERR");
            check(u_sram.access_count == a0, "a SRAM foi acessada por uma transacao ilegal");
            check(chk.cnt_e09 == 0, "E-09 (rresp inconsistente no burst)");
            sys_end(0);
        end

        if (run_this("T-S-SZ-006")) begin
            // Ida e volta estreita: 256 bytes individuais escritos (burst awsize=0, awlen=255) e
            // lidos de volta como bytes. Esperado: cada byte lido igual ao escrito, na lane
            // correta. Checagem: scoreboard. Bloq.
            sys_begin("T-S-SZ-006", "Bloq");
            for (i = 0; i < 256; i = i + 1) begin
                w_data_buf[i] = (i[7:0]) << (8*(i % 4));
                w_strb_buf[i] = 4'b0001 << (i % 4);
            end
            axi_write_burst(32'h2000, 4'h1, 8'd255, 2'b01, 3'd0, 0, 0, 0);
            do_read(32'h2000, 4'h1, 8'd255, 3'd0, 0, 0);
            for (i = 0; i < 256; i = i + 1)
                check(lane_byte(r_data_buf[i], i % 4) === i[7:0], "byte lido diferente do escrito");
            sys_end(0);
        end

        if (run_this("T-S-SZ-007")) begin
            // Tamanho nao vaza entre transacoes: burst estreito (arsize=0) imediatamente apos um
            // burst largo (arsize=2), mesmo ID. Esperado: o beat 2 do burst estreito usa o size da
            // transacao CORRENTE, nao o da anterior (detecta usar req_axsize_q em vez da entrada
            // axi_arsize_i, MAS §5.4.1). Checagem: scoreboard. Bloq.
            sys_begin("T-S-SZ-007", "Bloq");
            sb_preload_word(32'h3000, 32'h0000_0001);
            sb_preload_word(32'h3004, 32'h0000_0002);
            sb_preload_word(32'h3008, 32'h0000_0003);
            sb_preload_word(32'h300C, 32'h0000_0004);
            sb_preload_word(32'h3100, 32'h4433_2211);
            sb_preload_word(32'h3104, 32'h0000_00EE);      // onde um incremento de 4 bytes iria parar
            fork
                begin
                    ar_send_burst(32'h3000, 4'h5, 8'd3, 2'b01, 3'd2, 0);
                    ar_send_burst(32'h3100, 4'h5, 8'd3, 2'b01, 3'd0, 0);
                end
                begin
                    repeat (60) @(posedge aclk);
                    collect_r_beats(8);
                end
            join
            for (i = 0; i < 4; i = i + 1) check(cb_data[i] === i + 1, "burst largo corrompido");
            check(lane_byte(cb_data[4], 0) === 8'h11, "burst estreito, beat 0");
            check(lane_byte(cb_data[5], 1) === 8'h22, "burst estreito, beat 1 usou o size da transacao anterior");
            check(lane_byte(cb_data[6], 2) === 8'h33, "burst estreito, beat 2");
            check(lane_byte(cb_data[7], 3) === 8'h44, "burst estreito, beat 3");
            sys_end(0);
        end

        if (run_this("T-S-SZ-D12")) begin
            // Apoio (decisao D12, MAS §5.6; pendencia P-06), sem ID no VP: as lanes NAO usadas de
            // uma leitura estreita recebem o dado replicado. O scoreboard ignora essas lanes por
            // regra (VP §2.4 regra 5); este caso as confere explicitamente. Informativo.
            sys_begin("T-S-SZ-D12", "Inform");
            sb_preload_word(32'h4000, 32'hAABB_CCDD);
            do_read(32'h4001, 4'h1, 8'd0, 3'd0, 0, 0);
            expw = 32'hCCCC_CCCC;
            check(r_data_buf[0] === expw, "byte 1: lanes nao usadas deveriam replicar CC");
            do_read(32'h4002, 4'h1, 8'd0, 3'd1, 0, 0);
            expw = 32'hAABB_AABB;
            check(r_data_buf[0] === expw, "meia palavra alta: lanes nao usadas deveriam replicar AABB");
            do_read(32'h4000, 4'h1, 8'd0, 3'd1, 0, 0);
            expw = 32'hCCDD_CCDD;
            check(r_data_buf[0] === expw, "meia palavra baixa: lanes nao usadas deveriam replicar CCDD");
            sys_end(0);
        end

        final_result("tb_system_narrow_transfers_axsize_byte_lanes");
        $finish;
    end

    initial begin
        #100_000_000;
        $display("RESULT: FAIL tb_system_narrow_transfers_axsize_byte_lanes (timeout)");
        $finish;
    end
endmodule
