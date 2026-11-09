// sram_agent_cfg.svh - configuracao do agente SRAM (vif, checagem de temporizacao).
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_AGENT_CFG_SVH
`define SRAM_AGENT_CFG_SVH

class sram_agent_cfg extends uvm_object;
  `uvm_object_utils(sram_agent_cfg)

  // TODO: vif sram_if e flag de checagem de temporizacao

  function new(string name = "sram_agent_cfg");
    super.new(name);
  endfunction

endclass : sram_agent_cfg

`endif // SRAM_AGENT_CFG_SVH
