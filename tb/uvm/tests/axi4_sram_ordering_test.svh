// axi4_sram_ordering_test.svh - teste: ordenacao por ID.
// Cobre: T-S-ORD, R-03
`ifndef AXI4_SRAM_ORDERING_TEST_SVH
`define AXI4_SRAM_ORDERING_TEST_SVH

class axi4_sram_ordering_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_ordering_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: ordenacao por ID
  endtask

endclass : axi4_sram_ordering_test

`endif // AXI4_SRAM_ORDERING_TEST_SVH
