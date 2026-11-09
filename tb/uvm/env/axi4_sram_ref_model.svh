// axi4_sram_ref_model.svh - memoria de referencia 1M x 16 com byte lanes.
// Cobre: T-S-SRAM, T-S-SZ
`ifndef AXI4_SRAM_REF_MODEL_SVH
`define AXI4_SRAM_REF_MODEL_SVH

class axi4_sram_ref_model extends uvm_component;
  `uvm_component_utils(axi4_sram_ref_model)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: alocar memoria 1M x 16 e metodos de leitura/escrita com strb
  endfunction

endclass : axi4_sram_ref_model

`endif // AXI4_SRAM_REF_MODEL_SVH
