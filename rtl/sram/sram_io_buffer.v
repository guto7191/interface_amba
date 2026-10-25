// sram_io_buffer - resolve o barramento bidirecional SRAM_DQ e liga os sinais aos pinos.
// MAS §5.2 (R-08, L-01).
//
// A controladora expoe dado de entrada e de saida separados e um sinal de direcao
// (data_out_en). Sem a direcao, a FPGA dirigiria DQ o tempo todo e entraria em contencao
// com a SRAM durante a leitura. O turnaround (um ciclo entre OE_N subir e data_out_en subir)
// e garantido pela controladora, que sempre passa por IDLE ao trocar de sentido.
//
// Os registradores de pino ficam na controladora; no Quartus eles sao empurrados para as
// celulas de I/O por FAST_OUTPUT_REGISTER / FAST_OUTPUT_ENABLE_REGISTER / FAST_INPUT_REGISTER
// no .qsf (MAS §8.2), ja que os atributos IOB da IP sao de Xilinx (L-04).
module sram_io_buffer (
    // lado da controladora
    input  [19:0] addr_i,
    input  [15:0] data_out_i,
    input         data_out_en_i,
    output [15:0] data_in_o,
    input         oe_n_i,
    input         we_n_i,
    input         lb_n_i,
    input         ub_n_i,
    input         ce_n_i,

    // pinos da placa
    output [19:0] SRAM_ADDR,
    inout  [15:0] SRAM_DQ,
    output        SRAM_OE_N,
    output        SRAM_WE_N,
    output        SRAM_LB_N,
    output        SRAM_UB_N,
    output        SRAM_CE_N
);

    // alta impedancia fora da janela de escrita
    assign SRAM_DQ   = data_out_en_i ? data_out_i : 16'bz;
    assign data_in_o = SRAM_DQ;

    assign SRAM_ADDR = addr_i;
    assign SRAM_OE_N = oe_n_i;
    assign SRAM_WE_N = we_n_i;
    assign SRAM_LB_N = lb_n_i;
    assign SRAM_UB_N = ub_n_i;
    assign SRAM_CE_N = ce_n_i;

endmodule
