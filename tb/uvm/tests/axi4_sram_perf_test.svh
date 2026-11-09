// axi4_sram_perf_test.svh - teste: desempenho (ciclos/beat).
// Cobre: T-S-PERF
`ifndef AXI4_SRAM_PERF_TEST_SVH
`define AXI4_SRAM_PERF_TEST_SVH

class axi4_sram_perf_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_perf_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: desempenho (ciclos/beat)
  endtask

endclass : axi4_sram_perf_test

`endif // AXI4_SRAM_PERF_TEST_SVH
