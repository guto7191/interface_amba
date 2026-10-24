`include "axi_defs.vh"

// Canais AR e R de um subordinado AXI4-Lite, implementado como FSM.
// Pede a memoria via rd_req/rd_grant; o dado volta um ciclo depois.
module axi_subordinate_read #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16,
    parameter IDX_WIDTH  = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input aclk,
    input aresetn,

    //AR
    input [ADDR_WIDTH-1:0] araddr,
    input                  arvalid,
    output                 arready,

    //R
    output reg [DATA_WIDTH-1:0] rdata,
    output reg [1:0]            rresp,
    output                      rvalid,
    input                       rready,

    //interface de memoria
    output                  rd_req,
    input                   rd_grant,
    output [IDX_WIDTH-1:0]  rd_idx,
    input  [DATA_WIDTH-1:0] rd_data
);

    localparam [1:0] S_IDLE = 2'd0,  // aceita AR
                     S_REQ  = 2'd1,  // pede a memoria ate o grant
                     S_WAIT = 2'd2,  // captura rd_data
                     S_RESP = 2'd3;  // RVALID ate RREADY

    reg [1:0]            state, next_state;
    reg [ADDR_WIDTH-1:0] addr_q;

    wire in_range = ((addr_q >> $clog2(DATA_WIDTH/8)) < DEPTH);

    // Saidas Moore: ARREADY nao depende de ARVALID; RVALID nao depende de RREADY
    assign arready = (state == S_IDLE);
    assign rvalid  = (state == S_RESP);
    assign rd_req  = (state == S_REQ);
    assign rd_idx  = addr_q[$clog2(DATA_WIDTH/8) +: IDX_WIDTH];

    wire ar_hs = arvalid && arready;

    // registrador de estado
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) state <= S_IDLE;
        else          state <= next_state;
    end

    always @* begin
        next_state = state;
        case (state)
            S_IDLE: 
            begin   if (ar_hs)        next_state = S_REQ;
                    else next_state = S_IDLE;
            end
            
            S_REQ:
            begin
                if (!in_range)    next_state = S_RESP;
                else if (rd_grant) next_state = S_WAIT;
            end 
            S_WAIT:                   next_state = S_RESP;
            
            S_RESP: 
            begin 
                if (rready)       next_state = S_IDLE;
                else next_state = S_RESP;
            end
            default:                  next_state = S_IDLE;
        endcase
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            addr_q <= {ADDR_WIDTH{1'b0}};
            rdata  <= {DATA_WIDTH{1'b0}};
            rresp  <= `AXI_RESP_OKAY;
        end else begin
            if (ar_hs) addr_q <= araddr;

            if (state == S_REQ && !in_range) begin
                rdata <= {DATA_WIDTH{1'b0}};
                rresp <= `AXI_RESP_SLVERR;
            end

            if (state == S_WAIT) begin
                rdata <= rd_data;
                rresp <= `AXI_RESP_OKAY;
            end
        end
    end
endmodule
