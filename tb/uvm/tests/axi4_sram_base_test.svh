// axi4_sram_base_test.svh - teste base: constroi env/cfg, le vif do config_db, timeout.
// Cobre: VP §3
`ifndef AXI4_SRAM_BASE_TEST_SVH
`define AXI4_SRAM_BASE_TEST_SVH

class axi4_sram_base_test extends uvm_test;
  `uvm_component_utils(axi4_sram_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar cfg/env, obter vifs do config_db, configurar timeout
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: criar cfg/env, obter vifs do config_db, configurar timeout
  endtask

endclass : axi4_sram_base_test

`endif // AXI4_SRAM_BASE_TEST_SVH
