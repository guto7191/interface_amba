// Top: apenas instancias e fios. AXI4-Lite subordinado + RAM.
module axi_interface_subordinate_ram #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input                         s_axi_aclk,
    input                         s_axi_aresetn,
    // AW
    input  [ADDR_WIDTH-1:0]       s_axi_awaddr,
    input                         s_axi_awvalid,
    output                        s_axi_awready,
    // W
    input  [DATA_WIDTH-1:0]       s_axi_wdata,
    input  [DATA_WIDTH/8-1:0]     s_axi_wstrb,
    input                         s_axi_wvalid,
    output                        s_axi_wready,
    // B
    output [1:0]                  s_axi_bresp,
    output                        s_axi_bvalid,
    input                         s_axi_bready,
    // AR
    input  [ADDR_WIDTH-1:0]       s_axi_araddr,
    input                         s_axi_arvalid,
    output                        s_axi_arready,
    // R
    output [DATA_WIDTH-1:0]       s_axi_rdata,
    output [1:0]                  s_axi_rresp,
    output                        s_axi_rvalid,
    input                         s_axi_rready
);
    localparam IDX_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    wire                    wr_en, rd_req, rd_grant;
    wire [IDX_WIDTH-1:0]    wr_idx, rd_idx;
    wire [DATA_WIDTH-1:0]   wr_data;
    wire [DATA_WIDTH/8-1:0] wr_strb;

    wire                    ram_en, ram_we;
    wire [IDX_WIDTH-1:0]    ram_addr;
    wire [DATA_WIDTH-1:0]   ram_wdata, ram_rdata;
    wire [DATA_WIDTH/8-1:0] ram_wstrb; //?

    axi_subordinate_write #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_write (
        .aclk(s_axi_aclk), 
        .aresetn(s_axi_aresetn),
        .awaddr(s_axi_awaddr), 
        .awvalid(s_axi_awvalid),
        .awready(s_axi_awready),
        .wdata(s_axi_wdata), 
        .wstrb(s_axi_wstrb), //?
        .wvalid(s_axi_wvalid), 
        .wready(s_axi_wready),
        .bresp(s_axi_bresp), //Código de erro Okay ... 
        .bvalid(s_axi_bvalid), 
        .bready(s_axi_bready),
        .wr_en(wr_en), 
        .wr_idx(wr_idx), 
        .wr_data(wr_data), 
        .wr_strb(wr_strb));

    axi_subordinate_read #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_read (
        .aclk(s_axi_aclk), 
        .aresetn(s_axi_aresetn),
        .araddr(s_axi_araddr), 
        .arvalid(s_axi_arvalid), 
        .arready(s_axi_arready),
        .rdata(s_axi_rdata), 
        .rresp(s_axi_rresp), 
        .rvalid(s_axi_rvalid), 
        .rready(s_axi_rready),
        .rd_req(rd_req), 
        .rd_grant(rd_grant), 
        .rd_idx(rd_idx), 
        .rd_data(ram_rdata));

    axi_ram_adapter #(.DATA_WIDTH(DATA_WIDTH), .IDX_WIDTH(IDX_WIDTH)) u_adapter (
        .wr_en(wr_en), 
        .wr_idx(wr_idx), 
        .wr_data(wr_data), 
        .wr_strb(wr_strb),
        .rd_req(rd_req), 
        .rd_grant(rd_grant), 
        .rd_idx(rd_idx),
        .ram_en(ram_en), 
        .ram_we(ram_we), 
        .ram_addr(ram_addr),
        .ram_wdata(ram_wdata), 
        .ram_wstrb(ram_wstrb));



        // Tem que ver esse barramwnto aqui pq na sram leitrua 
        // e escrita é no mesmo barramento
    ram #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_ram (
        .clk(s_axi_aclk), 
        .rst_n(s_axi_aresetn),
        .en(ram_en), 
        .we(ram_we), 
        .addr(ram_addr),
        .wdata(ram_wdata), 
        .wstrb(ram_wstrb), 
        .rdata(ram_rdata));
endmodule
