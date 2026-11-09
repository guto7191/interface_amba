// axi4_if.sv - interface AXI4 (ID 4b, ADDR 32b, DATA 32b, STRB 4b, LEN 8b).
// Cobre: T-S-AXI, T-S-ARB, T-S-ORD
// Sinais sem prefixo s_axi_. Sem awlock/awcache/awprot/awqos/*user (MAS §3.1: ignorados).
// aresetn deve vir do reset ja sincronizado do DUT (aresetn_w); ver tb_top.
interface axi4_if (input logic aclk, input logic aresetn);
  logic [3:0]  awid, arid, bid, rid;
  logic [31:0] awaddr, araddr, wdata, rdata;
  logic [7:0]  awlen, arlen;
  logic [2:0]  awsize, arsize;
  logic [1:0]  awburst, arburst, bresp, rresp;
  logic [3:0]  wstrb;
  logic        awvalid, awready, arvalid, arready;
  logic        wvalid, wready, wlast;
  logic        bvalid, bready, rvalid, rready, rlast;

  // Driver (manager): dirige aw*/w*/ar*/bready/rready e amostra as respostas do DUT.
  // output #1ns evita corrida com o RTL; input #1step le o valor pre-borda.
  clocking drv_cb @(posedge aclk);
    default input #1step output #1ns;
    output awid, awaddr, awlen, awsize, awburst, awvalid;
    output wdata, wstrb, wlast, wvalid;
    output arid, araddr, arlen, arsize, arburst, arvalid;
    output bready, rready;
    input  awready, wready, arready;
    input  bid, bresp, bvalid;
    input  rid, rdata, rresp, rlast, rvalid;
  endclocking : drv_cb

  // Monitor: todos os sinais como input.
  clocking mon_cb @(posedge aclk);
    default input #1step;
    input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
    input wdata, wstrb, wlast, wvalid, wready;
    input bid, bresp, bvalid, bready;
    input arid, araddr, arlen, arsize, arburst, arvalid, arready;
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking : mon_cb

  modport DRV (clocking drv_cb, input aresetn);
  modport MON (clocking mon_cb, input aresetn);
endinterface : axi4_if
