// sram_if.sv - pinos da SRAM IS61WV102416 (1M x 16); somente observacao.
// Cobre: T-S-SRAM, R-12
interface sram_if (input logic aclk);
  logic [19:0] addr;
  wire  [15:0] dq;
  logic        oe_n, we_n, lb_n, ub_n, ce_n;

  // TODO: clocking block mon (todos input) para o sram_monitor
  // clocking mon_cb @(posedge aclk); ... endclocking
  // TODO: modport MON (clocking mon_cb)
endinterface : sram_if
