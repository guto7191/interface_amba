#!/usr/bin/env bash
# bundle_edaplayground.sh - esqueleto: gera design.sv / testbench.sv achatados para o EDA Playground.
# TODO: implementar (executar da raiz do repo).
set -euo pipefail

OUT_DIR="build/edaplayground"
FILELISTS="rtl/filelists/axi4_sram_common.f rtl/filelists/axi4_sram_phase2.f"
UVM_DIR="tb/uvm"

# TODO: concatenar RTL (via filelists) + modelo SRAM + checker em $OUT_DIR/design.sv
# TODO: concatenar interfaces, pkgs, .svh (achatados), bind e tb_top em $OUT_DIR/testbench.sv
# TODO: garantir que os `include usem so nome de arquivo
