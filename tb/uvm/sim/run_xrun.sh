#!/usr/bin/env bash
# run_xrun.sh - roda o UVM TB no Cadence Xcelium (executar da raiz do repo).
# NAO TESTADO: o xrun nao esta disponivel na maquina de desenvolvimento.
set -euo pipefail

TESTNAME="${TESTNAME:-axi4_sram_smoke_test}"
SEED="${SEED:-1}"
PHASE="${PHASE:-2}"
FILELIST="tb/uvm/sim/uvm_tb.f"

xrun -uvm -sv -f "$FILELIST" \
  +UVM_TESTNAME="$TESTNAME" +UVM_VERBOSITY=UVM_MEDIUM \
  -svseed "$SEED" -defparam tb_top.PHASE="$PHASE" \
  -timescale 1ns/1ps -access +rwc
