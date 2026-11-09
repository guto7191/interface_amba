#!/usr/bin/env bash
# run.bash - roda o UVM TB do subordinado AXI4-SRAM dentro do EDA Playground (Xcelium, UVM 1.2).
#
# USO: marque "Use run.bash" e cole este arquivo numa aba chamada run.bash.
#      Edite as variaveis abaixo e clique em Run. Detalhes: edaplayground/scripts/README.md
#
# PREMISSA NAO VERIFICADA: assume que as abas (design.sv, testbench.sv) estao no diretorio
# corrente e que o comando abaixo (xrun -uvm -sv ...) e valido no playground. Se falhar,
# rode uma vez SEM "Use run.bash", copie o comando gerado do topo do log e ajuste XRUN_BASE.

# ---- variaveis editaveis -------------------------------------------------------------
MODE=run                          # run | check (so elaborar) | list (listar testes)
TESTNAME=axi4_sram_smoke_test     # ver MODE=list
SEED=1
VERBOSITY=UVM_MEDIUM              # UVM_NONE|UVM_LOW|UVM_MEDIUM|UVM_HIGH|UVM_FULL
DUMP=0                            # 1 = passa +dump (tb_top grava tb_top.vcd)
TIMEOUT_S=55                      # o playground limita cada execucao a 60 s
# ---------------------------------------------------------------------------------------

set -uo pipefail
DESIGN=design.sv
TB=testbench.sv
LOG=xrun_run.log
XRUN_BASE="xrun -uvm -sv -timescale 1ns/1ps -access +rwc -top tb_top"

lista_testes() {
  grep -oE '^[[:space:]]*class +axi4_sram_[a-z_]+_test' "$TB" 2>/dev/null \
    | awk '{print $2}' | grep -v '_base_test$' | sort -u
}

if [ ! -f "$TB" ] || [ ! -f "$DESIGN" ]; then
  echo "ERRO: $DESIGN e/ou $TB nao encontrados em $(pwd). Arquivos presentes:"
  ls -1
  exit 2
fi

if [ "$MODE" = "list" ]; then
  echo "Testes disponiveis (use em TESTNAME / +UVM_TESTNAME):"
  lista_testes | sed 's/^/  /'
  echo "Variaveis: MODE=run|check|list TESTNAME SEED VERBOSITY DUMP TIMEOUT_S"
  exit 0
fi

if [ "$MODE" != "run" ] && [ "$MODE" != "check" ]; then
  echo "ERRO: MODE invalido '$MODE' (use run, check ou list)"
  exit 2
fi

if ! lista_testes | grep -qx "$TESTNAME"; then
  echo "ERRO: teste '$TESTNAME' nao existe em $TB. Disponiveis:"
  lista_testes | sed 's/^/  /'
  exit 2
fi

resumo() {
  local rc=$1 nerr nfat nwrn res
  nerr=$(grep -cE '^UVM_ERROR|(^|[^A-Za-z_])Error-\[|\*E,' "$LOG" 2>/dev/null)
  nfat=$(grep -cE '^UVM_FATAL' "$LOG" 2>/dev/null)
  nwrn=$(grep -cE '^UVM_WARNING' "$LOG" 2>/dev/null)
  res=PASS
  if [ "$rc" -ne 0 ] || [ "${nerr:-0}" -gt 0 ] || [ "${nfat:-0}" -gt 0 ]; then res=FAIL; fi
  echo
  echo "================ RESUMO ================"
  echo "modo=$MODE teste=$TESTNAME seed=$SEED verbosidade=$VERBOSITY"
  echo "UVM_ERROR/erros=${nerr:-0}  UVM_FATAL=${nfat:-0}  UVM_WARNING=${nwrn:-0}  codigo_saida=$rc"
  if [ "$rc" -eq 124 ]; then echo "TIMEOUT: passou de ${TIMEOUT_S}s (limite do playground: 60 s)"; fi
  echo "RESULTADO: $res"
  [ "$res" = PASS ]
}

if [ "$MODE" = "check" ]; then
  timeout "$TIMEOUT_S" $XRUN_BASE -elaborate "$DESIGN" "$TB" 2>&1 | tee "$LOG"
  resumo "${PIPESTATUS[0]}"
  exit $?
fi

EXTRA=""
[ "$DUMP" = "1" ] && EXTRA="+dump"
timeout "$TIMEOUT_S" $XRUN_BASE -svseed "$SEED" "$DESIGN" "$TB" \
  +UVM_TESTNAME="$TESTNAME" +UVM_VERBOSITY="$VERBOSITY" $EXTRA 2>&1 | tee "$LOG"
resumo "${PIPESTATUS[0]}"
exit $?
