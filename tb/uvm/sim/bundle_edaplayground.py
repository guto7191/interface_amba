#!/usr/bin/env python3
"""bundle_edaplayground.py - gera design.sv e testbench.sv achatados para o EDA Playground.

Uso (qualquer diretorio): python3 -I tb/uvm/sim/bundle_edaplayground.py [--phase 1|2] [--out DIR] [--check]

Somente le o repositorio; escreve apenas em --out (padrao: edaplayground/).
A ordem do RTL vem dos filelists (fonte unica; entra so a controladora da fase); a do UVM, do manifesto abaixo (espelha uvm_tb.f).
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HEADER = "// GERADO por tb/uvm/sim/bundle_edaplayground.py - NAO EDITAR\n"

COMMON_FILELIST = "rtl/filelists/axi4_sram_common.f"
# so a controladora da fase escolhida entra no bundle (limite de 100.000 caracteres por aba do playground)
PHASE_FILELISTS = {1: "rtl/filelists/axi4_sram_phase1.f", 2: "rtl/filelists/axi4_sram_phase2.f"}
FILE_CHAR_LIMIT = 100_000  # "design.sv code must be less than 100000 characters" (mensagem do playground)
# copias proprias do UVM (mesmas usadas em tb/uvm/sim/uvm_tb.f)
DESIGN_EXTRA = [
    "tb/uvm/models/sram_is61wv102416_behavioral_model.v",
    "tb/uvm/checkers/axi_protocol_checker.v",
]
AXI_DEFS = "rtl/include/axi_defs.vh"

TB_INTERFACES = ["tb/uvm/interfaces/axi4_if.sv", "tb/uvm/interfaces/sram_if.sv"]
# ordem de dependencia: cada pacote so importa os anteriores
TB_PACKAGES = [
    "tb/uvm/agents/sram_agent/sram_agent_pkg.sv",
    "tb/uvm/agents/axi4_agent/axi4_agent_pkg.sv",
    "tb/uvm/env/axi4_sram_env_pkg.sv",
    "tb/uvm/sequences/axi4_sram_seq_pkg.sv",
    "tb/uvm/tests/axi4_sram_test_pkg.sv",
]
TB_BIND = "tb/uvm/top/axi4_sram_bind.sv"
TB_TOP = "tb/uvm/top/tb_top.sv"

INCLUDE_RE = re.compile(r'^\s*`include\s+"([^"]+)"')
TIMESCALE_RE = re.compile(r'^\s*`timescale\b')


def die(msg):
    sys.exit(f"ERRO: {msg}")


def require(rel):
    p = ROOT / rel
    if not p.is_file():
        die(f"arquivo nao encontrado: {rel}")
    return p


def read_lines(rel):
    return require(rel).read_text(encoding="utf-8").splitlines()


def read_filelist(rel):
    """Retorna os caminhos de arquivos de um filelist (ignora comentarios; nao segue -f)."""
    out = []
    for line in read_lines(rel):
        s = line.split("//")[0].strip()
        if not s or s.startswith("-"):
            continue
        out.append(s)
    return out


def banner(rel):
    return [f"// ==== arquivo: {rel} ===="]


def strip_comments(text):
    """Remove // e /* */ respeitando strings; retira linhas ficadas em branco e espacos no fim."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                die("comentario /* sem fechamento")
            out.append(" " if "\n" not in text[i:j] else "\n" * text[i:j].count("\n"))
            i = j + 2
            continue
        else:
            out.append(c)
        i += 1
    lines = "".join(out).split("\n")
    return [l.rstrip() for l in lines if l.strip()]


def emit_rtl(rel):
    """RTL/modelo sem comentarios; remove timescale e include de axi_defs.vh (injetado uma vez no topo)."""
    out = []
    for line in strip_comments("\n".join(read_lines(rel))):
        m = INCLUDE_RE.match(line)
        if TIMESCALE_RE.match(line) or (m and m.group(1) == "axi_defs.vh"):
            continue
        out.append(line)
    return out


class Expander:
    """Expande `include "x.svh" por busca de nome em tb/uvm/ (equivale ao -incdir do uvm_tb.f)."""

    def __init__(self):
        self.index = {}
        for p in sorted((ROOT / "tb/uvm").rglob("*.svh")):
            if p.name in self.index:
                die(f"nome de .svh duplicado em tb/uvm: {p.name}")
            self.index[p.name] = p

    def expand(self, rel, stack=()):
        if rel in stack:
            die(f"include ciclico: {' -> '.join(stack + (rel,))}")
        out = []
        for line in read_lines(rel):
            m = INCLUDE_RE.match(line)
            if not m or m.group(1) == "uvm_macros.svh":
                if not TIMESCALE_RE.match(line):
                    out.append(line)
                continue
            name = m.group(1)
            if name not in self.index:
                die(f'`include "{name}" (em {rel}) nao resolvido em tb/uvm')
            sub = str(self.index[name].relative_to(ROOT))
            out.append(f"// ---- inicio {name} ----")
            out.extend(self.expand(sub, stack + (rel,)))
            out.append(f"// ---- fim {name} ----")
        return out


def build_design(phase):
    files = read_filelist(COMMON_FILELIST)
    files += read_filelist(PHASE_FILELISTS[phase])
    files = [f for f in files if f not in DESIGN_EXTRA] + DESIGN_EXTRA
    if len(set(files)) != len(files):
        die("arquivo repetido na lista do design")
    out = [HEADER.rstrip("\n"), "`timescale 1ns/1ps", ""]
    out.extend(strip_comments("\n".join(read_lines(AXI_DEFS))))
    for f in files:
        out.extend(emit_rtl(f))
    return out, files


def build_testbench(phase):
    exp = Expander()
    out = [HEADER.rstrip("\n"), "`timescale 1ns/1ps", "`include \"uvm_macros.svh\"", "import uvm_pkg::*;", ""]
    for f in TB_INTERFACES:
        out += banner(f) + [l for l in read_lines(f) if not TIMESCALE_RE.match(l)] + [""]
    for f in TB_PACKAGES:
        out += banner(f) + exp.expand(f) + [""]
    # bind: o modulo-casca vira segundo top no Xcelium; emite so o comando bind (escopo $unit)
    out += banner(TB_BIND)
    for l in read_lines(TB_BIND):
        if re.match(r"^\s*module\s+axi4_sram_bind\s*;", l) or re.match(r"^\s*endmodule\b", l):
            continue
        out.append(l)
    out.append("")
    out += banner(TB_TOP)
    for l in read_lines(TB_TOP):
        if TIMESCALE_RE.match(l):
            continue
        l = re.sub(r"(parameter\s+PHASE\s*=\s*)\d+", rf"\g<1>{phase}", l)
        out.append(l)
    return out + [""]


def validate(design, tb):
    errors = []
    for name, lines in (("design.sv", design), ("testbench.sv", tb)):
        for i, l in enumerate(lines, 1):
            m = INCLUDE_RE.match(l)
            if m and m.group(1) != "uvm_macros.svh":
                errors.append(f'{name}:{i}: `include "{m.group(1)}" sobrou')
    # duplicatas de module/interface/package
    decl = re.compile(r"^\s*(module|interface|package)\s+(?:automatic\s+)?(\w+)")
    seen = {}
    for name, lines in (("design.sv", design), ("testbench.sv", tb)):
        for i, l in enumerate(lines, 1):
            m = decl.match(l)
            if m:
                key = m.group(2)
                if key in seen:
                    errors.append(f"{name}:{i}: {m.group(1)} '{key}' duplicado (ja em {seen[key]})")
                seen[key] = f"{name}:{i}"
    # ordem dos packages: imports so de packages ja declarados
    declared = set()
    pkg_re = re.compile(r"^\s*package\s+(\w+)")
    imp_re = re.compile(r"^\s*import\s+(\w+)::")
    for i, l in enumerate(tb, 1):
        m = pkg_re.match(l)
        if m:
            declared.add(m.group(1))
        m = imp_re.match(l)
        if m and m.group(1) not in declared and m.group(1) != "uvm_pkg":
            errors.append(f"testbench.sv:{i}: import de '{m.group(1)}' antes da declaracao do package")
    if "axi4_sram_bind" in "\n".join(tb).replace("// ====", ""):
        for i, l in enumerate(tb, 1):
            if re.match(r"^\s*module\s+axi4_sram_bind", l):
                errors.append(f"testbench.sv:{i}: modulo axi4_sram_bind virou segundo top")
    return errors


README = """# EDA Playground - subordinado AXI4-SRAM (GERADO)

Gerado por `python3 -I tb/uvm/sim/bundle_edaplayground.py` (fase {phase}). Nao editar a mao.

## Como usar
1. Abra https://www.edaplayground.com.
2. Cole `testbench.sv` no painel da esquerda e `design.sv` no da direita.
3. Em "Tools & Simulators": **Cadence Xcelium** (ou outro com UVM + bind).
4. Em "Languages & Libraries": **UVM 1.2**.
5. Compile options: `-timescale 1ns/1ps -access +rwc`
6. Run options: `+UVM_TESTNAME=axi4_sram_smoke_test` (outros: burst, narrow, ordering, arbitration, perf, error, reset, random).
7. Top: `tb_top`.

## Notas
- Fase do DUT fixada em `tb_top` (parameter PHASE = {phase}); para a fase 1 gere com `--phase 1`.
- O modelo da SRAM inicializa 1M posicoes; a simulacao inicial pode demorar.
- design.sv sai sem comentarios e so com a controladora da fase (limite do playground: menos de 100000 caracteres por arquivo).
- O comando `bind` do checker foi extraido do modulo `axi4_sram_bind` para nao criar um segundo top.

## Script run.bash (opcional)
`scripts/run.bash` roda dentro do playground (marque "Use run.bash" e cole numa aba `run.bash`):
escolhe teste/seed/verbosidade, lista testes, so elabora (`MODE=check`) e imprime resumo PASS/FAIL.
Veja `scripts/README.md`. Limites: 60 s por run, 100 MB, 1.000.000 de caracteres no total.
"""


def write_out(out_dir, design, tb, phase):
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "design.sv").write_text("\n".join(design) + "\n", encoding="utf-8", newline="\n")
    (out_dir / "testbench.sv").write_text("\n".join(tb) + "\n", encoding="utf-8", newline="\n")
    (out_dir / "README.md").write_text(README.format(phase=phase), encoding="utf-8", newline="\n")


PLAYGROUND_CHAR_LIMIT = 1_000_000
PLAYGROUND_CHAR_WARN = 900_000


def check_size(out_dir):
    """Soma caracteres das abas coladas no playground (limite de 1.000.000)."""
    for name in ("design.sv", "testbench.sv"):
        n = len((out_dir / name).read_text(encoding="utf-8"))
        print(f"  {name}: {n} / {FILE_CHAR_LIMIT} caracteres")
        if n >= FILE_CHAR_LIMIT:
            die(f"{name} com {n} caracteres: o playground exige menos de {FILE_CHAR_LIMIT} por arquivo")
    tabs = [out_dir / "design.sv", out_dir / "testbench.sv", out_dir / "scripts" / "run.bash"]
    total = sum(len(t.read_text(encoding="utf-8")) for t in tabs if t.is_file())
    print(f"caracteres no playground: {total} / {PLAYGROUND_CHAR_LIMIT}")
    if total > PLAYGROUND_CHAR_LIMIT:
        die(f"total de {total} caracteres excede o limite do playground ({PLAYGROUND_CHAR_LIMIT})")
    if total > PLAYGROUND_CHAR_WARN:
        print(f"AVISO: total acima de {PLAYGROUND_CHAR_WARN} caracteres")


def run_checks(out_dir, phase):
    d, t = out_dir / "design.sv", out_dir / "testbench.sv"
    if shutil.which("iverilog"):
        r = subprocess.run(["iverilog", "-g2012", f"-Pde2_115_top.PHASE={phase}", "-o", "/dev/null", str(d)], capture_output=True, text=True)
        print("iverilog design.sv:", "OK" if r.returncode == 0 else "FALHOU\n" + r.stderr)
        if r.returncode:
            return 1
    else:
        print("iverilog ausente: design.sv nao verificado")
    if shutil.which("xrun"):
        r = subprocess.run(["xrun", "-uvm", "-sv", "-elaborate", "-timescale", "1ns/1ps",
                            str(d), str(t)], capture_output=True, text=True)
        print("xrun elaborate:", "OK" if r.returncode == 0 else "FALHOU\n" + r.stdout[-3000:])
        return r.returncode
    print("xrun ausente: UVM nao verificado localmente")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--phase", type=int, choices=(1, 2), default=2)
    ap.add_argument("--out", default="edaplayground")
    ap.add_argument("--check", action="store_true", help="roda iverilog/xrun se disponiveis")
    a = ap.parse_args()

    design, files = build_design(a.phase)
    tb = build_testbench(a.phase)
    errs = validate(design, tb)
    if errs:
        die("validacao falhou:\n  " + "\n  ".join(errs))

    out_dir = Path(a.out)
    out_dir = out_dir if out_dir.is_absolute() else ROOT / out_dir
    write_out(out_dir, design, tb, a.phase)
    print(f"fase {a.phase}: {len(files)} arquivos RTL/modelo em design.sv ({len(design)} linhas); "
          f"testbench.sv ({len(tb)} linhas)")
    for f in files:
        print("  design   <-", f)
    print(f"saida: {out_dir}")
    check_size(out_dir)
    if a.check:
        sys.exit(run_checks(out_dir, a.phase))


if __name__ == "__main__":
    main()
