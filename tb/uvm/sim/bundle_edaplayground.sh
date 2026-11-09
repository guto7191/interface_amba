#!/usr/bin/env bash
# bundle_edaplayground.sh - wrapper: gera edaplayground/design.sv e testbench.sv (executar da raiz do repo).
# Repassa argumentos (ex.: --phase 1 --check) para bundle_edaplayground.py.
set -euo pipefail
exec python3 -I "$(dirname "$0")/bundle_edaplayground.py" "$@"
