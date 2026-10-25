`timescale 1ns/1ps
// Teste unitario do calculo de endereco de burst do axi_transaction_manager (MAS §5.4.1, R-19).
// VP §3.13.1: T-U-SZ-001..004, chamando a funcao calculate_addr_next por referencia hierarquica.
// axtype = 2'b01 e INCR.
module tb_unit_axi_transaction_manager_burst_address_calc;

    // DUT com entradas inertes: so a funcao interessa
    wire awready, wready, bvalid, arready, rvalid, rlast;
    axi_transaction_manager dut (
        .clk_i(1'b0), .rst_i(1'b1),
        .axi_awvalid_i(1'b0), .axi_awaddr_i(32'h0), .axi_awid_i(4'h0), .axi_awlen_i(8'h0),
        .axi_awburst_i(2'b01), .axi_awsize_i(3'd2),
        .axi_wvalid_i(1'b0), .axi_wdata_i(32'h0), .axi_wstrb_i(4'h0), .axi_wlast_i(1'b0),
        .axi_bready_i(1'b0),
        .axi_arvalid_i(1'b0), .axi_araddr_i(32'h0), .axi_arid_i(4'h0), .axi_arlen_i(8'h0),
        .axi_arburst_i(2'b01), .axi_arsize_i(3'd2), .axi_rready_i(1'b0),
        .ram_accept_i(1'b0), .ram_ack_i(1'b0), .ram_error_i(1'b0), .ram_read_data_i(32'h0),
        .axi_awready_o(awready), .axi_wready_o(wready), .axi_bvalid_o(bvalid),
        .axi_bresp_o(), .axi_bid_o(), .axi_arready_o(arready), .axi_rvalid_o(rvalid),
        .axi_rdata_o(), .axi_rresp_o(), .axi_rid_o(), .axi_rlast_o(rlast),
        .ram_wr_o(), .ram_rd_o(), .ram_len_o(), .ram_addr_o(), .ram_write_data_o(),
        .ram_size_o(), .ram_wr_req_o(), .resp_addr_lo_o(), .resp_size_o());

    `include "tb/common/testbench_case_runner_utils.vh"

    reg [31:0] r;

    initial begin
        if (run_this("T-U-SZ-001")) begin
            // calculate_addr_next(0x1000, INCR, 3, size=0) -> 0x1001. Bloq. (§A3.4.1)
            case_begin("T-U-SZ-001", "Bloq");
            r = dut.calculate_addr_next(32'h1000, 2'b01, 8'd3, 3'd0);
            check(r === 32'h1001, "size=0 deveria incrementar 1 byte");
            case_end;
        end

        if (run_this("T-U-SZ-002")) begin
            // calculate_addr_next(0x1000, INCR, 3, size=1) -> 0x1002. Bloq.
            case_begin("T-U-SZ-002", "Bloq");
            r = dut.calculate_addr_next(32'h1000, 2'b01, 8'd3, 3'd1);
            check(r === 32'h1002, "size=1 deveria incrementar 2 bytes");
            case_end;
        end

        if (run_this("T-U-SZ-003")) begin
            // calculate_addr_next(0x1000, INCR, 3, size=2) -> 0x1004 (regressao do comportamento
            // original). Bloq.
            case_begin("T-U-SZ-003", "Bloq");
            r = dut.calculate_addr_next(32'h1000, 2'b01, 8'd3, 3'd2);
            check(r === 32'h1004, "size=2 deveria incrementar 4 bytes");
            case_end;
        end

        if (run_this("T-U-SZ-004")) begin
            // calculate_addr_next(0x1002, INCR, 3, size=2) -> 0x1004, NAO 0x1006: aplica
            // Aligned_Address. Detecta a omissao do mascaramento de alinhamento. Bloq.
            case_begin("T-U-SZ-004", "Bloq");
            r = dut.calculate_addr_next(32'h1002, 2'b01, 8'd3, 3'd2);
            check(r === 32'h1004, "Aligned_Address nao aplicado (esperado 1004)");
            case_end;
        end

        final_result("tb_unit_axi_transaction_manager");
        $finish;
    end
endmodule
