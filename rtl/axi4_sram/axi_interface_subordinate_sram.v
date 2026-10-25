// axi_interface_subordinate_sram - wrapper do subordinado AXI4 sobre a SRAM externa.
// MAS §2. Espelha axi_interface_subordinate_ram.v: so instancias e fios.
//
//   mestre AXI4 -> axi_address_decoder -> axi_transaction_manager -> controladora da SRAM
//                  (faixa, AxSIZE)        (burst, ID, ordem)         (contrato ram_*, MAS §3.2)
//   leitura:       axi_transaction_manager -> axi_narrow_read_align -> axi_address_decoder (R)
//
// PHASE = 2 usa sram_controller (pipeline); PHASE = 1 usa sram_controller_baseline (fork da
// FSM da IP, esperas em 1, MAS §6.2). Os dois cumprem o mesmo contrato ram_*, entao a troca
// nao altera o resto (T-I-RAM-007).
//
// O ram_addr chega alinhado a 4 bytes (D17): o alinhamento de lane e feito so por
// axi_narrow_read_align (leitura) e wstrb (escrita). O endereco da SRAM tem 20 bits.
// O reset da IP e ativo-alto assincrono: rst_w = ~aresetn, aplicado ao aresetn ja sincronizado.
module axi_interface_subordinate_sram #(
    parameter PHASE = 2
)(
    input         aclk,
    input         aresetn,

    // ---------------- AXI4 (subordinado) ----------------
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
    input         s_axi_rready,

    // ---------------- lado da SRAM (pinos tratados em sram_io_buffer) ----------------
    output [19:0] sram_addr,
    output [15:0] sram_data_out,
    output        sram_data_out_en,
    input  [15:0] sram_data_in,
    output        sram_oe_n,
    output        sram_we_n,
    output        sram_lb_n,
    output        sram_ub_n,
    output        sram_ce_n
);

    wire rst_w = ~aresetn;

    // ---------------- decoder -> gerenciador de transacoes ----------------
    wire [3:0]  m_awid, m_arid, m_bid, m_rid;
    wire [31:0] m_awaddr, m_araddr, m_wdata, m_rdata_raw, m_rdata;
    wire [7:0]  m_awlen, m_arlen;
    wire [2:0]  m_awsize, m_arsize;
    wire [1:0]  m_awburst, m_arburst, m_bresp, m_rresp;
    wire [3:0]  m_wstrb;
    wire        m_awvalid, m_awready, m_wlast, m_wvalid, m_wready, m_bvalid, m_bready;
    wire        m_arvalid, m_arready, m_rlast, m_rvalid, m_rready;

    axi_address_decoder u_decoder (
        .aclk(aclk), .aresetn(aresetn),
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
        .m_axi_awid(m_awid), .m_axi_awaddr(m_awaddr), .m_axi_awlen(m_awlen),
        .m_axi_awsize(m_awsize), .m_axi_awburst(m_awburst),
        .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb), .m_axi_wlast(m_wlast),
        .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready),
        .m_axi_bid(m_bid), .m_axi_bresp(m_bresp), .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_arid(m_arid), .m_axi_araddr(m_araddr), .m_axi_arlen(m_arlen),
        .m_axi_arsize(m_arsize), .m_axi_arburst(m_arburst),
        .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rid(m_rid), .m_axi_rdata(m_rdata), .m_axi_rresp(m_rresp), .m_axi_rlast(m_rlast),
        .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready));

    // ---------------- gerenciador de transacoes (fork da IP) ----------------
    wire [31:0] ram_addr_w, ram_write_data_w, ram_read_data_w;
    wire [3:0]  ram_wr_w;
    wire [7:0]  ram_len_w;
    wire [2:0]  ram_size_w;
    wire        ram_wr_req_w, ram_rd_w, ram_accept_w, ram_ack_w;
    wire [1:0]  resp_addr_lo_w;
    wire [2:0]  resp_size_w;

    axi_transaction_manager u_manager (
        .clk_i(aclk), .rst_i(rst_w),
        .axi_awvalid_i(m_awvalid), .axi_awaddr_i(m_awaddr), .axi_awid_i(m_awid),
        .axi_awlen_i(m_awlen), .axi_awburst_i(m_awburst), .axi_awsize_i(m_awsize),
        .axi_wvalid_i(m_wvalid), .axi_wdata_i(m_wdata), .axi_wstrb_i(m_wstrb), .axi_wlast_i(m_wlast),
        .axi_bready_i(m_bready),
        .axi_arvalid_i(m_arvalid), .axi_araddr_i(m_araddr), .axi_arid_i(m_arid),
        .axi_arlen_i(m_arlen), .axi_arburst_i(m_arburst), .axi_arsize_i(m_arsize),
        .axi_rready_i(m_rready),
        .ram_accept_i(ram_accept_w), .ram_ack_i(ram_ack_w), .ram_error_i(1'b0),
        .ram_read_data_i(ram_read_data_w),
        .axi_awready_o(m_awready), .axi_wready_o(m_wready),
        .axi_bvalid_o(m_bvalid), .axi_bresp_o(m_bresp), .axi_bid_o(m_bid),
        .axi_arready_o(m_arready),
        .axi_rvalid_o(m_rvalid), .axi_rdata_o(m_rdata_raw), .axi_rresp_o(m_rresp),
        .axi_rid_o(m_rid), .axi_rlast_o(m_rlast),
        .ram_wr_o(ram_wr_w), .ram_rd_o(ram_rd_w), .ram_len_o(ram_len_w),
        .ram_addr_o(ram_addr_w), .ram_write_data_o(ram_write_data_w),
        .ram_size_o(ram_size_w), .ram_wr_req_o(ram_wr_req_w),
        .resp_addr_lo_o(resp_addr_lo_w), .resp_size_o(resp_size_w));

    // ---------------- posicionamento de byte lane na leitura ----------------
    axi_narrow_read_align u_align (
        .rdata_raw(m_rdata_raw), .addr_lo(resp_addr_lo_w), .axsize(resp_size_w),
        .rdata_aligned(m_rdata));

    // ---------------- controladora da SRAM (contrato ram_*) ----------------
    wire [31:0] ram_addr_aligned_w = {ram_addr_w[31:2], 2'b00};   // D17

    generate
        if (PHASE == 1) begin : g_phase1
            wire [31:0] sram_address_w;
            wire [1:0]  sram_be_n_w;
            sram_controller_baseline #() u_ctl (
                .clk_i(aclk), .rst_i(rst_w),
                .ram_addr_i(ram_addr_aligned_w), .ram_wr_i(ram_wr_w), .ram_wr_req_i(ram_wr_req_w),
                .ram_rd_i(ram_rd_w), .ram_write_data_i(ram_write_data_w),
                .sram_data_in_i(sram_data_in),
                .ram_accept_o(ram_accept_w), .ram_ack_o(ram_ack_w), .ram_read_data_o(ram_read_data_w),
                .sram_address_o(sram_address_w), .sram_data_out_o(sram_data_out),
                .sram_data_out_en_o(sram_data_out_en), .sram_oe_n_o(sram_oe_n),
                .sram_cs_n_o(sram_ce_n), .sram_be_n_o(sram_be_n_w), .sram_we_n_o(sram_we_n));
            defparam u_ctl.WRITE_WAIT_CYCLES = 4'd1;   // MAS §6.2, L-05
            defparam u_ctl.READ_WAIT_CYCLES  = 4'd1;
            defparam u_ctl.WRITE_HOLD_CYCLES = 4'd1;
            assign sram_addr = sram_address_w[19:0];
            assign sram_lb_n = sram_be_n_w[0];          // MAS §3.3: bit 0 da IP = byte baixo
            assign sram_ub_n = sram_be_n_w[1];
        end else begin : g_phase2
            sram_controller u_ctl (
                .aclk(aclk), .aresetn(aresetn),
                .ram_addr(ram_addr_aligned_w), .ram_wr(ram_wr_w), .ram_wr_req(ram_wr_req_w),
                .ram_rd(ram_rd_w), .ram_size(ram_size_w), .ram_write_data(ram_write_data_w),
                .ram_accept(ram_accept_w), .ram_ack(ram_ack_w), .ram_read_data(ram_read_data_w),
                .sram_addr_o(sram_addr), .sram_data_out_o(sram_data_out),
                .sram_data_out_en_o(sram_data_out_en), .sram_data_in_i(sram_data_in),
                .sram_oe_n_o(sram_oe_n), .sram_we_n_o(sram_we_n),
                .sram_lb_n_o(sram_lb_n), .sram_ub_n_o(sram_ub_n), .sram_ce_n_o(sram_ce_n));
        end
    endgenerate

endmodule
