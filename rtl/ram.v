module ram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input                         clk,
    input                         rst_n,
    input                         en,
    input                         we,
    input  [ADDR_WIDTH-1:0]       addr,
    input  [DATA_WIDTH-1:0]       wdata,
    input  [DATA_WIDTH/8-1:0]     wstrb,
    output reg [DATA_WIDTH-1:0]   rdata
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial for (i = 0; i < DEPTH; i = i + 1) mem[i] = {DATA_WIDTH{1'b0}};

    integer b;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
        end else if (en) begin
            if (we) begin
                for (b = 0; b < DATA_WIDTH/8; b = b + 1)
                    if (wstrb[b]) mem[addr][b*8 +: 8] <= wdata[b*8 +: 8];
            end else begin
                rdata <= mem[addr];
            end
        end
    end
endmodule
