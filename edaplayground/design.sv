// GERADO por tb/uvm/sim/bundle_edaplayground.py - NAO EDITAR
`timescale 1ns/1ps

`ifndef AXI_DEFS_VH
`define AXI_DEFS_VH
`define AXI_RESP_OKAY   2'b00
`define AXI_RESP_EXOKAY 2'b01
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11
`endif
module reset_synchronizer (
    input  clk,
    input  async_reset_n,
    output aresetn
);
    reg sync_ff1_q;
    reg sync_ff2_q;
    always @(posedge clk or negedge async_reset_n) begin
        if (!async_reset_n) begin
            sync_ff1_q <= 1'b0;
            sync_ff2_q <= 1'b0;
        end else begin
            sync_ff1_q <= 1'b1;
            sync_ff2_q <= sync_ff1_q;
        end
    end
    assign aresetn = sync_ff2_q;
endmodule
module axi_address_decoder (
    input         aclk,
    input         aresetn,
    input  [3:0]  s_axi_awid,
    input  [31:0] s_axi_awaddr,
    input  [7:0]  s_axi_awlen,
    input  [2:0]  s_axi_awsize,
    input  [1:0]  s_axi_awburst,
    input         s_axi_awvalid,
    output reg    s_axi_awready,
    input  [31:0] s_axi_wdata,
    input  [3:0]  s_axi_wstrb,
    input         s_axi_wlast,
    input         s_axi_wvalid,
    output reg    s_axi_wready,
    output reg [3:0] s_axi_bid,
    output reg [1:0] s_axi_bresp,
    output reg    s_axi_bvalid,
    input         s_axi_bready,
    input  [3:0]  s_axi_arid,
    input  [31:0] s_axi_araddr,
    input  [7:0]  s_axi_arlen,
    input  [2:0]  s_axi_arsize,
    input  [1:0]  s_axi_arburst,
    input         s_axi_arvalid,
    output reg    s_axi_arready,
    output reg [3:0]  s_axi_rid,
    output reg [31:0] s_axi_rdata,
    output reg [1:0]  s_axi_rresp,
    output reg    s_axi_rlast,
    output reg    s_axi_rvalid,
    input         s_axi_rready,
    output [3:0]  m_axi_awid,
    output [31:0] m_axi_awaddr,
    output [7:0]  m_axi_awlen,
    output [2:0]  m_axi_awsize,
    output [1:0]  m_axi_awburst,
    output reg    m_axi_awvalid,
    input         m_axi_awready,
    output [31:0] m_axi_wdata,
    output [3:0]  m_axi_wstrb,
    output        m_axi_wlast,
    output reg    m_axi_wvalid,
    input         m_axi_wready,
    input  [3:0]  m_axi_bid,
    input  [1:0]  m_axi_bresp,
    input         m_axi_bvalid,
    output reg    m_axi_bready,
    output [3:0]  m_axi_arid,
    output [31:0] m_axi_araddr,
    output [7:0]  m_axi_arlen,
    output [2:0]  m_axi_arsize,
    output [1:0]  m_axi_arburst,
    output reg    m_axi_arvalid,
    input         m_axi_arready,
    input  [3:0]  m_axi_rid,
    input  [31:0] m_axi_rdata,
    input  [1:0]  m_axi_rresp,
    input         m_axi_rlast,
    input         m_axi_rvalid,
    output reg    m_axi_rready
);
    localparam [1:0] S_IDLE        = 2'd0,
                     S_PASSTHROUGH = 2'd1,
                     S_ERROR_DRAIN = 2'd2;
    assign m_axi_awid    = s_axi_awid;
    assign m_axi_awaddr  = s_axi_awaddr;
    assign m_axi_awlen   = s_axi_awlen;
    assign m_axi_awsize  = s_axi_awsize;
    assign m_axi_awburst = s_axi_awburst;
    assign m_axi_wdata   = s_axi_wdata;
    assign m_axi_wstrb   = s_axi_wstrb;
    assign m_axi_wlast   = s_axi_wlast;
    assign m_axi_arid    = s_axi_arid;
    assign m_axi_araddr  = s_axi_araddr;
    assign m_axi_arlen   = s_axi_arlen;
    assign m_axi_arsize  = s_axi_arsize;
    assign m_axi_arburst = s_axi_arburst;
    wire [31:0] ar_nbytes_w  = 32'd1 << s_axi_arsize;
    wire [31:0] ar_aligned_w = s_axi_araddr & ~(ar_nbytes_w - 32'd1);
    wire [31:0] ar_end_w     = ar_aligned_w + (({24'd0, s_axi_arlen} + 32'd1) << s_axi_arsize) - 32'd1;
    wire        ar_addr_ok_w = ~(|s_axi_araddr[31:21]) & ~(|ar_end_w[31:21]);
    wire        ar_size_ok_w = (s_axi_arsize <= 3'b010);
    wire        ar_ok_w      = ar_addr_ok_w & ar_size_ok_w;
    wire [31:0] aw_nbytes_w  = 32'd1 << s_axi_awsize;
    wire [31:0] aw_aligned_w = s_axi_awaddr & ~(aw_nbytes_w - 32'd1);
    wire [31:0] aw_end_w     = aw_aligned_w + (({24'd0, s_axi_awlen} + 32'd1) << s_axi_awsize) - 32'd1;
    wire        aw_addr_ok_w = ~(|s_axi_awaddr[31:21]) & ~(|aw_end_w[31:21]);
    wire        aw_size_ok_w = (s_axi_awsize <= 3'b010);
    wire        aw_ok_w      = aw_addr_ok_w & aw_size_ok_w;
    reg [1:0] ar_err_code_r;
    reg [1:0] aw_err_code_r;
    always @* begin
        if (!ar_addr_ok_w) ar_err_code_r = `AXI_RESP_DECERR;
        else               ar_err_code_r = `AXI_RESP_SLVERR;
    end
    always @* begin
        if (!aw_addr_ok_w) aw_err_code_r = `AXI_RESP_DECERR;
        else               aw_err_code_r = `AXI_RESP_SLVERR;
    end
    reg [1:0] rd_state_q, rd_state_next_r;
    reg [3:0] rd_err_id_q;
    reg [1:0] rd_err_code_q;
    reg [7:0] rd_beat_cnt_q;
    reg [3:0] rd_outstanding_q;
    wire m_ar_hs_w = m_axi_arvalid & m_axi_arready;
    wire m_r_last_hs_w = m_axi_rvalid & m_axi_rready & m_axi_rlast;
    wire rd_err_beat_w   = (rd_state_q == S_ERROR_DRAIN) & (rd_outstanding_q == 4'd0);
    wire rd_err_hs_w     = rd_err_beat_w & s_axi_rready;
    wire rd_err_last_w   = (rd_beat_cnt_q == 8'd0);
    always @* begin
        rd_state_next_r = rd_state_q;
        case (rd_state_q)
            S_IDLE: begin
                if (s_axi_arvalid) begin
                    if (!ar_ok_w)          rd_state_next_r = S_ERROR_DRAIN;
                    else if (m_axi_arready) rd_state_next_r = S_IDLE;
                    else                   rd_state_next_r = S_PASSTHROUGH;
                end
            end
            S_PASSTHROUGH: begin
                if (m_axi_arready) rd_state_next_r = S_IDLE;
            end
            S_ERROR_DRAIN: begin
                if (rd_err_hs_w && rd_err_last_w) rd_state_next_r = S_IDLE;
            end
            default: rd_state_next_r = S_IDLE;
        endcase
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) rd_state_q <= S_IDLE;
        else          rd_state_q <= rd_state_next_r;
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_err_id_q      <= 4'd0;
            rd_err_code_q    <= `AXI_RESP_OKAY;
            rd_beat_cnt_q    <= 8'd0;
            rd_outstanding_q <= 4'd0;
        end else begin
            if (rd_state_q == S_IDLE && s_axi_arvalid && !ar_ok_w) begin
                rd_err_id_q   <= s_axi_arid;
                rd_err_code_q <= ar_err_code_r;
                rd_beat_cnt_q <= s_axi_arlen;
            end
            if (rd_err_hs_w) rd_beat_cnt_q <= rd_beat_cnt_q - 8'd1;
            if (m_ar_hs_w && !m_r_last_hs_w)      rd_outstanding_q <= rd_outstanding_q + 4'd1;
            else if (!m_ar_hs_w && m_r_last_hs_w) rd_outstanding_q <= rd_outstanding_q - 4'd1;
        end
    end
    always @* begin
        m_axi_arvalid = 1'b0;
        s_axi_arready = 1'b0;
        case (rd_state_q)
            S_IDLE: begin
                if (s_axi_arvalid && !ar_ok_w) begin
                    s_axi_arready = 1'b1;
                end else begin
                    m_axi_arvalid = s_axi_arvalid;
                    s_axi_arready = m_axi_arready;
                end
            end
            S_PASSTHROUGH: begin
                m_axi_arvalid = s_axi_arvalid;
                s_axi_arready = m_axi_arready;
            end
            default: ;
        endcase
    end
    always @* begin
        if (rd_err_beat_w) begin
            s_axi_rid     = rd_err_id_q;
            s_axi_rdata   = 32'h0000_0000;
            s_axi_rresp   = rd_err_code_q;
            s_axi_rlast   = rd_err_last_w;
            s_axi_rvalid  = 1'b1;
            m_axi_rready  = 1'b0;
        end else begin
            s_axi_rid     = m_axi_rid;
            s_axi_rdata   = m_axi_rdata;
            s_axi_rresp   = m_axi_rresp;
            s_axi_rlast   = m_axi_rlast;
            s_axi_rvalid  = m_axi_rvalid;
            m_axi_rready  = s_axi_rready;
        end
    end
    reg [1:0] wr_state_q, wr_state_next_r;
    reg [3:0] wr_err_id_q;
    reg [1:0] wr_err_code_q;
    reg       wr_err_w_done_q;
    reg       aw_done_q;
    reg       wlast_done_q;
    reg [3:0] wr_outstanding_q;
    wire m_aw_hs_w      = m_axi_awvalid & m_axi_awready;
    wire m_w_last_hs_w  = m_axi_wvalid & m_axi_wready & s_axi_wlast;
    wire m_b_hs_w       = m_axi_bvalid & m_axi_bready;
    wire wr_err_b_w     = (wr_state_q == S_ERROR_DRAIN) & wr_err_w_done_q & (wr_outstanding_q == 4'd0);
    wire wr_err_b_hs_w  = wr_err_b_w & s_axi_bready;
    always @* begin
        wr_state_next_r = wr_state_q;
        case (wr_state_q)
            S_IDLE: begin
                if (s_axi_awvalid) begin
                    if (!aw_ok_w)                          wr_state_next_r = S_ERROR_DRAIN;
                    else if (m_aw_hs_w && m_w_last_hs_w)   wr_state_next_r = S_IDLE;
                    else                                   wr_state_next_r = S_PASSTHROUGH;
                end
            end
            S_PASSTHROUGH: begin
                if ((aw_done_q || m_aw_hs_w) && (wlast_done_q || m_w_last_hs_w))
                    wr_state_next_r = S_IDLE;
            end
            S_ERROR_DRAIN: begin
                if (wr_err_b_hs_w) wr_state_next_r = S_IDLE;
            end
            default: wr_state_next_r = S_IDLE;
        endcase
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) wr_state_q <= S_IDLE;
        else          wr_state_q <= wr_state_next_r;
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_err_id_q      <= 4'd0;
            wr_err_code_q    <= `AXI_RESP_OKAY;
            wr_err_w_done_q  <= 1'b0;
            aw_done_q        <= 1'b0;
            wlast_done_q     <= 1'b0;
            wr_outstanding_q <= 4'd0;
        end else begin
            if (wr_state_q == S_IDLE) begin
                aw_done_q       <= m_aw_hs_w;
                wlast_done_q    <= m_w_last_hs_w;
                wr_err_w_done_q <= 1'b0;
                if (s_axi_awvalid && !aw_ok_w) begin
                    wr_err_id_q   <= s_axi_awid;
                    wr_err_code_q <= aw_err_code_r;
                end
            end else if (wr_state_q == S_PASSTHROUGH) begin
                if (m_aw_hs_w)     aw_done_q    <= 1'b1;
                if (m_w_last_hs_w) wlast_done_q <= 1'b1;
            end else begin
                if (s_axi_wvalid && s_axi_wready && s_axi_wlast) wr_err_w_done_q <= 1'b1;
            end
            if (m_aw_hs_w && !m_b_hs_w)      wr_outstanding_q <= wr_outstanding_q + 4'd1;
            else if (!m_aw_hs_w && m_b_hs_w) wr_outstanding_q <= wr_outstanding_q - 4'd1;
        end
    end
    always @* begin
        m_axi_awvalid = 1'b0;
        s_axi_awready = 1'b0;
        m_axi_wvalid  = 1'b0;
        s_axi_wready  = 1'b0;
        case (wr_state_q)
            S_IDLE: begin
                if (s_axi_awvalid && !aw_ok_w) begin
                    s_axi_awready = 1'b1;
                end else if (s_axi_awvalid) begin
                    m_axi_awvalid = s_axi_awvalid;
                    s_axi_awready = m_axi_awready;
                    m_axi_wvalid  = s_axi_wvalid;
                    s_axi_wready  = m_axi_wready;
                end
            end
            S_PASSTHROUGH: begin
                m_axi_awvalid = s_axi_awvalid & ~aw_done_q;
                s_axi_awready = m_axi_awready & ~aw_done_q;
                m_axi_wvalid  = s_axi_wvalid & ~wlast_done_q;
                s_axi_wready  = m_axi_wready & ~wlast_done_q;
            end
            S_ERROR_DRAIN: begin
                s_axi_wready = ~wr_err_w_done_q;
            end
            default: ;
        endcase
    end
    always @* begin
        if (wr_err_b_w) begin
            s_axi_bid     = wr_err_id_q;
            s_axi_bresp   = wr_err_code_q;
            s_axi_bvalid  = 1'b1;
            m_axi_bready  = 1'b0;
        end else begin
            s_axi_bid     = m_axi_bid;
            s_axi_bresp   = m_axi_bresp;
            s_axi_bvalid  = m_axi_bvalid;
            m_axi_bready  = s_axi_bready;
        end
    end
endmodule
module axi_narrow_read_align (
    input      [31:0] rdata_raw,
    input      [1:0]  addr_lo,
    input      [2:0]  axsize,
    output reg [31:0] rdata_aligned
);
    always @* begin
        rdata_aligned = rdata_raw;
        case ({axsize, addr_lo})
            {3'b001, 2'b00}: rdata_aligned = {rdata_raw[15:0],  rdata_raw[15:0]};
            {3'b001, 2'b10}: rdata_aligned = {rdata_raw[31:16], rdata_raw[31:16]};
            {3'b000, 2'b00}: rdata_aligned = {4{rdata_raw[7:0]}};
            {3'b000, 2'b01}: rdata_aligned = {4{rdata_raw[15:8]}};
            {3'b000, 2'b10}: rdata_aligned = {4{rdata_raw[23:16]}};
            {3'b000, 2'b11}: rdata_aligned = {4{rdata_raw[31:24]}};
            default: rdata_aligned = rdata_raw;
        endcase
    end
endmodule
module axi_transaction_manager
(
     input           clk_i
    ,input           rst_i
    ,input           axi_awvalid_i
    ,input  [ 31:0]  axi_awaddr_i
    ,input  [  3:0]  axi_awid_i
    ,input  [  7:0]  axi_awlen_i
    ,input  [  1:0]  axi_awburst_i
    ,input  [  2:0]  axi_awsize_i
    ,input           axi_wvalid_i
    ,input  [ 31:0]  axi_wdata_i
    ,input  [  3:0]  axi_wstrb_i
    ,input           axi_wlast_i
    ,input           axi_bready_i
    ,input           axi_arvalid_i
    ,input  [ 31:0]  axi_araddr_i
    ,input  [  3:0]  axi_arid_i
    ,input  [  7:0]  axi_arlen_i
    ,input  [  1:0]  axi_arburst_i
    ,input  [  2:0]  axi_arsize_i
    ,input           axi_rready_i
    ,input           ram_accept_i
    ,input           ram_ack_i
    ,input           ram_error_i
    ,input  [ 31:0]  ram_read_data_i
    ,output          axi_awready_o
    ,output          axi_wready_o
    ,output          axi_bvalid_o
    ,output [  1:0]  axi_bresp_o
    ,output [  3:0]  axi_bid_o
    ,output          axi_arready_o
    ,output          axi_rvalid_o
    ,output [ 31:0]  axi_rdata_o
    ,output [  1:0]  axi_rresp_o
    ,output [  3:0]  axi_rid_o
    ,output          axi_rlast_o
    ,output [  3:0]  ram_wr_o
    ,output          ram_rd_o
    ,output [  7:0]  ram_len_o
    ,output [ 31:0]  ram_addr_o
    ,output [ 31:0]  ram_write_data_o
    ,output [  2:0]  ram_size_o
    ,output          ram_wr_req_o
    ,output [  1:0]  resp_addr_lo_o
    ,output [  2:0]  resp_size_o
);
function [31:0] calculate_addr_next;
    input [31:0] addr;
    input [1:0]  axtype;
    input [7:0]  axlen;
    input [2:0]  axsize;
    reg [31:0]   mask;
    reg [31:0]   num_bytes;
    reg [31:0]   aligned;
begin
    mask = 0;
    num_bytes = 32'd1 << axsize;
    aligned   = addr & ~(num_bytes - 32'd1);
    case (axtype)
`ifdef SUPPORT_FIXED_BURST
    2'd0:
        calculate_addr_next = addr;
`endif
`ifdef SUPPORT_WRAP_BURST
    2'd2:
    begin
        mask = (num_bytes * (axlen + 32'd1)) - 32'd1;
        calculate_addr_next = (addr & ~mask) | ((aligned + num_bytes) & mask);
    end
`endif
    default:
        calculate_addr_next = aligned + num_bytes;
    endcase
end
endfunction
reg [7:0]   req_len_q;
reg [31:0]  req_addr_q;
reg         req_rd_q;
reg         req_wr_q;
reg [3:0]   req_id_q;
reg [1:0]   req_axburst_q;
reg [7:0]   req_axlen_q;
reg [2:0]   req_axsize_q;
reg         req_prio_q;
reg         req_hold_rd_q;
reg         req_hold_wr_q;
wire        req_fifo_accept_w;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    req_len_q     <= 8'b0;
    req_addr_q    <= 32'b0;
    req_wr_q      <= 1'b0;
    req_rd_q      <= 1'b0;
    req_id_q      <= 4'b0;
    req_axburst_q <= 2'b0;
    req_axlen_q   <= 8'b0;
    req_axsize_q  <= 3'b0;
    req_prio_q    <= 1'b0;
end
else
begin
    if ((ram_wr_req_o || ram_rd_o) && ram_accept_i)
    begin
        if (req_len_q == 8'd0)
        begin
            req_rd_q   <= 1'b0;
            req_wr_q   <= 1'b0;
        end
        else
        begin
            req_addr_q <= calculate_addr_next(req_addr_q, req_axburst_q, req_axlen_q, req_axsize_q);
            req_len_q  <= req_len_q - 8'd1;
        end
    end
    if (axi_awvalid_i && axi_awready_o)
    begin
        if (axi_wvalid_i && axi_wready_o)
        begin
            req_wr_q      <= !axi_wlast_i;
            req_len_q     <= axi_awlen_i - 8'd1;
            req_id_q      <= axi_awid_i;
            req_axburst_q <= axi_awburst_i;
            req_axlen_q   <= axi_awlen_i;
            req_axsize_q  <= axi_awsize_i;
            req_addr_q    <= calculate_addr_next(axi_awaddr_i, axi_awburst_i, axi_awlen_i, axi_awsize_i);
        end
        else
        begin
            req_wr_q      <= 1'b1;
            req_len_q     <= axi_awlen_i;
            req_id_q      <= axi_awid_i;
            req_axburst_q <= axi_awburst_i;
            req_axlen_q   <= axi_awlen_i;
            req_axsize_q  <= axi_awsize_i;
            req_addr_q    <= axi_awaddr_i;
        end
        req_prio_q    <= !req_prio_q;
    end
    else if (axi_arvalid_i && axi_arready_o)
    begin
        req_rd_q      <= (axi_arlen_i != 0);
        req_len_q     <= axi_arlen_i - 8'd1;
        req_addr_q    <= calculate_addr_next(axi_araddr_i, axi_arburst_i, axi_arlen_i, axi_arsize_i);
        req_id_q      <= axi_arid_i;
        req_axburst_q <= axi_arburst_i;
        req_axlen_q   <= axi_arlen_i;
        req_axsize_q  <= axi_arsize_i;
        req_prio_q    <= !req_prio_q;
    end
end
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    req_hold_rd_q   <= 1'b0;
    req_hold_wr_q   <= 1'b0;
end
else
begin
    if (ram_rd_o && !ram_accept_i)
        req_hold_rd_q   <= 1'b1;
    else if (ram_accept_i)
        req_hold_rd_q   <= 1'b0;
    if (ram_wr_req_o && !ram_accept_i)
        req_hold_wr_q   <= 1'b1;
    else if (ram_accept_i)
        req_hold_wr_q   <= 1'b0;
end
wire       req_push_w = (ram_rd_o || ram_wr_req_o) && ram_accept_i;
reg [10:0] req_in_r;
wire       req_out_valid_w;
wire [10:0] req_out_w;
wire       resp_accept_w;
always @ *
begin
    req_in_r = 11'b0;
    if (axi_arvalid_i && axi_arready_o)
        req_in_r = {1'b1, (axi_arlen_i == 8'd0), axi_arid_i, axi_araddr_i[1:0], axi_arsize_i};
    else if (axi_awvalid_i && axi_awready_o)
        req_in_r = {1'b0, (axi_awlen_i == 8'd0), axi_awid_i, axi_awaddr_i[1:0], axi_awsize_i};
    else
        req_in_r = {ram_rd_o, (req_len_q == 8'd0), req_id_q, req_addr_q[1:0], req_axsize_q};
end
axi_transaction_fifo
#( .WIDTH(1 + 1 + 4 + 2 + 3) )
u_requests
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_in_i(req_in_r),
    .push_i(req_push_w),
    .accept_o(req_fifo_accept_w),
    .pop_i(resp_accept_w),
    .data_out_o(req_out_w),
    .valid_o(req_out_valid_w)
);
wire resp_is_write_w = req_out_valid_w ? ~req_out_w[10] : 1'b0;
wire resp_is_read_w  = req_out_valid_w ? req_out_w[10]  : 1'b0;
wire resp_is_last_w  = req_out_w[9];
wire [3:0] resp_id_w = req_out_w[8:5];
assign resp_addr_lo_o = req_out_w[4:3];
assign resp_size_o    = req_out_w[2:0];
wire resp_valid_w;
axi_transaction_fifo
#( .WIDTH(32) )
u_response
(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_in_i(ram_read_data_i),
    .push_i(ram_ack_i),
    .accept_o(),
    .pop_i(resp_accept_w),
    .data_out_o(axi_rdata_o),
    .valid_o(resp_valid_w)
);
wire write_prio_w   = ((req_prio_q  & !req_hold_rd_q) | req_hold_wr_q);
wire read_prio_w    = ((!req_prio_q & !req_hold_wr_q) | req_hold_rd_q);
wire write_active_w  = (axi_awvalid_i || req_wr_q) && !req_rd_q && req_fifo_accept_w && (write_prio_w || req_wr_q || !axi_arvalid_i);
wire read_active_w   = (axi_arvalid_i || req_rd_q) && !req_wr_q && req_fifo_accept_w && (read_prio_w || req_rd_q || !axi_awvalid_i);
assign axi_awready_o = write_active_w && !req_wr_q && ram_accept_i && req_fifo_accept_w;
assign axi_wready_o  = write_active_w &&              ram_accept_i && req_fifo_accept_w;
assign axi_arready_o = read_active_w  && !req_rd_q && ram_accept_i && req_fifo_accept_w;
wire [31:0] addr_w   = ((req_wr_q || req_rd_q) ? req_addr_q:
                        write_active_w ? axi_awaddr_i : axi_araddr_i);
wire wr_w    = write_active_w && axi_wvalid_i;
wire rd_w    = read_active_w;
assign ram_addr_o       = addr_w;
assign ram_write_data_o = axi_wdata_i;
assign ram_wr_req_o     = wr_w;
assign ram_rd_o         = rd_w;
assign ram_wr_o         = wr_w ? axi_wstrb_i : 4'b0;
assign ram_len_o        = axi_awvalid_i ? axi_awlen_i:
                          axi_arvalid_i ? axi_arlen_i : 8'b0;
reg [2:0] ram_size_r;
always @ *
begin
    if (req_wr_q || req_rd_q)
        ram_size_r = req_axsize_q;
    else if (write_active_w)
        ram_size_r = axi_awsize_i;
    else
        ram_size_r = axi_arsize_i;
end
assign ram_size_o = ram_size_r;
assign axi_bvalid_o  = resp_valid_w & resp_is_write_w & resp_is_last_w;
assign axi_bresp_o   = 2'b0;
assign axi_bid_o     = resp_id_w;
assign axi_rvalid_o  = resp_valid_w & resp_is_read_w;
assign axi_rresp_o   = 2'b0;
assign axi_rid_o     = resp_id_w;
assign axi_rlast_o   = resp_is_last_w;
assign resp_accept_w    = (axi_rvalid_o & axi_rready_i) |
                          (axi_bvalid_o & axi_bready_i) |
                          (resp_valid_w & resp_is_write_w & !resp_is_last_w);
endmodule
module axi_transaction_fifo
#(
    parameter WIDTH   = 8,
    parameter DEPTH   = 4,
    parameter ADDR_W  = 2
)
(
     input               clk_i
    ,input               rst_i
    ,input  [WIDTH-1:0]  data_in_i
    ,input               push_i
    ,input               pop_i
    ,output [WIDTH-1:0]  data_out_o
    ,output              accept_o
    ,output              valid_o
);
localparam COUNT_W = ADDR_W + 1;
reg [WIDTH-1:0]         ram [DEPTH-1:0];
reg [ADDR_W-1:0]        rd_ptr;
reg [ADDR_W-1:0]        wr_ptr;
reg [COUNT_W-1:0]       count;
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin
    count   <= {(COUNT_W) {1'b0}};
    rd_ptr  <= {(ADDR_W) {1'b0}};
    wr_ptr  <= {(ADDR_W) {1'b0}};
end
else
begin
    if (push_i & accept_o)
    begin
        ram[wr_ptr] <= data_in_i;
        wr_ptr      <= wr_ptr + 1;
    end
    if (pop_i & valid_o)
        rd_ptr      <= rd_ptr + 1;
    if ((push_i & accept_o) & ~(pop_i & valid_o))
        count <= count + 1;
    else if (~(push_i & accept_o) & (pop_i & valid_o))
        count <= count - 1;
end
assign accept_o   = (count != DEPTH);
assign valid_o    = (count != 0);
assign data_out_o = ram[rd_ptr];
endmodule
module axi_interface_subordinate_sram #(
    parameter PHASE = 2
)(
    input         aclk,
    input         aresetn,
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
    axi_narrow_read_align u_align (
        .rdata_raw(m_rdata_raw), .addr_lo(resp_addr_lo_w), .axsize(resp_size_w),
        .rdata_aligned(m_rdata));
    wire [31:0] ram_addr_aligned_w = {ram_addr_w[31:2], 2'b00};
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
            defparam u_ctl.WRITE_WAIT_CYCLES = 4'd1;
            defparam u_ctl.READ_WAIT_CYCLES  = 4'd1;
            defparam u_ctl.WRITE_HOLD_CYCLES = 4'd1;
            assign sram_addr = sram_address_w[19:0];
            assign sram_lb_n = sram_be_n_w[0];
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
module sram_io_buffer (
    input  [19:0] addr_i,
    input  [15:0] data_out_i,
    input         data_out_en_i,
    output [15:0] data_in_o,
    input         oe_n_i,
    input         we_n_i,
    input         lb_n_i,
    input         ub_n_i,
    input         ce_n_i,
    output [19:0] SRAM_ADDR,
    inout  [15:0] SRAM_DQ,
    output        SRAM_OE_N,
    output        SRAM_WE_N,
    output        SRAM_LB_N,
    output        SRAM_UB_N,
    output        SRAM_CE_N
);
    assign SRAM_DQ   = data_out_en_i ? data_out_i : 16'bz;
    assign data_in_o = SRAM_DQ;
    assign SRAM_ADDR = addr_i;
    assign SRAM_OE_N = oe_n_i;
    assign SRAM_WE_N = we_n_i;
    assign SRAM_LB_N = lb_n_i;
    assign SRAM_UB_N = ub_n_i;
    assign SRAM_CE_N = ce_n_i;
endmodule
module de2_115_top #(
    parameter PHASE = 2
)(
    input         CLOCK_50,
    input  [3:0]  KEY,
    output [19:0] SRAM_ADDR,
    inout  [15:0] SRAM_DQ,
    output        SRAM_OE_N,
    output        SRAM_WE_N,
    output        SRAM_CE_N,
    output        SRAM_LB_N,
    output        SRAM_UB_N,
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
module sram_controller (
    input         aclk,
    input         aresetn,
    input  [31:0] ram_addr,
    input  [3:0]  ram_wr,
    input         ram_wr_req,
    input         ram_rd,
    input  [2:0]  ram_size,
    input  [31:0] ram_write_data,
    output        ram_accept,
    output        ram_ack,
    output [31:0] ram_read_data,
    output [19:0] sram_addr_o,
    output [15:0] sram_data_out_o,
    output        sram_data_out_en_o,
    input  [15:0] sram_data_in_i,
    output        sram_oe_n_o,
    output        sram_we_n_o,
    output        sram_lb_n_o,
    output        sram_ub_n_o,
    output        sram_ce_n_o
);
    localparam [2:0] S_IDLE         = 3'd0,
                     S_RD_LOW       = 3'd1,
                     S_RD_HIGH      = 3'd2,
                     S_WR_LOW       = 3'd3,
                     S_WR_LOW_HOLD  = 3'd4,
                     S_WR_HIGH      = 3'd5,
                     S_WR_HIGH_HOLD = 3'd6;
    reg [2:0] state_q, state_next_r;
    wire req_write_low_w  = ram_wr_req & (|ram_wr[1:0]);
    wire req_write_high_w = ram_wr_req & ~(|ram_wr[1:0]) & (|ram_wr[3:2]);
    wire req_write_null_w = ram_wr_req & ~(|ram_wr);
    reg [3:0]  wr_q;
    reg [31:0] wdata_q;
    reg [18:0] word_q;
    reg [15:0] data_lo_q;
    reg [19:0] sram_addr_q;
    reg [15:0] sram_data_q;
    reg        oe_n_q, we_n_q, lb_n_q, ub_n_q, data_out_en_q;
    reg        ack_q;
    reg [31:0] read_data_q;
    wire accept_idle_w  = (state_q == S_IDLE);
    wire accept_read_w  = (state_q == S_RD_HIGH) & ram_rd;
    wire accept_write_w = (state_q == S_WR_HIGH_HOLD) & (req_write_low_w | req_write_high_w);
    assign ram_accept = accept_idle_w | accept_read_w | accept_write_w;
    wire load_w = ram_accept & (ram_rd | ram_wr_req);
    always @* begin
        state_next_r = state_q;
        case (state_q)
            S_IDLE: begin
                if (ram_rd)                  state_next_r = S_RD_LOW;
                else if (req_write_low_w)    state_next_r = S_WR_LOW;
                else if (req_write_high_w)   state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;
            end
            S_RD_LOW:  state_next_r = S_RD_HIGH;
            S_RD_HIGH: begin
                if (ram_rd)                  state_next_r = S_RD_LOW;
                else                         state_next_r = S_IDLE;
            end
            S_WR_LOW:  state_next_r = S_WR_LOW_HOLD;
            S_WR_LOW_HOLD: begin
                if (|wr_q[3:2])              state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;
            end
            S_WR_HIGH: state_next_r = S_WR_HIGH_HOLD;
            S_WR_HIGH_HOLD: begin
                if (req_write_low_w)         state_next_r = S_WR_LOW;
                else if (req_write_high_w)   state_next_r = S_WR_HIGH;
                else                         state_next_r = S_IDLE;
            end
            default: state_next_r = S_IDLE;
        endcase
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) state_q <= S_IDLE;
        else          state_q <= state_next_r;
    end
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_q      <= 4'b0000;
            wdata_q   <= 32'h0000_0000;
            word_q    <= 19'h0;
            data_lo_q <= 16'h0000;
        end else begin
            if (load_w) begin
                wr_q    <= ram_wr;
                wdata_q <= ram_write_data;
                word_q  <= ram_addr[20:2];
            end
            if (state_q == S_RD_LOW) data_lo_q <= sram_data_in_i;
        end
    end
    wire high_from_regs_w = (state_q == S_WR_LOW_HOLD);
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            sram_addr_q   <= 20'h0;
            sram_data_q   <= 16'h0000;
            oe_n_q        <= 1'b1;
            we_n_q        <= 1'b1;
            lb_n_q        <= 1'b1;
            ub_n_q        <= 1'b1;
            data_out_en_q <= 1'b0;
            ack_q         <= 1'b0;
            read_data_q   <= 32'h0000_0000;
        end else begin
            ack_q <= 1'b0;
            if (state_q == S_RD_HIGH) begin
                read_data_q <= {sram_data_in_i, data_lo_q};
                ack_q       <= 1'b1;
            end
            if (state_q == S_WR_HIGH_HOLD)                          ack_q <= 1'b1;
            if (state_q == S_WR_LOW_HOLD && !(|wr_q[3:2]))          ack_q <= 1'b1;
            if (state_q == S_IDLE && req_write_null_w)              ack_q <= 1'b1;
            case (state_next_r)
                S_IDLE: begin
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b1;
                    lb_n_q        <= 1'b1;
                    ub_n_q        <= 1'b1;
                    data_out_en_q <= 1'b0;
                end
                S_RD_LOW: begin
                    sram_addr_q   <= {ram_addr[20:2], 1'b0};
                    oe_n_q        <= 1'b0;
                    we_n_q        <= 1'b1;
                    lb_n_q        <= 1'b0;
                    ub_n_q        <= 1'b0;
                    data_out_en_q <= 1'b0;
                end
                S_RD_HIGH: begin
                    sram_addr_q   <= {word_q, 1'b1};
                end
                S_WR_LOW: begin
                    sram_addr_q   <= {ram_addr[20:2], 1'b0};
                    sram_data_q   <= ram_write_data[15:0];
                    lb_n_q        <= ~ram_wr[0];
                    ub_n_q        <= ~ram_wr[1];
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b0;
                    data_out_en_q <= 1'b1;
                end
                S_WR_LOW_HOLD,
                S_WR_HIGH_HOLD: begin
                    we_n_q        <= 1'b1;
                end
                S_WR_HIGH: begin
                    oe_n_q        <= 1'b1;
                    we_n_q        <= 1'b0;
                    data_out_en_q <= 1'b1;
                    if (high_from_regs_w) begin
                        sram_addr_q <= {word_q, 1'b1};
                        sram_data_q <= wdata_q[31:16];
                        lb_n_q      <= ~wr_q[2];
                        ub_n_q      <= ~wr_q[3];
                    end else begin
                        sram_addr_q <= {ram_addr[20:2], 1'b1};
                        sram_data_q <= ram_write_data[31:16];
                        lb_n_q      <= ~ram_wr[2];
                        ub_n_q      <= ~ram_wr[3];
                    end
                end
                default: ;
            endcase
        end
    end
    assign ram_ack            = ack_q;
    assign ram_read_data      = read_data_q;
    assign sram_addr_o        = sram_addr_q;
    assign sram_data_out_o    = sram_data_q;
    assign sram_data_out_en_o = data_out_en_q;
    assign sram_oe_n_o        = oe_n_q;
    assign sram_we_n_o        = we_n_q;
    assign sram_lb_n_o        = lb_n_q;
    assign sram_ub_n_o        = ub_n_q;
    assign sram_ce_n_o        = 1'b0;
endmodule
module sram_is61wv102416_behavioral_model #(
    parameter real T_AA   = 10.0,
    parameter real T_OHA  = 2.5,
    parameter real T_DOE  = 6.5,
    parameter real T_HZOE = 4.0,
    parameter real T_PWE1 = 8.0,
    parameter real T_WC   = 10.0,
    parameter real T_SD   = 6.0
)(
    input  [19:0] addr,
    inout  [15:0] dq,
    input         ce_n,
    input         oe_n,
    input         we_n,
    input         lb_n,
    input         ub_n,
    input         sample_clk,
    output [31:0] errors,
    output reg [31:0] access_count,
    output reg [31:0] we_pulse_count
);
    reg [15:0] mem [0:1048575];
    integer init_i;
    initial begin
        for (init_i = 0; init_i < 1048576; init_i = init_i + 1) mem[init_i] = 16'hDEAD;
        access_count   = 0;
        we_pulse_count = 0;
    end
    task mem_poke(input [19:0] a, input [15:0] v);
        begin
            mem[a] = v;
            -> wr_done;
        end
    endtask
    function [15:0] mem_peek(input [19:0] a);
        mem_peek = mem[a];
    endfunction
    event wr_done;
    reg [15:0] rd_val;
    always @(addr or wr_done) rd_val = mem[addr];
    wire rd_en_w = !ce_n && !oe_n && we_n;
    wire [15:0] dq_model;
    assign #(T_AA, T_AA, T_HZOE) dq_model[7:0]  = (rd_en_w && !lb_n) ? rd_val[7:0]  : 8'bz;
    assign #(T_AA, T_AA, T_HZOE) dq_model[15:8] = (rd_en_w && !ub_n) ? rd_val[15:8] : 8'bz;
    assign dq = dq_model;
    always @(posedge we_n) begin
        if (!ce_n) begin
            if (!lb_n) mem[addr][7:0]  = dq[7:0];
            if (!ub_n) mem[addr][15:8] = dq[15:8];
            -> wr_done;
        end
    end
    always @(negedge oe_n) if (!ce_n) access_count = access_count + 1;
    always @(negedge we_n) if (!ce_n) begin
        access_count   = access_count + 1;
        we_pulse_count = we_pulse_count + 1;
    end
    integer cnt_a01 = 0, cnt_a02 = 0, cnt_a03 = 0, cnt_a04 = 0;
    integer cnt_a05 = 0, cnt_a06 = 0, cnt_a07 = 0, cnt_a08 = 0;
    assign errors = cnt_a01 + cnt_a02 + cnt_a03 + cnt_a04 + cnt_a05 + cnt_a06 + cnt_a07 + cnt_a08;
    realtime t_we_fall   = -1000.0;
    realtime t_we_fall_p = -1000.0;
    realtime t_addr      = -1000.0;
    realtime t_dq        = -1000.0;
    always @(addr) t_addr = $realtime;
    always @(dq)   t_dq   = $realtime;
    always @(negedge we_n) begin
        t_we_fall_p = t_we_fall;
        t_we_fall   = $realtime;
        if (!ce_n && ($realtime - t_we_fall_p) < T_WC) begin
            cnt_a02 = cnt_a02 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-02 @%0t: ciclo de escrita %0.3f ns < tWC", $time, $realtime - t_we_fall_p);
        end
    end
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
    always @(addr) begin
        #0.001;
        if (!ce_n && !we_n && ($realtime - t_we_fall) > 0.002) begin
            cnt_a04 = cnt_a04 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-04 @%0t: endereco mudou durante o pulso de WE_N", $time);
        end
    end
    always @(posedge sample_clk) begin
        if (rd_en_w && ($realtime - t_addr) > 0.002 && ($realtime - t_addr) < T_AA) begin
            cnt_a05 = cnt_a05 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-05 @%0t: amostra %0.3f ns apos o endereco < tAA", $time, $realtime - t_addr);
        end
    end
    always @(dq or dq_model) begin
        #0.001;
        if ((dq_model[7:0]  !== 8'bz && dq[7:0]  !== dq_model[7:0]) ||
            (dq_model[15:8] !== 8'bz && dq[15:8] !== dq_model[15:8])) begin
            cnt_a06 = cnt_a06 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-06 @%0t: contencao em dq (resolvido=%h, modelo=%h)", $time, dq, dq_model);
        end
    end
    always @(addr or oe_n or we_n or ce_n) begin
        if (!ce_n && (!oe_n || !we_n) && (^addr === 1'bx)) begin
            cnt_a07 = cnt_a07 + 1;
            $display("SRAM_MODEL VIOLATION A-SRAM-07 @%0t: endereco com X em acesso", $time);
        end
    end
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
module axi_protocol_checker #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter TIMEOUT      = 200,
    parameter AXI4_FULL    = 0,
    parameter RESP_TIMEOUT = 2000
)(
    input aclk,
    input aresetn,
    input [ADDR_WIDTH-1:0]   awaddr,
    input                    awvalid,
    input                    awready,
    input [DATA_WIDTH-1:0]   wdata,
    input [DATA_WIDTH/8-1:0] wstrb,
    input                    wvalid,
    input                    wready,
    input [1:0]              bresp,
    input                    bvalid,
    input                    bready,
    input [ADDR_WIDTH-1:0]   araddr,
    input                    arvalid,
    input                    arready,
    input [DATA_WIDTH-1:0]   rdata,
    input [1:0]              rresp,
    input                    rvalid,
    input                    rready,
    output reg [31:0]        errors,
    input [3:0]              awid,
    input [7:0]              awlen,
    input [2:0]              awsize,
    input [1:0]              awburst,
    input                    wlast,
    input [3:0]              bid,
    input [3:0]              arid,
    input [7:0]              arlen,
    input [2:0]              arsize,
    input [1:0]              arburst,
    input [3:0]              rid,
    input                    rlast
);
    reg                    p_awv, p_awr, p_wv, p_wr, p_bv, p_br, p_arv, p_arr, p_rv, p_rr;
    reg [ADDR_WIDTH-1:0]   p_awaddr, p_araddr;
    reg [DATA_WIDTH-1:0]   p_wdata, p_rdata;
    reg [DATA_WIDTH/8-1:0] p_wstrb;
    reg [1:0]              p_bresp, p_rresp;
    integer aw_cnt, w_cnt, b_cnt, ar_cnt, r_cnt;
    integer aw_to, w_to, ar_to;
    localparam QD = 16;
    integer cnt_e01, cnt_e02, cnt_e03, cnt_e04, cnt_e05;
    integer cnt_e06, cnt_e07, cnt_e08, cnt_e09, cnt_e10;
    reg [7:0] rq_len   [0:16*QD-1];
    integer   rq_head  [0:15];
    integer   rq_cnt   [0:15];
    integer   r_beat   [0:15];
    reg [1:0] r_resp0  [0:15];
    reg       r_done   [0:15];
    reg [7:0]  aw_len_h  [0:255];
    reg [2:0]  aw_size_h [0:255];
    reg [3:0]  aw_id_h   [0:255];
    reg [31:0] aw_addr_h [0:255];
    reg [8:0]  w_cnt_h   [0:255];
    integer    aw_total, w_done, w_cur;
    integer    b_pend   [0:15];
    integer    aw_out   [0:15];
    reg        b_done   [0:15];
    integer    idle_cycles;
    integer    i;
    integer    rd_out_total;
    initial begin
        errors = 0;
        aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
        aw_to = 0; w_to = 0; ar_to = 0;
        p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
        p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
        cnt_e01 = 0; cnt_e02 = 0; cnt_e03 = 0; cnt_e04 = 0; cnt_e05 = 0;
        cnt_e06 = 0; cnt_e07 = 0; cnt_e08 = 0; cnt_e09 = 0; cnt_e10 = 0;
        clear_axi4_state;
    end
    task err(input [8*48-1:0] msg);
        begin
            errors = errors + 1;
            $display("CHECKER FAIL @%0t: %0s", $time, msg);
        end
    endtask
    task errn(input integer n, input [8*48-1:0] msg);
        begin
            case (n)
                1:  cnt_e01 = cnt_e01 + 1;
                2:  cnt_e02 = cnt_e02 + 1;
                3:  cnt_e03 = cnt_e03 + 1;
                4:  cnt_e04 = cnt_e04 + 1;
                5:  cnt_e05 = cnt_e05 + 1;
                6:  cnt_e06 = cnt_e06 + 1;
                7:  cnt_e07 = cnt_e07 + 1;
                8:  cnt_e08 = cnt_e08 + 1;
                9:  cnt_e09 = cnt_e09 + 1;
                default: cnt_e10 = cnt_e10 + 1;
            endcase
            errors = errors + 1;
            $display("CHECKER FAIL E-%02d @%0t: %0s", n, $time, msg);
        end
    endtask
    task clear_axi4_state;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                rq_head[i] = 0; rq_cnt[i] = 0; r_beat[i] = 0; r_resp0[i] = 2'b00; r_done[i] = 1'b0;
                b_pend[i] = 0; aw_out[i] = 0; b_done[i] = 1'b0;
            end
            aw_total = 0; w_done = 0; w_cur = 0; idle_cycles = 0;
        end
    endtask
    function [3:0] lanes_mask(input [31:0] start, input [2:0] size, input integer n);
        reg [31:0] nb, aligned, beat_addr;
        integer    lower, upper, b;
        begin
            nb      = 32'd1 << size;
            aligned = start & ~(nb - 32'd1);
            if (n == 0) begin
                lower = start[1:0];
                upper = aligned[1:0] + nb - 1;
            end else begin
                beat_addr = aligned + n * nb;
                lower     = beat_addr[1:0];
                upper     = lower + nb - 1;
            end
            lanes_mask = 4'b0000;
            for (b = 0; b < 4; b = b + 1)
                if (b >= lower && b <= upper) lanes_mask[b] = 1'b1;
        end
    endfunction
    task check_4kb(input [31:0] start, input [7:0] len, input [2:0] size);
        reg [31:0] nb, aligned, last;
        begin
            nb      = 32'd1 << size;
            aligned = start & ~(nb - 32'd1);
            last    = aligned + ((len + 32'd1) << size) - 32'd1;
            if (start[31:12] != last[31:12]) errn(6, "burst cruza fronteira de 4 KB");
        end
    endtask
    task pop_read_burst(input [3:0] id);
        begin
            rq_head[id] = (rq_head[id] + 1) % QD;
            rq_cnt[id]  = rq_cnt[id] - 1;
            r_beat[id]  = 0;
            r_done[id]  = 1'b1;
        end
    endtask
    task burst_complete(input integer k);
        begin
            b_pend[aw_id_h[k % 256]] = b_pend[aw_id_h[k % 256]] + 1;
        end
    endtask
    integer    id_i, beat_i, exp_len, qidx;
    reg [3:0]  mask_i;
    reg        new_b;
    always @(posedge aclk) begin
        if (!aresetn) begin
            if (bvalid !== 1'b0) err("BVALID alto durante reset");
            if (rvalid !== 1'b0) err("RVALID alto durante reset");
            aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
            aw_to = 0; w_to = 0; ar_to = 0;
            p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
            p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
            clear_axi4_state;
        end else begin
            if ((^{awready, wready, arready, bvalid, rvalid}) === 1'bx) err("X em saida de controle do subordinado");
            if ((^{awvalid, wvalid, arvalid, bready, rready}) === 1'bx) err("X em controle do mestre");
            if (bvalid && ((^bresp) === 1'bx))            err("BRESP com X");
            if (rvalid && ((^{rresp, rdata}) === 1'bx))   err("RRESP/RDATA com X");
            if (bvalid && bresp == 2'b01)                 err("EXOKAY sem suporte a acesso exclusivo");
            if (rvalid && rresp == 2'b01)                 err("EXOKAY sem suporte a acesso exclusivo");
            if (p_awv && !p_awr) begin
                if (!awvalid)               err("AWVALID caiu antes de AWREADY");
                else if (awaddr !== p_awaddr) err("AWADDR mudou com AWVALID pendente");
            end
            if (p_wv && !p_wr) begin
                if (!wvalid)                err("WVALID caiu antes de WREADY");
                else if (wdata !== p_wdata || wstrb !== p_wstrb) err("WDATA/WSTRB mudou com WVALID pendente");
            end
            if (p_arv && !p_arr) begin
                if (!arvalid)               err("ARVALID caiu antes de ARREADY");
                else if (araddr !== p_araddr) err("ARADDR mudou com ARVALID pendente");
            end
            if (p_bv && !p_br) begin
                if (!bvalid)                err("BVALID caiu antes de BREADY");
                else if (bresp !== p_bresp) err("BRESP mudou com BVALID pendente");
            end
            if (p_rv && !p_rr) begin
                if (!rvalid)                err("RVALID caiu antes de RREADY");
                else if (rdata !== p_rdata || rresp !== p_rresp) err("RDATA/RRESP mudou com RVALID pendente");
            end
            if (bvalid && !(b_cnt < aw_cnt && b_cnt < w_cnt)) err("BVALID sem AW e W aceitos");
            if (!AXI4_FULL && rvalid && !(r_cnt < ar_cnt))    err("RVALID sem AR aceito");
            if (AXI4_FULL) begin
                new_b = bvalid && (!p_bv || p_br);
                if (new_b) begin
                    if (b_pend[bid] == 0) begin
                        if (aw_out[bid] > 0)    errn(5, "BVALID antes do wlast do burst");
                        else if (b_done[bid])   errn(7, "segunda resposta B para o mesmo burst");
                        else                    errn(1, "BID sem burst de escrita pendente");
                    end
                end
                if (bvalid && bready) begin
                    if (b_pend[bid] > 0) begin
                        b_pend[bid] = b_pend[bid] - 1;
                        aw_out[bid] = aw_out[bid] - 1;
                        b_done[bid] = 1'b1;
                    end
                end
                if (awvalid && awready) begin
                    check_4kb(awaddr, awlen, awsize);
                    aw_len_h [aw_total % 256] = awlen;
                    aw_size_h[aw_total % 256] = awsize;
                    aw_id_h  [aw_total % 256] = awid;
                    aw_addr_h[aw_total % 256] = awaddr;
                    aw_out[awid]  = aw_out[awid] + 1;
                    b_done[awid]  = 1'b0;
                    if (w_done > aw_total) begin
                        if (w_cnt_h[aw_total % 256] != awlen + 1)
                            errn(4, "contagem de beats de W diferente de awlen+1");
                        burst_complete(aw_total);
                    end
                    aw_total = aw_total + 1;
                end
                if (wvalid && wready) begin
                    if (aw_total > w_done) begin
                        exp_len = aw_len_h[w_done % 256];
                        if (wlast && w_cur != exp_len)       errn(4, "wlast precoce");
                        if (!wlast && w_cur >= exp_len)      errn(4, "wlast ausente no ultimo beat");
                        mask_i = lanes_mask(aw_addr_h[w_done % 256], aw_size_h[w_done % 256], w_cur);
                        if ((wstrb & ~mask_i) != 0)
                            errn(10, "wstrb ativa lane fora da permitida por AxSIZE");
                    end
                    w_cur = w_cur + 1;
                    if (wlast) begin
                        w_cnt_h[w_done % 256] = w_cur;
                        if (aw_total > w_done) burst_complete(w_done);
                        w_done = w_done + 1;
                        w_cur  = 0;
                    end
                end
                if (rvalid && rready) begin
                    if (rq_cnt[rid] == 0) begin
                        if (r_done[rid]) errn(2, "beat de R em excesso");
                        else             errn(1, "RID sem burst de leitura pendente");
                    end else begin
                        qidx    = rid * QD + rq_head[rid];
                        exp_len = rq_len[qidx];
                        beat_i  = r_beat[rid];
                        if (beat_i == 0) r_resp0[rid] = rresp;
                        else if (rresp !== r_resp0[rid]) errn(9, "rresp mudou dentro do burst");
                        if (rlast && beat_i != exp_len) begin
                            errn(3, "rlast precoce");
                            pop_read_burst(rid);
                        end else if (!rlast && beat_i == exp_len) begin
                            errn(3, "rlast ausente no ultimo beat");
                            pop_read_burst(rid);
                        end else if (rlast) begin
                            pop_read_burst(rid);
                        end else begin
                            r_beat[rid] = beat_i + 1;
                            r_done[rid] = 1'b0;
                        end
                    end
                end
                if (arvalid && arready) begin
                    check_4kb(araddr, arlen, arsize);
                    qidx = arid * QD + ((rq_head[arid] + rq_cnt[arid]) % QD);
                    rq_len[qidx]   = arlen;
                    rq_cnt[arid]   = rq_cnt[arid] + 1;
                    r_done[arid]   = 1'b0;
                end
                rd_out_total = 0;
                for (id_i = 0; id_i < 16; id_i = id_i + 1)
                    rd_out_total = rd_out_total + rq_cnt[id_i] + aw_out[id_i];
                if ((awvalid && awready) || (wvalid && wready) || (arvalid && arready) ||
                    (rvalid && rready) || (bvalid && bready) || rd_out_total == 0)
                    idle_cycles = 0;
                else
                    idle_cycles = idle_cycles + 1;
                if (idle_cycles > RESP_TIMEOUT) begin
                    errn(8, "burst pendente sem resposta (deadlock)");
                    idle_cycles = 0;
                end
            end
            if (awvalid && awready) aw_cnt = aw_cnt + 1;
            if (wvalid  && wready)  w_cnt  = w_cnt  + 1;
            if (bvalid  && bready)  b_cnt  = b_cnt  + 1;
            if (arvalid && arready) ar_cnt = ar_cnt + 1;
            if (rvalid  && rready)  r_cnt  = r_cnt  + 1;
            aw_to = (awvalid && !awready) ? aw_to + 1 : 0;
            w_to  = (wvalid  && !wready)  ? w_to  + 1 : 0;
            ar_to = (arvalid && !arready) ? ar_to + 1 : 0;
            if (aw_to > TIMEOUT) begin err("timeout AWREADY"); aw_to = 0; end
            if (w_to  > TIMEOUT) begin err("timeout WREADY");  w_to  = 0; end
            if (ar_to > TIMEOUT) begin err("timeout ARREADY"); ar_to = 0; end
            p_awv = awvalid; p_awr = awready; p_awaddr = awaddr;
            p_wv  = wvalid;  p_wr  = wready;  p_wdata = wdata; p_wstrb = wstrb;
            p_bv  = bvalid;  p_br  = bready;  p_bresp = bresp;
            p_arv = arvalid; p_arr = arready; p_araddr = araddr;
            p_rv  = rvalid;  p_rr  = rready;  p_rdata = rdata; p_rresp = rresp;
        end
    end
endmodule
