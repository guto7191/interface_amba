`timescale 1ns/1ps
// Integracao do contrato ram_* com o frontend isolado - "montagem B" (VP §3.5).
// axi_transaction_manager + controladora falsa programavel (negar accept, reter acks).
// T-I-RAM-002 (accept negado por varios ciclos) e T-I-RAM-004 (profundidade de 4 em voo, R-13).
`define AXI4_MASTER_TASKS
module tb_integration_ram_contract_backpressure_with_stub;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg aclk = 1'b0, aresetn = 1'b1;
    always #10 aclk = ~aclk;

    reg  [31:0] awaddr = 0;  reg [3:0] awid = 0;  reg [7:0] awlen = 0;  reg [2:0] awsize = 3'd2;
    reg  [1:0]  awburst = 2'b01;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0;  reg wlast = 0, wvalid = 0;  wire wready;
    wire [3:0]  bid;  wire [1:0] bresp;  wire bvalid;  reg bready = 0;
    reg  [31:0] araddr = 0;  reg [3:0] arid = 0;  reg [7:0] arlen = 0;  reg [2:0] arsize = 3'd2;
    reg  [1:0]  arburst = 2'b01;  reg arvalid = 0;  wire arready;
    wire [3:0]  rid;  wire [31:0] rdata;  wire [1:0] rresp;  wire rlast, rvalid;  reg rready = 0;

    wire [31:0] ram_addr, ram_write_data, ram_read_data;
    wire [3:0]  ram_wr;
    wire [7:0]  ram_len;
    wire [2:0]  ram_size;
    wire        ram_wr_req, ram_rd, ram_accept, ram_ack;
    wire [1:0]  resp_addr_lo;
    wire [2:0]  resp_size;

    reg  [7:0]  deny_cycles = 8'd0;
    reg         hold_acks = 1'b0;
    wire [31:0] stub_accepted, stub_acked, stub_max_inflight;

    axi_transaction_manager dut (
        .clk_i(aclk), .rst_i(~aresetn),
        .axi_awvalid_i(awvalid), .axi_awaddr_i(awaddr), .axi_awid_i(awid), .axi_awlen_i(awlen),
        .axi_awburst_i(awburst), .axi_awsize_i(awsize),
        .axi_wvalid_i(wvalid), .axi_wdata_i(wdata), .axi_wstrb_i(wstrb), .axi_wlast_i(wlast),
        .axi_bready_i(bready),
        .axi_arvalid_i(arvalid), .axi_araddr_i(araddr), .axi_arid_i(arid), .axi_arlen_i(arlen),
        .axi_arburst_i(arburst), .axi_arsize_i(arsize), .axi_rready_i(rready),
        .ram_accept_i(ram_accept), .ram_ack_i(ram_ack), .ram_error_i(1'b0),
        .ram_read_data_i(ram_read_data),
        .axi_awready_o(awready), .axi_wready_o(wready), .axi_bvalid_o(bvalid),
        .axi_bresp_o(bresp), .axi_bid_o(bid), .axi_arready_o(arready), .axi_rvalid_o(rvalid),
        .axi_rdata_o(rdata), .axi_rresp_o(rresp), .axi_rid_o(rid), .axi_rlast_o(rlast),
        .ram_wr_o(ram_wr), .ram_rd_o(ram_rd), .ram_len_o(ram_len), .ram_addr_o(ram_addr),
        .ram_write_data_o(ram_write_data), .ram_size_o(ram_size), .ram_wr_req_o(ram_wr_req),
        .resp_addr_lo_o(resp_addr_lo), .resp_size_o(resp_size));

    ram_contract_programmable_controller_stub stub (
        .aclk(aclk), .aresetn(aresetn), .deny_cycles(deny_cycles), .hold_acks(hold_acks),
        .ram_addr(ram_addr), .ram_wr(ram_wr), .ram_wr_req(ram_wr_req), .ram_rd(ram_rd),
        .ram_write_data(ram_write_data), .ram_accept(ram_accept), .ram_ack(ram_ack),
        .ram_read_data(ram_read_data),
        .accepted_count(stub_accepted), .ack_count(stub_acked), .max_inflight(stub_max_inflight));

    wire [31:0] chk_errors;
    axi_protocol_checker #(.AXI4_FULL(1), .RESP_TIMEOUT(5000)) chk (
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

    // ---------------- monitor do contrato ----------------
    integer stab_viol = 0, deny_run = 0, max_deny_run = 0;
    reg [31:0] p_addr, p_wdata;  reg [3:0] p_wr;  reg p_rd, p_wr_req, p_pend;
    wire c_req = ram_rd | ram_wr_req;
    always @(posedge aclk) begin
        if (aresetn) begin
            if (p_pend && (ram_addr !== p_addr || ram_wr !== p_wr || ram_rd !== p_rd ||
                ram_wr_req !== p_wr_req || ram_write_data !== p_wdata)) stab_viol = stab_viol + 1;
            if (c_req && !ram_accept) begin
                deny_run = deny_run + 1;
                if (deny_run > max_deny_run) max_deny_run = deny_run;
            end else deny_run = 0;
        end
        p_pend = c_req && !ram_accept;
        p_addr = ram_addr; p_wr = ram_wr; p_rd = ram_rd; p_wr_req = ram_wr_req; p_wdata = ram_write_data;
    end

    integer chk_base = 0;
    task reset_dut;
        begin
            aresetn <= 1'b0;
            awvalid <= 1'b0; wvalid <= 1'b0; arvalid <= 1'b0; bready <= 1'b0; rready <= 1'b0;
            deny_cycles <= 8'd0; hold_acks <= 1'b0;
            repeat (3) @(posedge aclk);
            aresetn <= 1'b1;
            repeat (2) @(posedge aclk);
            stab_viol = 0; deny_run = 0; max_deny_run = 0;
            master_errors = 0; chk_base = chk_errors;
        end
    endtask

    integer i, i2, guard, acc_at_100;

    initial begin
        #1 aresetn = 1'b0;
        repeat (3) @(posedge aclk);
        aresetn <= 1'b1;
        repeat (2) @(posedge aclk);

        if (run_this("T-I-RAM-002")) begin
            // ram_accept negado por varios ciclos: a controladora nega ram_accept por 10 ciclos.
            // Esperado: o frontend mantem ram_addr, ram_wr, ram_wr_req, ram_rd e ram_write_data
            // estaveis (contrato regra 2). Checagem: assertiva de estabilidade. Bloq.
            case_begin("T-I-RAM-002", "Bloq"); reset_dut;
            deny_cycles <= 8'd10;
            w_data_buf[0] = 32'hCAFE_F00D; w_strb_buf[0] = 4'b1111;
            axi_write_burst(32'h0000_0040, 4'h1, 8'd0, 2'b01, 3'd2, 0, 0, 0);
            deny_cycles <= 8'd10;
            axi_read_burst (32'h0000_0040, 4'h2, 8'd0, 2'b01, 3'd2, 0, 0);
            repeat (20) @(posedge aclk);
            check(max_deny_run >= 10, "o accept deveria ter sido negado por pelo menos 10 ciclos");
            check(stab_viol == 0, "a requisicao mudou enquanto ram_accept estava negado");
            check(r_data_buf[0] === 32'hCAFE_F00D, "a escrita atrasada nao foi aplicada");
            check(chk_errors == chk_base && master_errors == 0, "violacao no lado AXI");
            $display("INFO: T-I-RAM-002 accept negado por %0d ciclos seguidos", max_deny_run);
            case_end;
        end

        if (run_this("T-I-RAM-004")) begin
            // Profundidade de 4 transacoes (R-13): bursts sem aceitar respostas. Esperado:
            // arready/awready baixam ao atingir 4 em voo; sem perda de requisicao. Inform.
            case_begin("T-I-RAM-004", "Inform"); reset_dut;
            hold_acks <= 1'b1;
            fork
                begin : emissor                          // 6 leituras len=0, IDs distintos
                    for (i = 0; i < 6; i = i + 1)
                        ar_send_burst(32'h0000_0100 + i*4, i[3:0], 8'd0, 2'b01, 3'd2, 0);
                end
                begin : observador
                    repeat (100) @(posedge aclk);
                    acc_at_100 = stub_accepted;
                    check(arready === 1'b0, "arready deveria estar baixo com 4 em voo");
                    check(stub_max_inflight == 4, "deveriam ser exatamente 4 requisicoes em voo");
                    hold_acks <= 1'b0;                   // libera as respostas
                end
                begin : receptor                         // so depois da liberacao: o mestre
                    repeat (120) @(posedge aclk);        // precisa consumir R para o 5o e 6o AR entrarem
                    for (i2 = 0; i2 < 6; i2 = i2 + 1) begin
                        r_recv_burst(8'd0, i2[3:0], 0);
                        check(r_data_buf[0] === 32'hDEAD_DEAD, "dado do AR emitido apos o limite");
                    end
                end
            join
            $display("INFO: T-I-RAM-004 aceitas ao atingir o limite=%0d, max em voo=%0d", acc_at_100, stub_max_inflight);
            check(stub_accepted == 6 && stub_acked == 6, "alguma requisicao foi perdida");
            check(master_errors == 0 && chk_errors == chk_base, "violacao no lado AXI");
            case_end;
        end

        final_result("tb_integration_ram_contract_backpressure_with_stub");
        $finish;
    end

    initial begin
        #20_000_000;
        $display("RESULT: FAIL tb_integration_ram_contract_backpressure_with_stub (timeout)");
        $finish;
    end
endmodule
