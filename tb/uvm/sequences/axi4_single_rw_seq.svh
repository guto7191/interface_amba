// axi4_single_rw_seq.svh - sequencia: escrita/leitura de um beat.
// Cobre: T-S-AXI
`ifndef AXI4_SINGLE_RW_SEQ_SVH
`define AXI4_SINGLE_RW_SEQ_SVH

class axi4_single_rw_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_single_rw_seq)

  function new(string name = "axi4_single_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: escrita/leitura de um beat
  endtask

endclass : axi4_single_rw_seq

`endif // AXI4_SINGLE_RW_SEQ_SVH
