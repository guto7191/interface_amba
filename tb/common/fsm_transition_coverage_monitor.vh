// Monitor de cobertura de transicoes (arcos) de FSM, incluido dentro do modulo do testbench.
// VP §4.2: visitar um estado nao basta; cada arco da tabela de transicoes precisa ser exercitado.
//
// Ate FSM_MAX_INST maquinas, de ate 8 estados. Uso:
//   fsm_arc_legal(inst, de, para);                  // declara cada arco legal (no initial)
//   always @(posedge aclk) fsm_arc_sample(inst, dut.state_q);
//   fsm_arc_report(inst, "nome");                   // imprime os arcos nao visitados; ao fim
//                                                    // fsm_arc_missing = quantos faltaram
// Um valor X no estado (reset) reinicia o rastreio sem registrar arco.

localparam FSM_MAX_INST = 4;

reg [7:0] fsm_arc_hit_r   [0:FSM_MAX_INST*8-1];   // [inst*8 + de][para]
reg [7:0] fsm_arc_legal_r [0:FSM_MAX_INST*8-1];
integer   fsm_prev_r      [0:FSM_MAX_INST-1];
integer   fsm_arc_missing = 0;
integer   fsm_init_i;

initial begin
    for (fsm_init_i = 0; fsm_init_i < FSM_MAX_INST*8; fsm_init_i = fsm_init_i + 1) begin
        fsm_arc_hit_r[fsm_init_i]   = 8'h00;
        fsm_arc_legal_r[fsm_init_i] = 8'h00;
    end
    for (fsm_init_i = 0; fsm_init_i < FSM_MAX_INST; fsm_init_i = fsm_init_i + 1)
        fsm_prev_r[fsm_init_i] = -1;
end

task fsm_arc_legal(input integer inst, input integer de, input integer para);
    begin
        fsm_arc_legal_r[inst*8 + de][para] = 1'b1;
    end
endtask

task fsm_arc_sample(input integer inst, input [7:0] cur);
    begin
        if ((^cur) === 1'bx) begin
            fsm_prev_r[inst] = -1;
        end else begin
            if (fsm_prev_r[inst] >= 0)
                fsm_arc_hit_r[inst*8 + fsm_prev_r[inst]][cur] = 1'b1;
            fsm_prev_r[inst] = cur;
        end
    end
endtask

task fsm_arc_clear_history(input integer inst);
    begin
        fsm_prev_r[inst] = -1;
    end
endtask

task fsm_arc_report(input integer inst, input [8*24-1:0] nome);
    integer de, para, total, visited;
    begin
        total = 0; visited = 0;
        for (de = 0; de < 8; de = de + 1)
            for (para = 0; para < 8; para = para + 1)
                if (fsm_arc_legal_r[inst*8 + de][para]) begin
                    total = total + 1;
                    if (fsm_arc_hit_r[inst*8 + de][para]) visited = visited + 1;
                    else begin
                        fsm_arc_missing = fsm_arc_missing + 1;
                        $display("COBERTURA %0s: arco %0d -> %0d NAO visitado", nome, de, para);
                    end
                end
        $display("INFO: cobertura de arcos %0s = %0d/%0d", nome, visited, total);
    end
endtask
