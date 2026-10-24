`include "axi_defs.vh"

// Canais AW, W e B de um subordinado AXI4-Lite
// AW e W sao independentes (qualquer ordem);
// BVALID so depois de ambos.
module axi_subordinate_write #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16,
    parameter IDX_WIDTH  = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input aclk,
    input aresetn,

    //AW
    input [ADDR_WIDTH-1:0] awaddr,
    input                  awvalid,
    output                 awready,

    //W
    input [DATA_WIDTH-1:0]   wdata,
    input [DATA_WIDTH/8-1:0] wstrb,
    input                    wvalid,
    output                   wready,

    //B
    output reg [1:0]       bresp,
    output                 bvalid,
    input                  bready,

    //interface de memoria
    output reg                    wr_en,
    output reg [IDX_WIDTH-1:0]    wr_idx,
    output reg [DATA_WIDTH-1:0]   wr_data,
    output reg [DATA_WIDTH/8-1:0] wr_strb
);

    localparam [2:0] S_IDLE   = 3'd0,  // aceita AW e W
                     S_GOT_AW = 3'd1,  // AW recebido, aguarda W
                     S_GOT_W  = 3'd2,  // W recebido, aguarda AW
                     S_WRITE  = 3'd3,  // efetiva a escrita na memoria
                     S_RESP   = 3'd4;  // BVALID ate BREADY

    reg [2:0]            state, next_state;
    reg [ADDR_WIDTH-1:0] addr_q;

    wire in_range = ((addr_q >> $clog2(DATA_WIDTH/8)) < DEPTH);

    // Saidas Moore: READY antecipado (nao depende de VALID); BVALID nao depende de BREADY
    assign awready = (state == S_IDLE) || (state == S_GOT_W);
    assign wready  = (state == S_IDLE) || (state == S_GOT_AW);
    assign bvalid  = (state == S_RESP);

    wire aw_hs = awvalid && awready;
    wire w_hs  = wvalid  && wready;

    // registrador de estado
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) state <= S_IDLE;
        else          state <= next_state;
    end

    // proximo estado
    always @* begin
        next_state = state;
        case (state)
            
            S_IDLE:  
            begin  
                if (aw_hs && w_hs) next_state = S_WRITE;
                else if (aw_hs)    next_state = S_GOT_AW;
                else if (w_hs)     next_state = S_GOT_W;
                else               next_state = S_IDLE;
            end
            
            S_GOT_AW:
            begin 
                if (w_hs)          next_state = S_WRITE;
                else               next_state = S_GOT_AW; 
            end
            
            S_GOT_W: 
            begin  
                if (aw_hs)         next_state = S_WRITE;
                else               next_state = S_GOT_W;
            end
            
            S_WRITE:                     next_state = S_RESP;
            
            S_RESP: 
            begin 
                if (bready)        next_state = S_IDLE;
                else next_state = S_RESP;
            end
                default:                     next_state = S_IDLE;
        endcase
    end


    // datapath
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bresp   <= `AXI_RESP_OKAY;
            wr_en   <= 1'b0;
            addr_q  <= {ADDR_WIDTH{1'b0}};
            wr_idx  <= {IDX_WIDTH{1'b0}};
            wr_data <= {DATA_WIDTH{1'b0}};
            wr_strb <= {(DATA_WIDTH/8){1'b0}};
        end else begin
            wr_en <= 1'b0;

            if (aw_hs) addr_q <= awaddr;
            if (w_hs) begin
                wr_data <= wdata;
                wr_strb <= wstrb;
            end

            if (state == S_WRITE) begin
                // descarta os bits de offset de byte do endereco
                wr_idx <= addr_q[$clog2(DATA_WIDTH/8) +: IDX_WIDTH];
                wr_en  <= in_range;
                bresp  <= in_range ? `AXI_RESP_OKAY : `AXI_RESP_SLVERR;
            end
        end
    end
endmodule
