# Scripts para o EDA Playground

## run.bash
Script opcional que roda **dentro** do playground (Cadence Xcelium, UVM 1.2) e substitui a edicao manual de Compile/Run Options.

### Como usar
1. Cole `design.sv` e `testbench.sv` (gerados por `make edaplayground`) nos paineis do playground.
2. Em "Tools & Simulators", escolha **Cadence Xcelium** (exige conta validada) e marque **Use run.bash**.
3. Clique em `+`, crie uma aba chamada `run.bash` e cole o conteudo de [run.bash](run.bash).
4. Edite as variaveis no topo da aba e clique em **Run**.

### Variaveis
| Variavel | Padrao | Funcao |
|---|---|---|
| `MODE` | `run` | `run` simula; `check` so compila/elabora; `list` lista os testes |
| `TESTNAME` | `axi4_sram_smoke_test` | teste UVM (`+UVM_TESTNAME`); veja `MODE=list` |
| `SEED` | `1` | semente (`-svseed`) |
| `VERBOSITY` | `UVM_MEDIUM` | `+UVM_VERBOSITY` |
| `DUMP` | `0` | `1` passa `+dump` (o `tb_top` grava `tb_top.vcd`) |
| `TIMEOUT_S` | `55` | tempo maximo; o playground limita a 60 s |

### Saida
No fim imprime `RESUMO` com contagem de `UVM_ERROR`/erros, `UVM_FATAL` e `UVM_WARNING` e a linha `RESULTADO: PASS|FAIL`. O codigo de saida e 0 em PASS, 1 em FAIL, 2 para erro de uso (arquivo ou teste inexistente). O log completo fica em `xrun_run.log`.

### Limites do playground
- 60 s de execucao e 100 MB de memoria por run.
- Cada aba deve ter menos de 100.000 caracteres (mensagem do playground: "design.sv code must be less than 100000 characters") e o playground, 1.000.000 no total. O gerador `bundle_edaplayground.py` falha se `design.sv` ou `testbench.sv` passar de 100.000 e mostra o total. Para isso o `design.sv` sai sem comentarios e so com a controladora da fase escolhida.
- A simulacao inicial pode demorar: o modelo da SRAM inicializa 1M posicoes.
- Todas as abas ficam num unico diretorio, com o nome da aba.

### Premissa nao verificada e fallback
A documentacao do playground so cita "Use run.bash" de passagem. O script assume o comando tipico
`xrun -uvm -sv -timescale 1ns/1ps -access +rwc -top tb_top design.sv testbench.sv ...` (variavel `XRUN_BASE`).
Se falhar: rode uma vez **sem** "Use run.bash", copie o comando gerado (topo do log) e ajuste `XRUN_BASE` e as chamadas em `run.bash`.
Sem o script, os campos Compile/Run Options continuam funcionando (ver `../README.md`).
