#!/usr/bin/env bash
# run_xrun.sh - esqueleto para rodar o UVM TB no Cadence Xcelium.
# TODO: implementar (executar da raiz do repo).
set -euo pipefail

TESTNAME="${TESTNAME:-axi4_sram_smoke_test}"
SEED="${SEED:-1}"
PHASE="${PHASE:-2}"
FILELIST="tb/uvm/sim/uvm_tb.f"

# TODO: xrun -uvm -f "$FILELIST" +UVM_TESTNAME="$TESTNAME" +UVM_VERBOSITY=UVM_MEDIUM -svseed "$SEED" -define PHASE="$PHASE" -access +rwc
