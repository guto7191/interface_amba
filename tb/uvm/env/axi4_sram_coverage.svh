// axi4_sram_coverage.svh - cobertura funcional (covergroups).
// Cobre: VP §4.1
`ifndef AXI4_SRAM_COVERAGE_SVH
`define AXI4_SRAM_COVERAGE_SVH

class axi4_sram_coverage extends uvm_subscriber#(axi4_seq_item);
  `uvm_component_utils(axi4_sram_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: definir covergroups (burst, len, size, id, resp) e amostrar em write()
  endfunction

  // uvm_subscriber exige write()
  virtual function void write(axi4_seq_item t);
    // TODO: amostrar covergroups com a transacao t
  endfunction

endclass : axi4_sram_coverage

`endif // AXI4_SRAM_COVERAGE_SVH
