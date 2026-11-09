// axi4_sram_narrow_test.svh - teste: acessos narrow.
// Cobre: T-S-SZ
`ifndef AXI4_SRAM_NARROW_TEST_SVH
`define AXI4_SRAM_NARROW_TEST_SVH

class axi4_sram_narrow_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_narrow_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: acessos narrow
  endtask

endclass : axi4_sram_narrow_test

`endif // AXI4_SRAM_NARROW_TEST_SVH
