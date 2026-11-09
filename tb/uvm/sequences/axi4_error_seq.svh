// axi4_error_seq.svh - sequencia: endereco fora da faixa / SLVERR/DECERR (decoder).
// Cobre: T-S-ROB
`ifndef AXI4_ERROR_SEQ_SVH
`define AXI4_ERROR_SEQ_SVH

class axi4_error_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_error_seq)

  function new(string name = "axi4_error_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: endereco fora da faixa / SLVERR/DECERR (decoder)
  endtask

endclass : axi4_error_seq

`endif // AXI4_ERROR_SEQ_SVH
