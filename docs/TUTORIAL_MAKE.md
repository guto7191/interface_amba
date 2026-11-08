# Tutorial: rodando os testbenches com `make`

## 1. Pré-requisitos

- **Icarus Verilog** (`iverilog` e `vvp`) — compila e simula (usado com `-g2012`).
- **make**
- *(opcional)* **GTKWave** — para visualizar formas de onda.

Verifique a instalação:

```bash
iverilog -V | head -1
vvp -V | head -1
make --version | head -1
```

No Ubuntu/Debian: `sudo apt install iverilog gtkwave make`.

## 2. Estrutura do projeto

```
interface_amba/
├── Makefile
├── rtl/
│   ├── include/        axi_defs.vh
│   ├── board/          topo da placa e reset_synchronizer
│   ├── axi4_sram/      subordinado AXI4 (derived/ = forks LGPL)
│   ├── sram/           controladora e buffer de I/O da SRAM (derived/ = forks LGPL)
│   ├── third_party/    IP original, intocada
│   ├── axi4_lite_ram/  caminho AXI4-Lite legado
│   └── filelists/      listas de compilacao (.f)
├── tb/
│   ├── axi4_lite_ram/  tb_ram, tb_write, tb_read, tb_top (regressao)
│   ├── common/         checker, tasks, scoreboard
│   ├── models/         modelo da SRAM e stubs
│   ├── unit/ integration/ system/ negative/
└── build/              binarios gerados (criado pelo make)
```

## 3. Rodando

Execute sempre a partir da raiz do projeto (onde está o `Makefile`).

| Comando          | O que faz                                                        |
|------------------|------------------------------------------------------------------|
| `make` / `make all` | Alias de `make test`                                          |
| `make test`      | Roda **todos** os testbenches (`test_ram` + `test_top`)          |
| `make test_ram`  | Testbench unitário da RAM (`tb/testbench_legado/axi4_lite_ram/tb_ram.v`)                   |
| `make test_top`  | Testbench do top AXI + protocol checker (`tb/testbench_legado/axi4_lite_ram/tb_top.v`)      |
| `make lint`      | Só compila o RTL (`-Wall`), sem simular — checa erros de sintaxe |
| `make clean`     | Remove a pasta `build/`                                          |

### Exemplo

```bash
make test
```

Saída esperada (resumida):

```
iverilog -g2012 -Wall -Irtl -o build/tb_ram rtl/ram.v tb/testbench_legado/axi4_lite_ram/tb_ram.v && vvp build/tb_ram
tb_ram: PASS
...
tb_top: PASS
```

O resultado de cada teste aparece como `PASS` ou `FAIL` na saída do `vvp`.
Os avisos `Some design elements have no explicit time unit` são inofensivos
(os módulos não têm `` `timescale``).

## 4. O que cada alvo executa

```make
test_ram:  iverilog -g2012 -Wall -Irtl -o build/tb_ram  rtl/ram.v tb/testbench_legado/axi4_lite_ram/tb_ram.v
           vvp build/tb_ram

test_top:  iverilog -g2012 -Wall -Irtl -o build/tb_top  $(RTL) \
                    tb/testbench_legado/common/axi_protocol_checker.v tb/testbench_legado/axi4_lite_ram/tb_top.v
           vvp build/tb_top
```

1. `iverilog` compila RTL + testbench em um executável em `build/`.
2. `vvp` executa a simulação até o `$finish` do testbench.

`-Irtl` permite que `` `include "axi_defs.vh"`` seja encontrado.

## 5. Adicionando um novo testbench

1. Crie o arquivo, por exemplo `tb/testbench_legado/unit/tb_novo.v`.
2. Adicione um alvo no `Makefile`:

   ```make
   test_novo: | $(BUILD)
   	$(IV) -o $(BUILD)/tb_novo $(RTL) tb/testbench_legado/unit/tb_novo.v && vvp $(BUILD)/tb_novo
   ```

   (a linha da receita precisa começar com **TAB**, não espaços)
3. Inclua o alvo em `.PHONY` e na linha `test: test_ram test_top test_novo`.

## 6. Visualizando formas de onda (GTKWave)

O `.PHONY` declara um alvo `wave`, mas ele **ainda não está implementado**, e
os testbenches atuais **não geram `.vcd`**. Para habilitar:

1. No testbench, dentro de um `initial`, adicione:

   ```verilog
   initial begin
       $dumpfile("build/tb_top.vcd");
       $dumpvars(0, tb_top);   // nome do módulo do testbench
   end
   ```

2. Adicione ao `Makefile`:

   ```make
   wave: test_top
   	gtkwave $(BUILD)/tb_top.vcd &
   ```

3. Rode `make wave`.

## 7. Problemas comuns

| Sintoma | Causa / solução |
|---------|-----------------|
| `make: *** No rule to make target` | Você não está na raiz do projeto. |
| `Makefile:N: *** missing separator` | A receita está com espaços em vez de TAB. |
| `iverilog: command not found` | Instale o Icarus Verilog. |
| `Unable to open include file axi_defs.vh` | Falta o `-Irtl` na compilação. |
| Teste não termina | Falta `$finish` ou há deadlock no handshake AXI; adicione um timeout no testbench. |
| Resultado desatualizado | Rode `make clean && make test`. |
