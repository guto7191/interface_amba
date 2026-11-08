`timescale 1ns/1ps
// Teste unitario da RAM de porta unica.
module tb_ram;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg         en = 0, we = 0;
    reg  [3:0]  addr = 0;
    reg  [31:0] wdata = 0;
    reg  [3:0]  wstrb = 0;
    wire [31:0] rdata;

    ram #(.DATA_WIDTH(32), .DEPTH(16)) dut (
        .clk(clk), .rst_n(rst_n), .en(en), .we(we), .addr(addr),
        .wdata(wdata), .wstrb(wstrb), .rdata(rdata));

    integer errs = 0;
    task check(input c, input [8*32-1:0] msg);
        if (!c) begin errs = errs + 1; $display("FAIL @%0t: %0s", $time, msg); end
    endtask

    task wr(input [3:0] a, input [31:0] d, input [3:0] s);
        begin
            @(posedge clk); en <= 1; we <= 1; addr <= a; wdata <= d; wstrb <= s;
            @(posedge clk); en <= 0; we <= 0;
        end
    endtask

    task rd(input [3:0] a, output [31:0] d);
        begin
            @(posedge clk); en <= 1; we <= 0; addr <= a;
            @(posedge clk); en <= 0;
            #1 d = rdata;
        end
    endtask

    reg [31:0] v;
    initial begin
        repeat (3) @(posedge clk);
        rst_n <= 1;
        rd(4'd3, v);  check(v == 0, "memoria inicial zerada");
        wr(4'd3, 32'h11223344, 4'hF);
        rd(4'd3, v);  check(v == 32'h11223344, "escrita total");
        wr(4'd3, 32'hAABBCCDD, 4'b0101);
        rd(4'd3, v);  check(v == 32'h11BB33DD, "escrita parcial por byte");
        wr(4'd3, 32'hFFFFFFFF, 4'b0000);
        rd(4'd3, v);  check(v == 32'h11BB33DD, "wstrb=0 nao altera");
        // rdata segura o valor com en baixo
        repeat (3) @(posedge clk);
        check(rdata == 32'h11BB33DD, "rdata deve segurar o valor");
        // en=0 nao escreve
        @(posedge clk); en <= 0; we <= 1; addr <= 4'd3; wdata <= 32'h0; wstrb <= 4'hF;
        @(posedge clk); we <= 0;
        rd(4'd3, v);  check(v == 32'h11BB33DD, "en=0 nao escreve");
        wr(4'd15, 32'hCAFE0015, 4'hF);
        rd(4'd15, v); check(v == 32'hCAFE0015, "ultimo endereco");

        if (errs == 0) $display("RESULT: PASS tb_ram");
        else           $display("RESULT: FAIL tb_ram (%0d erros)", errs);
        $finish;
    end
endmodule
