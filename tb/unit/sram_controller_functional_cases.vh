// Casos funcionais da controladora da SRAM, compartilhados entre a Fase 2 (sram_controller) e
// a Fase 1 (sram_controller_baseline). Incluido dentro do modulo do testbench.
// VP §3.4 (T-U-CTL-*), §3.2 (T-U-IOB-004..006).
//
// O testbench que inclui este arquivo precisa declarar:
//   clk; regs do driver ram_addr[31:0], ram_wr[3:0], ram_wr_req, ram_rd, ram_write_data[31:0];
//   wires ram_accept, ram_ack, ram_read_data[31:0]; wires dos pinos observados
//   sram_oe_n, sram_we_n, sram_lb_n, sram_ub_n, sram_data_out_en e SRAM_DQ;
//   a instancia do modelo "u_sram"; e a task reset_dut.
// Com `define CHECK_CYCLES os casos tambem conferem o numero de ciclos e a estrutura dos pulsos
// de WE_N (contagem de pulsos e LB_N/UB_N durante o pulso). So a Fase 2 os cumpre: a FSM da IP
// (Fase 1) sempre emite os dois pulsos e mascara a metade nao usada por LB_N/UB_N, o que e
// funcionalmente correto mas nao e a estrutura especificada para o sram_controller.

// ---------------- monitores ----------------
integer          cyc = 0;                      // ciclos de clock desde o inicio
integer          acc_n = 0, ack_n = 0;         // requisicoes aceitas / acks
integer          acc_cyc [0:1023];
integer          ack_cyc [0:1023];
reg [31:0]       ack_data [0:1023];
integer          stab_errors = 0;              // contrato regra 2: estabilidade sem accept
integer          dq_x_cycles = 0;              // ciclos com DQ parcialmente indefinido
integer          lbub_in_pulse = 0;            // {ub_n, lb_n} observado durante o pulso de WE_N
integer          we_low_cycles = 0;
realtime         t_oe_rise = 0, t_dout_en_rise = 0;

reg        p_req, p_accept;
reg [31:0] p_addr, p_wdata;
reg [3:0]  p_wr;
reg        p_rd, p_wr_req;

always @(posedge clk) begin
    cyc = cyc + 1;
    if (ram_accept && (ram_rd || ram_wr_req)) begin
        acc_cyc[acc_n] = cyc;
        acc_n = acc_n + 1;
    end
    if (ram_ack) begin
        ack_cyc[ack_n]  = cyc;
        ack_data[ack_n] = ram_read_data;
        ack_n = ack_n + 1;
    end
    // estabilidade da requisicao pendente (contrato regra 2)
    if (p_req && !p_accept) begin
        if (ram_addr !== p_addr || ram_wr !== p_wr || ram_wr_req !== p_wr_req ||
            ram_rd !== p_rd || ram_write_data !== p_wdata) begin
            stab_errors = stab_errors + 1;
            $display("CONTRATO @%0t: requisicao mudou sem ram_accept", $time);
        end
    end
    p_req = ram_rd | ram_wr_req;  p_accept = ram_accept;
    p_addr = ram_addr; p_wr = ram_wr; p_wr_req = ram_wr_req; p_rd = ram_rd; p_wdata = ram_write_data;
    // DQ nem tudo em Z nem todo definido -> X ou contencao
    if (!(SRAM_DQ === 16'bz) && ((^SRAM_DQ) === 1'bx)) dq_x_cycles = dq_x_cycles + 1;
    if (!sram_we_n) begin
        lbub_in_pulse = {sram_ub_n, sram_lb_n};
        we_low_cycles = we_low_cycles + 1;
    end
end

always @(posedge sram_oe_n)        t_oe_rise      = $realtime;
always @(posedge sram_data_out_en) t_dout_en_rise = $realtime;

task mon_clear;
    begin
        acc_n = 0; ack_n = 0; stab_errors = 0; dq_x_cycles = 0; we_low_cycles = 0;
    end
endtask

// ---------------- driver do contrato ram_* ----------------
// Apresenta a requisicao e a mantem ate ram_accept. Ao retornar, a requisicao foi consumida
// (as entradas sao zeradas, a menos que a proxima chamada as sobrescreva no mesmo instante).
task ram_issue(input [31:0] a, input [3:0] wr, input wr_req, input rd, input [31:0] d);
    integer guard;
    begin
        ram_addr <= a; ram_wr <= wr; ram_wr_req <= wr_req; ram_rd <= rd; ram_write_data <= d;
        @(posedge clk);
        guard = 0;
        while (!ram_accept && guard < 1000) begin @(posedge clk); guard = guard + 1; end
        ram_wr_req <= 1'b0; ram_rd <= 1'b0; ram_wr <= 4'b0000;
    end
endtask

task ram_read (input [31:0] a);              begin ram_issue(a, 4'b0000, 1'b0, 1'b1, 32'h0); end endtask
task ram_write(input [31:0] a, input [3:0] s, input [31:0] d); begin ram_issue(a, s, 1'b1, 1'b0, d); end endtask

task wait_acks(input integer n);
    integer guard;
    begin
        guard = 0;
        while (ack_n < n && guard < 2000) begin @(posedge clk); guard = guard + 1; end
        repeat (2) @(posedge clk);
        check(ack_n == n, "numero de acks diferente do esperado");
    end
endtask

// palavra de 16 bits da SRAM para um endereco em bytes (metade baixa)
function [19:0] w16(input [31:0] byte_addr);
    w16 = {byte_addr[20:2], 1'b0};
endfunction

// ---------------- casos ----------------

task t_u_ctl_001;   // Leitura isolada
    begin
        // Objetivo: leitura isolada. Estimulo: uma requisicao ram_rd em 0x100.
        // Esperado: ram_ack em 3 ciclos; ram_read_data = duas palavras montadas. Bloq.
        case_begin("T-U-CTL-001", "Bloq");
        reset_dut; mon_clear;
        u_sram.mem_poke(w16(32'h100),     16'hBEEF);
        u_sram.mem_poke(w16(32'h100) + 1, 16'hCAFE);
        ram_read(32'h100);
        wait_acks(1);
        check(ack_data[0] === 32'hCAFE_BEEF, "dado lido diferente de CAFEBEEF");
`ifdef CHECK_CYCLES
        check(ack_cyc[0] - acc_cyc[0] == 3, "leitura isolada deveria dar ack em 3 ciclos");
`endif
        check(u_sram.cnt_a05 == 0 && u_sram.cnt_a06 == 0, "violacao no modelo da SRAM");
        case_end;
    end
endtask

task t_u_ctl_002;   // Leitura em regime
    integer i;
    begin
        // Objetivo: 2 ciclos por beat em regime. Estimulo: 8 ram_rd consecutivas, sempre aceitas.
        // Esperado: a partir da 2a, um ram_ack a cada 2 ciclos. Ajust.
        case_begin("T-U-CTL-002", "Ajust");
        reset_dut; mon_clear;
        for (i = 0; i < 8; i = i + 1) begin
            u_sram.mem_poke(w16(i*4),     16'hA000 + i);
            u_sram.mem_poke(w16(i*4) + 1, 16'hB000 + i);
        end
        for (i = 0; i < 8; i = i + 1) ram_read(i*4);
        wait_acks(8);
        for (i = 0; i < 8; i = i + 1)
            check(ack_data[i] === {16'hB000 + i[15:0], 16'hA000 + i[15:0]}, "dado do beat de leitura incorreto");
`ifdef CHECK_CYCLES
        for (i = 1; i < 8; i = i + 1)
            check(ack_cyc[i] - ack_cyc[i-1] == 2, "intervalo entre acks de leitura deveria ser 2");
`endif
        case_end;
    end
endtask

task t_u_ctl_003;   // Escrita isolada
    begin
        // Objetivo: escrita isolada. Estimulo: ram_wr = 4'b1111 em 0x100, dado 12345678.
        // Esperado: ram_ack em 5 ciclos; ambas as palavras escritas. Bloq.
        case_begin("T-U-CTL-003", "Bloq");
        reset_dut; mon_clear;
        ram_write(32'h100, 4'b1111, 32'h1234_5678);
        wait_acks(1);
        check(u_sram.mem_peek(w16(32'h100))     === 16'h5678, "palavra baixa incorreta");
        check(u_sram.mem_peek(w16(32'h100) + 1) === 16'h1234, "palavra alta incorreta");
`ifdef CHECK_CYCLES
        check(ack_cyc[0] - acc_cyc[0] == 5, "escrita isolada deveria dar ack em 5 ciclos");
`endif
        check(u_sram.errors == 0, "violacao no modelo da SRAM");
        case_end;
    end
endtask

task t_u_ctl_004;   // Escrita em regime
    integer i;
    begin
        // Objetivo: 4 ciclos por beat em regime (D15). Estimulo: 8 escritas consecutivas.
        // Esperado: um ram_ack a cada 4 ciclos; memoria correta. Ajust.
        case_begin("T-U-CTL-004", "Ajust");
        reset_dut; mon_clear;
        for (i = 0; i < 8; i = i + 1)
            ram_write(32'h600 + i*4, 4'b1111, {16'h1000 + i[15:0], 16'h2000 + i[15:0]});
        wait_acks(8);
        for (i = 0; i < 8; i = i + 1) begin
            check(u_sram.mem_peek(w16(32'h600 + i*4))     === 16'h2000 + i[15:0], "palavra baixa incorreta");
            check(u_sram.mem_peek(w16(32'h600 + i*4) + 1) === 16'h1000 + i[15:0], "palavra alta incorreta");
        end
`ifdef CHECK_CYCLES
        for (i = 1; i < 8; i = i + 1)
            check(ack_cyc[i] - ack_cyc[i-1] == 4, "intervalo entre acks de escrita deveria ser 4");
`endif
        check(u_sram.errors == 0, "violacao no modelo da SRAM");
        case_end;
    end
endtask

task t_u_ctl_005;   // Escrita so da metade baixa
    integer p0;
    begin
        // Objetivo: escrita parcial baixa. Estimulo: ram_wr = 4'b0011.
        // Esperado: so a palavra baixa acessada; alta intocada; um unico pulso de WE_N. Bloq.
        case_begin("T-U-CTL-005", "Bloq");
        reset_dut; mon_clear;
        u_sram.mem_poke(w16(32'h300),     16'h1111);
        u_sram.mem_poke(w16(32'h300) + 1, 16'h2222);
        p0 = u_sram.we_pulse_count;
        ram_write(32'h300, 4'b0011, 32'hAAAA_BBBB);
        wait_acks(1);
        check(u_sram.mem_peek(w16(32'h300))     === 16'hBBBB, "palavra baixa deveria ser BBBB");
        check(u_sram.mem_peek(w16(32'h300) + 1) === 16'h2222, "palavra alta deveria ficar intocada");
`ifdef CHECK_CYCLES
        check(u_sram.we_pulse_count - p0 == 1, "deveria haver exatamente 1 pulso de WE_N");
`endif
        case_end;
    end
endtask

task t_u_ctl_006;   // Escrita so da metade alta
    integer p0;
    begin
        // Objetivo: escrita parcial alta. Estimulo: ram_wr = 4'b1100.
        // Esperado: so a palavra alta acessada. Bloq.
        case_begin("T-U-CTL-006", "Bloq");
        reset_dut; mon_clear;
        u_sram.mem_poke(w16(32'h310),     16'h1111);
        u_sram.mem_poke(w16(32'h310) + 1, 16'h2222);
        p0 = u_sram.we_pulse_count;
        ram_write(32'h310, 4'b1100, 32'hAAAA_BBBB);
        wait_acks(1);
        check(u_sram.mem_peek(w16(32'h310))     === 16'h1111, "palavra baixa deveria ficar intocada");
        check(u_sram.mem_peek(w16(32'h310) + 1) === 16'hAAAA, "palavra alta deveria ser AAAA");
`ifdef CHECK_CYCLES
        check(u_sram.we_pulse_count - p0 == 1, "deveria haver exatamente 1 pulso de WE_N");
`endif
        case_end;
    end
endtask

task t_u_ctl_007;   // Escrita com strobe nulo
    integer a0;
    begin
        // Objetivo: strobe nulo nao acessa a SRAM. Estimulo: ram_wr = 4'b0000 com ram_rd = 0.
        // Esperado: nenhum acesso; ram_ack imediato; we_n nunca ativa. Bloq.
        case_begin("T-U-CTL-007", "Bloq");
        reset_dut; mon_clear;
        a0 = u_sram.access_count;
        ram_write(32'h320, 4'b0000, 32'hFFFF_FFFF);
        wait_acks(1);
        check(u_sram.access_count == a0, "a SRAM foi acessada numa escrita nula");
        check(we_low_cycles == 0, "we_n ativou numa escrita nula");
        check(ack_cyc[0] - acc_cyc[0] == 1, "ack da escrita nula deveria vir 1 ciclo apos o accept");
        case_end;
    end
endtask

task t_u_ctl_008;   // Escrita de um byte so
    begin
        // Objetivo: um byte. Estimulo: ram_wr = 4'b0001.
        // Esperado: so LB_N ativo na palavra baixa; so o byte [7:0] muda. Bloq.
        case_begin("T-U-CTL-008", "Bloq");
        reset_dut; mon_clear;
        u_sram.mem_poke(w16(32'h340),     16'h1234);
        u_sram.mem_poke(w16(32'h340) + 1, 16'h5678);
        ram_write(32'h340, 4'b0001, 32'h0000_00AB);
        wait_acks(1);
        check(u_sram.mem_peek(w16(32'h340))     === 16'h12AB, "so o byte baixo deveria mudar");
        check(u_sram.mem_peek(w16(32'h340) + 1) === 16'h5678, "palavra alta deveria ficar intocada");
`ifdef CHECK_CYCLES
        check(lbub_in_pulse == 2'b10, "durante o pulso: LB_N=0 e UB_N=1");
`endif
        case_end;
    end
endtask

task t_u_ctl_009;   // Turnaround leitura -> escrita
    begin
        // Objetivo: sem contencao ao trocar de leitura para escrita. Estimulo: leitura seguida
        // imediatamente de escrita. Esperado: >= 1 ciclo entre OE_N subir e data_out_en subir;
        // sem X em DQ. A-SRAM-06. Bloq.
        case_begin("T-U-CTL-009", "Bloq");
        reset_dut; mon_clear;
        u_sram.mem_poke(w16(32'h400), 16'h0F0F);
        ram_read(32'h400);
        ram_write(32'h404, 4'b1111, 32'hC0DE_C0DE);
        wait_acks(2);
        check(t_dout_en_rise - t_oe_rise >= 20.0, "menos de 1 ciclo entre OE_N subir e data_out_en subir");
        check(dq_x_cycles == 0, "X em SRAM_DQ (contencao)");
        check(u_sram.cnt_a06 == 0, "A-SRAM-06 (contencao) disparou");
        check(u_sram.mem_peek(w16(32'h404)) === 16'hC0DE, "escrita apos a leitura incorreta");
        case_end;
    end
endtask

task t_u_ctl_010;   // Turnaround escrita -> leitura
    begin
        // Objetivo: sem contencao ao trocar de escrita para leitura. Estimulo: escrita seguida
        // de leitura do mesmo endereco. Esperado: dado lido correto; A-SRAM-06 limpa. Bloq.
        case_begin("T-U-CTL-010", "Bloq");
        reset_dut; mon_clear;
        ram_write(32'h500, 4'b1111, 32'h0BAD_F00D);
        ram_read(32'h500);
        wait_acks(2);
        check(ack_data[1] === 32'h0BAD_F00D, "leitura apos a escrita retornou dado errado");
        check(dq_x_cycles == 0, "X em SRAM_DQ (contencao)");
        check(u_sram.cnt_a06 == 0, "A-SRAM-06 (contencao) disparou");
        case_end;
    end
endtask

task t_u_ctl_011;   // ram_accept negado
    begin
        // Objetivo: accept negado enquanto ocupada. Estimulo: nova requisicao com a controladora
        // ocupada. Esperado: ram_accept = 0; requisicao preservada e atendida depois. Bloq.
        case_begin("T-U-CTL-011", "Bloq");
        reset_dut; mon_clear;
        ram_read(32'h700);
        // apresenta uma escrita logo apos o accept da leitura; controladora esta em RD_LOW
        ram_addr <= 32'h710; ram_wr <= 4'b1111; ram_wr_req <= 1'b1; ram_rd <= 1'b0;
        ram_write_data <= 32'h7777_8888;
        @(posedge clk);
        check(ram_accept === 1'b0, "ram_accept deveria estar baixo com a controladora ocupada");
        while (!ram_accept) @(posedge clk);
        ram_wr_req <= 1'b0; ram_wr <= 4'b0000;
        wait_acks(2);
        check(stab_errors == 0, "requisicao nao ficou estavel enquanto pendente");
        check(u_sram.mem_peek(w16(32'h710))     === 16'h8888, "escrita pendente: palavra baixa incorreta");
        check(u_sram.mem_peek(w16(32'h710) + 1) === 16'h7777, "escrita pendente: palavra alta incorreta");
        case_end;
    end
endtask
