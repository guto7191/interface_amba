// sram_controller - controladora da SRAM assincrona (Fase 2). MAS §5.5, D15.
//
// Implementa o contrato ram_* (MAS §3.2) sobre a SRAM de 16 bits. Cada beat de 32 bits vira
// dois acessos de 16 bits (metade baixa, depois alta).
//
//   Leitura: 1 ciclo por metade. A SRAM e assincrona (tAA = 10 ns < 20 ns), entao o endereco
//            da proxima metade/requisicao e apresentado no mesmo ciclo em que o dado atual e
//            capturado -> 2 ciclos por beat em regime.
//   Escrita: 2 ciclos por metade (D15). WE_N cai junto com endereco e dado (tSA = 0) e sobe um
//            ciclo depois, com endereco e dado mantidos por mais um ciclo (hold) -> 4 ciclos por
//            beat em regime. Toda a janela de fim de escrita tem folga de um ciclo.
//   Turnaround: a troca leitura<->escrita SEMPRE passa por S_IDLE, o que garante um ciclo
//            entre OE_N subir e data_out_en subir (e o inverso), sem contencao em SRAM_DQ.
//
// Saidas de pino sao registradores, carregados na mesma borda em que o estado muda: durante
// o estado S_X os pinos ja mostram o que S_X manda. Reset assincrono leva WE_N, OE_N e
// data_out_en a inativo (nao corrompe a SRAM e libera o barramento).
module sram_controller (
    input         aclk,
    input         aresetn,

    // contrato ram_* (vista da controladora)
    input  [31:0] ram_addr,          // bytes, ja alinhado a 4 (bits [1:0] = 0)
    input  [3:0]  ram_wr,            // strobes de escrita (pode ser 0)
    input         ram_wr_req,        // requisicao de escrita
    input         ram_rd,            // requisicao de leitura
    input  [2:0]  ram_size,          // nao usado: a leitura e sempre de 32 bits (MAS §7.2)
    input  [31:0] ram_write_data,
    output        ram_accept,
    output        ram_ack,
    output [31:0] ram_read_data,

    // lado da SRAM (pinos tratados em sram_io_buffer)
    output [19:0] sram_addr_o,
    output [15:0] sram_data_out_o,
    output        sram_data_out_en_o,
    input  [15:0] sram_data_in_i,
    output        sram_oe_n_o,
    output        sram_we_n_o,
    output        sram_lb_n_o,
    output        sram_ub_n_o,
    output        sram_ce_n_o
);

    // ---------------- estados ----------------
    localparam [2:0] S_IDLE         = 3'd0,  // aceita requisicao
                     S_RD_LOW       = 3'd1,  // endereco da metade baixa na SRAM (leitura)
                     S_RD_HIGH      = 3'd2,  // endereco da metade alta; captura a baixa
                     S_WR_LOW       = 3'd3,  // WE_N=0 na metade baixa
                     S_WR_LOW_HOLD  = 3'd4,  // WE_N=1, endereco e dado mantidos
                     S_WR_HIGH      = 3'd5,  // WE_N=0 na metade alta
                     S_WR_HIGH_HOLD = 3'd6;  // WE_N=1, endereco e dado mantidos

    reg [2:0] state_q, state_next_r;

    // ---------------- decodificacao da requisicao ----------------
    wire req_write_low_w  = ram_wr_req & (|ram_wr[1:0]);                    // escreve a metade baixa
    wire req_write_high_w = ram_wr_req & ~(|ram_wr[1:0]) & (|ram_wr[3:2]);  // so a metade alta
    wire req_write_null_w = ram_wr_req & ~(|ram_wr);                        // strobe nulo: so responde

    // ---------------- registradores de contexto da requisicao aceita ----------------
    reg [3:0]  wr_q;          // strobes
    reg [31:0] wdata_q;       // dado de escrita
    reg [18:0] word_q;        // indice da palavra de 32 bits (ram_addr[20:2])
    reg [15:0] data_lo_q;     // metade baixa lida

    // ---------------- registradores de pino e resposta ----------------
    reg [19:0] sram_addr_q;
    reg [15:0] sram_data_q;
    reg        oe_n_q, we_n_q, lb_n_q, ub_n_q, data_out_en_q;
    reg        ack_q;
    reg [31:0] read_data_q;

    // ---------------- aceitacao ----------------
    // IDLE aceita tudo; no ultimo estado de um acesso, aceita a proxima requisicao do mesmo
    // sentido (pipeline). Troca de sentido espera o IDLE.
    wire accept_idle_w  = (state_q == S_IDLE);
    wire accept_read_w  = (state_q == S_RD_HIGH) & ram_rd;
    wire accept_write_w = (state_q == S_WR_HIGH_HOLD) & (req_write_low_w | req_write_high_w);

    assign ram_accept = accept_idle_w | accept_read_w | accept_write_w;

    // requisicao consumida neste ciclo
    wire load_w = ram_accept & (ram_rd | ram_wr_req);

    // ---------------- proximo estado (combinacional) ----------------
    always @* begin
        state_next_r = state_q;
        case (state_q)
            S_IDLE: begin
                if (ram_rd)                  state_next_r = S_RD_LOW;
                else if (req_write_low_w)    state_next_r = S_WR_LOW;
                else if (req_write_high_w)   state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;   // inclui escrita nula
            end

            S_RD_LOW:  state_next_r = S_RD_HIGH;

            S_RD_HIGH: begin
                if (ram_rd)                  state_next_r = S_RD_LOW; // proxima leitura sem passar por IDLE
                else                         state_next_r = S_IDLE;
            end

            S_WR_LOW:  state_next_r = S_WR_LOW_HOLD;

            S_WR_LOW_HOLD: begin
                if (|wr_q[3:2])              state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;
            end

            S_WR_HIGH: state_next_r = S_WR_HIGH_HOLD;

            S_WR_HIGH_HOLD: begin
                if (req_write_low_w)         state_next_r = S_WR_LOW;
                else if (req_write_high_w)   state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;
            end

            default: state_next_r = S_IDLE;
        endcase
    end

    // ---------------- registrador de estado ----------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) state_q <= S_IDLE;
        else          state_q <= state_next_r;
    end

    // ---------------- contexto da requisicao ----------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_q      <= 4'b0000;
            wdata_q   <= 32'h0000_0000;
            word_q    <= 19'h0;
            data_lo_q <= 16'h0000;
        end else begin
            if (load_w) begin
                wr_q    <= ram_wr;
                wdata_q <= ram_write_data;
                word_q  <= ram_addr[20:2];
            end
            // a metade baixa chegou ao fim do ciclo de S_RD_LOW
            if (state_q == S_RD_LOW) data_lo_q <= sram_data_in_i;
        end
    end

    // ---------------- pinos e resposta (registrados) ----------------
    // Os valores dependem do estado para o qual se esta indo (state_next_r).
    // Em S_WR_HIGH vindo de S_WR_LOW_HOLD usa-se o contexto guardado; vindo de IDLE ou de
    // S_WR_HIGH_HOLD, a requisicao ainda esta nas entradas.
    wire high_from_regs_w = (state_q == S_WR_LOW_HOLD);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            sram_addr_q   <= 20'h0;
            sram_data_q   <= 16'h0000;
            oe_n_q        <= 1'b1;
            we_n_q        <= 1'b1;
            lb_n_q        <= 1'b1;
            ub_n_q        <= 1'b1;
            data_out_en_q <= 1'b0;
            ack_q         <= 1'b0;
            read_data_q   <= 32'h0000_0000;
        end else begin
            // resposta: vale por um ciclo
            ack_q <= 1'b0;
            if (state_q == S_RD_HIGH) begin
                read_data_q <= {sram_data_in_i, data_lo_q};
                ack_q       <= 1'b1;
            end
            if (state_q == S_WR_HIGH_HOLD)                          ack_q <= 1'b1;
            if (state_q == S_WR_LOW_HOLD && !(|wr_q[3:2]))          ack_q <= 1'b1;
            if (state_q == S_IDLE && req_write_null_w)              ack_q <= 1'b1;

            case (state_next_r)
                S_IDLE: begin
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b1;
                    lb_n_q        <= 1'b1;
                    ub_n_q        <= 1'b1;
                    data_out_en_q <= 1'b0;
                end

                S_RD_LOW: begin
                    sram_addr_q   <= {ram_addr[20:2], 1'b0};
                    oe_n_q        <= 1'b0;
                    we_n_q        <= 1'b1;
                    lb_n_q        <= 1'b0;
                    ub_n_q        <= 1'b0;
                    data_out_en_q <= 1'b0;
                end

                S_RD_HIGH: begin
                    sram_addr_q   <= {word_q, 1'b1};
                end

                S_WR_LOW: begin
                    sram_addr_q   <= {ram_addr[20:2], 1'b0};
                    sram_data_q   <= ram_write_data[15:0];
                    lb_n_q        <= ~ram_wr[0];
                    ub_n_q        <= ~ram_wr[1];
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b0;
                    data_out_en_q <= 1'b1;
                end

                S_WR_LOW_HOLD,
                S_WR_HIGH_HOLD: begin
                    we_n_q        <= 1'b1;   // endereco e dado ficam como estavam (hold)
                end

                S_WR_HIGH: begin
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b0;
                    data_out_en_q <= 1'b1;
                    if (high_from_regs_w) begin
                        sram_addr_q <= {word_q, 1'b1};
                        sram_data_q <= wdata_q[31:16];
                        lb_n_q      <= ~wr_q[2];
                        ub_n_q      <= ~wr_q[3];
                    end else begin
                        sram_addr_q <= {ram_addr[20:2], 1'b1};
                        sram_data_q <= ram_write_data[31:16];
                        lb_n_q      <= ~ram_wr[2];
                        ub_n_q      <= ~ram_wr[3];
                    end
                end

                default: ;
            endcase
        end
    end

    // ---------------- saidas ----------------
    assign ram_ack            = ack_q;
    assign ram_read_data      = read_data_q;
    assign sram_addr_o        = sram_addr_q;
    assign sram_data_out_o    = sram_data_q;
    assign sram_data_out_en_o = data_out_en_q;
    assign sram_oe_n_o        = oe_n_q;
    assign sram_we_n_o        = we_n_q;
    assign sram_lb_n_o        = lb_n_q;
    assign sram_ub_n_o        = ub_n_q;
    assign sram_ce_n_o        = 1'b0;      // SRAM sempre selecionada (L-06)

endmodule
