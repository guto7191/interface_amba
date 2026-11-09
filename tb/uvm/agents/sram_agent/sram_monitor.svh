// sram_monitor.svh - monitor passivo; amostra pinos da SRAM e checa temporizacao.
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_MONITOR_SVH
`define SRAM_MONITOR_SVH

class sram_monitor extends uvm_monitor;
  `uvm_component_utils(sram_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: amostrar pinos, publicar sram_seq_item e checar temporizacao (R-12)
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: amostrar pinos, publicar sram_seq_item e checar temporizacao (R-12)
  endtask

endclass : sram_monitor

`endif // SRAM_MONITOR_SVH
