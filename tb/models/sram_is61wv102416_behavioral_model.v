`timescale 1ns/1ps
// Modelo comportamental da SRAM assincrona ISSI IS61WV102416BLL (1M x 16), grau -10.
// Referencia: VERIFICATION_PLAN_axi4_sram.md §2.1 (folha de dados ISSI Rev. G).
//
// - Sem clock proprio: a leitura reage a mudancas de addr/ce_n/oe_n/we_n/lb_n/ub_n.
// - O modelo so dirige "dq" com ce_n=0, oe_n=0 e we_n=1. Qualquer outra combinacao e alta
//   impedancia, entao contencao de barramento aparece como X (e como A-SRAM-06).
// - A escrita e capturada na SUBIDA de we_n.
// - Posicao nunca escrita le 16'hDEAD (distingue "nao inicializado" de zero legitimo).
// - E tambem um verificador: cada violacao incrementa cnt_a0n e imprime "SRAM_MODEL VIOLATION".
//   (a palavra FAIL e evitada de proposito: so o testbench decide PASS/FAIL.)
//
// Simplificacao: a leitura troca o dado direto de "antigo" para "novo" apos tAA (atraso
// inercial), sem a janela de X entre tOHA e tAA. Amostrar cedo demais e pego por A-SRAM-05
// (via sample_clk) e tambem por divergencia de dado no scoreboard.
module sram_is61wv102416_behavioral_model #(
    parameter real T_AA   = 10.0,   // endereco valido -> dado valido (max)
    parameter real T_OHA  = 2.5,    // dado permanece apos mudar o endereco (min), informativo
    parameter real T_DOE  = 6.5,    // OE_N -> dado valido (max), coberto por T_AA
    parameter real T_HZOE = 4.0,    // OE_N inativo -> alta impedancia (max)
    parameter real T_PWE1 = 8.0,    // largura minima do pulso de WE_N
    parameter real T_WC   = 10.0,   // ciclo minimo de escrita
    parameter real T_SD   = 6.0     // setup minimo de dado antes do fim da escrita
)(
    input  [19:0] addr,
    inout  [15:0] dq,
    input         ce_n,
    input         oe_n,
    input         we_n,
    input         lb_n,
    input         ub_n,
    input         sample_clk,        // clock do capturador (FPGA), usado so por A-SRAM-05
    output [31:0] errors,            // soma das violacoes
    output reg [31:0] access_count,  // quedas de oe_n e we_n (prova "a SRAM nao foi acessada")
    output reg [31:0] we_pulse_count // pulsos de escrita (quedas de we_n com ce_n=0)
);

    // ---------------- armazenamento ----------------
    reg [15:0] mem [0:1048575];
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 1048576; init_i = init_i + 1) mem[init_i] = 16'hDEAD;
        access_count   = 0;
        we_pulse_count = 0;
    end

    // acesso direto (backdoor) para os testbenches
    task mem_poke(input [19:0] a, input [15:0] v);
        begin
            mem[a] = v;
            -> wr_done;
        end
    endtask

    function [15:0] mem_peek(input [19:0] a);
        mem_peek = mem[a];
    endfunction

    // ---------------- leitura assincrona ----------------
    event wr_done;
    reg [15:0] rd_val;
    always @(addr or wr_done) rd_val = mem[addr];

    wire rd_en_w = !ce_n && !oe_n && we_n;

    // atraso: subida/descida = tAA, para alta impedancia = tHZOE
    wire [15:0] dq_model;
    assign #(T_AA, T_AA, T_HZOE) dq_model[7:0]  = (rd_en_w && !lb_n) ? rd_val[7:0]  : 8'bz;
    assign #(T_AA, T_AA, T_HZOE) dq_model[15:8] = (rd_en_w && !ub_n) ? rd_val[15:8] : 8'bz;
    assign dq = dq_model;

    // ---------------- escrita (na subida de we_n) ----------------
    always @(posedge we_n) begin
        if (!ce_n) begin
            if (!lb_n) mem[addr][7:0]  = dq[7:0];
            if (!ub_n) mem[addr][15:8] = dq[15:8];
            -> wr_done;
        end
    end

    // ---------------- contagem de acessos ----------------
    always @(negedge oe_n) if (!ce_n) access_count = access_count + 1;
    always @(negedge we_n) if (!ce_n) begin
        access_count   = access_count + 1;
        we_pulse_count = we_pulse_count + 1;
    end

    // ---------------- assertivas de temporizacao ----------------
    integer cnt_a01 = 0, cnt_a02 = 0, cnt_a03 = 0, cnt_a04 = 0;
    integer cnt_a05 = 0, cnt_a06 = 0, cnt_a07 = 0, cnt_a08 = 0;
    assign errors = cnt_a01 + cnt_a02 + cnt_a03 + cnt_a04 + cnt_a05 + cnt_a06 + cnt_a07 + cnt_a08;

    realtime t_we_fall   = -1000.0;   // ultima descida de we_n
    realtime t_we_fall_p = -1000.0;   // descida anterior
    realtime t_addr      = -1000.0;   // ultima mudanca de endereco
    realtime t_dq        = -1000.0;   // ultima mudanca em dq

    always @(addr) t_addr = $realtime;
    always @(dq)   t_dq   = $realtime;

    // A-SRAM-02: ciclo de escrita (descida a descida) menor que tWC
    always @(negedge we_n) begin
        t_we_fall_p = t_we_fall;
        t_we_fall   = $realtime;
        if (!ce_n && ($realtime - t_we_fall_p) < T_WC) begin
            cnt_a02 = cnt_a02 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-02 @%0t: ciclo de escrita %0.3f ns < tWC", $time, $realtime - t_we_fall_p);
        end
    end

    // A-SRAM-01 (largura do pulso) e A-SRAM-03 (setup de dado), avaliadas na subida de we_n
    always @(posedge we_n) begin
        if (!ce_n) begin
            if (($realtime - t_we_fall) < T_PWE1) begin
                cnt_a01 = cnt_a01 + 1;
                $display("SRAM_MODEL VIOLATION A-SRAM-01 @%0t: pulso de WE_N %0.3f ns < tPWE1", $time, $realtime - t_we_fall);
            end
            if (($realtime - t_dq) < T_SD) begin
                cnt_a03 = cnt_a03 + 1;
                $display("SRAM_MODEL VIOLATION A-SRAM-03 @%0t: dado estavel por %0.3f ns < tSD", $time, $realtime - t_dq);
            end
        end
    end

    // A-SRAM-04: endereco muda com we_n ativo. A mudanca no mesmo instante da descida de
    // we_n e permitida (tSA = 0). A checagem espera 1 ps para ignorar a corrida com a subida.
    always @(addr) begin
        #0.001;
        if (!ce_n && !we_n && ($realtime - t_we_fall) > 0.002) begin
            cnt_a04 = cnt_a04 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-04 @%0t: endereco mudou durante o pulso de WE_N", $time);
        end
    end

    // A-SRAM-05: o capturador amostra antes de tAA decorrido desde a ultima mudanca de endereco.
    // Mudanca no mesmo instante da borda (distancia 0) e a leitura do endereco anterior: valida.
    always @(posedge sample_clk) begin
        if (rd_en_w && ($realtime - t_addr) > 0.002 && ($realtime - t_addr) < T_AA) begin
            cnt_a05 = cnt_a05 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-05 @%0t: amostra %0.3f ns apos o endereco < tAA", $time, $realtime - t_addr);
        end
    end

    // A-SRAM-06: contencao. O modelo dirige uma lane e o valor resolvido em dq e diferente.
    always @(dq or dq_model) begin
        #0.001;
        if ((dq_model[7:0]  !== 8'bz && dq[7:0]  !== dq_model[7:0]) ||
            (dq_model[15:8] !== 8'bz && dq[15:8] !== dq_model[15:8])) begin
            cnt_a06 = cnt_a06 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-06 @%0t: contencao em dq (resolvido=%h, modelo=%h)", $time, dq, dq_model);
        end
    end

    // A-SRAM-07: endereco com X em acesso ativo
    always @(addr or oe_n or we_n or ce_n) begin
        if (!ce_n && (!oe_n || !we_n) && (^addr === 1'bx)) begin
            cnt_a07 = cnt_a07 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-07 @%0t: endereco com X em acesso", $time);
        end
    end

    // A-SRAM-08: oe_n e we_n ambos ativos com ce_n ativo. Reavalia 1 ps depois, para nao
    // acusar a corrida momentanea na troca de oe_n por we_n no mesmo instante.
    reg both_active_q = 1'b0;
    always @(ce_n or oe_n or we_n) begin
        #0.001;
        if (!ce_n && !oe_n && !we_n) begin
            if (!both_active_q) begin
                cnt_a08 = cnt_a08 + 1;
                $display("SRAM_MODEL VIOLATION A-SRAM-08 @%0t: oe_n e we_n ativos juntos", $time);
            end
            both_active_q = 1'b1;
        end else begin
            both_active_q = 1'b0;
        end
    end

endmodule
