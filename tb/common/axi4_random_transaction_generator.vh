// Gerador de transacoes AXI4 pseudoaleatorias legais (incluido dentro do modulo do testbench).
// Usado por T-I-RAM-007 e pelo estresse T-S-ROB-005/006. Requer axi_master_tasks.vh com
// `define AXI4_MASTER_TASKS (buffers w_data_buf/w_strb_buf).
//
// "Legal" aqui significa: INCR, endereco inicial alinhado a 2^AxSIZE (evita o caso desalinhado
// P-07), burst sem cruzar 4 KB (R-06, responsabilidade do mestre) e wstrb dentro das lanes
// permitidas por AxSIZE e addr[1:0] (checker E-10). Com g_allow_bad = 1, uma fracao das
// transacoes sai fora da faixa (DECERR) ou com AxSIZE ilegal (SLVERR).
//
// A semente (gen_seed) e fixa por execucao e registrada no log pelo testbench.

integer gen_seed      = 1;
integer g_allow_bad   = 0;
integer g_is_write;
reg [31:0] g_addr;
reg [7:0]  g_len;
reg [2:0]  g_size;
reg [3:0]  g_id;
integer    g_expect_err;        // 0 OKAY, 2 SLVERR, 3 DECERR

function integer rnd(input integer n);
    rnd = {$random(gen_seed)} % n;
endfunction

// lanes permitidas no beat n (IHI0022E §A3.4.1), igual a funcao do checker
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

// sorteia os parametros de uma transacao; region_bytes limita os enderecos validos [0, region)
task gen_txn_params(input integer region_bytes, input integer max_len_sel);
    integer r, maxbeats, lens;
    reg [31:0] base, mask4k;
    begin
        g_is_write   = (rnd(100) < 55);
        g_id         = rnd(16);
        g_expect_err = 0;
        r = rnd(100);
        if (r < 50)      g_size = 3'd2;
        else if (r < 75) g_size = 3'd1;
        else             g_size = 3'd0;

        case (rnd(6))
            0: g_len = 8'd0;   1: g_len = 8'd1;   2: g_len = 8'd3;
            3: g_len = 8'd7;   4: g_len = 8'd15;  default: g_len = (max_len_sel > 15) ? rnd(max_len_sel) : 8'd3;
        endcase

        base = rnd(region_bytes);
        g_addr = base & ~((32'd1 << g_size) - 32'd1);          // alinhado ao tamanho

        // nao cruzar 4 KB: reduz len ate caber
        maxbeats = (4096 - (g_addr & 32'hFFF)) >> g_size;
        if (g_len + 1 > maxbeats) g_len = maxbeats - 1;

        if (g_allow_bad) begin
            r = rnd(100);
            if (r < 5) begin                                    // fora da faixa -> DECERR
                g_addr = 32'h0020_0000 + (rnd(1024) << 2);
                g_len  = rnd(4);
                g_size = 3'd2;
                g_expect_err = 3;
            end else if (r < 8) begin                           // AxSIZE ilegal -> SLVERR
                g_size = 3'd3;
                g_len  = rnd(4);
                g_addr = g_addr & ~32'h7;
                g_expect_err = 2;
            end
        end
    end
endtask

// preenche w_data_buf / w_strb_buf para a transacao corrente
task gen_write_payload;
    integer n;
    reg [3:0] m;
    reg [2:0] sz;
    begin
        sz = (g_size > 3'd2) ? 3'd2 : g_size;
        for (n = 0; n <= g_len; n = n + 1) begin
            w_data_buf[n] = {$random(gen_seed)};
            m = lane_mask(g_addr, sz, n);
            case (rnd(6))
                0: w_strb_buf[n] = 4'b0000;
                default: w_strb_buf[n] = rnd(16) & m;
            endcase
            if (g_size > 3'd2) w_strb_buf[n] = 4'b1111;        // size ilegal: nunca chega a SRAM
        end
    end
endtask
