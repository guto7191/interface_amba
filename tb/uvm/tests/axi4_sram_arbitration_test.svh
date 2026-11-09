// axi4_sram_arbitration_test.svh - teste: arbitragem round-robin.
// Cobre: T-S-ARB
`ifndef AXI4_SRAM_ARBITRATION_TEST_SVH
`define AXI4_SRAM_ARBITRATION_TEST_SVH

class axi4_sram_arbitration_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_arbitration_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: arbitragem round-robin
  endtask

endclass : axi4_sram_arbitration_test

`endif // AXI4_SRAM_ARBITRATION_TEST_SVH
