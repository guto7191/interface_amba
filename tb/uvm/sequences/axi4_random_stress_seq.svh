// axi4_random_stress_seq.svh - sequencia: estresse aleatorio.
// Cobre: T-S-ROB
`ifndef AXI4_RANDOM_STRESS_SEQ_SVH
`define AXI4_RANDOM_STRESS_SEQ_SVH

class axi4_random_stress_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_random_stress_seq)

  function new(string name = "axi4_random_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: estresse aleatorio
  endtask

endclass : axi4_random_stress_seq

`endif // AXI4_RANDOM_STRESS_SEQ_SVH
