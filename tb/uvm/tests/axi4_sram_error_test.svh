// axi4_sram_error_test.svh - teste: enderecos invalidos / respostas de erro.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_ERROR_TEST_SVH
`define AXI4_SRAM_ERROR_TEST_SVH

class axi4_sram_error_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: enderecos invalidos / respostas de erro
  endtask

endclass : axi4_sram_error_test

`endif // AXI4_SRAM_ERROR_TEST_SVH
