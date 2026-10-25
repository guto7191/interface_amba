// Tarefas de mestre AXI4-Lite, incluidas dentro de cada testbench.
// Requer: aclk, regs de mestre (awaddr/awvalid, wdata/wstrb/wvalid, bready, araddr/arvalid, rready),
// wires de subordinado (awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid),
// e os parametros ADDR_WIDTH / DATA_WIDTH. Amostra no posedge, dirige com <=.

reg [1:0]            last_bresp;
reg [1:0]            last_rresp;
reg [DATA_WIDTH-1:0] last_rdata;

task aw_send(input [ADDR_WIDTH-1:0] a, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        awaddr  <= a;
        awvalid <= 1'b1;
        @(posedge aclk);
        while (!awready) @(posedge aclk);
        awvalid <= 1'b0;
    end
endtask

task w_send(input [DATA_WIDTH-1:0] d, input [DATA_WIDTH/8-1:0] s, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        wdata  <= d;
        wstrb  <= s;
        wvalid <= 1'b1;
        @(posedge aclk);
        while (!wready) @(posedge aclk);
        wvalid <= 1'b0;
    end
endtask

// BREADY sobe apos "dly" ciclos (0 = junto com o inicio da transacao, antes de BVALID)
task b_recv(input integer dly);
    begin
        bready <= 1'b0;
        repeat (dly) @(posedge aclk);
        bready <= 1'b1;
        @(posedge aclk);
        while (!bvalid) @(posedge aclk);
        last_bresp = bresp;
        bready <= 1'b0;
    end
endtask

task ar_send(input [ADDR_WIDTH-1:0] a, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        araddr  <= a;
        arvalid <= 1'b1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        arvalid <= 1'b0;
    end
endtask

task r_recv(input integer dly);
    begin
        rready <= 1'b0;
        repeat (dly) @(posedge aclk);
        rready <= 1'b1;
        @(posedge aclk);
        while (!rvalid) @(posedge aclk);
        last_rdata = rdata;
        last_rresp = rresp;
        rready <= 1'b0;
    end
endtask

task axi_write(input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d, input [DATA_WIDTH/8-1:0] s,
               input integer awd, input integer wd, input integer bd);
    begin
        fork
            aw_send(a, awd);
            w_send(d, s, wd);
            b_recv(bd);
        join
    end
endtask

task axi_read(input [ADDR_WIDTH-1:0] a, input integer ard, input integer rd);
    begin
        fork
            ar_send(a, ard);
            r_recv(rd);
        join
    end
endtask

// =====================================================================================
// Tasks de mestre AXI4 completo (bursts, ID, size). Habilitadas com `define AXI4_MASTER_TASKS
// antes do include. Requer, alem do bloco acima: awid/awlen/awsize/awburst, wlast, bid,
// arid/arlen/arsize/arburst, rid/rlast. VP §2.3.
//
// O Icarus nao passa arrays para task de forma confiavel. Os "arrays" da assinatura do VP
// sao buffers globais, preenchidos pelo teste antes da chamada:
//   w_data_buf / w_strb_buf  -> data_array / strb_array de w_send_burst e axi_write_burst
//   r_data_buf / r_resp_buf  -> out_array de r_recv_burst e axi_read_burst
// Acrescimos em relacao ao VP: axi_write_burst e axi_read_burst recebem tambem burst e size
// (o VP os lista em aw_send_burst/ar_send_burst), e os atrasos sao padroes (dly_pattern):
//   0 = sem atraso (sempre pronto)   1 = padrao 1010   2 = pseudoaleatorio (semente axi_seed)
// =====================================================================================
`ifdef AXI4_MASTER_TASKS

reg [31:0] w_data_buf [0:255];
reg [3:0]  w_strb_buf [0:255];
reg [31:0] r_data_buf [0:255];
reg [1:0]  r_resp_buf [0:255];
integer    master_errors = 0;     // erros detectados pelas proprias tasks (rid, bid, rlast)
integer    axi_seed      = 1;     // semente do atraso pseudoaleatorio; o teste a registra no log

// ciclos de espera antes de apresentar o beat numero "cyc"
function integer pat_gap(input integer pattern, input integer cyc);
    begin
        case (pattern)
            1:       pat_gap = cyc % 2;
            2:       pat_gap = {$random(axi_seed)} % 3;
            default: pat_gap = 0;
        endcase
    end
endfunction

// valor de READY do mestre no ciclo "cyc"
function pat_ready(input integer pattern, input integer cyc);
    begin
        case (pattern)
            1:       pat_ready = ((cyc % 2) == 0);
            2:       pat_ready = {$random(axi_seed)} % 2;
            default: pat_ready = 1'b1;
        endcase
    end
endfunction

task aw_send_burst(input [ADDR_WIDTH-1:0] a, input [3:0] id, input [7:0] len,
                   input [1:0] burst, input [2:0] size, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        awaddr  <= a;   awid   <= id;   awlen <= len;
        awburst <= burst; awsize <= size;
        awvalid <= 1'b1;
        @(posedge aclk);
        while (!awready) @(posedge aclk);
        awvalid <= 1'b0;
    end
endtask

task ar_send_burst(input [ADDR_WIDTH-1:0] a, input [3:0] id, input [7:0] len,
                   input [1:0] burst, input [2:0] size, input integer dly);
    begin
        repeat (dly) @(posedge aclk);
        araddr  <= a;   arid   <= id;   arlen <= len;
        arburst <= burst; arsize <= size;
        arvalid <= 1'b1;
        @(posedge aclk);
        while (!arready) @(posedge aclk);
        arvalid <= 1'b0;
    end
endtask

// len+1 beats de w_data_buf/w_strb_buf; wlast no ultimo; atraso por beat conforme dly_pattern
task w_send_burst(input [7:0] len, input integer dly_pattern);
    integer wb;
    begin
        for (wb = 0; wb <= len; wb = wb + 1) begin
            repeat (pat_gap(dly_pattern, wb)) @(posedge aclk);
            wdata  <= w_data_buf[wb];
            wstrb  <= w_strb_buf[wb];
            wlast  <= (wb == len);
            wvalid <= 1'b1;
            @(posedge aclk);
            while (!wready) @(posedge aclk);
            wvalid <= 1'b0;
            wlast  <= 1'b0;
        end
    end
endtask

// coleta exp_len+1 beats em r_data_buf/r_resp_buf; confere rid e rlast
task r_recv_burst(input [7:0] exp_len, input [3:0] exp_id, input integer dly_pattern);
    integer rb, rcyc, rdy;
    begin
        rb = 0; rcyc = 0;
        while (rb <= exp_len && rcyc < 200000) begin
            rdy = pat_ready(dly_pattern, rcyc);
            rready <= rdy[0];
            @(posedge aclk);
            rcyc = rcyc + 1;
            if (rvalid && rdy[0]) begin
                r_data_buf[rb] = rdata;
                r_resp_buf[rb] = rresp;
                if (rid !== exp_id) begin
                    master_errors = master_errors + 1;
                    $display("MASTER FAIL @%0t: rid=%0h esperado=%0h", $time, rid, exp_id);
                end
                if (rlast !== (rb == exp_len)) begin
                    master_errors = master_errors + 1;
                    $display("MASTER FAIL @%0t: rlast=%b no beat %0d de %0d", $time, rlast, rb, exp_len + 1);
                end
                rb = rb + 1;
            end
        end
        rready <= 1'b0;
        if (rb <= exp_len) begin
            master_errors = master_errors + 1;
            $display("MASTER FAIL @%0t: timeout no burst de leitura (%0d de %0d beats)", $time, rb, exp_len + 1);
        end
    end
endtask

task b_recv_id(input [3:0] exp_id, input integer dly);
    integer bcyc;
    begin
        bready <= 1'b0;
        repeat (dly) @(posedge aclk);
        bready <= 1'b1;
        @(posedge aclk);
        bcyc = 0;
        while (!bvalid && bcyc < 200000) begin @(posedge aclk); bcyc = bcyc + 1; end
        last_bresp = bresp;
        if (!bvalid || bid !== exp_id) begin
            master_errors = master_errors + 1;
            $display("MASTER FAIL @%0t: bid=%0h esperado=%0h (bvalid=%b)", $time, bid, exp_id, bvalid);
        end
        bready <= 1'b0;
    end
endtask

task axi_write_burst(input [ADDR_WIDTH-1:0] a, input [3:0] id, input [7:0] len,
                     input [1:0] burst, input [2:0] size,
                     input integer awd, input integer w_pat, input integer bd);
    begin
        fork
            aw_send_burst(a, id, len, burst, size, awd);
            w_send_burst(len, w_pat);
            b_recv_id(id, bd);
        join
    end
endtask

task axi_read_burst(input [ADDR_WIDTH-1:0] a, input [3:0] id, input [7:0] len,
                    input [1:0] burst, input [2:0] size,
                    input integer ard, input integer r_pat);
    begin
        fork
            ar_send_burst(a, id, len, burst, size, ard);
            r_recv_burst(len, id, r_pat);
        join
    end
endtask

`endif
