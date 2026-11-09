// axi4_sram_bind.sv - bind do axi_protocol_checker (copia em tb/uvm/checkers/) ao DUT.
// Cobre: T-S-AXI (conformidade de protocolo)
// TODO: bind axi_interface_subordinate_sram axi_protocol_checker u_chk (...);
//       conectar os sinais s_axi_* e aclk/aresetn (checker de tb/uvm/checkers/axi_protocol_checker.v)
module axi4_sram_bind;
  // TODO: ajustar parametros/portas do checker (AXI4_FULL=1)
endmodule : axi4_sram_bind
