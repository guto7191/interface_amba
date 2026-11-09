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
- Xcelium: `make test_uvm` ou tb/uvm/sim/run_xrun.sh (TESTNAME, SEED, PHASE). NAO TESTADO (sem xrun na maquina de desenvolvimento).
- EDA Playground: tb/uvm/sim/bundle_edaplayground.sh gera build/edaplayground/ (design.sv / testbench.sv) - TODO
- Includes somente por nome; caminhos via -incdir em sim/uvm_tb.f.

## Interfaces
- `axi4_if` (ID 4, ADDR 32, DATA 32, sem prefixo `s_axi_`): clocking `drv_cb` (`default input #1step output #1ns`; dirige aw*/w*/ar*/bready/rready) e `mon_cb` (tudo input). Modports `DRV` e `MON`.
- `aresetn` da `axi4_if` vem de `dut.aresetn_w` (reset ja sincronizado do `de2_115_top`); o `sram_if` so recebe `aclk`.
- `sram_if`: `mon_cb` por `aclk` e modport `MON`. A SRAM e assincrona; se o `sram_monitor` precisar, amostrar tambem em `@(posedge we_n)`.
- `config_db`: chaves `axi_vif` (`virtual axi4_if`) e `sram_vif` (`virtual sram_if`).
- `PHASE` e parametro do `tb_top` (padrao 2).
- O checker AXI e ligado por `bind` em `top/axi4_sram_bind.sv`; leitura de `u_chk.errors` fica para o scoreboard.
- Nada disto foi simulado ainda.
