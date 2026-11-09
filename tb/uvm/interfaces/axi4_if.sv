// axi4_if.sv - interface AXI4 (ID 4b, ADDR 32b, DATA 32b, STRB 4b, LEN 8b).
// Cobre: T-S-AXI, T-S-ARB, T-S-ORD
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

  // TODO: clocking block drv (saidas do manager: aw*/w*/ar*/bready/rready)
  // clocking drv_cb @(posedge aclk); ... endclocking
  // TODO: clocking block mon (todos os sinais como input)
  // clocking mon_cb @(posedge aclk); ... endclocking

  // TODO: modports (DRV com drv_cb, MON com mon_cb)
  // modport DRV (clocking drv_cb, input aresetn);
  // modport MON (clocking mon_cb, input aresetn);
endinterface : axi4_if
