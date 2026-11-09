# EDA Playground - subordinado AXI4-SRAM (GERADO)

Gerado por `python3 -I tb/uvm/sim/bundle_edaplayground.py` (fase 2). Nao editar a mao.

## Como usar
1. Abra https://www.edaplayground.com.
2. Cole `testbench.sv` no painel da esquerda e `design.sv` no da direita.
3. Em "Tools & Simulators": **Cadence Xcelium** (ou outro com UVM + bind).
4. Em "Languages & Libraries": **UVM 1.2**.
5. Compile options: `-timescale 1ns/1ps -access +rwc`
6. Run options: `+UVM_TESTNAME=axi4_sram_smoke_test` (outros: burst, narrow, ordering, arbitration, perf, error, reset, random).
7. Top: `tb_top`.

## Notas
- Fase do DUT fixada em `tb_top` (parameter PHASE = 2); para a fase 1 gere com `--phase 1`.
- O modelo da SRAM inicializa 1M posicoes; a simulacao inicial pode demorar.
- design.sv sai sem comentarios e so com a controladora da fase (limite do playground: menos de 100000 caracteres por arquivo).
- O comando `bind` do checker foi extraido do modulo `axi4_sram_bind` para nao criar um segundo top.

## Script run.bash (opcional)
`scripts/run.bash` roda dentro do playground (marque "Use run.bash" e cole numa aba `run.bash`):
escolhe teste/seed/verbosidade, lista testes, so elabora (`MODE=check`) e imprime resumo PASS/FAIL.
Veja `scripts/README.md`. Limites: 60 s por run, 100 MB, 1.000.000 de caracteres no total.
