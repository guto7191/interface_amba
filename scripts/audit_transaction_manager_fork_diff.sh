#!/bin/bash
# Auditoria de obra derivada (criterio de saida 13 do VP; MAS D10 e D14).
#
# Uso: audit_transaction_manager_fork_diff.sh <original> <fork> <prefixo-do-marcador>
#   ex.: ... asram16_axi4_pmem.v axi_transaction_manager.v A     (alteracoes A0..A9)
#        ... asram16_axi4.v      sram_controller_baseline.v B    (alteracoes B0..B9)
#
# Regras:
#   1. toda linha ADICIONADA de codigo deve ter o marcador "// <prefixo><n>"; linhas em branco
#      e so de comentario (cabecalho de obra derivada) sao aceitas;
#   2. toda linha de codigo REMOVIDA da IP deve constar de scripts/fork_deletions_<prefixo>.txt,
#      a lista revisada das linhas que o fork substitui. Apagar qualquer outra linha reprova.
#      Remocao de comentario ou de linha em branco nao conta.
#
# AUDIT_UPDATE=1 regrava a lista de remocoes a partir do diff atual (para revisao no git diff).
set -u
orig="$1"; fork="$2"; pre="$3"
allow="$(dirname "$0")/fork_deletions_${pre}.txt"
tmp="$(mktemp)"; trap 'rm -f "$tmp" "$tmp.del"' EXIT
rc=0

diff -U0 "$orig" "$fork" > "$tmp"

# ---- regra 1: adicoes ----
awk -v pre="$pre" '
/^(---|\+\+\+|@@)/ { next }
/^\+/ {
    line = substr($0, 2);
    if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*\/\//) next;
    if (line ~ ("//[ \t]*" pre "[0-9]")) next;
    printf("AUDIT FAIL: linha adicionada sem marcador %s<n>: %s\n", pre, line);
    bad++
}
END { exit (bad > 0) }' "$tmp" || rc=1

# ---- regra 2: remocoes ----
grep -E '^-' "$tmp" | grep -vE '^---' | sed 's/^-//' \
  | grep -vE '^[[:space:]]*$' | grep -vE '^[[:space:]]*//' | sort > "$tmp.del"

if [ "${AUDIT_UPDATE:-0}" = "1" ]; then
    cp "$tmp.del" "$allow"
    echo "AUDIT: lista de remocoes regravada em $allow ($(wc -l < "$allow") linhas)"
fi

extra="$(comm -23 "$tmp.del" <(sort "$allow" 2>/dev/null))"
if [ -n "$extra" ]; then
    echo "AUDIT FAIL: linhas da IP removidas fora da lista $allow:"
    echo "$extra" | sed 's/^/    - /'
    rc=1
fi

if [ $rc -eq 0 ]; then
    echo "AUDIT PASS: $fork difere de $(basename "$orig") apenas nas alteracoes ${pre}0..${pre}9"
else
    echo "AUDIT FAIL: $fork"
fi
exit $rc
