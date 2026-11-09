// axi4_sram_burst_test.svh - teste: bursts INCR/WRAP/FIXED.
// Cobre: T-S-AXI
`ifndef AXI4_SRAM_BURST_TEST_SVH
`define AXI4_SRAM_BURST_TEST_SVH

class axi4_sram_burst_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_burst_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: bursts INCR/WRAP/FIXED
  endtask

endclass : axi4_sram_burst_test

`endif // AXI4_SRAM_BURST_TEST_SVH
