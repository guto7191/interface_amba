// axi4_narrow_seq.svh - sequencia: acessos narrow (AxSIZE < 2, byte lanes).
// Cobre: T-S-SZ
`ifndef AXI4_NARROW_SEQ_SVH
`define AXI4_NARROW_SEQ_SVH

class axi4_narrow_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_narrow_seq)

  function new(string name = "axi4_narrow_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: acessos narrow (AxSIZE < 2, byte lanes)
  endtask

endclass : axi4_narrow_seq

`endif // AXI4_NARROW_SEQ_SVH
