// Funcoes normativas de endereco e byte lane de um beat AXI4 (IHI0022E §A3.4.1 e §A3.4.3),
// escritas de forma independente do RTL: servem de referencia para o scoreboard e o gerador.
// Incluido dentro do modulo do testbench; a guarda evita definicao dupla.
`ifndef AXI4_BEAT_FUNCS_DEFINED
`define AXI4_BEAT_FUNCS_DEFINED

// Address_1 = Start_Address; Address_N = Aligned_Address + (N-1) * Number_Bytes   (n = 0, 1, ...)
function [31:0] axi_beat_addr(input [31:0] start, input [2:0] size, input integer n);
    reg [31:0] nb, aligned;
    begin
        nb      = 32'd1 << size;
        aligned = start & ~(nb - 32'd1);
        if (n == 0) axi_beat_addr = start;
        else        axi_beat_addr = aligned + n * nb;
    end
endfunction

// lanes do barramento de 32 bits usadas no beat n:  Lower_Byte_Lane .. Upper_Byte_Lane
function [3:0] lane_mask(input [31:0] start, input [2:0] size, input integer n);
    reg [31:0] nb, aligned, beat_addr;
    integer    lower, upper, b;
    begin
        nb      = 32'd1 << size;
        aligned = start & ~(nb - 32'd1);
        if (n == 0) begin
            lower = start[1:0];
            upper = aligned[1:0] + nb - 1;
        end else begin
            beat_addr = aligned + n * nb;
            lower     = beat_addr[1:0];
            upper     = lower + nb - 1;
        end
        lane_mask = 4'b0000;
        for (b = 0; b < 4; b = b + 1)
            if (b >= lower && b <= upper) lane_mask[b] = 1'b1;
    end
endfunction

// resposta esperada de um burst: DECERR (fora de 0x0..0x1FFFFF, inicio ou fim), SLVERR
// (AxSIZE > 4 bytes) ou OKAY. DECERR tem precedencia (MAS §5.3.1). Retorna 0, 2 ou 3.
function integer expected_resp(input [31:0] start, input [7:0] len, input [2:0] size);
    reg [31:0] nb, aligned, last;
    begin
        nb      = 32'd1 << size;
        aligned = start & ~(nb - 32'd1);
        last    = aligned + ((len + 32'd1) << size) - 32'd1;
        if (start >= 32'h0020_0000 || last >= 32'h0020_0000) expected_resp = 3;
        else if (size > 3'd2)                                 expected_resp = 2;
        else                                                  expected_resp = 0;
    end
endfunction

`endif
