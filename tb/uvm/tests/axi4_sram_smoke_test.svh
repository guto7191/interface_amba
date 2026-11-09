// axi4_sram_smoke_test.svh - teste: teste de fumaca (escrita+leitura simples).
// Cobre: T-S-AXI
`ifndef AXI4_SRAM_SMOKE_TEST_SVH
`define AXI4_SRAM_SMOKE_TEST_SVH

class axi4_sram_smoke_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: teste de fumaca (escrita+leitura simples)
  endtask

endclass : axi4_sram_smoke_test

`endif // AXI4_SRAM_SMOKE_TEST_SVH
