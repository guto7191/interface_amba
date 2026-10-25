#!/bin/bash
# Gera build/report.md a partir dos logs em build/*.log (VP §2.5):
#   ID | Resultado | Severidade | Log        e a tabela comparativa Fase 1 x Fase 2 (T-S-PERF-004).
# Sai com 1 se algum caso bloqueante falhou.
out=build/report.md
logs=$(ls build/*.log 2>/dev/null)
{
echo "# Relatorio de verificacao"
echo
echo "Gerado em $(date -u +%Y-%m-%dT%H:%MZ)."
echo
echo "## Casos de teste"
echo
echo "| ID | Resultado | Severidade | Log |"
echo "|---|---|---|---|"
for f in $logs; do
  grep -hE "^CASE " "$f" | sed -E 's/^CASE ([^ ]+) \[([^]]*)\]: (PASS|FAIL).*/\1|\3|\2/' | while IFS='|' read -r id res sev; do
    echo "| $id | $res | $sev | $(basename "$f") |"
  done
done | sort -u
echo
echo "## Sementes dos testes aleatorios"
echo
grep -h "INFO: T-S-ROB-005 SEED=" build/*.log 2>/dev/null | sed -E 's/^INFO: //' | sort -u | sed 's/^/- /'
echo
echo "## Desempenho (T-S-PERF-001..003) por fase"
echo
echo "| Medida | Fase 1 | Fase 2 |"
echo "|---|---|---|"
p1=build/tb_system_throughput_cycles_per_beat_p1.log
p2=build/tb_system_throughput_cycles_per_beat_p2.log
get() { grep -h "INFO: $2 " "$1" 2>/dev/null | sed -E "s/.*$3=([0-9]+).*/\1/" | head -1; }
x1=$(get $p1 T-S-PERF-001 CYCLES_PER_BEAT_X100); x2=$(get $p2 T-S-PERF-001 CYCLES_PER_BEAT_X100)
w1=$(get $p1 T-S-PERF-002 CYCLES_PER_BEAT_X100); w2=$(get $p2 T-S-PERF-002 CYCLES_PER_BEAT_X100)
m1=$(get $p1 T-S-PERF-003 MB_PER_S); m2=$(get $p2 T-S-PERF-003 MB_PER_S)
echo "| Leitura, ciclos/beat (x100) | $x1 | $x2 |"
echo "| Escrita, ciclos/beat (x100) | $w1 | $w2 |"
echo "| Vazao mista, MB/s | $m1 | $m2 |"
if [ -n "$x1" ] && [ -n "$x2" ] && [ "$x2" -lt "$x1" ] && [ "$w2" -lt "$w1" ]; then
  echo; echo "CASE T-S-PERF-004 [Inform]: PASS (Fase 2 mais rapida que a Fase 1 em leitura e escrita)"
else
  echo; echo "CASE T-S-PERF-004 [Inform]: FAIL (Fase 2 nao e mais rapida)"
fi
echo
echo "## Latencia de cauda (T-S-ARB-002)"
echo
grep -h "INFO: T-S-ARB-002" build/*.log 2>/dev/null | sed 's/^INFO: /- /' | sort -u
echo
echo "## Cobertura funcional"
echo
echo '```'
scripts/merge_functional_coverage_bins.sh
echo '```'
} > "$out"
cat "$out" | tail -n +1 | grep -E "T-S-PERF-004|COBERTURA" 
# falha se algum caso BLOQUEANTE falhou
if grep -E "^\| .* \| FAIL \| Bloq \|" "$out" > /dev/null; then
  echo "REPORT: ha casos bloqueantes em FAIL"; grep -E "\| FAIL \| Bloq \|" "$out"; exit 1
fi
echo "REPORT: $out gerado; nenhum caso bloqueante em FAIL"
