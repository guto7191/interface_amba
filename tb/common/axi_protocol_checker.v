`timescale 1ns/1ps
// Monitor passivo de protocolo AXI4-Lite (lado subordinado). Conta violacoes em "errors".
module axi_protocol_checker #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter TIMEOUT    = 200
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
    output reg [31:0]        errors
);
    // valores do ciclo anterior
    reg                    p_awv, p_awr, p_wv, p_wr, p_bv, p_br, p_arv, p_arr, p_rv, p_rr;
    reg [ADDR_WIDTH-1:0]   p_awaddr, p_araddr;
    reg [DATA_WIDTH-1:0]   p_wdata, p_rdata;
    reg [DATA_WIDTH/8-1:0] p_wstrb;
    reg [1:0]              p_bresp, p_rresp;

    // handshakes concluidos desde o reset
    integer aw_cnt, w_cnt, b_cnt, ar_cnt, r_cnt;
    // ciclos esperando READY
    integer aw_to, w_to, ar_to;

    initial begin
        errors = 0;
        aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
        aw_to = 0; w_to = 0; ar_to = 0;
        p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
        p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
    end

    task err(input [8*48-1:0] msg);
        begin
            errors = errors + 1;
            $display("CHECKER FAIL @%0t: %0s", $time, msg);
        end
    endtask

    always @(posedge aclk) begin
        if (!aresetn) begin
            // saidas VALID devem estar em 0 durante o reset
            if (bvalid !== 1'b0) err("BVALID alto durante reset");
            if (rvalid !== 1'b0) err("RVALID alto durante reset");
            aw_cnt = 0; w_cnt = 0; b_cnt = 0; ar_cnt = 0; r_cnt = 0;
            aw_to = 0; w_to = 0; ar_to = 0;
            p_awv = 0; p_awr = 0; p_wv = 0; p_wr = 0; p_bv = 0; p_br = 0;
            p_arv = 0; p_arr = 0; p_rv = 0; p_rr = 0;
        end else begin
            // X nos controles
            if ((^{awready, wready, arready, bvalid, rvalid}) === 1'bx) err("X em saida de controle do subordinado");
            if ((^{awvalid, wvalid, arvalid, bready, rready}) === 1'bx) err("X em controle do mestre");
            if (bvalid && ((^bresp) === 1'bx))            err("BRESP com X");
            if (rvalid && ((^{rresp, rdata}) === 1'bx))   err("RRESP/RDATA com X");
            if (bvalid && bresp == 2'b01)                 err("EXOKAY em AXI4-Lite");
            if (rvalid && rresp == 2'b01)                 err("EXOKAY em AXI4-Lite");

            // estabilidade do mestre: VALID sobe e fica ate READY, payload constante
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
            // estabilidade do subordinado
            if (p_bv && !p_br) begin
                if (!bvalid)                err("BVALID caiu antes de BREADY");
                else if (bresp !== p_bresp) err("BRESP mudou com BVALID pendente");
            end
            if (p_rv && !p_rr) begin
                if (!rvalid)                err("RVALID caiu antes de RREADY");
                else if (rdata !== p_rdata || rresp !== p_rresp) err("RDATA/RRESP mudou com RVALID pendente");
            end

            // causalidade: resposta so depois dos handshakes de entrada
            if (bvalid && !(b_cnt < aw_cnt && b_cnt < w_cnt)) err("BVALID sem AW e W aceitos");
            if (rvalid && !(r_cnt < ar_cnt))                  err("RVALID sem AR aceito");

            // contagem de handshakes
            if (awvalid && awready) aw_cnt = aw_cnt + 1;
            if (wvalid  && wready)  w_cnt  = w_cnt  + 1;
            if (bvalid  && bready)  b_cnt  = b_cnt  + 1;
            if (arvalid && arready) ar_cnt = ar_cnt + 1;
            if (rvalid  && rready)  r_cnt  = r_cnt  + 1;

            // timeout de aceitacao (deadlock)
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
