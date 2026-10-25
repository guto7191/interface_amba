// Utilitarios de execucao de casos de teste (incluido dentro do modulo do testbench).
// Convencao do projeto (VP §2): cada caso imprime "CASE <ID> [sev]: PASS|FAIL" e o
// arquivo termina com "RESULT: PASS|FAIL <tb>", que e o que o Makefile verifica.
//
// Uso:
//   if (run_this("T-U-XXX-001")) begin
//       case_begin("T-U-XXX-001", "Bloq");
//       ... estimulo ...  check(condicao, "mensagem");
//       case_end;
//   end
//   final_result("nome_do_tb");
//
// Plusargs: +TEST=<ID> roda so aquele caso; +SEED=<n> semente dos geradores aleatorios.

integer          task_errors    = 0;   // erros do caso corrente
integer          n_cases_run    = 0;
integer          n_cases_fail   = 0;
integer          seed_value     = 1;
reg [8*40-1:0]   cur_id;
reg [8*8-1:0]    cur_sev;
reg [8*40-1:0]   sel_test;
reg              sel_active     = 1'b0;

initial begin
    sel_active = $value$plusargs("TEST=%s", sel_test);
    if (!$value$plusargs("SEED=%d", seed_value)) seed_value = 1;
    $display("INFO: SEED=%0d", seed_value);
end

// verdadeiro se o caso deve rodar (sem +TEST, todos rodam)
function run_this(input [8*40-1:0] id);
    run_this = !sel_active || (sel_test == id);
endfunction

task check(input cond, input [8*64-1:0] msg);
    begin
        if (!cond) begin
            task_errors = task_errors + 1;
            $display("FAIL [%0s] @%0t: %0s", cur_id, $time, msg);
        end
    end
endtask

task case_begin(input [8*40-1:0] id, input [8*8-1:0] sev);
    begin
        cur_id      = id;
        cur_sev     = sev;
        task_errors = 0;
    end
endtask

task case_end;
    begin
        n_cases_run = n_cases_run + 1;
        if (task_errors == 0) begin
            $display("CASE %0s [%0s]: PASS", cur_id, cur_sev);
        end else begin
            n_cases_fail = n_cases_fail + 1;
            $display("CASE %0s [%0s]: FAIL (%0d erros)", cur_id, cur_sev, task_errors);
        end
    end
endtask

task final_result(input [8*96-1:0] tb_name);
    begin
        if (n_cases_run == 0)
            $display("RESULT: FAIL %0s (nenhum caso executado)", tb_name);
        else if (n_cases_fail == 0)
            $display("RESULT: PASS %0s (%0d casos)", tb_name, n_cases_run);
        else
            $display("RESULT: FAIL %0s (%0d de %0d casos)", tb_name, n_cases_fail, n_cases_run);
    end
endtask
