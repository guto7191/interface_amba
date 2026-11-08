`timescale 1ns/1ps
// Teste unitario do axi_narrow_read_align (MAS §5.6, VP §3.13.2). Combinacional.
// Estimulo comum: rdata_raw = 32'hAABBCCDD. A comparacao considera so as lanes validas
// (scoreboard regra 5, VP §2.4); as demais seguem D12 (dado replicado) e sao checadas a parte.
module tb_unit_axi_narrow_read_align_byte_lanes;

    reg  [31:0] rdata_raw = 32'hAABBCCDD;
    reg  [1:0]  addr_lo   = 2'b00;
    reg  [2:0]  axsize    = 3'd2;
    wire [31:0] rdata_aligned;

    axi_narrow_read_align dut (.rdata_raw(rdata_raw), .addr_lo(addr_lo), .axsize(axsize),
                               .rdata_aligned(rdata_aligned));

    `include "common/testbench_case_runner_utils.vh"

    task apply(input [1:0] a, input [2:0] s);
        begin addr_lo = a; axsize = s; #1; end
    endtask

    initial begin
        if (run_this("T-U-SZ-005")) begin
            // Estimulo: addr_lo=00, size=0. Esperado: lane [7:0] = 0xDD. Bloq.
            case_begin("T-U-SZ-005", "Bloq");
            apply(2'b00, 3'd0);
            check(rdata_aligned[7:0] === 8'hDD, "lane [7:0] deveria ser DD");
            case_end;
        end

        if (run_this("T-U-SZ-006")) begin
            // Estimulo: addr_lo=10, size=0. Esperado: lane [23:16] = 0xBB. Bloq.
            case_begin("T-U-SZ-006", "Bloq");
            apply(2'b10, 3'd0);
            check(rdata_aligned[23:16] === 8'hBB, "lane [23:16] deveria ser BB");
            case_end;
        end

        if (run_this("T-U-SZ-007")) begin
            // Estimulo: addr_lo=10, size=1. Esperado: lanes [31:16] = 0xAABB. Bloq.
            case_begin("T-U-SZ-007", "Bloq");
            apply(2'b10, 3'd1);
            check(rdata_aligned[31:16] === 16'hAABB, "lanes [31:16] deveriam ser AABB");
            case_end;
        end

        if (run_this("T-U-SZ-008")) begin
            // Estimulo: addr_lo=00, size=2. Esperado: [31:0] = 0xAABBCCDD (passagem direta). Bloq.
            case_begin("T-U-SZ-008", "Bloq");
            apply(2'b00, 3'd2);
            check(rdata_aligned === 32'hAABBCCDD, "passagem direta deveria devolver AABBCCDD");
            case_end;
        end

        if (run_this("T-U-SZ-TABELA")) begin
            // Cobertura (VP §4.2): as 7 linhas legais da tabela da MAS §5.6, lanes validas e
            // lanes replicadas (D12). Apoio aos T-U-SZ-005..008, sem ID proprio no VP.
            case_begin("T-U-SZ-TABELA", "Bloq");
            apply(2'b00, 3'd2); check(rdata_aligned === 32'hAABBCCDD, "4 B @0");
            apply(2'b00, 3'd1); check(rdata_aligned === 32'hCCDDCCDD, "2 B @0 replicado");
            apply(2'b10, 3'd1); check(rdata_aligned === 32'hAABBAABB, "2 B @2 replicado");
            apply(2'b00, 3'd0); check(rdata_aligned === 32'hDDDDDDDD, "1 B @0 replicado");
            apply(2'b01, 3'd0); check(rdata_aligned === 32'hCCCCCCCC, "1 B @1 replicado");
            apply(2'b10, 3'd0); check(rdata_aligned === 32'hBBBBBBBB, "1 B @2 replicado");
            apply(2'b11, 3'd0); check(rdata_aligned === 32'hAAAAAAAA, "1 B @3 replicado");
            // caso desalinhado (P-07): passagem direta
            apply(2'b01, 3'd1); check(rdata_aligned === 32'hAABBCCDD, "2 B desalinhado: passagem direta");
            case_end;
        end

        final_result("tb_unit_axi_narrow_read_align");
        $finish;
    end
endmodule
