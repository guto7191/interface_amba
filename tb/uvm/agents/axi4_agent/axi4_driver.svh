// axi4_driver.svh - driver manager AXI4; canais AW/W/B/AR/R independentes.
// Cobre: T-S-AXI, T-S-ARB, T-S-ORD, T-S-ROB
`ifndef AXI4_DRIVER_SVH
`define AXI4_DRIVER_SVH

class axi4_driver extends uvm_driver#(axi4_seq_item);
  `uvm_component_utils(axi4_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: driver dos 5 canais com handshake valid/ready e atrasos
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: driver dos 5 canais com handshake valid/ready e atrasos
  endtask

endclass : axi4_driver

`endif // AXI4_DRIVER_SVH
