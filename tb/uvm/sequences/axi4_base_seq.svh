// axi4_base_seq.svh - sequencia base (utilitarios comuns).
// Cobre: VP §3
`ifndef AXI4_BASE_SEQ_SVH
`define AXI4_BASE_SEQ_SVH

class axi4_base_seq extends uvm_sequence#(axi4_seq_item);
  `uvm_object_utils(axi4_base_seq)

  function new(string name = "axi4_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: utilitarios comuns (obter cfg, helpers de leitura/escrita)
  endtask

endclass : axi4_base_seq

`endif // AXI4_BASE_SEQ_SVH
