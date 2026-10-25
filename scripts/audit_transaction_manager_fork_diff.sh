#!/bin/bash
# Auditoria de obra derivada (criterio de saida 13 do VP; MAS D10 e D14).
#
# Uso: audit_transaction_manager_fork_diff.sh <original> <fork> <prefixo-do-marcador>
#   ex.: ... asram16_axi4_pmem.v axi_transaction_manager.v A     (alteracoes A0..A9)
#        ... asram16_axi4.v      sram_controller_baseline.v B    (alteracoes B0..B9)
#
# Regras:
#   - toda linha ADICIONADA de codigo deve ter o marcador "// <prefixo><n>"; linhas em branco e
#     linhas so de comentario (cabecalho de obra derivada) sao aceitas;
#   - toda linha REMOVIDA deve estar num trecho do diff que tenha ao menos uma linha adicionada
#     com marcador (nao se remove codigo da IP sem registrar a alteracao).
set -u
orig="$1"; fork="$2"; pre="$3"

diff -U0 "$orig" "$fork" | awk -v pre="$pre" '
function flush_hunk() {
    if (del > 0 && marked == 0) {
        printf("AUDIT FAIL: %d linha(s) removida(s) sem marcador %s<n> (trecho %s)\n", del, pre, hunk);
        bad++;
    }
    del = 0; marked = 0;
}
/^(---|\+\+\+)/ { next }
/^@@/ { flush_hunk(); hunk = $0; next }
/^-/  { del++; next }
/^\+/ {
    line = substr($0, 2);
    if (line ~ /^[ \t]*$/)        next;          # linha em branco
    if (line ~ /^[ \t]*\/\//)     next;          # so comentario (cabecalho)
    if (line ~ ("//[ \t]*" pre "[0-9]")) { marked++; next }
    printf("AUDIT FAIL: linha adicionada sem marcador %s<n>: %s\n", pre, line);
    bad++;
}
END {
    flush_hunk();
    if (bad > 0) exit 1;
}'
rc=$?
if [ $rc -eq 0 ]; then
    echo "AUDIT PASS: $fork difere de $(basename "$orig") apenas nas alteracoes ${pre}0..${pre}9"
else
    echo "AUDIT FAIL: $fork"
fi
exit $rc
