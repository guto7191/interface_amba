`timescale 1ns/1ps
// Teste unitario de axi_subordinate_read com RAM sincrona (latencia 1) e grant programavel.
module tb_read;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;
    localparam IDX_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam SH        = $clog2(DATA_WIDTH/8);

    reg aclk = 0, aresetn = 1;   // cai em #1 para gerar negedge (reset assincrono)
    always #5 aclk = ~aclk;

    // canal de escrita nao existe neste DUT
    reg  [ADDR_WIDTH-1:0]   awaddr = 0;  reg awvalid = 0;
    reg  [DATA_WIDTH-1:0]   wdata  = 0;
    reg  [DATA_WIDTH/8-1:0] wstrb  = 0;  reg wvalid = 0;  reg bready = 0;
    wire awready = 1'b0, wready = 1'b0, bvalid = 1'b0;
    wire [1:0] bresp = 2'b00;

    reg  [ADDR_WIDTH-1:0] araddr = 0;  reg arvalid = 0;  wire arready;
    wire [DATA_WIDTH-1:0] rdata;
    wire [1:0]            rresp;
    wire                  rvalid;
    reg                   rready = 0;

    wire                   rd_req;
    wire                   rd_grant;
    wire [IDX_WIDTH-1:0]   rd_idx;
    reg  [DATA_WIDTH-1:0]  rd_data;

    axi_subordinate_read #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .rd_req(rd_req), .rd_grant(rd_grant), .rd_idx(rd_idx), .rd_data(rd_data));

    wire [31:0] chk_errors;
    axi_protocol_checker #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) chk (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
        .errors(chk_errors));

    `include "common/axi_master_tasks.vh"

    // modelo de RAM: grant apos grant_dly ciclos de rd_req; dado registrado (latencia 1)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer grant_dly = 0;
    integer gcnt = 0;
    integer req_cnt = 0;
    always @(posedge aclk) begin
        gcnt <= rd_req ? gcnt + 1 : 0;
        if (rd_req && rd_grant) begin
            rd_data <= mem[rd_idx];
            req_cnt <= req_cnt + 1;
        end
    end
    assign rd_grant = rd_req && (gcnt >= grant_dly);

    integer errs = 0;
    task check(input c, input [8*48-1:0] msg);
        if (!c) begin
            errs = errs + 1;
            $display("FAIL @%0t: %0s", $time, msg);
        end
    endtask

    task do_rd(input [ADDR_WIDTH-1:0] a, input integer gd, input integer ard, input integer rd);
        reg inr;
        integer cnt0;
        begin
            grant_dly = gd;
            cnt0 = req_cnt;
            inr = ((a >> SH) < DEPTH);
            axi_read(a, ard, rd);
            check(last_rresp == (inr ? 2'b00 : 2'b10), "RRESP incorreto");
            if (inr) begin
                check(last_rdata == mem[a >> SH], "RDATA incorreto");
                check(req_cnt == cnt0 + 1, "esperava exatamente 1 acesso a memoria");
            end else
                check(last_rdata == 0, "RDATA deveria ser 0 fora da faixa");
            repeat (2) @(posedge aclk);
        end
    endtask

    integer i, j;
    initial begin
        if ($test$plusargs("dump")) begin $dumpfile("build/tb_read.vcd"); $dumpvars(0, tb_read); end
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'hC0DE0000 + i * 32'h101;
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        // 1) todos os indices, grant imediato
        for (i = 0; i < DEPTH; i = i + 1) do_rd(i << SH, 0, 0, 0);

        // 2) grant atrasado, RREADY atrasado, AR atrasado
        do_rd(32'h8, 1, 0, 0);
        do_rd(32'h8, 3, 0, 0);
        do_rd(32'hC, 0, 0, 6);    // RVALID espera RREADY, dados estaveis
        do_rd(32'h10, 0, 4, 0);
        do_rd(32'h14, 2, 2, 5);

        // 3) fora da faixa e nao alinhado
        do_rd(DEPTH << SH, 0, 0, 0);
        do_rd((DEPTH + 3) << SH, 2, 0, 3);
        do_rd(32'hFFFF_FFFC & ((1 << ADDR_WIDTH) - 1), 0, 1, 1);
        do_rd((5 << SH) + 3, 0, 0, 0);

        // 4) varredura
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                do_rd(((i * 3 + j) % DEPTH) << SH, i, j, (i + j) % 4);

        // 5) reset no meio da leitura (AR aceito, antes do R)
        grant_dly = 20;
        araddr <= 32'h4; arvalid <= 1'b1;
        @(posedge aclk); while (!arready) @(posedge aclk);
        arvalid <= 1'b0;
        repeat (2) @(posedge aclk);
        aresetn <= 1'b0;
        repeat (2) @(posedge aclk);
        check(rvalid === 1'b0, "RVALID durante reset");
        aresetn <= 1'b1;
        @(posedge aclk);
        check(arready === 1'b1 && rvalid === 1'b0, "FSM nao voltou a IDLE apos reset");
        do_rd(32'h8, 0, 0, 0);

        repeat (5) @(posedge aclk);
        check(chk_errors == 0, "violacoes do checker de protocolo");
        if (errs == 0) $display("RESULT: PASS tb_read");
        else           $display("RESULT: FAIL tb_read (%0d erros)", errs);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: FAIL tb_read (timeout)");
        $finish;
    end
endmodule
