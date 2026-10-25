// de2_115_top - topo da placa Terasic DE2-115 (MAS §2, §3.3).
// Liga o oscilador de 50 MHz, o botao KEY[0] e os pinos da SRAM ISSI IS61WV102416BLL ao
// subordinado AXI4. O mestre AXI esta fora do escopo (MAS §1.2): o barramento s_axi_* fica
// exposto para um processador soft-core, um DMA ou um gerador de trafego (MAS §9.3).
module de2_115_top #(
    parameter PHASE = 2
)(
    input         CLOCK_50,
    input  [3:0]  KEY,              // KEY[0]: reset (ativo-baixo); os demais nao sao usados

    // pinos da SRAM
    output [19:0] SRAM_ADDR,
    inout  [15:0] SRAM_DQ,
    output        SRAM_OE_N,
    output        SRAM_WE_N,
    output        SRAM_CE_N,
    output        SRAM_LB_N,
    output        SRAM_UB_N,

    // AXI4 para o mestre
    input  [3:0]  s_axi_awid,
    input  [31:0] s_axi_awaddr,
    input  [7:0]  s_axi_awlen,
    input  [2:0]  s_axi_awsize,
    input  [1:0]  s_axi_awburst,
    input         s_axi_awvalid,
    output        s_axi_awready,
    input  [31:0] s_axi_wdata,
    input  [3:0]  s_axi_wstrb,
    input         s_axi_wlast,
    input         s_axi_wvalid,
    output        s_axi_wready,
    output [3:0]  s_axi_bid,
    output [1:0]  s_axi_bresp,
    output        s_axi_bvalid,
    input         s_axi_bready,
    input  [3:0]  s_axi_arid,
    input  [31:0] s_axi_araddr,
    input  [7:0]  s_axi_arlen,
    input  [2:0]  s_axi_arsize,
    input  [1:0]  s_axi_arburst,
    input         s_axi_arvalid,
    output        s_axi_arready,
    output [3:0]  s_axi_rid,
    output [31:0] s_axi_rdata,
    output [1:0]  s_axi_rresp,
    output        s_axi_rlast,
    output        s_axi_rvalid,
    input         s_axi_rready
);

    wire        aresetn_w;
    wire [19:0] sram_addr_w;
    wire [15:0] sram_data_out_w, sram_data_in_w;
    wire        sram_data_out_en_w, sram_oe_n_w, sram_we_n_w, sram_lb_n_w, sram_ub_n_w, sram_ce_n_w;

    reset_synchronizer u_reset (.clk(CLOCK_50), .async_reset_n(KEY[0]), .aresetn(aresetn_w));

    axi_interface_subordinate_sram #(.PHASE(PHASE)) u_axi_sram (
        .aclk(CLOCK_50), .aresetn(aresetn_w),
        .s_axi_awid(s_axi_awid), .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bid(s_axi_bid), .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_arid(s_axi_arid), .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rid(s_axi_rid), .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .sram_addr(sram_addr_w), .sram_data_out(sram_data_out_w),
        .sram_data_out_en(sram_data_out_en_w), .sram_data_in(sram_data_in_w),
        .sram_oe_n(sram_oe_n_w), .sram_we_n(sram_we_n_w),
        .sram_lb_n(sram_lb_n_w), .sram_ub_n(sram_ub_n_w), .sram_ce_n(sram_ce_n_w));

    sram_io_buffer u_io (
        .addr_i(sram_addr_w), .data_out_i(sram_data_out_w), .data_out_en_i(sram_data_out_en_w),
        .data_in_o(sram_data_in_w), .oe_n_i(sram_oe_n_w), .we_n_i(sram_we_n_w),
        .lb_n_i(sram_lb_n_w), .ub_n_i(sram_ub_n_w), .ce_n_i(sram_ce_n_w),
        .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_CE_N(SRAM_CE_N));

endmodule
