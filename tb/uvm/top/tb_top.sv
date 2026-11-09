// tb_top.sv - topo: clock 50 MHz, reset, DUT #(PHASE), modelo SRAM, ifs, config_db, run_test().
// Cobre: VP §3 (todos), R-12
`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_sram_test_pkg::*;

  // TODO: parametro PHASE (default 2, sobrescrevivel por +define/-defparam)
  logic aclk = 0, aresetn = 0;
  // TODO: gerar clock de 50 MHz (periodo 20 ns)
  // TODO: sequencia de reset (aresetn)

  axi4_if axi_if (aclk, aresetn);
  sram_if sram_if_i (aclk);

  // TODO: instanciar axi_interface_subordinate_sram #(.PHASE(PHASE)) ligando axi_if e sram_if_i
  // TODO: instanciar modelo behavioral da SRAM (tb/testbench_legado/models/sram_is61wv102416_behavioral_model.v) e tri-state de dq
  // TODO: uvm_config_db#(virtual axi4_if)::set / virtual sram_if
  // TODO: run_test() em initial; dump de formas de onda opcional
endmodule : tb_top
