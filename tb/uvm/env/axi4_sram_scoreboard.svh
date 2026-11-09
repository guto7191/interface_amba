// axi4_sram_scoreboard.svh - scoreboard: AXI esperado x observado; ordenacao por ID.
// Cobre: T-S-AXI, T-S-ORD, R-03
`ifndef AXI4_SRAM_SCOREBOARD_SVH
`define AXI4_SRAM_SCOREBOARD_SVH

class axi4_sram_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_sram_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: comparar respostas AXI com ref_model e checar ordem por ID
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_sram_scoreboard
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: comparar respostas AXI com ref_model e checar ordem por ID
  endtask

endclass : axi4_sram_scoreboard

`endif // AXI4_SRAM_SCOREBOARD_SVH
