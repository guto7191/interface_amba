// axi4_sram_reset_test.svh - teste: reset no meio de uma transacao.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_RESET_TEST_SVH
`define AXI4_SRAM_RESET_TEST_SVH

class axi4_sram_reset_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_reset_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: reset no meio de uma transacao
  endtask

endclass : axi4_sram_reset_test

`endif // AXI4_SRAM_RESET_TEST_SVH
