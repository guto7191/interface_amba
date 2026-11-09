// axi4_id_ordering_seq.svh - sequencia: ordenacao por ID.
// Cobre: T-S-ORD, R-03
`ifndef AXI4_ID_ORDERING_SEQ_SVH
`define AXI4_ID_ORDERING_SEQ_SVH

class axi4_id_ordering_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_id_ordering_seq)

  function new(string name = "axi4_id_ordering_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: ordenacao por ID
  endtask

endclass : axi4_id_ordering_seq

`endif // AXI4_ID_ORDERING_SEQ_SVH
