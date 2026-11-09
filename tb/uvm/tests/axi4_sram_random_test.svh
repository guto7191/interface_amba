// axi4_sram_random_test.svh - teste: estresse aleatorio com seeds.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_RANDOM_TEST_SVH
`define AXI4_SRAM_RANDOM_TEST_SVH

class axi4_sram_random_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: estresse aleatorio com seeds
  endtask

endclass : axi4_sram_random_test

`endif // AXI4_SRAM_RANDOM_TEST_SVH
