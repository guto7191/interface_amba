# Plano de Verificação — Subordinado AXI4 com controladora de SRAM externa

**Documento companheiro de:** `MAS_axi4_sram.md`
**Alvo:** Terasic DE2-115, SRAM ISSI IS61WV102416BLL
**Ferramenta:** Icarus Verilog (`iverilog -g2012`), conforme `Makefile` e `docs/TUTORIAL_MAKE.md`

---

## §0 Front matter

### §0.1 Propósito e uso deste documento

Este plano é escrito para que **os testbenches possam ser construídos a partir dele sem que o implementador precise decidir nada por conta própria**. Cada caso de teste traz estímulo com valores concretos, resposta esperada, mecanismo de checagem nomeado e severidade.

Um caso que diga apenas "testar bursts" é considerado incompleto e não entra neste documento.

**Nenhum código de testbench está incluído aqui.** A construção dos testbenches é etapa posterior.

### §0.2 Histórico de revisões

| Versão | Data | Autor | Resumo |
|---|---|---|---|
| 0.1 | 2026-10-25 | August | Versão inicial. Define níveis U/I/S/F, o ambiente, 61 casos de teste e os critérios de saída |
| 0.2 | 2026-10-25 | August | Área `SZ`: 15 casos de `AxSIZE` e 1 negativo. Extensão E-10 ao checker. Novo eixo de cobertura (tamanho). Regressão de T-S-AXI/ORD/PERF passa a obrigatória |
| 0.3 | 2026-10-25 | August | Acompanha a MAS v0.3: escrita da Fase 2 em 4 ciclos/beat (T-U-CTL-003/004, T-S-PERF-002); E-06 com `size` e E-10 como subconjunto de lanes; `wstrb=0000` coberto (A7); critério 13 com A1–A7 e B1–B3; alvos de Makefile novos; V-01 e V-04 fechadas |

### §0.3 Convenção de identificação

```
T-<nível>-<área>-<nnn>
  │        │       └── número sequencial, estável e nunca reaproveitado
  │        └────────── área funcional
  └─────────────────── nível: U (unitário), I (integração), S (sistema), F (formal)
```

**Áreas:** `RST` (reset), `IOB` (buffer de I/O), `DEC` (decoder), `CTL` (controladora), `RAM` (contrato `ram_*`), `AXI` (conformidade de protocolo), `ORD` (ordenação por ID), `ARB` (arbitragem), `PERF` (desempenho), `SRAM` (temporização da memória), `ROB` (robustez), `REG` (regressão), **`SZ` (tamanho de transferência, `AxSIZE`)**.

Os identificadores são **estáveis**: um caso removido deixa seu número vago, para que relatórios de execução antigos continuem legíveis.

### §0.4 Matriz de rastreabilidade inversa

Requisito da MAS → casos que o cobrem. **Requisito normativo sem caso em PASS é bloqueio de síntese** (§5).

| Requisito (MAS §1.3) | Origem | Casos | Severidade |
|---|---|---|---|
| R-01 handshake VALID/READY | Norma | T-S-AXI-001..004 | Bloqueante |
| R-02 burst INCR | Norma | T-S-AXI-005..009 | Bloqueante |
| R-03 ordenação por ID | Norma | T-S-ORD-001..003 | Bloqueante |
| R-04 `RLAST` | Norma | T-S-AXI-010, 011 | Bloqueante |
| R-05 `BVALID` após `WLAST` | Norma | T-S-AXI-012 | Bloqueante |
| R-06 fronteira de 4 KB | Norma | T-S-4KB-001 | Bloqueante |
| R-07 2 MB endereçáveis | Placa | T-U-DEC-001..003 | Bloqueante |
| R-08 `SRAM_DQ` bidirecional | Placa | T-U-IOB-001..004 | Bloqueante |
| R-09 20 bits de endereço | Placa | T-U-DEC-004 | Bloqueante |
| R-10 clock de 50 MHz | Placa | Síntese (TimeQuest), não simulação | Bloqueante |
| R-11 I/O em 3,3 V | Placa | Síntese (`.qsf`), não simulação | Bloqueante |
| R-12 temporização da SRAM | Folha de dados | T-S-SRAM-001..005 | Bloqueante |
| R-13 4 transações em voo | IP | T-I-RAM-004 | Informativo |
| R-14 FIXED/WRAP como INCR | IP | T-S-AXI-013 | Informativo |
| R-15 DECERR fora de faixa | Decisão | T-U-DEC-005..008 | Ajustável |
| R-16 sem inanição | Decisão (D5) | T-S-ARB-001..003 | Ajustável |
| R-17 4 a 6 ciclos por beat | Decisão (D3) | T-S-PERF-001..003 | Ajustável |
| R-18 sem CDC | Decisão (D2) | Síntese, não simulação | Bloqueante |
| **R-19 `AxSIZE` de 1, 2 e 4 bytes com incremento por `2^AxSIZE`** | Norma (§A3.4.1) | T-U-SZ-001..004, T-S-SZ-002, T-S-SZ-007 | Bloqueante |
| **R-20 rotação de byte lanes em burst estreito** | Norma (§A3.4.3) | T-U-SZ-005..008, T-S-SZ-001, T-S-SZ-006 | Bloqueante |
| **R-21 `AxSIZE` > 4 bytes rejeitado com SLVERR** | Decisão (D11) | T-S-SZ-005 | Ajustável |

### §0.5 Escala de severidade

| Severidade | Significado | Ação na falha |
|---|---|---|
| **Bloqueante** | Viola a norma AXI4, uma característica da placa ou a folha de dados | Corrigir o RTL. Não se sintetiza com falha pendente |
| **Ajustável** | Descumpre uma decisão de projeto | Corrigir o RTL **ou** revisar a decisão na MAS §0.2, com justificativa |
| **Informativo** | Documenta comportamento conhecido da IP | Registrar. Não bloqueia |

> Esta distinção existe para impedir que uma escolha de microarquitetura — a política de arbitragem, por exemplo — seja tratada como se fosse violação de protocolo.

---

## §1 Estratégia e níveis

| Nível | Prova | **Não** prova | Pré-requisito para avançar |
|---|---|---|---|
| **U — Unitário** | Lógica interna de cada módulo novo, isolado, com estímulo dirigido nas portas | Integração; conformidade de protocolo ponta a ponta | — |
| **I — Integração** | O wrapper com a IP, contra o contrato `ram_*` da MAS §3.2 | Comportamento com temporização real da SRAM | Nível U sem falha pendente |
| **S — Sistema** | Transações AXI4 completas contra o modelo da SRAM, com checker ativo | Timing pós-síntese; comportamento na placa | Nível I sem falha pendente |
| **F — Formal** (opcional) | Propriedades do contrato `ram_*` e ausência de deadlock | — | Nível S sem falha pendente |

**Regra de progressão:** não se avança de nível com falha pendente no anterior. Cada nível declara o que deixa para o seguinte, de modo que nenhuma lacuna fique implícita.

**O que nenhum nível prova:** comportamento na placa física. A validação final exige carga no FPGA, medição com analisador lógico ou teste de memória em execução, e está fora deste plano.

---

## §2 Ambiente de verificação

Mantém a convenção já existente no repositório: **cada teste imprime `RESULT: PASS` ou `RESULT: FAIL`**, pois a receita do `Makefile` depende de `grep -q "RESULT: PASS"`.

### §2.1 Modelo comportamental da SRAM

**Arquivo previsto:** `tb/models/sram_model.v`

É a referência de toda a verificação de sistema e precisa ser fiel à folha de dados ISSI Rev. G, grau -10.

**§2.1.1 Interface**

Espelha os pinos da MAS §3.3: `addr[19:0]`, `dq[15:0]` (inout), `ce_n`, `oe_n`, `we_n`, `lb_n`, `ub_n`. Parâmetros de temporização configuráveis, com os valores do grau -10 como padrão.

**§2.1.2 Armazenamento**

Memória **associativa esparsa** (`reg [15:0] mem [*]` em SystemVerilog, ou array de 2^20 se a ferramenta não suportar), para não alocar 1M de posições quando o teste usa poucas.

**Inicialização com padrão detectável:** toda posição nunca escrita retorna `16'hDEAD`. Isso distingue "posição não inicializada" de "zero legítimo" — distinção que um modelo inicializado em zero perde, mascarando bugs de endereçamento.

**§2.1.3 Comportamento de leitura (assíncrono)**

Não há clock. A leitura reage a mudanças:

```
sensível a: addr, ce_n, oe_n, lb_n, ub_n
quando (ce_n == 0 && oe_n == 0 && we_n == 1):
    após tAA (10 ns) a partir da última mudança de addr:
        dq[7:0]  <= lb_n ? 8'bz : mem[addr][7:0]
        dq[15:8] <= ub_n ? 8'bz : mem[addr][15:8]
caso contrário:
    dq <= 16'bz   (respeitando tHZOE = 4 ns)
```

**Regra de tri-state:** o modelo dirige `dq` **apenas** quando `ce_n == 0`, `oe_n == 0` e `we_n == 1`. Em qualquer outra combinação, alta impedância. Isso faz com que contenção de barramento — FPGA e SRAM dirigindo ao mesmo tempo — apareça como `X` na simulação e seja detectada, em vez de passar silenciosamente.

**§2.1.4 Comportamento de escrita**

A escrita é capturada na **borda de subida de `we_n`** (fim do pulso), conforme a nota 3 da folha de dados: "o tempo interno de escrita é definido pela sobreposição de CE baixo, UB ou LB, e WE baixo".

```
na borda de subida de we_n, se (ce_n == 0):
    se (lb_n == 0) mem[addr][7:0]  <= dq[7:0]
    se (ub_n == 0) mem[addr][15:8] <= dq[15:8]
    se (lb_n == 1 && ub_n == 1): nenhuma escrita (caso válido, não erro)
```

**§2.1.5 Assertivas de violação de temporização**

O modelo é também um verificador. Cada violação imprime mensagem e incrementa um contador de erros, exposto como porta de saída para o testbench agregar.

| Assertiva | Condição de erro | Parâmetro |
|---|---|---|
| A-SRAM-01 | Pulso de `we_n` mais curto que tPWE1 | 8 ns |
| A-SRAM-02 | Ciclo de escrita mais curto que tWC | 10 ns |
| A-SRAM-03 | Dado instável na janela de tSD antes da subida de `we_n` | 6 ns |
| A-SRAM-04 | Endereço muda durante pulso de `we_n` ativo | — |
| A-SRAM-05 | Leitura amostrada antes de tAA decorrido desde a mudança de endereço | 10 ns |
| A-SRAM-06 | Contenção: `dq` dirigido externamente enquanto o modelo dirige | — |
| A-SRAM-07 | Endereço com `X` em qualquer acesso | — |
| A-SRAM-08 | `ce_n` ativo com `oe_n` e `we_n` ambos ativos (combinação inválida) | — |

### §2.2 Extensões ao `axi_protocol_checker`

O checker atual (`tb/common/axi_protocol_checker.v`) **já cobre** e deve ser preservado:

- VALID não retirado antes de READY, nos cinco canais;
- payload estável enquanto VALID pendente (`AWADDR`, `WDATA`, `WSTRB`, `ARADDR`, `BRESP`, `RDATA`, `RRESP`);
- causalidade: `BVALID` só após AW e W aceitos; `RVALID` só após AR aceito;
- `X` em sinais de controle e em payload válido;
- timeout de READY, como detector de deadlock;
- `VALID` baixo durante reset.

**A acrescentar para AXI4 completo:**

| Extensão | Verificação | Requisito |
|---|---|---|
| **E-01 Rastreamento por ID** | Fila por `arid`/`awid`. Respostas de um mesmo ID devem sair na ordem de entrada. IDs distintos podem se intercalar livremente | R-03 |
| **E-02 Contagem de beats de leitura** | Para cada AR aceito com `arlen = N`, devem chegar exatamente `N+1` beats de R com o `rid` correspondente | R-02 |
| **E-03 `RLAST` exclusivo** | `rlast` alto no beat `N+1` e **somente** nele. `rlast` precoce ou ausente é erro | R-04 |
| **E-04 Contagem de beats de escrita** | Para cada AW com `awlen = N`, devem chegar `N+1` beats de W, com `wlast` apenas no último | R-02 |
| **E-05 `BVALID` após `WLAST`** | Nenhum `bvalid` do ID antes de o `wlast` daquele burst ser aceito | R-05 |
| **E-06 Fronteira de 4 KB** | Calcular `addr_início` e `addr_fim = alinhado(addr) + ((len+1) << size) - 1`; acusar se `addr_início[31:12] != addr_fim[31:12]` | R-06 |
| **E-07 Resposta única de escrita** | Exatamente uma resposta B por burst de escrita, nunca uma por beat | R-05 |
| **E-08 Timeout de resposta** | Burst aceito sem resposta completa em N ciclos (padrão 2000) é deadlock. Distinto do timeout de READY já existente | — |
| **E-09 `RRESP` consistente no burst** | Num burst de erro, todos os beats devem ter o mesmo `rresp` | R-15 |
| **E-10 Coerência `AxSIZE` × `WSTRB`** (v0.2) | As lanes ativas de `wstrb` são **subconjunto** das lanes permitidas, de `Lower_Byte_Lane = addr[1:0]` até `Upper_Byte_Lane` (`wstrb & ~lanes_permitidas == 0`). A leitura "exatamente" reprovaria `wstrb` parcial legítimo (T-S-AXI-014, padrão `0000`). Detecta **mestre mal configurado**, que de outro modo produziria falha silenciosa: um `awsize=0` com `wstrb=4'b1111` escreveria 4 bytes onde o mestre declarou 1 | R-19, R-20 |

**Nota de compatibilidade:** o checker atual acusa `EXOKAY` como erro (linhas 72-73), com a mensagem "EXOKAY em AXI4-Lite". Como este projeto não implementa acesso exclusivo, **a regra permanece válida** em AXI4. A mensagem deve ser atualizada para "EXOKAY sem suporte a acesso exclusivo", mas a verificação é mantida de propósito, não por omissão.

### §2.3 Extensões ao `axi_master_tasks.vh`

As tasks atuais são AXI4-Lite de transação única. As novas mantêm o estilo existente: amostragem no `posedge`, drive com `<=`, composição com `fork`/`join`.

| Task | Assinatura | Comportamento |
|---|---|---|
| `aw_send_burst` | `(addr, id, len, burst, size, dly)` | Emite AW com todos os campos; espera `awready` |
| `ar_send_burst` | `(addr, id, len, burst, size, dly)` | Espelha `aw_send_burst` |
| `w_send_burst` | `(data_array, strb_array, len, dly_pattern)` | Emite `len+1` beats; `wlast` no último; atraso por beat conforme `dly_pattern`, para exercitar `wready` intermitente |
| `r_recv_burst` | `(exp_len, exp_id, dly_pattern)` | Coleta beats; confere `rid` e `rlast`; devolve os dados em array para comparação |
| `b_recv_id` | `(exp_id, dly)` | Espera B; confere `bid` e devolve `bresp` |
| `axi_write_burst` | `(addr, id, len, data_array, strb_array, delays)` | Compõe AW, W e B com `fork`/`join` |
| `axi_read_burst` | `(addr, id, len, out_array, delays)` | Compõe AR e R |

**Gerador de atraso pseudoaleatório:** semente **fixa e registrada no log de cada execução**, para que toda falha seja reproduzível. Um teste que falha com semente desconhecida é um teste que não se pode depurar.

> **Nota da v0.2:** as assinaturas de `aw_send_burst` e `ar_send_burst` **já incluem** o parâmetro `size`, logo nenhuma mudança de interface é necessária. O que muda é que o parâmetro passa a ser **efetivamente exercitado** com valores diferentes de `0b010`, e não apenas transmitido. Os testes da área `SZ` são os primeiros a variá-lo.

### §2.4 Scoreboard

**Arquivo previsto:** `tb/common/scoreboard.vh`

Modelo de referência da memória, mantido pelo testbench de forma independente do modelo da SRAM, de modo que um erro de endereçamento na controladora apareça como divergência.

**Regras:**

1. Toda escrita aceita atualiza o modelo **byte a byte**, conforme `wstrb`. Byte com strobe em 0 **não** é alterado — é o ponto em que uma implementação errada de `LB_N`/`UB_N` se revela.
2. Toda leitura é comparada contra o modelo. Divergência imprime endereço esperado, valor esperado, valor recebido e o beat do burst.
3. Leitura de posição nunca escrita é comparada contra `32'hDEADDEAD` (duas palavras de `16'hDEAD`, conforme §2.1.2).
4. O scoreboard é a autoridade sobre **dados**; o checker é a autoridade sobre **protocolo**. Os dois são independentes e ambos devem estar ativos nos testes de sistema.
5. **Comparação por lane válida (v0.2).** Numa leitura, a comparação considera **apenas as lanes válidas** do beat, determinadas por `size` e `addr[1:0]` conforme a tabela da MAS §5.6. As demais seguem D12 (dado replicado) e **ficam fora da comparação**, pois a norma não lhes atribui valor. Sem esta regra, todo teste estreito falharia por comparar lanes irrelevantes — e a falha pareceria um bug do RTL quando seria do testbench.

### §2.5 Infraestrutura de execução

**Alvos de Makefile previstos:**

Os arquivos RTL são listados em `rtl/filelists/*.f` (MAS §0.4 regra 9); o Makefile não cita arquivos RTL.

```
test_unit      → todos os T-U-*
test_integ     → todos os T-I-*
test_system    → todos os T-S-*
test_regress   → T-S-REG-* (regressão do AXI4-Lite existente)
test_neg       → todos os T-N-* (PASS quando a assertiva dispara)
audit_fork     → critério de saída 13
coverage       → cobertura de transições e funcional (§4)
report         → build/report.md
test_all       → tudo, na ordem U → I → S
```

Cada caso gera log próprio em `build/<id>.log`. O critério de falha da receita é o mesmo já praticado: ausência de `RESULT: PASS`.

**Relatório de execução:** tabela com `ID | Resultado | Semente | Ciclos | Observação`, para que a evolução entre revisões seja comparável.

---

## §3 Casos de teste

### §3.1 Unitário — `reset_synchronizer` (MAS §5.1)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-U-RST-001 | Assert assíncrono funciona sem clock | Clock parado; `KEY[0]` → 0 | `aresetn` → 0 sem esperar borda de clock | Observação direta | Bloq. |
| T-U-RST-002 | Deassert é síncrono e atrasado em 2 ciclos | Clock ativo; `KEY[0]` → 1 entre bordas | `aresetn` → 1 exatamente 2 bordas depois | Contagem de ciclos | Bloq. |
| T-U-RST-003 | Pulso mais curto que um ciclo é capturado | `KEY[0]` → 0 por 5 ns (período 20 ns), fora da borda | `aresetn` → 0; reset não é perdido | Observação direta | Bloq. |
| T-U-RST-004 | Reset durante operação | Com FSM ativa, afirmar reset | Todos os registradores observáveis voltam ao valor inicial | Comparação de estado | Bloq. |
| T-U-RST-005 | Conversão de polaridade | Variar `aresetn` | `rst_i` = `~aresetn`, sem glitch | Observação direta | Bloq. |

### §3.2 Unitário — `sram_io_buffer` (MAS §5.2)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-U-IOB-001 | Alta impedância em leitura | `data_out_enable` = 0 | `SRAM_DQ` = `16'bz`; `data_in` reflete o que o estímulo externo impõe | Verificação de `=== 16'bz` | Bloq. |
| T-U-IOB-002 | Dirige em escrita | `data_out_enable` = 1, `data_out_q` = `16'hA5A5` | `SRAM_DQ` = `16'hA5A5` | Comparação | Bloq. |
| T-U-IOB-003 | Alta impedância em idle | Sem acesso ativo | `SRAM_DQ` = `16'bz` | Verificação de `=== 16'bz` | Bloq. |
| T-U-IOB-004 | **Sem contenção no turnaround** | Sequência leitura → escrita com o modelo da SRAM dirigindo | Em nenhum ciclo os dois lados dirigem. Pelo menos 1 ciclo de folga entre `oe_n` subir e `data_out_enable` subir | Assertiva A-SRAM-06; detecção de `X` em `SRAM_DQ` | Bloq. |
| T-U-IOB-005 | **Mapeamento LB/UB (pendência P-01)** | Escrita com `wstrb = 4'b0001`, dado `32'h000000FF` | Somente `mem[addr][7:0]` alterado; `[15:8]` preservado | Scoreboard byte a byte | Bloq. |
| T-U-IOB-006 | Mapeamento LB/UB, byte alto | Escrita com `wstrb = 4'b0010`, dado `32'h0000FF00` | Somente `mem[addr][15:8]` alterado | Scoreboard byte a byte | Bloq. |

> T-U-IOB-005 e 006 são os casos que **fecham a pendência P-01** da MAS. Se a ordem de `LB_N`/`UB_N` estiver trocada, o byte errado é escrito e o scoreboard acusa.

### §3.3 Unitário — `axi_address_decoder` (MAS §4.3, §5.3)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-U-DEC-001 | Primeiro endereço válido | Leitura em `0x0000_0000`, `len=0` | Encaminha à IP; `rresp` = OKAY | Observação de `passthrough` | Bloq. |
| T-U-DEC-002 | **Último endereço válido (fronteira exata)** | Leitura em `0x001F_FFFC`, `len=0` | Encaminha à IP; `rresp` = OKAY | Observação | Bloq. |
| T-U-DEC-003 | **Primeiro endereço inválido (fronteira exata)** | Leitura em `0x0020_0000`, `len=0` | **Não** encaminha; `rresp` = DECERR (`2'b11`) | Observação; verifica que a SRAM não é acessada | Bloq. |
| T-U-DEC-004 | Endereço muito acima da faixa | Leitura em `0xFFFF_FFFC` | DECERR; sem acesso à SRAM | Observação | Bloq. |
| T-U-DEC-005 | **Drenagem de burst de leitura em erro** | Leitura em `0x0040_0000`, `len=15` | Exatamente 16 beats de R, **todos** com DECERR, `rlast` só no 16º | E-02, E-03, E-09 | Ajust. |
| T-U-DEC-006 | **Drenagem de burst de escrita em erro** | Escrita em `0x0040_0000`, `len=15`, 16 beats de W | Todos os 16 beats de W consumidos; **uma** resposta B com DECERR | E-04, E-07 | Ajust. |
| T-U-DEC-007 | **Burst que começa válido e termina fora** | Leitura em `0x001F_FFF0`, `len=15` (termina em `0x0020_002C`) | Burst inteiro rejeitado com DECERR, conforme critério da MAS §4.3 | E-09 | Ajust. |
| T-U-DEC-008 | Canal não trava após erro | Burst em erro seguido de burst válido | O burst válido é atendido normalmente | E-08 (sem timeout) | Bloq. |

### §3.4 Unitário — `sram_controller` (Fase 2, MAS §5.5)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-U-CTL-001 | Leitura isolada | Uma requisição `ram_rd`, endereço `0x100` | `ram_ack` em 3 ciclos; `ram_read_data` = duas palavras montadas | Contagem de ciclos; scoreboard | Bloq. |
| T-U-CTL-002 | **Leitura em regime: 2 ciclos por beat** | 8 requisições `ram_rd` consecutivas, `ram_accept` sempre aceito | A partir da 2ª, um `ram_ack` a cada 2 ciclos | Contagem de ciclos entre acks | Ajust. |
| T-U-CTL-003 | Escrita isolada | Uma requisição `ram_wr = 4'b1111` | `ram_ack` em 5 ciclos; ambas as palavras escritas | Scoreboard | Bloq. |
| T-U-CTL-004 | **Escrita em regime: 4 ciclos por beat** | 8 escritas consecutivas | Um `ram_ack` a cada 4 ciclos | Contagem | Ajust. |
| T-U-CTL-005 | Escrita só da metade baixa | `ram_wr = 4'b0011` | Apenas a palavra baixa é acessada; metade alta intocada | Scoreboard; contagem de pulsos de `we_n` | Bloq. |
| T-U-CTL-006 | Escrita só da metade alta | `ram_wr = 4'b1100` | Apenas a palavra alta acessada | Scoreboard | Bloq. |
| T-U-CTL-007 | Escrita com strobe nulo | `ram_wr = 4'b0000` com `ram_rd = 0` | Nenhum acesso à SRAM; `ram_ack` imediato | Assertiva: `we_n` nunca ativa | Bloq. |
| T-U-CTL-008 | Escrita de um byte só | `ram_wr = 4'b0001` | Só `LB_N` ativo na palavra baixa | Scoreboard; observação de `lb_n`/`ub_n` | Bloq. |
| T-U-CTL-009 | **Turnaround leitura → escrita** | Leitura seguida imediatamente de escrita | Pelo menos 1 ciclo entre `oe_n` subir e `data_out_enable` subir; sem `X` em `dq` | A-SRAM-06 | Bloq. |
| T-U-CTL-010 | Turnaround escrita → leitura | Escrita seguida de leitura | Sem contenção; dado lido correto | A-SRAM-06; scoreboard | Bloq. |
| T-U-CTL-011 | `ram_accept` negado | Controladora ocupada; nova requisição | `ram_accept` = 0 enquanto ocupada; requisição preservada e atendida depois | Contrato §3.2 regra 2 | Bloq. |
| T-U-CTL-012 | Cobertura de transições | Estímulo que force todos os arcos da FSM | Toda transição da tabela da MAS §5.5.2 exercitada | Cobertura de transições (§4.2) | Bloq. |
| T-U-CTL-013 | Reset no meio do acesso | Reset durante `WR_LOW` com `we_n` ativo | `we_n`, `oe_n` e `data_out_enable` vão a inativo; SRAM não corrompida | Scoreboard; A-SRAM-01 | Bloq. |

### §3.5 Integração — contrato `ram_*` (MAS §3.2)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-I-RAM-001 | Handshake básico | Requisições isoladas de leitura e escrita via IP | Toda requisição aceita recebe exatamente um `ram_ack` | Contagem: acks = requisições aceitas | Bloq. |
| T-I-RAM-002 | **`ram_accept` negado por vários ciclos** | Controladora nega `ram_accept` por 10 ciclos | Frontend mantém `ram_addr`, `ram_wr`, `ram_rd` e `ram_write_data` estáveis | Contrato regra 2; assertiva de estabilidade | Bloq. |
| T-I-RAM-003 | **Ordem das respostas** | 8 requisições com endereços distintos e identificáveis | `ram_ack` retorna os dados na ordem exata de emissão | Scoreboard com fila esperada | Bloq. |
| T-I-RAM-004 | **Profundidade de 4 transações (R-13)** | Emitir bursts sem aceitar respostas | `arready`/`awready` baixam ao atingir 4 em voo; sem perda de requisição | Contagem de requisições em voo | Inform. |
| T-I-RAM-005 | Exclusividade leitura/escrita | Carga simultânea nos dois canais | `ram_wr != 0` e `ram_rd = 1` nunca no mesmo ciclo | Contrato regra 3; assertiva | Bloq. |
| T-I-RAM-006 | Sem negação indefinida | Carga contínua | Toda requisição é aceita em no máximo N ciclos (N = 50) | Contrato regra 7; timeout | Bloq. |
| T-I-RAM-007 | Troca de fase (Fase 1 ↔ Fase 2) | Rodar o mesmo conjunto com cada implementação | Resultados funcionais **idênticos**; só os ciclos diferem | Comparação de scoreboard | Bloq. |

> T-I-RAM-007 é o teste que **valida o contrato como contrato**: se as duas implementações divergirem funcionalmente, o contrato da MAS §3.2 está incompleto.

### §3.6 Sistema — conformidade AXI4

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-AXI-001 | Handshake AW/W/B | Escrita simples, `len=0`, sem atrasos | Transação completa; `bresp` = OKAY | Checker completo | Bloq. |
| T-S-AXI-002 | Handshake AR/R | Leitura simples, `len=0` | `rresp` = OKAY; `rlast` = 1 | Checker | Bloq. |
| T-S-AXI-003 | **`READY` intermitente do mestre** | `rready`/`bready` oscilando com padrão `1010` | Nenhum dado perdido; sem violação de estabilidade | Checker E-01..E-09; scoreboard | Bloq. |
| T-S-AXI-004 | W antes de AW | `wvalid` antes de `awvalid` | Transação completa (canais independentes) | Checker | Bloq. |
| T-S-AXI-005 | Burst de 2 beats | Escrita e leitura com `len=1` | Dados corretos; `rlast` no 2º beat | E-02, E-03; scoreboard | Bloq. |
| T-S-AXI-006 | Burst de 4 beats | `len=3` | 4 beats; dados corretos | E-02, E-03 | Bloq. |
| T-S-AXI-007 | Burst de 16 beats | `len=15` | 16 beats | E-02, E-03 | Bloq. |
| T-S-AXI-008 | **Burst máximo de 256 beats** | `len=255`, endereço alinhado que não cruze 4 KB | 256 beats; `rlast` no 256º | E-02, E-03, E-06 | Bloq. |
| T-S-AXI-009 | Bursts consecutivos | 10 bursts de `len=7` em sequência | Todos completos, sem interferência entre eles | Checker; scoreboard | Bloq. |
| T-S-AXI-010 | `RLAST` em burst de 1 beat | `len=0` | `rlast` = 1 no único beat | E-03 | Bloq. |
| T-S-AXI-011 | `RLAST` não precoce | `len=7` | `rlast` = 0 nos beats 1 a 7, = 1 no 8º | E-03 | Bloq. |
| T-S-AXI-012 | `BVALID` após `WLAST` | Escrita `len=7` com atraso no último beat de W | `bvalid` só após o `wlast` ser aceito | E-05, E-07 | Bloq. |
| T-S-AXI-013 | **FIXED e WRAP tratados como INCR (R-14)** | `awburst = 2'b00` e `2'b10` | Comportamento idêntico a INCR; documentado, não corrigido | Scoreboard com expectativa de INCR | Inform. |
| T-S-AXI-014 | `wstrb` parcial em burst | `len=3`, strobes variando por beat | Só os bytes com strobe alterados | Scoreboard byte a byte | Bloq. |
| T-S-AXI-015 | Leitura e escrita no mesmo endereço | Escrita seguida de leitura em `0x1000` | Leitura retorna o valor escrito | Scoreboard | Bloq. |
| T-S-4KB-001 | **Detecção de cruzamento de 4 KB** | `arlen=255` em `0x0000_0F00` (cruza a fronteira) | O **checker acusa** a violação (responsabilidade do mestre, MAS §4.4) | E-06 | Bloq. |

### §3.7 Sistema — ordenação por ID (R-03, normativo)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-ORD-001 | **Mesmo ID, ordem preservada** | 4 leituras com `arid = 4'h3`, endereços distintos | Respostas na ordem exata de emissão | E-01; scoreboard com fila | Bloq. |
| T-S-ORD-002 | IDs distintos podem intercalar | Leituras alternando `arid` entre `4'h1` e `4'h2` | Qualquer intercalação é válida; mas, dentro de cada ID, a ordem é mantida | E-01 | Bloq. |
| T-S-ORD-003 | `bid` e `rid` corretos | Escritas e leituras com 4 IDs distintos | `bid` e `rid` casam com o `awid`/`arid` da transação | Comparação direta | Bloq. |
| T-S-ORD-004 | ID preservado sob carga | 16 transações entrelaçadas, IDs de `4'h0` a `4'hF` | Nenhuma troca de ID | E-01 | Bloq. |

### §3.8 Sistema — arbitragem (D5, MAS §5.4.4)

> Estes casos verificam uma **decisão de projeto**, não a norma. Severidade ajustável: falha pode levar a revisar D5.

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-ARB-001 | **Ausência de inanição** | Carga saturada simultânea: 100 escritas e 100 leituras de `len=0`, ambos os canais sempre com VALID alto | **Ambos** os sentidos completam. Nenhum fica abaixo de 40% do total de transações concluídas | Contagem por sentido | Ajust. |
| T-S-ARB-002 | **Latência de cauda sob burst longo** | Burst de escrita `len=255` em curso; leitura isolada chega no meio | A leitura **é** atendida, mas após o fim do burst. **Medir** a latência e registrá-la | Medição de ciclos entre `arvalid` e `rvalid` | Ajust. |
| T-S-ARB-003 | Alternância sob carga leve | Leituras e escritas isoladas alternadas | Nenhum sentido é postergado mais de um comando | Observação da sequência de `ram_addr` | Ajust. |

> **T-S-ARB-002 mede, não reprova.** A MAS §5.4.4 já documenta que a arbitragem é por comando, não por beat, logo uma latência superior a 1000 ciclos é **comportamento esperado**. O teste existe para quantificá-la e registrá-la no TCC, não para tratá-la como defeito.

### §3.9 Sistema — desempenho (R-17, D3)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-PERF-001 | **Ciclos por beat em leitura** | Burst de leitura `len=63`, `rready` sempre alto | Fase 2: ≤ 6 ciclos por beat em regime (meta: 2). **O teste falha se exceder 6** | Medição: ciclos totais ÷ 64 beats | Ajust. |
| T-S-PERF-002 | **Ciclos por beat em escrita** | Burst de escrita `len=63`, sem atrasos | Fase 2: ≤ 6 ciclos por beat (meta: 4) | Medição | Ajust. |
| T-S-PERF-003 | Vazão agregada | 1000 beats mistos | ≥ 33 MB/s (equivalente a 6 ciclos/beat). Registrar o valor medido | Cálculo a partir dos ciclos | Ajust. |
| T-S-PERF-004 | **Comparação entre fases** | Mesmo estímulo nas Fases 1 e 2 | Fase 2 mensuravelmente mais rápida. Tabela comparativa para o TCC | Medição em ambas | Inform. |

> T-S-PERF-001 e 002 **transformam a meta de D3 em requisito verificável**. Sem eles, "alto desempenho" seria aspiração não comprovada.

### §3.10 Sistema — temporização da SRAM (R-12)

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-SRAM-001 | Nenhuma violação em leitura | 100 leituras aleatórias | Zero disparos de A-SRAM-05 | Contador do modelo | Bloq. |
| T-S-SRAM-002 | Nenhuma violação em escrita | 100 escritas aleatórias | Zero disparos de A-SRAM-01 a 04 | Contador | Bloq. |
| T-S-SRAM-003 | **Pulso de `WE_N` suficiente** | Escritas em regime de burst | Todo pulso ≥ tPWE1 (8 ns) | A-SRAM-01 | Bloq. |
| T-S-SRAM-004 | **Setup de dado suficiente** | Escritas com dado mudando entre beats | Dado estável por ≥ tSD (6 ns) antes da subida de `we_n` | A-SRAM-03 | Bloq. |
| T-S-SRAM-005 | Endereço estável durante escrita | Burst de escrita | Endereço não muda com `we_n` ativo | A-SRAM-04 | Bloq. |
| T-S-SRAM-006 | Margem com temporização pessimista | Repetir T-S-SRAM-001..005 com tAA = 12 ns no modelo | Ainda sem violação, ou falha identificando a margem real | Contadores | Inform. |

> T-S-SRAM-006 testa a robustez da premissa de D8. Se o projeto só funciona com tAA exatamente 10 ns, a margem é nula e a MAS §6.2 precisa de revisão.

### §3.11 Sistema — robustez

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-ROB-001 | **Reset no meio de burst de leitura** | Reset no beat 4 de um burst `len=15` | Sem travamento. Após o reset, nova transação é atendida | E-08; checker | Bloq. |
| T-S-ROB-002 | **Reset no meio de burst de escrita** | Reset no beat 4, com `we_n` possivelmente ativo | SRAM não corrompida além do beat corrente; sistema recupera | Scoreboard; A-SRAM-01 | Bloq. |
| T-S-ROB-003 | Reset assíncrono ao clock | Reset afirmado fora da borda, em vários deslocamentos | Recuperação consistente em todos os casos | Repetição com deslocamento variável | Bloq. |
| T-S-ROB-004 | Posição não inicializada | Leitura em endereço nunca escrito | Retorna `32'hDEADDEAD` (§2.1.2) | Scoreboard | Inform. |
| T-S-ROB-005 | **Estresse pseudoaleatório** | 5000 transações aleatórias: tipo, endereço, `len`, `wstrb`, `id` e atrasos. **Semente fixa, registrada no log** | Zero erros de checker; zero divergências de scoreboard; zero violações do modelo | Todos os mecanismos | Bloq. |
| T-S-ROB-006 | Estresse com múltiplas sementes | T-S-ROB-005 repetido com 10 sementes distintas, todas registradas | Zero erros em todas | Todos | Bloq. |
| T-S-ROB-007 | Endereços nas bordas da faixa | Acessos em `0x0`, `0x1F_FFFC` e vizinhos | Comportamento correto; sem aliasing | Scoreboard | Bloq. |

### §3.12 Regressão do AXI4-Lite existente

O caminho AXI4-Lite **não é removido** (MAS §0.3). Esta suíte garante que a evolução não o quebre.

| ID | Objetivo | Estímulo | Resposta esperada | Checagem | Sev. |
|---|---|---|---|---|---|
| T-S-REG-001 | `tb_ram` continua passando | Suíte existente | `RESULT: PASS` | Makefile | Bloq. |
| T-S-REG-002 | `tb_write` continua passando | Suíte existente | `RESULT: PASS` | Makefile | Bloq. |
| T-S-REG-003 | `tb_read` continua passando | Suíte existente | `RESULT: PASS` | Makefile | Bloq. |
| T-S-REG-004 | `tb_top` continua passando | Suíte existente | `RESULT: PASS` | Makefile | Bloq. |
| T-S-REG-005 | Variação de parâmetros | Alvo `test_param` existente | Todas as configurações em PASS | Makefile | Bloq. |

> **Atenção (pendência V-01, §6):** os alvos `test_write` e `test_read` do `Makefile` apontam para `rtl/axi_slave_write.v` e `rtl/axi_slave_read.v`, mas os arquivos no repositório são `axi_subordinate_write.v` e `axi_subordinate_read.v`. **T-S-REG-002 e 003 falhavam na compilação**; corrigido na v0.3 (WP1).

**§3.12.1 Regressão obrigatória do suporte a `AxSIZE` (v0.2)**

A alteração da v0.2 atinge dois pontos compartilhados por **todas** as transações, não apenas pelas estreitas:

| Ponto alterado | Seção da MAS | Suítes que dependem dele |
|---|---|---|
| `calculate_addr_next` — caminho comum de cálculo de endereço de burst | §5.4.1 | T-S-AXI-001..015 |
| FIFO de requisições alargado de 6 para 11 bits — reindexação de todos os campos | §5.4.2 | T-S-ORD-001..004 |
| Caminho de `rdata` com módulo combinacional novo | §5.6 | T-S-PERF-001..004 |

> Portanto **T-S-AXI-001..015, T-S-ORD-001..004 e T-S-PERF-001..004 são regressão obrigatória** desta mudança, não opcional. Um erro de índice na reindexação do FIFO corromperia a ordenação de respostas (R-03, **normativo**) de forma silenciosa, sem afetar nenhum teste da área `SZ`.

### §3.13 Transferências estreitas — área `SZ` (v0.2)

Origem: **norma AXI4** (IHI0022E §A3.4.1 e §A3.4.3), logo severidade **bloqueante**, salvo onde indicado. Fecham a pendência P-03 da MAS.

**§3.13.1 Unitários — cálculo de endereço** (`calculate_addr_next`, MAS §5.4.1)

| ID | Estímulo | Resposta esperada | Cláusula | Sev. |
|---|---|---|---|---|
| T-U-SZ-001 | `calculate_addr_next(0x1000, INCR, 3, size=0)` | `0x1001` | §A3.4.1 | Bloq. |
| T-U-SZ-002 | `calculate_addr_next(0x1000, INCR, 3, size=1)` | `0x1002` | §A3.4.1 | Bloq. |
| T-U-SZ-003 | `calculate_addr_next(0x1000, INCR, 3, size=2)` | `0x1004` — **regressão do comportamento já existente** | §A3.4.1 | Bloq. |
| T-U-SZ-004 | `calculate_addr_next(0x1002, INCR, 3, size=2)` | `0x1004`, **não** `0x1006` — aplica `Aligned_Address` | §A3.4.1 | Bloq. |

> **T-U-SZ-004 é o caso mais importante da área.** Ele detecta a omissão do mascaramento de alinhamento, que é o erro de implementação mais provável: sem ele, um burst iniciado em endereço desalinhado propaga o desalinhamento por todos os beats. Os outros três casos passariam mesmo com o bug presente.

**§3.13.2 Unitários — posicionamento de byte lane** (`axi_narrow_read_align`, MAS §5.6)

Estímulo comum: `rdata_raw = 32'hAABBCCDD`.

| ID | Estímulo | Resposta esperada | Sev. |
|---|---|---|---|
| T-U-SZ-005 | `addr_lo=2'b00`, `size=0` | Lane `[7:0]` = `0xDD` | Bloq. |
| T-U-SZ-006 | `addr_lo=2'b10`, `size=0` | Lane `[23:16]` = `0xBB` | Bloq. |
| T-U-SZ-007 | `addr_lo=2'b10`, `size=1` | Lanes `[31:16]` = `0xAABB` | Bloq. |
| T-U-SZ-008 | `addr_lo=2'b00`, `size=2` | `[31:0]` = `0xAABBCCDD` — passagem direta | Bloq. |

> A comparação segue a regra 5 do scoreboard (§2.4): só as lanes válidas entram no veredito.

**§3.13.3 Sistema — bursts estreitos ponta a ponta**

| ID | Objetivo | Estímulo | Resposta esperada | Mecanismo | Sev. |
|---|---|---|---|---|---|
| T-S-SZ-001 | **Reproduz a Figura A3-8 da norma** | `arsize=0`, `arlen=4`, `araddr=0x0`, barramento de 32 bits | 5 beats lendo `0x0`..`0x4`; o byte do beat N na lane `(N-1) mod 4`; o 5º beat volta à lane 0 | Scoreboard por lane | Bloq. |
| T-S-SZ-002 | Burst de halfwords | `arsize=1`, `arlen=3`, `araddr=0x1000` | 4 beats em `0x1000`, `0x1002`, `0x1004`, `0x1006`; lanes alternando `[15:0]` e `[31:16]` | Scoreboard por lane | Bloq. |
| T-S-SZ-003 | Burst de escrita de bytes | `awsize=0`, `awlen=3`, `awaddr=0x1000`, `wstrb` rotacionando `0001`→`0010`→`0100`→`1000` | Só o byte alvo de cada beat alterado na SRAM | Scoreboard byte a byte | Bloq. |
| T-S-SZ-004 | **Escrita estreita não altera vizinhos** | `awsize=0` em `0x1001`, dado `0xFF` | `0x1000`, `0x1002` e `0x1003` **preservados** | Scoreboard | Bloq. |
| T-S-SZ-005 | **Tamanho ilegal rejeitado** | `arsize=3'b011` (8 bytes), `arlen=3` | **SLVERR** em todos os 4 beats; `rlast` no último; SRAM **não acessada** | Checker E-09; contador de acessos à SRAM | Ajust. (D11) |
| T-S-SZ-006 | Ida e volta estreita | Escrever 256 bytes individuais, ler de volta como bytes | Cada byte lido igual ao escrito, na lane correta | Scoreboard | Bloq. |
| T-S-SZ-007 | **Tamanho não vaza entre transações** | Burst estreito (`arsize=0`) imediatamente após burst largo (`arsize=2`), mesmo ID | O beat 2 do burst estreito usa o `size` da transação **corrente**, não da anterior | Scoreboard | Bloq. |

> **T-S-SZ-007 detecta um bug específico:** usar `req_axsize_q` (registrado) em lugar de `axi_arsize_i` (entrada) no cálculo do segundo beat, conforme a armadilha registrada na MAS §5.4.1. O registrador só atualiza na borda seguinte, então o segundo beat herdaria o tamanho da transação anterior.

**§3.13.4 Teste negativo**

| ID | Estímulo | Resposta esperada | Sev. |
|---|---|---|---|
| T-N-SZ-001 | Mestre que emite `awsize=0` com `wstrb=4'b1111` | **A assertiva E-10 dispara.** Teste negativo: PASS quando a assertiva acusa a incoerência | Bloq. |

**Resumo da área `SZ`:** 15 casos (4 de endereço, 4 de alinhamento, 7 de sistema), sendo 14 bloqueantes e 1 ajustável, mais 1 teste negativo.

### §3.14 Formal (opcional, nível F)

Executado apenas se houver ferramenta disponível (SymbiYosys ou equivalente).

| ID | Propriedade | Alvo |
|---|---|---|
| T-F-RAM-001 | Toda requisição aceita recebe exatamente um `ram_ack` | Contrato §3.2 |
| T-F-RAM-002 | `ram_wr != 0` e `ram_rd` são mutuamente exclusivos | Contrato regra 3 |
| T-F-RAM-003 | Ausência de deadlock: `ram_accept` não fica baixo para sempre | Contrato regra 7 |
| T-F-AXI-001 | `rlast` é afirmado exatamente uma vez por burst | R-04 |
| T-F-IOB-001 | `data_out_enable` e o drive da SRAM nunca coincidem | R-08 |

---

## §4 Cobertura

### §4.1 Cobertura funcional

**Matriz de cruzamento obrigatória.** Toda combinação marcada deve ser exercitada ao menos uma vez.

| Eixo | Valores |
|---|---|
| Comprimento de burst (`len`) | 0, 1, 3, 15, 63, 255 |
| Tipo de acesso | Leitura, escrita |
| Padrão de `wstrb` | `0000`, `0001`, `0011`, `0110`, `1100`, `1111` |
| Intermitência de `READY` | Sempre alto, padrão `1010`, pseudoaleatório |
| ID | Único, dois alternados, 16 distintos |
| Faixa de endereço | Início, meio, fim da faixa válida, fora da faixa |
| **Tamanho (`AxSIZE`)** (v0.2) | **`0b000` (1 B), `0b001` (2 B), `0b010` (4 B)** |

**Combinações obrigatórias:** todo `len` × todo tipo de acesso (12 células); todo padrão de `wstrb` com `len=3`; toda intermitência com `len=15`; **todo tamanho × `len` ∈ {0, 3} × tipo de acesso (12 células, v0.2)**.

**Combinações amostradas:** com o eixo de tamanho, o produto completo passa de 6 × 2 × 6 × 3 × 3 × 4 = **2592** para 6 × 2 × 6 × 3 × 3 × 4 × 3 = **7776 células**. Exercitá-lo por inteiro não é proporcional; o estresse pseudoaleatório (T-S-ROB-005/006) amostra o espaço, agora também sorteando o tamanho, e o relatório deve informar **quantas células distintas** foram alcançadas.

**Meta:** 100% das combinações obrigatórias e ao menos 60% do espaço amostrado.

> **A meta de 60% é recalculada sobre as 7776 células**, não herdada das 2592 anteriores. Isso é dito explicitamente para que não pareça que a meta antiga foi mantida por descuido: em números absolutos, passa de ~1555 para ~4666 células distintas.

### §4.2 Cobertura de código

| Alvo | Meta |
|---|---|
| **Estados** das FSMs novas (`axi_address_decoder`, `sram_controller`) | 100% |
| **Transições** (arcos) das FSMs novas | 100% |
| **Linhas alteradas no fork** `axi_transaction_manager` (A1–A6, MAS §5.4.5) | **100%** — toda alteração deve ser exercitada |
| **Tabela de posicionamento** de `axi_narrow_read_align` (MAS §5.6) | **100% das 7 linhas legais** |
| Trechos **não alterados** do fork | Informativo; herdados da IP |

> **Transição, não apenas estado.** Visitar um estado não prova que todos os caminhos de entrada e saída dele funcionam. A tabela de transições da MAS §5.3 e §5.5.2 é a lista de arcos a cobrir.
>
> **Sobre o fork (v0.2):** o `axi_transaction_manager` deixou de ser código intocado, logo a distinção relevante não é mais "projeto × IP", e sim **alterado × herdado**. As seis alterações A1–A6 são de autoria do projeto e exigem cobertura integral; o restante permanece informativo. `axi_narrow_read_align` é combinacional e não tem FSM, por isso sua meta é a tabela de verdade, não arcos.

**Estados inalcançáveis** devem ser justificados por escrito neste plano ou removidos do RTL. Um estado inalcançável não justificado é indício de lógica morta ou de bug na condição de transição.

### §4.3 Cobertura de asserção

> Assertiva que nunca falha pode estar morta. O plano exige **comprovar que cada uma funciona**.

Toda assertiva do checker (E-01 a **E-10**) e do modelo de SRAM (A-SRAM-01 a 08) precisa ter **disparado ao menos uma vez em um teste negativo dedicado**, construído para violá-la de propósito.

**Testes negativos previstos:** um por assertiva, nomeados `T-N-<assertiva>`, com um mestre ou modelo deliberadamente incorreto. Esses testes **passam quando a assertiva dispara** — a lógica de PASS/FAIL é invertida e isso deve estar explícito no testbench.

---

## §5 Critérios de saída

Lista fechada. Todos os itens devem ser satisfeitos antes de considerar o RTL pronto para síntese e carga na placa.

| # | Critério | Como comprovar |
|---|---|---|
| 1 | **Todos os casos de severidade bloqueante em PASS** | Relatório de execução de §2.5 |
| 2 | **Zero erros no checker de protocolo** em todos os testes de sistema | Contador `errors` do checker = 0 |
| 3 | **Zero violações de temporização** no modelo da SRAM | Contador do modelo = 0 |
| 4 | **Cobertura de transições das FSMs novas em 100%** | Relatório de cobertura (§4.2) |
| 5 | **Todo requisito normativo da MAS com ao menos um caso em PASS** | Matriz de §0.4 preenchida |
| 6 | **Toda assertiva comprovada por teste negativo** | Suíte `T-N-*` em PASS (§4.3) |
| 7 | **Regressão do AXI4-Lite em PASS** | T-S-REG-001..005 |
| 8 | **Desempenho dentro do alvo de R-17**, ou desvio registrado na MAS §0.2 com justificativa | T-S-PERF-001..003 |
| 9 | **Pendências P-01 e P-03 da MAS resolvidas ou aceitas por escrito** | §9.2 da MAS atualizada |
| 10 | **Sementes de todos os testes aleatórios registradas** | Logs em `build/` |
| 11 | **Todos os casos da área `SZ` em PASS** (v0.2) — condição para declarar P-03 fechada na MAS §9.2.1 | §3.13 |
| 12 | **Regressão de T-S-AXI, T-S-ORD e T-S-PERF intacta** após a alteração do fork | §3.12.1 |
| 13 | **`diff` dos forks limpo:** `diff` entre `rtl/third_party/ultra_embedded_asram16_axi4/asram16_axi4_pmem.v` e `rtl/axi4_sram/derived/axi_transaction_manager.v` mostra apenas A1–A7 (MAS §5.4.5); o mesmo para `asram16_axi4.v` e `rtl/sram/derived/sram_controller_baseline.v`, apenas B1–B3; `rtl/third_party/` sem alteração | Exigência de D10 e D14 (`make audit_fork`) |

**Casos de severidade ajustável em falha não bloqueiam**, mas exigem uma de duas ações, registrada por escrito: corrigir o RTL, ou revisar a decisão correspondente na MAS §0.2.

---

## §6 Pendências registradas

| ID | Pendência | Impacto | Como fechar |
|---|---|---|---|
| **V-01** (fechada na v0.3) | O `Makefile` referenciava `rtl/axi_slave_write.v` e `rtl/axi_slave_read.v`, mas os arquivos são `axi_subordinate_write.v` e `axi_subordinate_read.v`. Os alvos `test_write` e `test_read` provavelmente **não compilam** no estado atual | T-S-REG-002 e 003 falham na compilação | Corrigir os nomes no `Makefile` ao atualizar os alvos. **Não alterado nesta etapa**, que só produz documentos |
| **V-02** | Os parâmetros de temporização do modelo da SRAM dependem do grau de velocidade real da peça montada na placa | Calibração de §2.1 | Confirmar o sufixo da peça na DE2-115 em mãos. A MAS assume o grau -10 (D8), que é a premissa conservadora |
| **V-03** | Disponibilidade de ferramenta formal | Define se o nível F entra | Avaliar SymbiYosys. Nível F é opcional e não bloqueia os critérios de saída |
| **V-04** (fechada na v0.3: array fixo de 2^20 posições) | Suporte de `reg [15:0] mem [*]` (array associativo) no Icarus com `-g2012` | Implementação de §2.1.2 | Testar. Alternativa: array de 2^20 posições, que o Icarus aloca sem dificuldade |
| **V-05** | Modelo de temporização em simulação de RTL puro não captura atraso de placa | Fidelidade de §3.10 | Aceito: a validação final de timing é no TimeQuest (MAS §6.4) e na placa, não em simulação |
| **V-06** (v0.2) | O fork `axi_transaction_manager` e a IP original definem módulos homônimos se a renomeação A6 (MAS §5.4.5) não for feita | Compilação conjunta dos dois arquivos, necessária para o critério de saída 13 | Conferir que o módulo de FIFO foi renomeado para `axi_transaction_fifo` no fork |
| **V-07** (v0.2) | A cobertura das linhas alteradas do fork (§4.2) exige distinguir código alterado de herdado, o que o Icarus não reporta nativamente | Meta de cobertura de A1–A6 | Rastrear manualmente contra a lista da MAS §5.4.5, ou marcar as linhas com comentário `// A<n>` no fork |

---

## §7 Resumo quantitativo

Contagem da **v0.2**, conferida sobre as tabelas de caso deste documento.

| Nível | Casos | Bloqueantes | Ajustáveis | Informativos |
|---|---|---|---|---|
| U — Unitário | 40 | 35 | 5 | 0 |
| I — Integração | 7 | 6 | 0 | 1 |
| S — Sistema | 51 | 40 | 7 | 4 |
| F — Formal | 5 | opcional | — | — |
| **Total** | **103** | **81** | **12** | **5** |

Mais os testes negativos de §4.3, um por assertiva: **10** do checker (E-01 a E-10) e 8 do modelo da SRAM, totalizando **18 testes negativos**. Destes, T-N-SZ-001 já está especificado em §3.13.4.

**Evolução em relação à v0.1:** 88 → 103 casos (+15, todos da área `SZ`) e 17 → 18 negativos (+1, para E-10).

---

## Referências

1. `MAS_axi4_sram.md` — Microarchitecture Specification, documento companheiro.
2. ARM. *AMBA AXI and ACE Protocol Specification*, IHI0022E.
3. ISSI. *IS61WV102416ALL/BLL* datasheet, Rev. G, junho de 2014.
4. Terasic. *DE2-115 User Manual*, 2013.
5. Infraestrutura existente: `tb/common/axi_protocol_checker.v`, `tb/common/axi_master_tasks.vh`, `Makefile`, `docs/TUTORIAL_MAKE.md`.
