// axi4_sram_bind.sv - bind do axi_protocol_checker (copia em tb/uvm/checkers/) ao DUT.
// Cobre: T-S-AXI (conformidade de protocolo)
// Observa os pinos s_axi_* do wrapper axi_interface_subordinate_sram (aresetn ja sincronizado).
// TIMEOUT/RESP_TIMEOUT ficam nos padroes (200/2000). A porta errors fica em u_chk.errors;
// quem le esse contador e falha o teste sera definido no plano do scoreboard.
module axi4_sram_bind;
  bind axi_interface_subordinate_sram axi_protocol_checker #(.AXI4_FULL(1)) u_chk (
    .aclk(aclk), .aresetn(aresetn),
    .awaddr(s_axi_awaddr), .awvalid(s_axi_awvalid), .awready(s_axi_awready),
    .wdata(s_axi_wdata), .wstrb(s_axi_wstrb), .wvalid(s_axi_wvalid), .wready(s_axi_wready),
    .bresp(s_axi_bresp), .bvalid(s_axi_bvalid), .bready(s_axi_bready),
    .araddr(s_axi_araddr), .arvalid(s_axi_arvalid), .arready(s_axi_arready),
    .rdata(s_axi_rdata), .rresp(s_axi_rresp), .rvalid(s_axi_rvalid), .rready(s_axi_rready),
    .errors(),
    .awid(s_axi_awid), .awlen(s_axi_awlen), .awsize(s_axi_awsize), .awburst(s_axi_awburst),
    .wlast(s_axi_wlast),
    .bid(s_axi_bid),
    .arid(s_axi_arid), .arlen(s_axi_arlen), .arsize(s_axi_arsize), .arburst(s_axi_arburst),
    .rid(s_axi_rid), .rlast(s_axi_rlast));
endmodule : axi4_sram_bind
