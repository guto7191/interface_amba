// Tarefas de mestre AXI4-Lite, incluidas dentro de cada testbench.
// Requer: aclk, regs de mestre (awaddr/awvalid, wdata/wstrb/wvalid, bready, araddr/arvalid, rready),
// wires de subordinado (awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid),
// e os parametros ADDR_WIDTH / DATA_WIDTH. Amostra no posedge, dirige com <=.

reg [1:0]            last_bresp;
reg [1:0]            last_rresp;
reg [DATA_WIDTH-1:0] last_rdata;

task aw_send(input [ADDR_WIDTH-1:0] a, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        awaddr  <= a;
        awvalid <= 1'b1;
        @(posedge aclk);
        while (!awready) @(posedge aclk);
        awvalid <= 1'b0;
    end
endtask

task w_send(input [DATA_WIDTH-1:0] d, input [DATA_WIDTH/8-1:0] s, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        wdata  <= d;
        wstrb  <= s;
        wvalid <= 1'b1;
        @(posedge aclk);
        while (!wready) @(posedge aclk);
        wvalid <= 1'b0;
    end
endtask

// BREADY sobe apos "dly" ciclos (0 = junto com o inicio da transacao, antes de BVALID)
task b_recv(input integer dly);
    begin
        bready <= 1'b0;
        repeat (dly) @(posedge aclk);
        bready <= 1'b1;
        @(posedge aclk);
        while (!bvalid) @(posedge aclk);
        last_bresp = bresp;
        bready <= 1'b0;
    end
endtask

task ar_send(input [ADDR_WIDTH-1:0] a, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        araddr  <= a;
        arvalid <= 1'b1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        arvalid <= 1'b0;
    end
endtask

task r_recv(input integer dly);
    begin
        rready <= 1'b0;
        repeat (dly) @(posedge aclk);
        rready <= 1'b1;
        @(posedge aclk);
        while (!rvalid) @(posedge aclk);
        last_rdata = rdata;
        last_rresp = rresp;
        rready <= 1'b0;
    end
endtask

task axi_write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d, input [DATA_WIDTH/8-1:0] s,
               input integer awd, input integer wd, input integer bd);
    begin
        fork
            aw_send(a, awd);
            w_send(d, s, wd);
            b_recv(bd);
        join
    end
endtask

task axi_read(input [ADDR_WIDTH-1:0] a, input integer ard, input integer rd);
    begin
        fork
            ar_send(a, ard);
            r_recv(rd);
        join
    end
endtask
