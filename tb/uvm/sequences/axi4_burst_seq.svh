// axi4_burst_seq.svh - sequencia: bursts INCR/WRAP/FIXED, len 0..255.
// Cobre: T-S-AXI
`ifndef AXI4_BURST_SEQ_SVH
`define AXI4_BURST_SEQ_SVH

class axi4_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_burst_seq)

  function new(string name = "axi4_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: bursts INCR/WRAP/FIXED, len 0..255
  endtask

endclass : axi4_burst_seq

`endif // AXI4_BURST_SEQ_SVH
