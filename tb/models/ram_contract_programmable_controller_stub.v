`timescale 1ns/1ps
// Controladora falsa do contrato ram_* (MAS §3.2), com memoria de 32 bits interna e
// comportamento programavel, para testar o frontend (axi_transaction_manager) isolado.
//   deny_cycles - ram_accept so sobe depois de a requisicao ficar pendente por N ciclos
//   hold_acks   - enquanto 1, as respostas ficam retidas (acumulam requisicoes em voo)
// Comportamental, nao sintetizavel.
module ram_contract_programmable_controller_stub (
    input         aclk,
    input         aresetn,
    input  [7:0]  deny_cycles,
    input         hold_acks,

    input  [31:0] ram_addr,
    input  [3:0]  ram_wr,
    input         ram_wr_req,
    input         ram_rd,
    input  [31:0] ram_write_data,
    output        ram_accept,
    output reg    ram_ack,
    output reg [31:0] ram_read_data,

    output reg [31:0] accepted_count,
    output reg [31:0] ack_count,
    output reg [31:0] max_inflight
);
    reg [31:0] mem [0:4095];            // palavras de 32 bits, indexadas por ram_addr[13:2]
    integer    i;
    initial for (i = 0; i < 4096; i = i + 1) mem[i] = 32'hDEAD_DEAD;

    // fila de respostas (so o dado de leitura; escrita responde com dado qualquer)
    reg [31:0] rq [0:15];
    integer    rq_head, rq_tail, rq_n;
    integer    pend_cycles;             // ciclos com a requisicao atual pendente
    wire       req_w = ram_rd | ram_wr_req;

    assign ram_accept = req_w && (pend_cycles >= deny_cycles) && (rq_n < 16);

    always @(posedge aclk) begin
        if (!aresetn) begin
            rq_head = 0; rq_tail = 0; rq_n = 0; pend_cycles = 0;
            ram_ack <= 1'b0; ram_read_data <= 32'h0;
            accepted_count <= 0; ack_count <= 0; max_inflight <= 0;
        end else begin
            ram_ack <= 1'b0;

            if (ram_accept) begin
                if (ram_rd) rq[rq_tail] = mem[ram_addr[13:2]];
                else begin
                    rq[rq_tail] = 32'h0;
                    if (ram_wr[0]) mem[ram_addr[13:2]][7:0]   = ram_write_data[7:0];
                    if (ram_wr[1]) mem[ram_addr[13:2]][15:8]  = ram_write_data[15:8];
                    if (ram_wr[2]) mem[ram_addr[13:2]][23:16] = ram_write_data[23:16];
                    if (ram_wr[3]) mem[ram_addr[13:2]][31:24] = ram_write_data[31:24];
                end
                rq_tail = (rq_tail + 1) % 16;
                rq_n    = rq_n + 1;
                accepted_count <= accepted_count + 1;
                pend_cycles = 0;
            end else if (req_w) begin
                pend_cycles = pend_cycles + 1;
            end

            if (rq_n > max_inflight) max_inflight <= rq_n;

            // uma resposta por ciclo, na ordem de aceitacao, salvo se retidas
            if (!hold_acks && rq_n > 0) begin
                ram_ack       <= 1'b1;
                ram_read_data <= rq[rq_head];
                rq_head = (rq_head + 1) % 16;
                rq_n    = rq_n - 1;
                ack_count <= ack_count + 1;
            end
        end
    end
endmodule
