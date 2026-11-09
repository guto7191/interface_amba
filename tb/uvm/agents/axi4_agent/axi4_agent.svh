// axi4_agent.svh - agente AXI4 (sequencer + driver + monitor).
// Cobre: T-S-AXI
`ifndef AXI4_AGENT_SVH
`define AXI4_AGENT_SVH

class axi4_agent extends uvm_agent;
  `uvm_component_utils(axi4_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar monitor sempre; sequencer/driver se is_active
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_agent
  endfunction

endclass : axi4_agent

`endif // AXI4_AGENT_SVH
