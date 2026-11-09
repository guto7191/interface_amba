// axi4_seq_item.svh - transacao AXI4 (rw, id, addr, len, size, burst, data[], strb[], resp[]).
// Cobre: T-S-AXI, T-S-SZ, T-S-ORD
`ifndef AXI4_SEQ_ITEM_SVH
`define AXI4_SEQ_ITEM_SVH

class axi4_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi4_seq_item)

  // TODO: campos rw, id, addr, len, size, burst, data[], strb[], resp[] (sem constraints ainda)

  function new(string name = "axi4_seq_item");
    super.new(name);
  endfunction

endclass : axi4_seq_item

`endif // AXI4_SEQ_ITEM_SVH
