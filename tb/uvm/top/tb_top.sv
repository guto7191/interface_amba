// tb_top.sv - topo: clock 50 MHz, reset, DUT #(PHASE), modelo SRAM, ifs, config_db, run_test().
// Cobre: VP §3 (todos), R-12
`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_sram_test_pkg::*;

  // Fase do DUT (padrao 2); override opcional por -defparam tb_top.PHASE=1
  parameter PHASE = 2;

  // clock de 50 MHz (periodo 20 ns)
  logic aclk = 0;
  always #10 aclk = ~aclk;

  // reset: KEY[0] ativo-baixo por 4 ciclos; o DUT o sincroniza (aresetn_w)
  logic [3:0] key = 4'hE;
  initial begin
    repeat (4) @(posedge aclk);
    key[0] = 1'b1;
  end

  // a axi_if usa o reset ja sincronizado do DUT
  wire aresetn_axi = dut.aresetn_w;

  axi4_if axi_if (aclk, aresetn_axi);
  sram_if sram_if_i (aclk);

  // saidas de observacao do modelo da SRAM
  wire [31:0] sram_errors, sram_access_count, sram_we_pulse_count;

  de2_115_top #(.PHASE(PHASE)) dut (
    .CLOCK_50(aclk), .KEY(key),
    .SRAM_ADDR(sram_if_i.addr), .SRAM_DQ(sram_if_i.dq),
    .SRAM_OE_N(sram_if_i.oe_n), .SRAM_WE_N(sram_if_i.we_n),
    .SRAM_CE_N(sram_if_i.ce_n), .SRAM_LB_N(sram_if_i.lb_n), .SRAM_UB_N(sram_if_i.ub_n),
    .s_axi_awid(axi_if.awid), .s_axi_awaddr(axi_if.awaddr), .s_axi_awlen(axi_if.awlen),
    .s_axi_awsize(axi_if.awsize), .s_axi_awburst(axi_if.awburst),
    .s_axi_awvalid(axi_if.awvalid), .s_axi_awready(axi_if.awready),
    .s_axi_wdata(axi_if.wdata), .s_axi_wstrb(axi_if.wstrb), .s_axi_wlast(axi_if.wlast),
    .s_axi_wvalid(axi_if.wvalid), .s_axi_wready(axi_if.wready),
    .s_axi_bid(axi_if.bid), .s_axi_bresp(axi_if.bresp),
    .s_axi_bvalid(axi_if.bvalid), .s_axi_bready(axi_if.bready),
    .s_axi_arid(axi_if.arid), .s_axi_araddr(axi_if.araddr), .s_axi_arlen(axi_if.arlen),
    .s_axi_arsize(axi_if.arsize), .s_axi_arburst(axi_if.arburst),
    .s_axi_arvalid(axi_if.arvalid), .s_axi_arready(axi_if.arready),
    .s_axi_rid(axi_if.rid), .s_axi_rdata(axi_if.rdata), .s_axi_rresp(axi_if.rresp),
    .s_axi_rlast(axi_if.rlast), .s_axi_rvalid(axi_if.rvalid), .s_axi_rready(axi_if.rready));

  // modelo comportamental da SRAM (copia propria em tb/uvm/models/)
  sram_is61wv102416_behavioral_model sram_model (
    .addr(sram_if_i.addr), .dq(sram_if_i.dq),
    .ce_n(sram_if_i.ce_n), .oe_n(sram_if_i.oe_n), .we_n(sram_if_i.we_n),
    .lb_n(sram_if_i.lb_n), .ub_n(sram_if_i.ub_n),
    .sample_clk(aclk),
    .errors(sram_errors), .access_count(sram_access_count),
    .we_pulse_count(sram_we_pulse_count));

  initial begin
    uvm_config_db#(virtual axi4_if)::set(null, "*", "axi_vif", axi_if);
    uvm_config_db#(virtual sram_if)::set(null, "*", "sram_vif", sram_if_i);
    run_test();
  end

  // formas de onda opcionais (+dump)
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("tb_top.vcd");
      $dumpvars(0, tb_top);
    end
  end
endmodule : tb_top
