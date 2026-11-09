// sram_agent.svh - agente SRAM, sempre UVM_PASSIVE (so monitor).
// Cobre: T-S-SRAM
`ifndef SRAM_AGENT_SVH
`define SRAM_AGENT_SVH

class sram_agent extends uvm_agent;
  `uvm_component_utils(sram_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar apenas o monitor; forcar UVM_PASSIVE
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de sram_agent
  endfunction

endclass : sram_agent

`endif // SRAM_AGENT_SVH
