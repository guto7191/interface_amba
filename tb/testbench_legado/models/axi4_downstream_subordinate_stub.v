`timescale 1ns/1ps
// Subordinado AXI4 falso (comportamental) para testar o axi_address_decoder isolado.
// Aceita AR/AW/W e responde: R com rdata = endereco do beat, B apos o wlast. OKAY sempre.
// Controles em tempo de execucao:
//   ready_gap  - AR/AW aceitam 1 vez a cada (gap+1) ciclos; W idem, em fase diferente. Com gap > 0
//                o decoder entra em PASSTHROUGH (comando oferecido e ainda nao aceito).
//   resp_delay - ciclos entre aceitar o comando e iniciar a resposta (deixa bursts "em voo").
// Contadores para provar que "a SRAM nao foi acessada": ar_count, aw_count, w_beats.
module axi4_downstream_subordinate_stub (
    input         aclk,
    input         aresetn,
    input  [3:0]  ready_gap,
    input  [7:0]  resp_delay,

    input  [3:0]  awid,   input [31:0] awaddr, input [7:0] awlen, input [2:0] awsize,
    input         awvalid, output awready,
    input  [31:0] wdata,  input [3:0]  wstrb,  input       wlast, input wvalid, output wready,
    output reg [3:0] bid, output reg [1:0] bresp, output reg bvalid, input bready,
    input  [3:0]  arid,   input [31:0] araddr, input [7:0] arlen, input [2:0] arsize,
    input         arvalid, output arready,
    output reg [3:0] rid, output reg [31:0] rdata, output reg [1:0] rresp, output reg rlast,
    output reg    rvalid, input rready,

    output reg [31:0] ar_count,
    output reg [31:0] aw_count,
    output reg [31:0] w_beats
);
    reg [3:0] ctr;

    initial begin
        rvalid = 1'b0; bvalid = 1'b0; rlast = 1'b0;
    end

    // fila de leitura (ate 8 bursts)
    reg [3:0]  rq_id   [0:7];
    reg [7:0]  rq_len  [0:7];
    reg [31:0] rq_addr [0:7];
    integer    rq_head, rq_tail, rq_n;
    // fila de escrita (IDs dos AW)
    reg [3:0]  wq_id [0:15];
    integer    aw_taken, w_done, b_sent;

    // resposta de leitura em andamento
    integer    rsp_state;                 // 0 ocioso, 1 aguardando atraso, 2 transmitindo
    integer    rsp_delay_left, beat;
    reg [3:0]  cur_id;
    reg [7:0]  cur_len;
    reg [31:0] cur_addr;
    integer    b_delay_left;

    assign awready = (ctr == 4'd0) && (aw_taken - b_sent < 16);
    assign arready = (ctr == 4'd0) && (rq_n < 8);
    assign wready  = (ctr == ready_gap);

    always @(posedge aclk) begin
        if (!aresetn) begin
            ctr <= 4'd0;
            rq_head = 0; rq_tail = 0; rq_n = 0;
            aw_taken = 0; w_done = 0; b_sent = 0;
            rsp_state = 0; rsp_delay_left = 0; beat = 0; b_delay_left = 0;
            ar_count <= 0; aw_count <= 0; w_beats <= 0;
            rvalid <= 1'b0; rlast <= 1'b0; rdata <= 32'h0; rid <= 4'h0; rresp <= 2'b00;
            bvalid <= 1'b0; bid <= 4'h0; bresp <= 2'b00;
        end else begin
            ctr <= (ctr >= ready_gap) ? 4'd0 : ctr + 4'd1;

            // ---- aceitacao de comandos ----
            if (arvalid && arready) begin
                rq_id[rq_tail]   = arid;
                rq_len[rq_tail]  = arlen;
                rq_addr[rq_tail] = araddr;
                rq_tail = (rq_tail + 1) % 8;
                rq_n    = rq_n + 1;
                ar_count <= ar_count + 1;
            end
            if (awvalid && awready) begin
                wq_id[aw_taken % 16] = awid;
                aw_taken = aw_taken + 1;
                aw_count <= aw_count + 1;
            end
            if (wvalid && wready) begin
                w_beats <= w_beats + 1;
                if (wlast) w_done = w_done + 1;
            end

            // ---- resposta de leitura ----
            case (rsp_state)
                0: if (rq_n > 0) begin
                       cur_id   = rq_id[rq_head];
                       cur_len  = rq_len[rq_head];
                       cur_addr = rq_addr[rq_head];
                       rq_head  = (rq_head + 1) % 8;
                       rq_n     = rq_n - 1;
                       rsp_delay_left = resp_delay;
                       rsp_state = 1;
                   end
                1: begin
                       if (rsp_delay_left > 0) rsp_delay_left = rsp_delay_left - 1;
                       if (rsp_delay_left == 0) begin
                           beat = 0;
                           rvalid <= 1'b1; rid <= cur_id; rdata <= cur_addr;
                           rresp <= 2'b00; rlast <= (cur_len == 0);
                           rsp_state = 2;
                       end
                   end
                2: if (rvalid && rready) begin
                       if (rlast) begin
                           rvalid <= 1'b0; rlast <= 1'b0;
                           rsp_state = 0;
                       end else begin
                           beat = beat + 1;
                           cur_addr = cur_addr + 4;
                           rdata <= cur_addr;
                           rlast <= (beat == cur_len);
                       end
                   end
            endcase

            // ---- resposta de escrita ----
            if (bvalid && bready) begin
                bvalid <= 1'b0;
                b_sent = b_sent + 1;
                b_delay_left = resp_delay;
            end else if (!bvalid && b_sent < w_done && b_sent < aw_taken) begin
                if (b_delay_left > 0) b_delay_left = b_delay_left - 1;
                else begin
                    bvalid <= 1'b1; bid <= wq_id[b_sent % 16]; bresp <= 2'b00;
                end
            end
        end
    end
endmodule
