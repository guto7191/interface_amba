`timescale 1ns/1ps
// Teste de integracao: axi_interface_subordinate_ram (slaves + adaptador + RAM) com scoreboard.
module tb_top;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;
    parameter N_RANDOM   = 1500;
    localparam BYTES = DATA_WIDTH/8;
    localparam SH    = $clog2(BYTES);

    reg aclk = 0, aresetn = 1;   // cai em #1 para gerar negedge (reset assincrono)
    always #5 aclk = ~aclk;

    reg  [ADDR_WIDTH-1:0]   awaddr = 0;  reg awvalid = 0;  wire awready;
    reg  [DATA_WIDTH-1:0]   wdata  = 0;
    reg  [BYTES-1:0]        wstrb  = 0;  reg wvalid = 0;   wire wready;
    wire [1:0] bresp;  wire bvalid;  reg bready = 0;
    reg  [ADDR_WIDTH-1:0]   araddr = 0;  reg arvalid = 0;  wire arready;
    wire [DATA_WIDTH-1:0]   rdata;  wire [1:0] rresp;  wire rvalid;  reg rready = 0;

    axi_interface_subordinate_ram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
        .s_axi_aclk(aclk), .s_axi_aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready));

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

    // ---------------- scoreboard ----------------
    reg [DATA_WIDTH-1:0] model [0:DEPTH-1];
    integer errs = 0;
    integer n_wr = 0, n_rd = 0, n_err_resp = 0;
    integer seed = 32'h5EED;

    task check(input c, input [8*48-1:0] msg);
        if (!c) begin
            errs = errs + 1;
            $display("FAIL @%0t: %0s", $time, msg);
        end
    endtask

    function in_range(input [ADDR_WIDTH-1:0] a);
        in_range = ((a >> SH) < DEPTH);
    endfunction

    function integer rnd(input integer max);
        rnd = {$random(seed)} % max;
    endfunction

    function [DATA_WIDTH-1:0] rnd_data(input integer dummy);
        reg [63:0] t;
        begin
            t = {$random(seed), $random(seed)};
            rnd_data = t[DATA_WIDTH-1:0];
        end
    endfunction

    task model_write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d, input [BYTES-1:0] s);
        integer b, idx;
        begin
            idx = a >> SH;
            for (b = 0; b < BYTES; b = b + 1)
                if (s[b]) model[idx][b*8 +: 8] = d[b*8 +: 8];
        end
    endtask

    task do_wr(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d, input [BYTES-1:0] s,
               input integer awd, input integer wd, input integer bd);
        begin
            axi_write(a, d, s, awd, wd, bd);
            n_wr = n_wr + 1;
            if (in_range(a)) begin
                check(last_bresp == 2'b00, "BRESP deveria ser OKAY");
                model_write(a, d, s);
            end else begin
                check(last_bresp == 2'b10, "BRESP deveria ser SLVERR");
                n_err_resp = n_err_resp + 1;
            end
        end
    endtask

    task do_rd(input [ADDR_WIDTH-1:0] a, input integer ard, input integer rd);
        begin
            axi_read(a, ard, rd);
            n_rd = n_rd + 1;
            if (in_range(a)) begin
                check(last_rresp == 2'b00, "RRESP deveria ser OKAY");
                check(last_rdata === model[a >> SH], "RDATA diferente do modelo");
            end else begin
                check(last_rresp == 2'b10, "RRESP deveria ser SLVERR");
                check(last_rdata === {DATA_WIDTH{1'b0}}, "RDATA fora da faixa deveria ser 0");
                n_err_resp = n_err_resp + 1;
            end
        end
    endtask

    // leitura concorrente (modelo ja sabe o valor esperado em "exp", resultado em rd_ok)
    reg [DATA_WIDTH-1:0] c_exp;
    reg [DATA_WIDTH-1:0] c_old, c_new;
    reg [1:0]            c_rresp;
    reg [DATA_WIDTH-1:0] c_rdata;

    integer i, j, k, n, op;
    reg [ADDR_WIDTH-1:0] a, ra;
    reg [DATA_WIDTH-1:0] d;
    reg [BYTES-1:0]      s;

    initial begin
        if ($test$plusargs("dump")) begin $dumpfile("build/tb_top.vcd"); $dumpvars(0, tb_top); end
        for (i = 0; i < DEPTH; i = i + 1) model[i] = {DATA_WIDTH{1'b0}};
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        // 1) conteudo inicial zerado
        for (i = 0; i < DEPTH; i = i + 1) do_rd(i << SH, 0, 0);

        // 2) escreve e le de volta cada endereco
        for (i = 0; i < DEPTH; i = i + 1) do_wr(i << SH, rnd_data(0), {BYTES{1'b1}}, 0, 0, 0);
        for (i = 0; i < DEPTH; i = i + 1) do_rd(i << SH, 0, 0);

        // 3) WSTRB parcial e zero
        do_wr(32'h4, {DATA_WIDTH{1'b1}}, {BYTES{1'b0}}, 0, 0, 0);
        do_rd(32'h4, 0, 0);
        do_wr(32'h4, {DATA_WIDTH{1'b1}}, {{BYTES-1{1'b0}}, 1'b1}, 0, 0, 0);
        do_rd(32'h4, 0, 0);
        do_wr(32'h4, 64'hA5A5A5A5_5A5A5A5A, {BYTES{1'b1}} & 8'hAA, 0, 0, 0);
        do_rd(32'h4, 0, 0);

        // 4) varredura de atrasos
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1)
                for (k = 0; k < 4; k = k + 1) begin
                    a = ((i * 5 + j * 3 + k) % DEPTH) << SH;
                    do_wr(a, rnd_data(0), {BYTES{1'b1}}, i, j, k);
                    do_rd(a, k, i + j);
                end

        // 5) fora da faixa nao altera a memoria
        do_wr(DEPTH << SH, 64'hDEAD_BEEF_DEAD_BEEF, {BYTES{1'b1}}, 0, 0, 0);
        do_wr((DEPTH * 2) << SH, 64'hDEAD_BEEF_DEAD_BEEF, {BYTES{1'b1}}, 0, 0, 0);
        do_rd(DEPTH << SH, 0, 0);
        do_rd(((1 << ADDR_WIDTH) - 4), 2, 1);
        for (i = 0; i < DEPTH; i = i + 1) do_rd(i << SH, 0, 0);

        // 6) nao alinhado
        do_wr((2 << SH) + 1, 64'h0123_4567_89AB_CDEF, {BYTES{1'b1}}, 0, 0, 0);
        do_rd((2 << SH) + (BYTES - 1), 0, 0);

        // 7) escrita e leitura concorrentes, enderecos diferentes
        for (i = 0; i < 40; i = i + 1) begin
            a  = rnd(DEPTH) << SH;
            ra = ((a >> SH) + 1 + rnd(DEPTH - 1)) % DEPTH;
            ra = ra << SH;
            if (DEPTH == 1) ra = a;
            d  = rnd_data(0);
            if (DEPTH > 1)
                fork
                    do_wr(a, d, {BYTES{1'b1}}, rnd(3), rnd(3), rnd(3));
                    do_rd(ra, rnd(3), rnd(3));
                join
        end

        // 8) escrita e leitura concorrentes no MESMO endereco: leitura devolve valor antigo ou novo
        for (i = 0; i < 40; i = i + 1) begin
            a = rnd(DEPTH) << SH;
            d = rnd_data(0);
            c_old = model[a >> SH];
            c_new = d;
            fork
                axi_write(a, d, {BYTES{1'b1}}, rnd(3), rnd(3), rnd(3));
                axi_read(a, rnd(3), rnd(3));
            join
            model_write(a, d, {BYTES{1'b1}});
            check(last_bresp == 2'b00 && last_rresp == 2'b00, "resp != OKAY em acesso concorrente");
            check(last_rdata === c_old || last_rdata === c_new, "leitura concorrente nao eh antigo nem novo");
            do_rd(a, 0, 0);
        end

        // 9) teste aleatorio
        for (n = 0; n < N_RANDOM; n = n + 1) begin
            op = rnd(3);
            a  = (rnd(DEPTH + 4) << SH) | rnd(BYTES);
            ra = (rnd(DEPTH + 4) << SH) | rnd(BYTES);
            d  = rnd_data(0);
            s  = rnd_data(0);
            if (op == 0)      do_wr(a, d, s, rnd(5), rnd(5), rnd(5));
            else if (op == 1) do_rd(a, rnd(5), rnd(5));
            else begin
                // concorrentes: so se nao tocarem a mesma palavra
                if ((a >> SH) == (ra >> SH)) do_wr(a, d, s, rnd(5), rnd(5), rnd(5));
                else
                    fork
                        do_wr(a, d, s, rnd(5), rnd(5), rnd(5));
                        do_rd(ra, rnd(5), rnd(5));
                    join
            end
        end
        for (i = 0; i < DEPTH; i = i + 1) do_rd(i << SH, 0, 0);

        // 10) reset no meio de transacoes (AW aceito sem W; AR aceito)
        awaddr <= 32'h8; awvalid <= 1'b1;
        @(posedge aclk); while (!awready) @(posedge aclk);
        awvalid <= 1'b0;
        araddr <= 32'hC; arvalid <= 1'b1;
        @(posedge aclk); while (!arready) @(posedge aclk);
        arvalid <= 1'b0;
        aresetn <= 1'b0;
        repeat (2) @(posedge aclk);
        check(bvalid === 1'b0 && rvalid === 1'b0, "VALID de resposta durante reset");
        aresetn <= 1'b1;
        @(posedge aclk);
        check(awready === 1'b1 && wready === 1'b1 && arready === 1'b1, "FSMs nao voltaram a IDLE apos reset");
        check(bvalid === 1'b0 && rvalid === 1'b0, "VALID espurio apos reset");
        do_wr(32'h8, rnd_data(0), {BYTES{1'b1}}, 0, 0, 0);
        do_rd(32'h8, 0, 0);
        do_rd(32'hC, 0, 0);

        repeat (5) @(posedge aclk);
        check(chk_errors == 0, "violacoes do checker de protocolo");
        $display("INFO: %0d escritas, %0d leituras, %0d respostas SLVERR, %0d violacoes do checker",
                 n_wr, n_rd, n_err_resp, chk_errors);
        if (errs == 0) $display("RESULT: PASS tb_top");
        else           $display("RESULT: FAIL tb_top (%0d erros)", errs);
        $finish;
    end

    initial begin
        #50_000_000;
        $display("RESULT: FAIL tb_top (timeout)");
        $finish;
    end
endmodule
