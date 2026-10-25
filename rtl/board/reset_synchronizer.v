// reset_synchronizer - converte o reset assincrono externo (KEY[0]) em aresetn sincrono.
// MAS §5.1. Padrao: assert assincrono, deassert sincrono, com dois flip-flops em cascata.
//
// - Assert assincrono: ao apertar o botao o reset vale na hora, mesmo sem clock (um reset
//   precisa funcionar com o clock ausente).
// - Deassert sincrono: ao soltar, o '1' atravessa dois flip-flops antes de chegar a aresetn,
//   entao todos os registradores saem do reset no mesmo ciclo de clock.
// Isto nao e CDC (MAS §6.1.1): e a entrada de um sinal assincrono por natureza no dominio
// sincrono. A conversao de polaridade para a IP (rst_i = ~aresetn) e feita no wrapper.
module reset_synchronizer (
    input  clk,
    input  async_reset_n,   // ativo-baixo, assincrono (botao)
    output aresetn          // ativo-baixo, sincrono ao clk
);

    reg sync_ff1_q;
    reg sync_ff2_q;

    always @(posedge clk or negedge async_reset_n) begin
        if (!async_reset_n) begin
            sync_ff1_q <= 1'b0;
            sync_ff2_q <= 1'b0;
        end else begin
            sync_ff1_q <= 1'b1;
            sync_ff2_q <= sync_ff1_q;
        end
    end

    assign aresetn = sync_ff2_q;

endmodule
