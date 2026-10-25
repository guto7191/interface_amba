#!/bin/bash
# Junta as linhas de cobertura funcional (build/cov/*.cov) e confere as metas do VP §4.1.
#
#   Eixos: len {0,1,3,15,63,255} x tipo {R,W} x wstrb {0000,0001,0011,0110,1100,1111}
#          x READY {always,1010,rand} x ID {single,two,sixteen} x zona {start,mid,end,out}
#          x size {0,1,2}                                         = 6*2*6*3*3*4*3 = 7776 celulas
#   Leitura nao tem wstrb: uma celula de leitura vale pelas 6 do eixo wstrb. Sem essa regra o
#   teto alcancavel seria 4536 (< 60% de 7776) e a meta seria impossivel.
#
#   Obrigatorias (100%): todo len x todo tipo (12); todo wstrb com len=3 (6); todo READY com
#   len=15 (3); todo size x len {0,3} x tipo (12).
#   Amostrada (meta 60%): celulas distintas do espaco de 7776.
# Saida: tabela em texto; codigo de saida 1 se alguma obrigatoria faltar.
dir="${1:-build/cov}"
files=$(ls "$dir"/*.cov 2>/dev/null)
if [ -z "$files" ]; then echo "COBERTURA: nenhum arquivo em $dir"; exit 1; fi

cat $files | sort -u | awk '
function kv(s, key,   n, a, i, p) { n = split(s, a, " "); for (i = 1; i <= n; i++) { split(a[i], p, "="); if (p[1] == key) return p[2] } return "" }
BEGIN {
    nl = split("0 1 3 15 63 255", LENS, " "); ns = split("0 1 2", SIZES, " ")
    nstrb = split("0000 0001 0011 0110 1100 1111", STRBS, " ")
    nr = split("always 1010 rand", RDYS, " ")
}
{
    len = kv($0, "len"); typ = kv($0, "type"); st = kv($0, "strb"); rdy = kv($0, "rdy")
    id = kv($0, "id"); zn = kv($0, "zone"); sz = kv($0, "size")
    valid_len = (len == 0 || len == 1 || len == 3 || len == 15 || len == 63 || len == 255)
    if (!valid_len || sz > 2 || zn == "" || rdy == "" || id == "") next
    if (typ == "W" && !(st == "0000" || st == "0001" || st == "0011" || st == "0110" || st == "1100" || st == "1111")) next
    cell[$0] = 1
    LT[len "|" typ] = 1
    if (typ == "W" && len == 3) ST3[st] = 1
    if (len == 15) RD15[rdy] = 1
    if (len == 0 || len == 3) SZLT[sz "|" len "|" typ] = 1
    if (typ == "W") { if (st != "") nw++ ; ncells_w++ } else ncells_r++
}
END {
    # obrigatorias
    a = 0; for (i = 1; i <= nl; i++) { if ((LENS[i] "|R") in LT) a++; if ((LENS[i] "|W") in LT) a++ }
    b = 0; for (i = 1; i <= nstrb; i++) if (STRBS[i] in ST3) b++
    c = 0; for (i = 1; i <= nr; i++) if (RDYS[i] in RD15) c++
    d = 0; for (i = 1; i <= ns; i++) { for (j = 0; j < 4; j = j + 3) { if ((SIZES[i] "|" j "|R") in SZLT) d++; if ((SIZES[i] "|" j "|W") in SZLT) d++ } }
    # celulas distintas: escrita conta 1; leitura conta 6 (eixo wstrb nao se aplica)
    w = 0; r = 0
    for (k in cell) { if (index(k, "type=W") > 0) w++; else r++ }
    total = w + 6 * r
    printf("COBERTURA FUNCIONAL (VP §4.1)\n")
    printf("  obrigatoria len x tipo           : %2d/12\n", a)
    printf("  obrigatoria wstrb com len=3      : %2d/6\n", b)
    printf("  obrigatoria READY com len=15     : %2d/3\n", c)
    printf("  obrigatoria size x len{0,3} x tipo: %2d/12\n", d)
    printf("  celulas distintas (escrita=%d, leitura=%d x6) = %d de 7776 = %.1f%% (meta: 60%% = 4666)\n", w, r, total, 100.0 * total / 7776)
    ok = (a == 12 && b == 6 && c == 3 && d == 12)
    if (ok) printf("COBERTURA: obrigatorias em 100%%\n"); else printf("COBERTURA: FALTAM combinacoes obrigatorias\n")
    if (total >= 4666) printf("COBERTURA: meta amostrada (60%%) atingida\n"); else printf("COBERTURA: meta amostrada (60%%) NAO atingida\n")
    exit (ok ? 0 : 1)
}'
