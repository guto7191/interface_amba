`timescale 1ns/1ps
// Teste unitario de axi_slave_write com modelo de memoria que apenas captura wr_*.
module tb_write;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;
    localparam IDX_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam SH        = $clog2(DATA_WIDTH/8);

    reg aclk = 0, aresetn = 1;   // cai em #1 para gerar negedge (reset assincrono)
    always #5 aclk = ~aclk;

    reg  [ADDR_WIDTH-1:0]   awaddr = 0;  reg awvalid = 0;  wire awready;
    reg  [DATA_WIDTH-1:0]   wdata  = 0;
    reg  [DATA_WIDTH/8-1:0] wstrb  = 0;  reg wvalid = 0;   wire wready;
    wire [1:0] bresp;  wire bvalid;  reg bready = 0;
    // canal de leitura nao existe neste DUT
    reg  [ADDR_WIDTH-1:0] araddr = 0;  reg arvalid = 0;  reg rready = 0;
    wire arready = 1'b0, rvalid = 1'b0;
    wire [DATA_WIDTH-1:0] rdata = {DATA_WIDTH{1'b0}};
    wire [1:0]            rresp = 2'b00;

    wire                    wr_en;
    wire [IDX_WIDTH-1:0]    wr_idx;
    wire [DATA_WIDTH-1:0]   wr_data;
    wire [DATA_WIDTH/8-1:0] wr_strb;

    axi_slave_write #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .wr_en(wr_en), .wr_idx(wr_idx), .wr_data(wr_data), .wr_strb(wr_strb));

    wire [31:0] chk_errors;
    axi_protocol_checker #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) chk (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .errors(chk_errors));

    `include "tb/common/axi_master_tasks.vh"

    // captura das escritas na "memoria"
    integer                 wr_cnt = 0;
    reg [IDX_WIDTH-1:0]     cap_idx;
    reg [DATA_WIDTH-1:0]    cap_data;
    reg [DATA_WIDTH/8-1:0]  cap_strb;
    always @(posedge aclk) if (wr_en) begin
        wr_cnt   <= wr_cnt + 1;
        cap_idx  <= wr_idx;
        cap_data <= wr_data;
        cap_strb <= wr_strb;
    end

    integer errs = 0;
    task check(input c, input [8*48-1:0] msg);
        if (!c) begin
            errs = errs + 1;
            $display("FAIL @%0t: %0s", $time, msg);
        end
    endtask

    task do_wr(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d, input [DATA_WIDTH/8-1:0] s,
               input integer awd, input integer wd, input integer bd);
        reg inr;
        integer cnt0;
        begin
            cnt0 = wr_cnt;
            inr = ((a >> SH) < DEPTH);
            axi_write(a, d, s, awd, wd, bd);
            repeat (3) @(posedge aclk);
            check(last_bresp == (inr ? 2'b00 : 2'b10), "BRESP incorreto");
            if (inr) begin
                check(wr_cnt == cnt0 + 1, "esperava exatamente 1 wr_en");
                check(cap_idx == (a >> SH), "wr_idx incorreto");
                check(cap_data == d, "wr_data incorreto");
                check(cap_strb == s, "wr_strb incorreto");
            end else
                check(wr_cnt == cnt0, "wr_en ativo para endereco fora da faixa");
        end
    endtask

    integer i, j;
    initial begin
        if ($test$plusargs("dump")) begin $dumpfile("build/tb_write.vcd"); $dumpvars(0, tb_write); end
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        // 1) combinacoes de atraso AW / W / B
        do_wr(32'h14, 32'hDEADBEEF, 4'hF, 0, 0, 0);   // simultaneos, BREADY ja alto
        do_wr(32'h14, 32'h11111111, 4'hF, 3, 0, 0);   // W antes de AW
        do_wr(32'h18, 32'h22222222, 4'hF, 0, 3, 0);   // AW antes de W
        do_wr(32'h1C, 32'h33333333, 4'hF, 0, 0, 6);   // BREADY atrasado
        do_wr(32'h20, 32'h44444444, 4'hF, 4, 1, 2);
        do_wr(32'h24, 32'h55555555, 4'hF, 1, 4, 0);
        do_wr(32'h28, 32'h66666666, 4'hF, 7, 7, 7);

        // 2) WSTRB
        do_wr(32'h08, 32'hA5A5A5A5, 4'h0, 0, 0, 0);
        do_wr(32'h08, 32'hA5A5A5A5, 4'hA, 0, 0, 0);
        do_wr(32'h08, 32'hA5A5A5A5, 4'h1, 1, 0, 0);

        // 3) limites: primeiro e ultimo indice validos, primeiro invalido
        do_wr(32'h0, 32'h12345678, 4'hF, 0, 0, 0);
        do_wr((DEPTH-1) << SH, 32'h87654321, 4'hF, 0, 0, 0);
        do_wr(DEPTH << SH, 32'hBADBAD00, 4'hF, 0, 0, 0);
        do_wr(32'hFFFF_FFFC & ((1 << ADDR_WIDTH) - 1), 32'hBADBAD01, 4'hF, 2, 0, 0);

        // 4) endereco nao alinhado (bits de offset ignorados)
        do_wr((3 << SH) + 2, 32'hCAFEF00D, 4'hF, 0, 0, 0);

        // 5) varredura de atrasos
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                do_wr(((i * 4 + j) % DEPTH) << SH, {i[3:0], j[3:0], 24'hABCDEF}, 4'hF, i, j, (i + j) % 4);

        // 6) reset no meio de uma escrita (AW aceito, W pendente)
        awaddr <= 32'h4; awvalid <= 1'b1;
        @(posedge aclk); while (!awready) @(posedge aclk);
        awvalid <= 1'b0;
        repeat (2) @(posedge aclk);
        aresetn <= 1'b0;
        repeat (2) @(posedge aclk);
        check(bvalid === 1'b0, "BVALID durante reset");
        aresetn <= 1'b1;
        @(posedge aclk);
        check(awready === 1'b1 && wready === 1'b1 && bvalid === 1'b0, "FSM nao voltou a IDLE apos reset");
        do_wr(32'h10, 32'hFEEDFACE, 4'hF, 0, 0, 0);

        repeat (5) @(posedge aclk);
        check(chk_errors == 0, "violacoes do checker de protocolo");
        if (errs == 0) $display("RESULT: PASS tb_write");
        else           $display("RESULT: FAIL tb_write (%0d erros)", errs);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_write (timeout)");
        $finish;
    end
endmodule
