// Arbitra o acesso de porta unica da RAM: escrita tem prioridade, leitura espera.
module axi_ram_adapter #(
    parameter DATA_WIDTH = 32,
    parameter IDX_WIDTH  = 4
)(
    input                         wr_en,
    input  [IDX_WIDTH-1:0]        wr_idx,
    input  [DATA_WIDTH-1:0]       wr_data,
    input  [DATA_WIDTH/8-1:0]     wr_strb,
    input                         rd_req,
    output                        rd_grant,
    input  [IDX_WIDTH-1:0]        rd_idx,
    // porta da RAM
    output                        ram_en,
    output                        ram_we,
    output [IDX_WIDTH-1:0]        ram_addr,
    output [DATA_WIDTH-1:0]       ram_wdata,
    output [DATA_WIDTH/8-1:0]     ram_wstrb
);
    assign rd_grant  = !wr_en; 
    assign ram_en    = wr_en | rd_req;
    assign ram_we    = wr_en;
    assign ram_addr  = wr_en ? wr_idx : rd_idx;
    assign ram_wdata = wr_data;
    assign ram_wstrb = wr_strb;
endmodule
