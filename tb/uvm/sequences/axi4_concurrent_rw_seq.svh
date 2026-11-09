// axi4_concurrent_rw_seq.svh - sequencia: leitura e escrita concorrentes (round-robin).
// Cobre: T-S-ARB
`ifndef AXI4_CONCURRENT_RW_SEQ_SVH
`define AXI4_CONCURRENT_RW_SEQ_SVH

class axi4_concurrent_rw_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_concurrent_rw_seq)

  function new(string name = "axi4_concurrent_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: leitura e escrita concorrentes (round-robin)
  endtask

endclass : axi4_concurrent_rw_seq

`endif // AXI4_CONCURRENT_RW_SEQ_SVH
