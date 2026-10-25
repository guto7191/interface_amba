// Harness comum dos testbenches de sistema (VP §3.6 a §3.13), incluido dentro do modulo do TB.
// O modulo que inclui define antes:  `define TB_NAME "<nome do tb>"   e   `define AXI4_MASTER_TASKS
//
// Monta o DUT completo (de2_115_top: reset_synchronizer + subordinado AXI4 + sram_io_buffer),
// o modelo da SRAM, o checker de protocolo (AXI4_FULL=1) e o scoreboard, e expoe as tasks de
// mestre AXI4. Cada caso comeca com sys_begin (reset do sistema, bases de erro) e termina com
// sys_end, que exige: checker, scoreboard e modelo da SRAM sem erros novos e nenhum burst pendente.

parameter PHASE       = 2;
parameter ADDR_WIDTH  = 32;
parameter DATA_WIDTH  = 32;
parameter CHK_RESP_TIMEOUT = 5000;
parameter real SRAM_T_AA = 10.0;       // T-S-SRAM-006 roda com 12.0

reg CLOCK_50 = 1'b0;
always #10 CLOCK_50 = ~CLOCK_50;                    // 50 MHz
wire aclk = CLOCK_50;
reg [3:0] KEY = 4'hF;

// ---------------- sinais AXI4 do mestre ----------------
reg  [31:0] awaddr = 0;  reg [3:0] awid = 0;  reg [7:0] awlen = 0;  reg [2:0] awsize = 3'd2;
reg  [1:0]  awburst = 2'b01;  reg awvalid = 0;  wire awready;
reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0;  reg wlast = 0, wvalid = 0;  wire wready;
wire [3:0]  bid;  wire [1:0] bresp;  wire bvalid;  reg bready = 0;
reg  [31:0] araddr = 0;  reg [3:0] arid = 0;  reg [7:0] arlen = 0;  reg [2:0] arsize = 3'd2;
reg  [1:0]  arburst = 2'b01;  reg arvalid = 0;  wire arready;
wire [3:0]  rid;  wire [31:0] rdata;  wire [1:0] rresp;  wire rlast, rvalid;  reg rready = 0;

// ---------------- pinos da SRAM ----------------
wire [19:0] SRAM_ADDR;
wire [15:0] SRAM_DQ;
wire        SRAM_OE_N, SRAM_WE_N, SRAM_CE_N, SRAM_LB_N, SRAM_UB_N;

de2_115_top #(.PHASE(PHASE)) dut (
    .CLOCK_50(CLOCK_50), .KEY(KEY),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_OE_N(SRAM_OE_N), .SRAM_WE_N(SRAM_WE_N),
    .SRAM_CE_N(SRAM_CE_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N),
    .s_axi_awid(awid), .s_axi_awaddr(awaddr), .s_axi_awlen(awlen), .s_axi_awsize(awsize),
    .s_axi_awburst(awburst), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wlast(wlast),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bid(bid), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_arid(arid), .s_axi_araddr(araddr), .s_axi_arlen(arlen), .s_axi_arsize(arsize),
    .s_axi_arburst(arburst), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rid(rid), .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rlast(rlast),
    .s_axi_rvalid(rvalid), .s_axi_rready(rready));

wire aresetn = dut.aresetn_w;                        // reset sincronizado, observado pelo checker

wire [31:0] sram_errors, sram_access_count, sram_we_pulses;
sram_is61wv102416_behavioral_model #(.T_AA(SRAM_T_AA)) u_sram (
    .addr(SRAM_ADDR), .dq(SRAM_DQ), .ce_n(SRAM_CE_N), .oe_n(SRAM_OE_N), .we_n(SRAM_WE_N),
    .lb_n(SRAM_LB_N), .ub_n(SRAM_UB_N), .sample_clk(aclk),
    .errors(sram_errors), .access_count(sram_access_count), .we_pulse_count(sram_we_pulses));

wire [31:0] chk_errors;
axi_protocol_checker #(.AXI4_FULL(1), .RESP_TIMEOUT(CHK_RESP_TIMEOUT), .TIMEOUT(CHK_RESP_TIMEOUT)) chk (
    .aclk(aclk), .aresetn(aresetn),
    .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
    .bresp(bresp), .bvalid(bvalid), .bready(bready),
    .araddr(araddr), .arvalid(arvalid), .arready(arready),
    .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready),
    .errors(chk_errors),
    .awid(awid), .awlen(awlen), .awsize(awsize), .awburst(awburst), .wlast(wlast),
    .bid(bid), .arid(arid), .arlen(arlen), .arsize(arsize), .arburst(arburst),
    .rid(rid), .rlast(rlast));

`include "tb/common/testbench_case_runner_utils.vh"
`include "tb/common/axi_master_tasks.vh"
`include "tb/common/axi4_random_transaction_generator.vh"
`include "tb/common/axi4_functional_coverage_collector.vh"
`include "tb/common/axi4_reference_scoreboard_with_monitors.vh"

// ---------------- contador de ciclos ----------------
integer cycle_count = 0;
always @(posedge aclk) cycle_count = cycle_count + 1;

// ---------------- reset do sistema e delimitacao de caso ----------------
integer chk_base = 0, sb_base = 0, sram_base = 0;

task reset_system;
    begin
        KEY[0] = 1'b0;
        awvalid <= 1'b0; wvalid <= 1'b0; arvalid <= 1'b0; bready <= 1'b0; rready <= 1'b0;
        repeat (4) @(posedge aclk);
        KEY[0] = 1'b1;
        repeat (4) @(posedge aclk);
        while (aresetn !== 1'b1) @(posedge aclk);
        repeat (2) @(posedge aclk);
    end
endtask

task sys_begin(input [8*40-1:0] id, input [8*8-1:0] sev);
    begin
        case_begin(id, sev);
        reset_system;
        master_errors = 0;
        chk_base = chk_errors; sb_base = sb_errors; sram_base = sram_errors;
        cov_rdy = 0; cov_idmode = 0;
    end
endtask

// allow_chk = 1 nos casos em que o proprio estimulo viola o protocolo de proposito (T-S-4KB-001)
task sys_end(input integer allow_chk);
    begin
        repeat (60) @(posedge aclk);
        check(sb_pending(0) == 0, "ha bursts pendentes (sem resposta completa)");
        check(sb_errors == sb_base, "scoreboard acusou divergencia");
        if (!allow_chk) check(chk_errors == chk_base, "checker de protocolo acusou violacao");
        check(sram_errors == sram_base, "modelo da SRAM acusou violacao de temporizacao");
        check(master_errors == 0, "o mestre detectou rid/bid/rlast incorretos");
        case_end;
    end
endtask

// ---------------- atalhos para os testes ----------------
// payload deterministico; wstrb = lanes permitidas pelo AxSIZE (escrita "cheia" do beat)
integer pl_i;
task fill_payload(input [31:0] a, input [7:0] len, input [2:0] size, input [31:0] base);
    begin
        for (pl_i = 0; pl_i <= len; pl_i = pl_i + 1) begin
            w_data_buf[pl_i] = base ^ (pl_i * 32'h0101_0101) ^ (pl_i << 3);
            w_strb_buf[pl_i] = lane_mask(a, (size > 3'd2) ? 3'd2 : size, pl_i);
        end
    end
endtask

task do_write(input [31:0] a, input [3:0] id, input [7:0] len, input [2:0] size, input [31:0] base,
              input integer awd, input integer w_pat, input integer bd);
    begin
        fill_payload(a, len, size, base);
        axi_write_burst(a, id, len, 2'b01, size, awd, w_pat, bd);
    end
endtask

task do_read(input [31:0] a, input [3:0] id, input [7:0] len, input [2:0] size,
             input integer ard, input integer r_pat);
    begin
        axi_read_burst(a, id, len, 2'b01, size, ard, r_pat);
    end
endtask

// ---------------- contadores de beats e coleta de respostas ----------------
integer rb_cnt = 0, wb_cnt = 0;              // beats de R / W aceitos desde o inicio
always @(posedge aclk) begin
    if (rvalid && rready) rb_cnt = rb_cnt + 1;
    if (wvalid && wready) wb_cnt = wb_cnt + 1;
end

reg [3:0]  cb_id   [0:255];
reg [31:0] cb_data [0:255];
reg [1:0]  cb_resp [0:255];
reg        cb_last [0:255];

// recolhe n beats de R na ordem de chegada (rready fixo em 1), sem supor um ID
task collect_r_beats(input integer n);
    integer c, cyc;
    begin
        c = 0; cyc = 0;
        rready <= 1'b1;
        while (c < n && cyc < 200000) begin
            @(posedge aclk);
            cyc = cyc + 1;
            if (rvalid && rready) begin
                cb_id[c] = rid; cb_data[c] = rdata; cb_resp[c] = rresp; cb_last[c] = rlast;
                c = c + 1;
            end
        end
        rready <= 1'b0;
        if (c < n) begin
            master_errors = master_errors + 1;
            $display("MASTER FAIL @%0t: timeout recolhendo beats de R (%0d de %0d)", $time, c, n);
        end
    end
endtask

// leva os sinais do mestre ao repouso (depois de um reset que interrompeu uma transacao)
task master_idle;
    begin
        awvalid <= 1'b0; wvalid <= 1'b0; wlast <= 1'b0; bready <= 1'b0;
        arvalid <= 1'b0; rready <= 1'b0;
    end
endtask
