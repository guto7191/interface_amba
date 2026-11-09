// axi4_sram_env.svh - ambiente: agentes, ref_model, scoreboard, coverage.
// Cobre: VP §3
`ifndef AXI4_SRAM_ENV_SVH
`define AXI4_SRAM_ENV_SVH

class axi4_sram_env extends uvm_env;
  `uvm_component_utils(axi4_sram_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar agentes/scoreboard/coverage; conectar analysis ports
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_sram_env
  endfunction

endclass : axi4_sram_env

`endif // AXI4_SRAM_ENV_SVH
