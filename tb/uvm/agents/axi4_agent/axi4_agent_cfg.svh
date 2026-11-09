// axi4_agent_cfg.svh - configuracao do agente AXI4 (is_active, vif, knobs de backpressure).
// Cobre: VP §3 (todos os T-S-*)
`ifndef AXI4_AGENT_CFG_SVH
`define AXI4_AGENT_CFG_SVH

class axi4_agent_cfg extends uvm_object;
  `uvm_object_utils(axi4_agent_cfg)

  // TODO: is_active, vif axi4_if, knobs de backpressure (atrasos de ready/valid)

  function new(string name = "axi4_agent_cfg");
    super.new(name);
  endfunction

endclass : axi4_agent_cfg

`endif // AXI4_AGENT_CFG_SVH
