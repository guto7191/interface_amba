// axi4_monitor.svh - monitor AXI4; reconstroi transacoes e publica na analysis_port.
// Cobre: T-S-AXI, T-S-ORD, R-03
`ifndef AXI4_MONITOR_SVH
`define AXI4_MONITOR_SVH

class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: amostrar canais via vif e reconstruir transacoes (ap.write)
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: amostrar canais via vif e reconstruir transacoes (ap.write)
  endtask

endclass : axi4_monitor

`endif // AXI4_MONITOR_SVH
