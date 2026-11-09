# UVM TB - axi_interface_subordinate_sram (PHASE=2)

TODO: completar esta documentacao conforme a implementacao avancar.

## Estrutura
interfaces/ (axi4_if, sram_if) | agents/{axi4_agent,sram_agent} | env/ | sequences/ | tests/ | top/ | models/ (modelo SRAM) | checkers/ (checker AXI) | sim/

## Ordem de implementacao sugerida
1. interfaces e tb_top (clock/reset/DUT/modelo SRAM)
2. axi4_agent (types, seq_item, driver, monitor) + smoke_test
3. sram_agent (monitor passivo) e ref_model + scoreboard
4. sequencias/testes: burst, narrow (T-S-SZ), ordering (T-S-ORD), arbitration (T-S-ARB)
5. perf (T-S-PERF), error, reset e random (T-S-ROB); cobertura (VP §4.1); temporizacao SRAM (R-12)

## Como rodar
- Xcelium: tb/uvm/sim/run_xrun.sh (TESTNAME, SEED, PHASE) - TODO
- EDA Playground: tb/uvm/sim/bundle_edaplayground.sh gera build/edaplayground/ (design.sv / testbench.sv) - TODO
- Includes somente por nome; caminhos via -incdir em sim/uvm_tb.f.
