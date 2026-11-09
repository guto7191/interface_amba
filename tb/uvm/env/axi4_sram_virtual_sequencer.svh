// axi4_sram_virtual_sequencer.svh - sequenciador virtual com handle do sequencer AXI4.
// Cobre: T-S-ARB
`ifndef AXI4_SRAM_VIRTUAL_SEQUENCER_SVH
`define AXI4_SRAM_VIRTUAL_SEQUENCER_SVH

class axi4_sram_virtual_sequencer extends uvm_sequencer#(uvm_sequence_item);
  `uvm_component_utils(axi4_sram_virtual_sequencer)

  // TODO: handle do axi4_sequencer (atribuido no connect_phase do env)
  // axi4_sequencer axi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: declarar handle axi4_sequencer
  endfunction

endclass : axi4_sram_virtual_sequencer

`endif // AXI4_SRAM_VIRTUAL_SEQUENCER_SVH
