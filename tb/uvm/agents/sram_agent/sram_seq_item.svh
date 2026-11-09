// sram_seq_item.svh - acesso fisico a SRAM (addr, data, lb/ub, rd/wr, timestamp).
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_SEQ_ITEM_SVH
`define SRAM_SEQ_ITEM_SVH

class sram_seq_item extends uvm_sequence_item;
  `uvm_object_utils(sram_seq_item)

  // TODO: campos addr, data, lb/ub, rd/wr, timestamp

  function new(string name = "sram_seq_item");
    super.new(name);
  endfunction

endclass : sram_seq_item

`endif // SRAM_SEQ_ITEM_SVH
