`timescale 1ns/1ps
// Testes negativos das extensoes E-01..E-10 do axi_protocol_checker (VP §4.3).
// T-N-SZ-001 e o negativo de E-10 (VP §3.13.4).
//
// ATENCAO - LOGICA INVERTIDA: um mestre/subordinado FALSO viola o protocolo de proposito,
// dirigindo o checker diretamente. O caso passa quando o contador da assertiva alvo SOBE e
// os contadores das demais NAO sobem. Se a assertiva nao disparar, ela esta morta.
module tb_negative_axi_protocol_checker_assertions;

    reg aclk = 0, aresetn = 1;
    always #10 aclk = ~aclk;

    reg  [31:0] awaddr = 0;  reg [3:0] awid = 0;  reg [7:0] awlen = 0;  reg [2:0] awsize = 0;
    reg  [1:0]  awburst = 2'b01;  reg awvalid = 0, awready = 0;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0;  reg wlast = 0, wvalid = 0, wready = 0;
    reg  [3:0]  bid = 0;     reg [1:0] bresp = 0;  reg bvalid = 0, bready = 0;
    reg  [31:0] araddr = 0;  reg [3:0] arid = 0;  reg [7:0] arlen = 0;  reg [2:0] arsize = 0;
    reg  [1:0]  arburst = 2'b01;  reg arvalid = 0, arready = 0;
    reg  [31:0] rdata = 0;   reg [3:0] rid = 0;    reg [1:0] rresp = 0;
    reg  rlast = 0, rvalid = 0, rready = 0;
    wire [31:0] chk_errors;

    axi_protocol_checker #(.AXI4_FULL(1), .RESP_TIMEOUT(2000)) chk (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .errors(chk_errors),
        .awid(awid), .awlen(awlen), .awsize(awsize), .awburst(awburst), .wlast(wlast),
        .bid(bid), .arid(arid), .arlen(arlen), .arsize(arsize), .arburst(arburst),
        .rid(rid), .rlast(rlast));

    `include "common/testbench_case_runner_utils.vh"

    // ---------------- helpers: cada um dura exatamente um ciclo de handshake ----------------
    task do_reset;
        begin
            aresetn <= 1'b0;
            repeat (3) @(posedge aclk);
            aresetn <= 1'b1;
            repeat (2) @(posedge aclk);
        end
    endtask

    task aw_hs(input [3:0] id, input [31:0] a, input [7:0] len, input [2:0] size);
        begin
            awid <= id; awaddr <= a; awlen <= len; awsize <= size;
            awvalid <= 1'b1; awready <= 1'b1;
            @(posedge aclk);
            awvalid <= 1'b0; awready <= 1'b0;
        end
    endtask

    task w_hs(input [31:0] d, input [3:0] s, input last);
        begin
            wdata <= d; wstrb <= s; wlast <= last;
            wvalid <= 1'b1; wready <= 1'b1;
            @(posedge aclk);
            wvalid <= 1'b0; wready <= 1'b0; wlast <= 1'b0;
        end
    endtask

    task b_hs(input [3:0] id);
        begin
            bid <= id; bresp <= 2'b00;
            bvalid <= 1'b1; bready <= 1'b1;
            @(posedge aclk);
            bvalid <= 1'b0; bready <= 1'b0;
            @(posedge aclk);
        end
    endtask

    task ar_hs(input [3:0] id, input [31:0] a, input [7:0] len, input [2:0] size);
        begin
            arid <= id; araddr <= a; arlen <= len; arsize <= size;
            arvalid <= 1'b1; arready <= 1'b1;
            @(posedge aclk);
            arvalid <= 1'b0; arready <= 1'b0;
        end
    endtask

    task r_hs(input [3:0] id, input [1:0] resp, input last);
        begin
            rid <= id; rdata <= 32'h1234_5678; rresp <= resp; rlast <= last;
            rvalid <= 1'b1; rready <= 1'b1;
            @(posedge aclk);
            rvalid <= 1'b0; rready <= 1'b0; rlast <= 1'b0;
        end
    endtask

    // ---------------- contadores E-01..E-10 lidos por indice ----------------
    function integer cnt(input integer n);
        case (n)
            1: cnt = chk.cnt_e01;  2: cnt = chk.cnt_e02;  3: cnt = chk.cnt_e03;
            4: cnt = chk.cnt_e04;  5: cnt = chk.cnt_e05;  6: cnt = chk.cnt_e06;
            7: cnt = chk.cnt_e07;  8: cnt = chk.cnt_e08;  9: cnt = chk.cnt_e09;
            default: cnt = chk.cnt_e10;
        endcase
    endfunction

    integer snap [1:10];
    integer k;
    task snapshot;
        begin for (k = 1; k <= 10; k = k + 1) snap[k] = cnt(k); end
    endtask

    // PASS quando a assertiva alvo subiu e nenhuma outra subiu
    task expect_only(input integer alvo);
        begin
            repeat (3) @(posedge aclk);
            for (k = 1; k <= 10; k = k + 1) begin
                if (k == alvo) check(cnt(k) > snap[k],  "assertiva alvo NAO disparou (esta morta?)");
                else           check(cnt(k) == snap[k], "outra assertiva disparou junto");
            end
        end
    endtask

    initial begin
        do_reset;

        // E-01: R com rid=7 sem nenhum burst de leitura pendente para esse ID
        if (run_this("T-N-E01")) begin
            case_begin("T-N-E01", "Bloq"); do_reset; snapshot;
            ar_hs(4'h5, 32'h100, 8'd0, 3'd2);
            r_hs(4'h7, 2'b00, 1'b1);
            expect_only(1); case_end;
        end

        // E-02: arlen=3 (4 beats) mas chega um 5o beat do mesmo ID
        if (run_this("T-N-E02")) begin
            case_begin("T-N-E02", "Bloq"); do_reset; snapshot;
            ar_hs(4'h2, 32'h200, 8'd3, 3'd2);
            r_hs(4'h2, 2'b00, 1'b0); r_hs(4'h2, 2'b00, 1'b0);
            r_hs(4'h2, 2'b00, 1'b0); r_hs(4'h2, 2'b00, 1'b1);
            r_hs(4'h2, 2'b00, 1'b0);
            expect_only(2); case_end;
        end

        // E-03: rlast no 2o beat de um burst de 4 beats
        if (run_this("T-N-E03")) begin
            case_begin("T-N-E03", "Bloq"); do_reset; snapshot;
            ar_hs(4'h2, 32'h200, 8'd3, 3'd2);
            r_hs(4'h2, 2'b00, 1'b0); r_hs(4'h2, 2'b00, 1'b1);
            expect_only(3); case_end;
        end

        // E-04: wlast no 2o beat de um burst de 4 beats
        if (run_this("T-N-E04")) begin
            case_begin("T-N-E04", "Bloq"); do_reset; snapshot;
            aw_hs(4'h1, 32'h300, 8'd3, 3'd2);
            w_hs(32'hA, 4'b1111, 1'b0); w_hs(32'hB, 4'b1111, 1'b1);
            expect_only(4); case_end;
        end

        // E-05: B apresentado antes de qualquer beat de W (wlast ainda nao aceito)
        if (run_this("T-N-E05")) begin
            case_begin("T-N-E05", "Bloq"); do_reset; snapshot;
            aw_hs(4'h1, 32'h300, 8'd1, 3'd2);
            b_hs(4'h1);
            expect_only(5); case_end;
        end

        // E-06: arlen=255 em 0x0000_0F00 cruza a fronteira de 4 KB
        if (run_this("T-N-E06")) begin
            case_begin("T-N-E06", "Bloq"); do_reset; snapshot;
            ar_hs(4'h1, 32'h0000_0F00, 8'd255, 3'd2);
            expect_only(6); case_end;
        end

        // E-07: duas respostas B para um unico burst de escrita
        if (run_this("T-N-E07")) begin
            case_begin("T-N-E07", "Bloq"); do_reset; snapshot;
            aw_hs(4'h1, 32'h300, 8'd0, 3'd2);
            w_hs(32'hA, 4'b1111, 1'b1);
            b_hs(4'h1);
            b_hs(4'h1);
            expect_only(7); case_end;
        end

        // E-08: AR aceito e nenhuma resposta por 2100 ciclos
        if (run_this("T-N-E08")) begin
            case_begin("T-N-E08", "Bloq"); do_reset; snapshot;
            ar_hs(4'h1, 32'h100, 8'd0, 3'd2);
            repeat (2100) @(posedge aclk);
            expect_only(8); case_end;
        end

        // E-09: rresp muda de OKAY para SLVERR dentro do mesmo burst de leitura
        if (run_this("T-N-E09")) begin
            case_begin("T-N-E09", "Bloq"); do_reset; snapshot;
            ar_hs(4'h3, 32'h400, 8'd3, 3'd2);
            r_hs(4'h3, 2'b00, 1'b0); r_hs(4'h3, 2'b10, 1'b0);
            expect_only(9); case_end;
        end

        // E-10 (T-N-SZ-001): mestre mal configurado, awsize=0 com wstrb=4'b1111
        if (run_this("T-N-SZ-001")) begin
            case_begin("T-N-SZ-001", "Bloq"); do_reset; snapshot;
            aw_hs(4'h1, 32'h0, 8'd0, 3'd0);
            w_hs(32'hFFFF_FFFF, 4'b1111, 1'b1);
            expect_only(10); case_end;
        end

        final_result("tb_negative_axi_protocol_checker_assertions");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_negative_axi_protocol_checker_assertions (timeout)");
        $finish;
    end
endmodule
