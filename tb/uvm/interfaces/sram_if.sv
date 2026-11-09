// sram_if.sv - pinos da SRAM IS61WV102416 (1M x 16); somente observacao.
// Cobre: T-S-SRAM, R-12
// NOTA: a SRAM e assincrona e captura a escrita na subida de we_n. O mon_cb amostra por aclk
// e so ve o que esta estavel na borda. O sram_monitor decide se tambem precisa de
// @(posedge we_n) (nao implementado aqui).
interface sram_if (input logic aclk);
  logic [19:0] addr;
  wire  [15:0] dq;
  logic        oe_n, we_n, lb_n, ub_n, ce_n;

  clocking mon_cb @(posedge aclk);
    default input #1step;
    input addr, dq, oe_n, we_n, lb_n, ub_n, ce_n;
  endclocking : mon_cb

  modport MON (clocking mon_cb);
endinterface : sram_if
