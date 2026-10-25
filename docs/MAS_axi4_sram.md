# Microarchitecture Specification — Subordinado AXI4 com controladora de SRAM externa (DE2-115)

**Projeto:** interface_amba — TCC
**Alvo:** Terasic DE2-115, FPGA Altera Cyclone IV E (EP4CE115F29C7)
**Memória:** SRAM assíncrona ISSI IS61WV102416BLL, 1024K × 16 (2 MB)

---

## §0 Front matter

### §0.1 Histórico de revisões

| Versão | Data | Autor | Resumo |
|---|---|---|---|
| 0.1 | 2026-10-25 | August | Versão inicial. Define a fusão da IP `asram16_axi4` com o barramento AXI4, as decisões D1–D7 e o contrato `ram_*`. Temporização calibrada pela folha de dados Rev. G da ISSI |
| 0.2 | 2026-10-25 | August | Suporte a `AxSIZE` (1, 2 e 4 bytes): fecha P-03. Acrescenta `axi_transaction_manager` (fork LGPL da IP) e `axi_narrow_read_align`. FIFO de requisições alargado para 11 bits. Decisões D9–D13 |

Este é um **documento vivo**. Cada alteração entra como nova linha aqui e, quando for decisão de projeto, como nova linha em §0.2. Nenhuma seção é reescrita silenciosamente.

### §0.2 Registro de decisões

| ID | Decisão | Alternativas consideradas | Justificativa | Status |
|---|---|---|---|---|
| **D1** | **Fusão**: a IP `asram16_axi4` (Ultra-Embedded, LGPL) permanece como núcleo; o projeto escreve as camadas AXI4 em volta | Reescrever tudo do zero; modificar a IP internamente | Menor risco e prazo. A IP já resolve burst, ID e arbitragem, que são a parte laboriosa. A autoria do projeto fica nas camadas novas, claramente delimitadas | Ativa |
| **D2** | **Clock único de 50 MHz**, direto do oscilador da placa, sem PLL | PLL com domínios separados para AXI e SRAM; PLL de 100 MHz único | Elimina a classe inteira de problemas de CDC (§6.1). O período de 20 ns acomoda a SRAM de 10 ns com folga, permitindo acesso em 1 ciclo de espera | Ativa |
| **D3** | **Pipeline de endereço em burst** — alvo de 4 a 6 ciclos por beat de 32 bits | Apenas reduzir as esperas da IP (~8 ciclos/beat) | A SRAM é assíncrona e não tem latência de comando, então o endereço do próximo acesso pode ser apresentado enquanto o dado atual é capturado. Sem isso, o rótulo de alto desempenho não se sustenta | Ativa |
| **D4** | **Plano de verificação em documento separado** | Seção dentro desta MAS | Os testbenches serão construídos a partir dele; separar mantém os dois documentos legíveis e permite versioná-los em ritmos diferentes | Ativa |
| **D5** | **Arbitragem round-robin** entre leitura e escrita, a da própria IP | Prioridade fixa para escrita (política atual do projeto, `axi_ram_adapter.v:21`) | Evita inanição de qualquer dos sentidos sob carga simultânea. **Não é exigência do AXI4** — ver §5.5 | Ativa |
| **D6** | **Tabela única de requisitos** com coluna de origem | Tabelas separadas por origem | Mantém o documento compacto e deixa auditável o que é norma, o que é placa e o que é autoria | Ativa |
| **D7** | **Convenção de nomeação** conforme §0.4 | Nomes livres por módulo | Evita redebater nome a cada módulo novo e mantém coerência com o que o repositório já pratica | Ativa |
| **D8** | **Grau de velocidade -10 (10 ns)** como premissa de temporização | Grau -8 (8 ns) | A DE2-115 alimenta a SRAM em 3,3 V, e o grau -8 só é especificado para 3,3 V + 5%. Assumir -8 seria otimista e poderia falhar na placa | Ativa |
| **D9** | **Suporte completo a `AxSIZE`**: `0b000` (1 byte), `0b001` (2 bytes) e `0b010` (4 bytes), com incremento de endereço por `2^AxSIZE` **e** rotação de byte lanes | Corrigir só o incremento, mantendo o dado nas lanes baixas; rejeitar todo acesso estreito com erro | Fecha a violação normativa por inteiro. Tamanhos acima de 4 bytes são ilegais num barramento de 32 bits (IHI0022E §A3.4.1: "The size of any transfer must not exceed the data bus width") | Ativa |
| **D10** | **Fork da IP** para `rtl/axi_transaction_manager.v`; o `asram16_axi4_pmem.v` original fica **intocado** | Editar a IP no lugar; resolver num wrapper externo sem tocar na IP | A LGPL exige preservar o aviso de copyright e sinalizar obra derivada. Manter o original ao lado torna as alterações auditáveis por `diff`, o que é valioso para a banca. Esta decisão **flexibiliza D1**, que previa não alterar a IP: a violação normativa de P-03 não é contornável por fora sem lógica de fatiamento mais complexa que a alteração interna | Ativa |
| **D11** | **`AxSIZE` > `0b010` rejeitado com SLVERR** pelo `axi_address_decoder` | Truncar silenciosamente para 4 bytes; aceitar e ignorar | Transação ilegal para 32 bits. SLVERR sinaliza explicitamente, em vez de corromper em silêncio. DECERR fica reservado a erro de endereço, conforme a semântica da norma | Ativa |
| **D12** | **Lanes não usadas em leitura recebem o dado replicado**, não zeros | Zerar as lanes não usadas; deixar indefinidas | **Não há cláusula na IHI0022E** que determine o valor dessas lanes: a Figura A3-8 apenas as marca como "bytes que não são transferidos". Replicar é o comportamento usual de subordinados comerciais e protege um mestre com máscara frouxa, que leria zeros espúrios. Registrada como **decisão, não como exigência** — ver P-06 | Ativa |
| **D13** | **Nome do fork:** `axi_transaction_manager` — gerencia o ciclo de vida das transações AXI (endereço de burst, IDs, ordenação, arbitragem) até convertê-las em acessos `ram_*` | `axi_subordinate_burst` (cita característica do protocolo em vez da função, e colidiria com a família `axi_subordinate_write`/`_read`, sugerindo um canal inexistente); `axi_memory_frontend` (jargão, vedado por §0.4 regra 4); `axi_subordinate_full` (descreve a variante do protocolo, não a função) | Conforme §0.4 regra 3, o nome diz o que o módulo faz | Ativa |

### §0.3 Status dos módulos

| Módulo | Origem | Fase | Status | Arquivo RTL previsto |
|---|---|---|---|---|
| `de2_115_top` | Projeto | 1 | A implementar | `rtl/de2_115_top.v` |
| `reset_synchronizer` | Projeto | 1 | A implementar | `rtl/reset_synchronizer.v` |
| `axi_interface_subordinate_sram` | Projeto | 1 | A implementar | `rtl/axi_interface_subordinate_sram.v` |
| `axi_address_decoder` | Projeto | 1 | A implementar | `rtl/axi_address_decoder.v` |
| `sram_io_buffer` | Projeto | 1 | A implementar | `rtl/sram_io_buffer.v` |
| `axi_transaction_manager` | Projeto (fork de IP LGPL, D10) | 1 e 2 | A implementar | `rtl/axi_transaction_manager.v` |
| `axi_narrow_read_align` | Projeto | 1 e 2 | A implementar | `rtl/axi_narrow_read_align.v` |
| `asram16_axi4_pmem` | IP (LGPL) | — | **Substituído pelo fork; mantido intocado como referência (D10)** | `rtl/asram16_axi4_pmem.v` |
| `asram16_axi4` (FSM) | IP (LGPL) | 1 | Presente, não instanciado | `rtl/asram16_axi4.v` |
| `sram_controller` | Projeto | 2 | A implementar | `rtl/sram_controller.v` |

Módulos AXI4-Lite existentes (`axi_interface_subordinate_ram`, `axi_subordinate_write`, `axi_subordinate_read`, `axi_ram_adapter`, `ram`) **permanecem no repositório** e continuam funcionais. Esta MAS não os remove.

### §0.4 Convenção de nomeação (normativa, D7)

Extraída do padrão que o repositório já pratica em `axi_subordinate_write.v`, `axi_subordinate_read.v` e `axi_interface_subordinate_ram.v`.

1. **Prefixo `axi_`** para todo módulo que fala o protocolo AXI. **Prefixo `sram_`** para módulos do lado da memória física. Sem prefixo para recursos genéricos (`ram.v`).
2. **`subordinate`, nunca `slave`** — terminologia já adotada pelo projeto e alinhada à ARM atual.
3. **O nome descreve a função, não a técnica de implementação.** Um módulo que usa pipeline não se chama `*_pipelined`; a técnica é documentada em §5. Nome que carrega técnica passa a mentir quando a implementação muda.
4. **Sem jargão importado de outros domínios** (`phy`, `pads`) e **sem abreviação** quando o nome completo cabe (`reset_synchronizer`, não `reset_sync`).
5. **Módulos análogos espelham o nome:** `axi_interface_subordinate_sram.v` ao lado de `axi_interface_subordinate_ram.v` torna a migração legível só pela listagem do diretório.
6. **Sinais:** sufixo `_q` para registrado, `_w` para wire combinacional, `_r` para variável de bloco `always`, `_n` para ativo-baixo. Comentários em português. Verilog-2001. Reset ativo-baixo `aresetn` na fronteira AXI.
7. **Exceção:** os módulos da IP (`asram16_axi4*`) **mantêm os nomes originais**, por serem código de terceiros sob LGPL. Renomeá-los dificultaria rastrear a origem e eventuais atualizações do autor.
8. **Obra derivada (v0.2):** um **fork** de código de terceiros recebe nome do projeto conforme as regras 1 a 6, e **não** herda o nome original. A razão é oposta à da regra 7: o original permanece no repositório com seu nome, e o fork precisa ser distinguível dele à primeira vista. O cabeçalho do fork registra a procedência e a lista de alterações (ver §5.4.5).

### §0.5 Glossário

| Termo | Significado |
|---|---|
| **Beat** | Uma transferência de dados dentro de um burst AXI. Um burst de `awlen=3` tem 4 beats |
| **Burst** | Sequência de transferências geradas por um único endereço de comando |
| **CDC** | *Clock Domain Crossing* — travessia de dado entre domínios de clock distintos (§6.1) |
| **Contrato `ram_*`** | A interface entre o frontend AXI da IP e a controladora da SRAM (§3.2). É o ponto de troca entre Fase 1 e Fase 2 |
| **Inanição** | Situação em que um sentido (leitura ou escrita) nunca é atendido porque o outro monopoliza o recurso |
| **Metaestabilidade** | Estado indefinido de um flip-flop que amostrou um sinal durante sua transição |
| **Turnaround** | Intervalo necessário entre leitura e escrita para que o barramento bidirecional troque de direção sem contenção |
| **`AxSIZE`** | `AWSIZE` ou `ARSIZE`. Codifica o tamanho de cada beat: `2^AxSIZE` bytes (IHI0022E Tabela A3-2). Num barramento de 32 bits, apenas `0b000`, `0b001` e `0b010` são legais |
| **Byte lane** | Faixa de 8 bits do barramento de dados. Um barramento de 32 bits tem 4 lanes, indexadas por `addr[1:0]` |
| **Transferência estreita** (*narrow transfer*) | Beat menor que a largura do barramento. Em burst INCR, **as lanes usadas mudam a cada beat** (§A3.4.3) |
| **`Aligned_Address`** | `INT(Start_Address / Number_Bytes) × Number_Bytes`. Base de cálculo dos beats **após** o primeiro, que impede a propagação de desalinhamento (§4.2.1) |
| **Obra derivada** | Arquivo criado a partir de código de terceiros sob LGPL, com o aviso de copyright preservado e as alterações registradas. Aqui: `axi_transaction_manager` (§5.4.5) |

---

## §1 Visão geral e requisitos

### §1.1 Objetivo

Especificar a microarquitetura de um **subordinado AXI4 completo** que atende transações de leitura e escrita sobre a **SRAM externa de 2 MB** da DE2-115, com suporte a burst e IDs, de forma sintetizável e com desempenho próximo ao limite físico da memória.

### §1.2 Escopo

**Dentro do escopo:** o subordinado AXI4, a controladora da SRAM, a interface física com os pinos da placa, a decodificação de endereço e o tratamento de erro.

**Fora do escopo:** o mestre AXI (seja ele um processador, um DMA ou um gerador de tráfego); interconexão AXI com múltiplos mestres; a SDRAM de 128 MB da placa; acessos exclusivos (`lock`), cache e QoS.

### §1.3 Tabela de requisitos (D6)

A coluna **Origem** distingue o que é exigência externa verificável do que é escolha deste projeto. Essa distinção determina a severidade da falha no plano de verificação: violar a norma é bloqueante, enquanto descumprir uma decisão de projeto pode levar a revisar a decisão.

| ID | Requisito | Origem | Seção da origem | Verificação |
|---|---|---|---|---|
| R-01 | Handshake VALID/READY: VALID não é retirado antes de READY; payload estável enquanto VALID pendente | Norma AXI4 | IHI0022E §A3.2.1 | T-S-AXI |
| R-02 | Burst INCR com `awlen`/`arlen` de 1 a 256 beats | Norma AXI4 | IHI0022E §A3.4.1 | T-S-AXI |
| R-03 | Respostas de um **mesmo ID** retornam na ordem de emissão | Norma AXI4 | IHI0022E §A5.3 | T-S-ORD |
| R-04 | `RLAST` afirmado no último beat de leitura, e somente nele | Norma AXI4 | IHI0022E §A3.4.1 | T-S-AXI |
| R-05 | `BVALID` somente após o beat com `WLAST` do burst correspondente | Norma AXI4 | IHI0022E §A3.4.4 | T-S-AXI |
| R-06 | Burst não cruza fronteira de 4 KB | Norma AXI4 | IHI0022E §A3.4.1 | T-S-4KB |
| R-07 | 2 MB endereçáveis, de `0x0000_0000` a `0x001F_FFFF` | Placa DE2-115 | Manual §4.19 | T-U-DEC |
| R-08 | `SRAM_DQ[15:0]` bidirecional, com barramento físico único compartilhado entre leitura e escrita | Placa DE2-115 | Manual Tabela 4-27 | T-U-IOB |
| R-09 | 20 bits de endereço (`SRAM_ADDR[19:0]`) | Placa DE2-115 | Manual Tabela 4-27 | T-U-DEC |
| R-10 | Clock de 50 MHz, período de 20 ns | Placa DE2-115 | Manual §4.5 | Síntese |
| R-11 | Padrão de I/O 3,3 V em todos os pinos da SRAM | Placa DE2-115 | Manual Tabela 4-27 | Síntese (`.qsf`) |
| R-12 | Respeitar tAA = 10 ns, tWC = 10 ns, tSD = 6 ns, tPWE1 = 8 ns | Folha de dados | ISSI Rev. G, tabelas de leitura e escrita | T-S-SRAM |
| R-13 | Máximo de 4 transações em voo (profundidade dos FIFOs) | IP (herdado no fork) | `axi_transaction_manager.v:255` | T-I-RAM |
| R-14 | Bursts FIXED e WRAP tratados como INCR, salvo `define` explícito | IP (herdado no fork) | `axi_transaction_manager.v:99-117` | T-S-AXI |
| R-15 | Endereço fora da faixa retorna **DECERR**, nunca aliasing | Decisão (§4.3) | — | T-U-DEC |
| R-16 | Arbitragem round-robin, sem inanição de nenhum dos sentidos | Decisão (D5) | — | T-S-ARB |
| R-17 | Desempenho de 4 a 6 ciclos por beat de 32 bits em regime permanente | Decisão (D3) | — | T-S-PERF |
| R-18 | Domínio de clock único, sem CDC | Decisão (D2) | — | §6.1, síntese |
| R-19 | `AxSIZE` de 1, 2 e 4 bytes, com incremento de endereço por `2^AxSIZE` e aplicação de `Aligned_Address` | Norma AXI4 | IHI0022E §A3.4.1 | T-U-SZ-001..004 |
| R-20 | Rotação de byte lanes em burst INCR estreito, conforme `Lower_Byte_Lane` | Norma AXI4 | IHI0022E §A3.4.3 | T-U-SZ-005..008, T-S-SZ-001 |
| R-21 | `AxSIZE` acima de 4 bytes rejeitado com SLVERR | Decisão (D11) | — | T-S-SZ-005 |

### §1.4 Requisitos não funcionais

- Sintetizável para Cyclone IV E (EP4CE115F29C7) no Quartus, em Verilog-2001.
- Fechamento de timing a 50 MHz com folga positiva em todos os caminhos, incluindo os pinos da SRAM.
- Sem inferência de RAM de bloco para a memória de dados: a memória é externa.

### §1.5 Restrições herdadas

Limitações já identificadas na análise da IP, que esta microarquitetura precisa contornar:

| # | Restrição | Contorno nesta MAS |
|---|---|---|
| L-01 | A IP expõe `sram_data_in_i` e `sram_data_out_o` separados, sem sinal de direção | `sram_io_buffer` deriva a direção do estado da FSM (§5.3) |
| L-02 | `sram_address_o` tem 32 bits, contra 20 da placa | Truncamento explícito, com DECERR para fora de faixa (§4) |
| L-03 | A IP fixa `bresp`/`rresp` em OKAY, sem SLVERR nem DECERR | `axi_address_decoder` gera o erro antes de a requisição chegar à IP (§5.4) |
| L-04 | Os atributos `synthesis attribute IOB` da IP são de Xilinx e não têm efeito no Quartus | Requisito equivalente declarado no `.qsf` (§8.2) |
| L-05 | As esperas padrão da IP são de 7 ciclos, excessivas para 50 MHz | Reparametrizadas conforme o orçamento de §6.2 |
| L-06 | `CE_N` fixo em 0 na IP, sem power-down | Aceito: a SRAM fica sempre selecionada. Registrado como consequência de consumo, não como defeito |
| L-07 | A IP não possui portas `awsize`/`arsize` e opera sempre em 32 bits, violando IHI0022E §A3.4.1 e §A3.4.3 | **Resolvido na v0.2** — fork `axi_transaction_manager` (§5.4.5) e `axi_narrow_read_align` (§5.6). Antes P-03 |

---

## §2 Diagrama de blocos e hierarquia

```
de2_115_top.v                                  (projeto — pinos físicos da placa)
 │
 ├── reset_synchronizer.v                      (projeto — KEY[0] → aresetn síncrono)
 │
 ├── axi_interface_subordinate_sram.v          (projeto — wrapper do subordinado;
 │    │                                         espelha axi_interface_subordinate_ram.v)
 │    │
 │    ├── axi_address_decoder.v                (projeto — faixa válida, DECERR,
 │    │                                         e validação de AxSIZE → SLVERR)
 │    │
 │    ├── axi_transaction_manager.v            (projeto — fork LGPL da IP, D10;
 │    │                                         burst, ID, arbitragem, FIFOs,
 │    │                                         endereço por 2^AxSIZE)
 │    │                                         ◄── mantido nas duas fases
 │    │
 │    ├── axi_narrow_read_align.v              (projeto — posiciona o dado lido
 │    │                                         na byte lane correta, §5.6)
 │    │                                         ◄── combinacional, no caminho de rdata
 │    │
 │    │     ═══ fronteira do contrato ram_* (§3.2) ═══
 │    │
 │    └── Fase 1: asram16_axi4.v               (IP — FSM com esperas fixas)
 │        Fase 2: sram_controller.v            (projeto — FSM com pipeline)
 │                                              ▲ a troca ocorre exatamente aqui
 │
 └── sram_io_buffer.v                          (projeto — tri-state de SRAM_DQ)
                                                │
                                                ▼
                            SRAM externa IS61WV102416BLL (2 MB)
```

| Módulo | Origem | Responsabilidade | Interfaces |
|---|---|---|---|
| `de2_115_top` | Projeto | Ligar pinos da placa, instanciar o subordinado, prover tráfego ou expor o AXI | Pinos da placa |
| `reset_synchronizer` | Projeto | Converter reset assíncrono externo em `aresetn` síncrono | `KEY[0]` → `aresetn` |
| `axi_interface_subordinate_sram` | Projeto | Agregar decoder, IP e controladora; converter `aresetn` em `rst_i` | AXI4 ↔ pinos SRAM |
| `axi_address_decoder` | Projeto | Validar faixa e `AxSIZE`; gerar DECERR e SLVERR; drenar burst em erro | AXI4 ↔ AXI4 |
| `axi_transaction_manager` | Projeto (fork, D10) | Burst, ID, arbitragem, FIFOs; cálculo de endereço por `2^AxSIZE` | AXI4 ↔ `ram_*` |
| `axi_narrow_read_align` | Projeto | Posicionar o dado lido na byte lane determinada pelo endereço e pelo tamanho | `rdata` bruto ↔ `rdata` AXI |
| `asram16_axi4` / `sram_controller` | IP / Projeto | Temporização dos acessos de 16 bits à SRAM | `ram_*` ↔ sinais SRAM |
| `sram_io_buffer` | Projeto | Tri-state de `SRAM_DQ`; registradores de pino | Sinais SRAM ↔ pinos |

---

## §3 Interfaces

### §3.1 AXI4 subordinado

Largura de dados de 32 bits, endereço de 32 bits, ID de 4 bits.

**Canal AW (endereço de escrita)**

| Sinal | Dir | Largura | Suporte | Observação |
|---|---|---|---|---|
| `awid` | in | 4 | Sim | Propagado para `bid` |
| `awaddr` | in | 32 | Sim | Faixa útil `[20:0]`; acima disso, DECERR |
| `awlen` | in | 8 | Sim | `awlen+1` beats |
| `awsize` | in | 3 | **Sim** | 1, 2 ou 4 bytes (`0b000`, `0b001`, `0b010`). Acima de 4 bytes → SLVERR. Ver §5.6 |
| `awburst` | in | 2 | Parcial | INCR suportado; FIXED e WRAP tratados como INCR (R-14) |
| `awvalid`/`awready` | — | 1 | Sim | — |
| `awlock`/`awcache`/`awprot`/`awqos` | in | — | **Ignorados** | Aceitos e descartados |

**Canal W (dados de escrita):** `wdata[31:0]`, `wstrb[3:0]`, `wlast`, `wvalid`/`wready`. Todos suportados.
**Canal B (resposta de escrita):** `bid[3:0]`, `bresp[1:0]`, `bvalid`/`bready`. `bresp` ∈ {OKAY, SLVERR, DECERR}.
**Canal AR (endereço de leitura):** espelha AW, inclusive `arsize`.
**Canal R (dados de leitura):** `rid[3:0]`, `rdata[31:0]`, `rresp[1:0]`, `rlast`, `rvalid`/`rready`.

> **Nota sobre `awsize`/`arsize` (R-19, R-20, R-21 — resolve L-07):** transferências estreitas são **suportadas** desde a v0.2. O cálculo de endereço entre beats usa `Number_Bytes = 2^AxSIZE` com aplicação de `Aligned_Address`, conforme IHI0022E §A3.4.1 (ver §4.2 e §5.4.1), e o dado lido é posicionado na byte lane determinada por `Lower_Byte_Lane`, conforme §A3.4.3 (ver §5.6). Tamanhos acima de 4 bytes excedem a largura do barramento e são rejeitados com **SLVERR** pelo `axi_address_decoder` (§5.3), em vez de truncados em silêncio.
>
> **Limitação remanescente:** transferência de 2 bytes com endereço ímpar (`AxSIZE = 0b001` e `addr[1:0]` ∈ {`01`, `11`}) é desalinhada. A norma a permite (§A3.4.3, "Unaligned transfers"), mas atendê-la exigiria dois acessos à SRAM de 16 bits. O caso é tratado como passagem direta e está registrado em **P-07** (§9.2).

### §3.2 Contrato `ram_*` — a interface crítica

Esta é a fronteira que torna Fase 1 e Fase 2 intercambiáveis. Qualquer implementação que respeite este contrato pode substituir a outra sem alterar o frontend AXI.

| Sinal | Dir (vista da controladora) | Largura | Descrição |
|---|---|---|---|
| `ram_addr` | in | 32 | Endereço em **bytes**. O bit [0] é ignorado |
| `ram_wr` | in | 4 | Strobes de escrita. Diferente de zero indica escrita |
| `ram_rd` | in | 1 | Requisição de leitura |
| `ram_size` | in | 3 | Tamanho do beat (`2^size` bytes). **Necessário na leitura**, onde não há strobes para indicar a largura (v0.2) |
| `ram_write_data` | in | 32 | Dado a escrever |
| `ram_accept` | out | 1 | A controladora aceita a requisição neste ciclo |
| `ram_ack` | out | 1 | Uma resposta está válida neste ciclo |
| `ram_read_data` | out | 32 | Dado lido, válido quando `ram_ack` |

**Regras normativas do contrato:**

1. **Requisição:** `ram_wr != 0` ou `ram_rd == 1` indica requisição pendente. A requisição é consumida no ciclo em que `ram_accept == 1`.
2. **Estabilidade:** enquanto a requisição não for aceita, o frontend mantém `ram_addr`, `ram_wr`, `ram_rd`, `ram_size` e `ram_write_data` estáveis.
3. **Exclusividade:** `ram_wr != 0` e `ram_rd == 1` nunca ocorrem no mesmo ciclo. O árbitro do frontend garante isso.
4. **Resposta:** `ram_ack` vale por exatamente um ciclo por requisição aceita, inclusive para escritas.
5. **Ordenação:** as respostas retornam **na mesma ordem** das requisições aceitas. É o que permite ao frontend casar cada resposta com a entrada correspondente do seu FIFO, e é o mecanismo que cumpre R-03.
6. **Pipeline:** a controladora **pode** aceitar uma nova requisição antes de responder a anterior. O número máximo de requisições em voo é um parâmetro da implementação: 1 na Fase 1, 2 na Fase 2.
7. **Latência:** não há limite máximo especificado, mas a controladora não pode negar `ram_accept` indefinidamente — toda requisição é eventualmente aceita, sem o que o barramento entra em deadlock.
8. **Contexto de alinhamento (v0.2):** o tamanho (`ram_size`) e os dois bits baixos do endereço (`ram_addr[1:0]`) acompanham cada requisição e **são devolvidos junto da resposta**, para que o alinhamento de byte lane (§5.6) saiba onde posicionar o dado. O transporte é feito pelo FIFO de requisições, alargado para isso (§5.4.2), e não por um caminho paralelo — o que preserva a ordenação da regra 5.

**Acesso isolado (Fase 1, leitura):**

```
ciclo      0     1     2     3     4     5
clk      ─┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌─
          └─┘   └─┘   └─┘   └─┘   └─┘   └─┘
ram_rd    ─────────────┐
                       └──────────────────
ram_accept      ───────┐
                       └──────────────────
sram_addr  ╞═══ A ═══════════════════════╡
sram_oe_n  ────┐                   ┌──────
               └───────────────────┘
ram_ack                      ──────┐
                                   └──────
ram_read_data                ╞══ D ══╡
```

**Dois acessos em pipeline (Fase 2):** o endereço do acesso N+1 é apresentado à SRAM no mesmo ciclo em que o dado do acesso N é capturado. Como a SRAM é assíncrona e não tem latência de comando, o único requisito é que o endereço permaneça estável por tAA antes da captura.

```
ciclo      0     1     2     3     4     5     6
sram_addr  ╞═ A0 ═╡╞═ A1 ═╡╞═ A2 ═╡╞═ A3 ═╡
captura         ↑D0    ↑D1    ↑D2    ↑D3
ram_ack         ─┐     ─┐     ─┐     ─┐
                 └─     └─     └─     └─
```

### §3.3 Pinos físicos da SRAM

Conforme o manual da DE2-115, Tabela 4-27.

| Sinal | Dir | Largura | Pino FPGA (exemplos) | Padrão | Função |
|---|---|---|---|---|---|
| `SRAM_ADDR` | out | 20 | `AB7` (bit 0) … `T8` (bit 19) | 3,3 V | Endereço de palavra de 16 bits |
| `SRAM_DQ` | **inout** | 16 | `AH3` (bit 0) … `AG3` (bit 15) | 3,3 V | Dados bidirecionais |
| `SRAM_OE_N` | out | 1 | `AD5` | 3,3 V | Output enable, ativo-baixo |
| `SRAM_WE_N` | out | 1 | `AE8` | 3,3 V | Write enable, ativo-baixo |
| `SRAM_CE_N` | out | 1 | `AF8` | 3,3 V | Chip enable, ativo-baixo. Fixo em 0 (L-06) |
| `SRAM_LB_N` | out | 1 | `AD4` | 3,3 V | Habilita byte baixo, `DQ[7:0]` |
| `SRAM_UB_N` | out | 1 | `AC4` | 3,3 V | Habilita byte alto, `DQ[15:8]` |

> **Mapeamento de `sram_be_n_o` da IP:** a IP gera `sram_be_n_o[1:0]` a partir de `~wstrb`. A ligação é `LB_N = sram_be_n_o[0]` e `UB_N = sram_be_n_o[1]`, pois na IP o bit 0 corresponde ao byte menos significativo (`sram_data_q[7:0]`). Registrado como pendência de confirmação P-01 (§9.2), a ser validada no teste T-U-IOB.

---

## §4 Mapa de endereços e decodificação

### §4.1 Mapa

| Região | Faixa de endereços AXI | Tamanho | Destino |
|---|---|---|---|
| SRAM | `0x0000_0000` – `0x001F_FFFF` | 2 MB | SRAM externa |
| Não mapeado | `0x0020_0000` – `0xFFFF_FFFF` | — | DECERR |

### §4.2 Conversão de endereço

O AXI endereça **bytes**; a SRAM endereça **palavras de 16 bits**. Cada beat de 32 bits ocupa duas palavras consecutivas.

```
Endereço AXI (bytes):   awaddr[20:0]
                            │
                            ├─ [20:2] → índice da palavra de 32 bits
                            ├─ [1]    → selecionado pela FSM (metade baixa/alta)
                            └─ [0]    → ignorado (acesso alinhado)

Endereço SRAM:  sram_addr[19:0] = { awaddr[20:2], metade }
                onde metade = 0 para DQ[15:0] baixo, 1 para o alto
```

A controladora implementa isso como `sram_address_q <= {1'b0, ram_addr_w[31:1]}` seguido de `+1` para a segunda metade. O truncamento para 20 bits ocorre na ligação com os pinos, em `de2_115_top`.

#### §4.2.1 Incremento de endereço entre beats (R-19, normativo)

O incremento **não é fixo em 4 bytes**: depende de `AxSIZE`. As equações são normativas (IHI0022E §A3.4.1) e implementadas em `calculate_addr_next` (§5.4.1):

```
Number_Bytes    = 2 ^ AxSIZE
Burst_Length    = AxLEN + 1
Aligned_Address = INT(Start_Address / Number_Bytes) × Number_Bytes

Address_1 = Start_Address                                    (primeiro beat, pode estar desalinhado)
Address_N = Aligned_Address + (N - 1) × Number_Bytes         (beats seguintes, sempre alinhados)
```

| `AxSIZE` | `Number_Bytes` | Incremento entre beats |
|---|---|---|
| `0b000` | 1 | 1 byte |
| `0b001` | 2 | 2 bytes |
| `0b010` | 4 | 4 bytes |

> **Ponto de atenção:** a distinção entre `Address_1` e `Address_N` é o que exige o mascaramento de alinhamento. Um burst que **comece** desalinhado usa o endereço como veio no primeiro beat, mas os seguintes partem de `Aligned_Address` — o desalinhamento **não se propaga**. Omitir esse mascaramento é o erro de implementação mais provável, e o caso de teste T-U-SZ-004 existe para detectá-lo.

### §4.3 Tratamento de erro (R-15, decisão de projeto)

A IP fixa `bresp` e `rresp` em OKAY (L-03). Sem intervenção, um acesso a `0x0020_0000` sofreria **aliasing silencioso** para `0x0000_0000`, por truncamento do endereço — o pior tipo de falha, porque corrompe dados sem sinalizar.

**Decisão:** o `axi_address_decoder` intercepta a requisição **antes** da IP e, quando o endereço está fora da faixa:

1. Não encaminha a requisição à IP, de modo que a SRAM não é acessada.
2. Gera a resposta de erro com `rresp`/`bresp` = `DECERR` (`2'b11`).
3. **Drena o burst inteiro.** Para leitura, emite `arlen+1` beats de R, todos com DECERR, e `rlast` no último. Para escrita, consome `awlen+1` beats de W e emite uma única resposta B com DECERR.

O passo 3 é essencial: um burst parcialmente respondido deixa o mestre à espera e **trava o canal**. A norma exige que o número de beats de resposta case com o comprimento do burst, mesmo em erro.

**Critério de faixa:** a verificação é feita sobre o endereço de **início** do burst e sobre o de **fim** calculado, de modo que um burst que comece válido e termine fora também é rejeitado por inteiro. A alternativa — responder OKAY aos primeiros beats e DECERR aos últimos — é permitida pela norma, mas foi descartada por complicar a FSM sem benefício prático.

### §4.4 Fronteira de 4 KB (R-06)

A norma proíbe que um burst cruze fronteira de 4 KB. **A responsabilidade é do mestre.** Este subordinado não é obrigado a detectar a violação, e a IP não a detecta.

**Decisão:** o checker de protocolo do ambiente de verificação detecta e acusa a violação, para que o problema apareça em simulação. No RTL sintetizado, nenhuma lógica é gasta com isso. Um mestre que viole a regra receberá dados de endereços incorretos, porque o incremento de `calculate_addr_next` não respeita a fronteira.

---

## §5 Microarquitetura por módulo

### §5.1 `reset_synchronizer`

**Responsabilidade:** converter o reset externo assíncrono, vindo de `KEY[0]`, em um `aresetn` síncrono ao clock de 50 MHz.

**Problema que resolve:** `KEY[0]` é um botão, sem relação alguma com o clock. Se a sua borda de liberação cair perto da borda do clock, registradores diferentes podem sair do reset em ciclos diferentes, deixando a FSM num estado inconsistente. Note que isto **não é CDC** (§6.1.1), mas sim a entrada de um sinal assíncrono por natureza no domínio síncrono.

**Estrutura:** dois flip-flops em cascata, com *assert* assíncrono e *deassert* síncrono.

```
KEY[0] ──────────────┐ (assíncrono, ativo-baixo)
                     │
              ┌──────▼──────┐     ┌─────────────┐
    1'b1 ────►│ D         Q ├────►│ D         Q ├────► aresetn
              │   ff1       │     │   ff2       │      (síncrono)
         clk ►│>         R̅ │     │>         R̅ │
              └──────▲──────┘     └──────▲──────┘
                     └───────────────────┘
                        reset assíncrono
```

- **Assert assíncrono:** ao pressionar o botão, o reset é afirmado imediatamente, sem esperar o clock. Isso é desejável, pois um reset precisa funcionar mesmo que o clock esteja ausente.
- **Deassert síncrono:** ao liberar, `1'b1` propaga por dois ciclos antes de chegar a `aresetn`, garantindo que todos os registradores saiam do reset no mesmo ciclo.

**Conversão de polaridade:** a IP usa `rst_i` ativo-**alto** e assíncrono (`always @(posedge clk_i or posedge rst_i)`), enquanto a fronteira AXI usa `aresetn` ativo-**baixo**. A conversão `rst_i = ~aresetn` é feita em `axi_interface_subordinate_sram`, aplicada ao sinal **já sincronizado**.

### §5.2 `sram_io_buffer`

**Responsabilidade:** resolver o barramento bidirecional `SRAM_DQ` (R-08, L-01).

**Problema que resolve:** a IP expõe entrada e saída de dados como portas separadas, sem indicar quando dirigir o barramento. A placa tem um barramento único. Sem um sinal de direção, a FPGA dirigiria `DQ` permanentemente e entraria em **contenção** com a SRAM durante a leitura — as duas tentando impor níveis opostos no mesmo fio, o que degrada o sinal e pode danificar os dispositivos.

**Estrutura:**

```verilog
// Conceitual, não é o RTL final
assign SRAM_DQ      = data_out_enable ? data_out_q : 16'bz;
assign data_in_w    = SRAM_DQ;
```

**Geração de `data_out_enable`:** derivada do estado da FSM da controladora, com a regra:

```
data_out_enable = (acesso é escrita) AND (estado está na janela de dado válido)
```

**Regra crítica de turnaround:** `data_out_enable` deve cair **antes** de `OE_N` descer num acesso de leitura subsequente, e subir **depois** de `OE_N` subir. A folha de dados dá tHZOE = 4 ns (máximo) para a SRAM liberar o barramento após `OE_N` subir. A 20 ns de período, um ciclo de folga entre a desativação da leitura e a ativação da escrita é suficiente, e a FSM deve garantir esse ciclo. Verificado em T-U-IOB.

**Registradores de pino:** `data_out_q`, o endereço e os controles devem ser registrados fisicamente nas células de I/O, para que o atraso de saída seja previsível. Como os atributos da IP são de Xilinx (L-04), isso é declarado no `.qsf` (§8.2).

### §5.3 `axi_address_decoder`

**Responsabilidade:** implementar R-15 conforme §4.3.

**Portas:** passagem AXI4 completa (entrada do mestre, saída para a IP) mais a geração própria de respostas de erro.

**FSM:**

```
        ┌─────────────────────────────────────────┐
        │                                         │
        ▼                                         │
   ┌─────────┐  endereço válido    ┌────────────┐ │
   │  IDLE   │────────────────────►│ PASSTHROUGH│ │
   │         │                     │  (para IP) │ │
   │ avalia  │  fora de faixa      └──────┬─────┘ │
   │  faixa  │────────┐                   │ fim   │
   └─────────┘        │                   └───────┘
                      ▼
            ┌───────────────────┐
            │   ERROR_DRAIN     │  emite arlen+1 beats DECERR
            │                   │  (leitura) ou consome W e
            │ conta beats       │  emite 1 B DECERR (escrita)
            └─────────┬─────────┘
                      │ último beat (rlast)
                      └──────────► IDLE
```

| Estado | Condição de saída | Próximo estado | Ação |
|---|---|---|---|
| `IDLE` | `arvalid`/`awvalid`, endereço na faixa **e** tamanho válido | `PASSTHROUGH` | Encaminha ao `axi_transaction_manager` |
| `IDLE` | `arvalid`/`awvalid` e fora da faixa | `ERROR_DRAIN` | Captura `len` e `id`; não encaminha; resposta = **DECERR** |
| `IDLE` | `arvalid`/`awvalid` e `AxSIZE > 0b010` | `ERROR_DRAIN` | Captura `len` e `id`; não encaminha; resposta = **SLVERR** |
| `PASSTHROUGH` | burst concluído | `IDLE` | — |
| `ERROR_DRAIN` | contador de beats ≠ 0 | `ERROR_DRAIN` | Emite beat com o código capturado; decrementa |
| `ERROR_DRAIN` | contador zerado | `IDLE` | Emite `rlast` ou `bvalid` |

**Caminho crítico:** a comparação de faixa é um comparador de magnitude sobre `awaddr[31:21]`. Como a fronteira é potência de dois, reduz-se a `|awaddr[31:21]`, que é um OR reduzido — barato e rápido.

#### §5.3.1 Validação de tamanho (R-21, decisão D11)

Num barramento de 32 bits, `AxSIZE` acima de `0b010` (4 bytes) é **transação ilegal**, pois a norma proíbe que o tamanho exceda a largura do barramento (IHI0022E §A3.4.1: "The size of any transfer must not exceed the data bus width of either agent in the transaction").

**Condição de erro**, avaliada em `IDLE` junto da verificação de faixa:

```
size_invalido = (awvalid && awsize > 3'b010) || (arvalid && arsize > 3'b010)
```

**Códigos de resposta diferenciados.** A FSM `ERROR_DRAIN` é reaproveitada integralmente — muda apenas o valor emitido:

| Condição | Resposta | Semântica |
|---|---|---|
| Endereço fora de `0x0`–`0x1FFFFF` | **DECERR** (`2'b11`) | Erro de decodificação: não existe subordinado nesse endereço |
| `AxSIZE > 0b010` | **SLVERR** (`2'b10`) | O subordinado existe, mas não atende essa transferência |

**Precedência:** se ambas as condições ocorrerem, **DECERR tem precedência**, pois sem endereço válido não há subordinado para recusar o tamanho.

> A distinção entre os dois códigos não é cosmética: ela informa ao mestre se o problema está no **mapa de endereços** (reconfigurar o destino) ou na **transação** (reconfigurar o tamanho).

### §5.3.2 Nota de implementação

O decoder valida o tamanho **antes** de encaminhar, logo o `axi_transaction_manager` nunca recebe `AxSIZE` inválido e não precisa tratá-lo. Isso mantém a lógica de tamanho do fork restrita aos três casos legais (§5.4.1).

### §5.4 `axi_transaction_manager` (fork da IP — D10)

**A partir da v0.2 este módulo é um fork**, derivado de `asram16_axi4_pmem.v` (Ultra-Embedded, LGPL). O original permanece no repositório **sem alteração alguma**, como referência e por exigência de rastreabilidade da licença. A lista completa das alterações está em §5.4.5.

**Nota sobre as referências de linha:** os números de linha citados nesta seção referem-se ao arquivo original, e permanecem válidos no fork, pois as alterações são pontuais e preservam a estrutura. Isso é deliberado: mantém o `diff` legível e permite que esta especificação sirva para os dois arquivos.

**§5.4.1 Geração de endereço de burst (R-19)**

A função `calculate_addr_next` (linha 89) é **alterada no fork** (alteração A2). Na IP original ela incrementava 4 bytes fixos, ignorando `AxSIZE` — a causa raiz de L-07.

**Assinatura nova:** `(addr, axtype, axlen, axsize)`, com `axsize` acrescentado.

```verilog
num_bytes = 32'd1 << axsize;                   // Number_Bytes = 2^AxSIZE
aligned   = addr & ~(num_bytes - 32'd1);       // Aligned_Address

// INCR (caso default, o único ativo):
calculate_addr_next = aligned + num_bytes;     // Address_N

// WRAP (sob `ifdef, desabilitado):
mask = (num_bytes * (axlen + 32'd1)) - 32'd1;  // Wrap_Boundary
calculate_addr_next = (addr & ~mask) | ((aligned + num_bytes) & mask);
```

**Dois pontos críticos da implementação:**

1. **O mascaramento de alinhamento é obrigatório.** A função produz o endereço do beat **seguinte**, que pela norma é `Aligned_Address + (N-1) × Number_Bytes`. Escrever `addr + num_bytes` sem mascarar propagaria um desalinhamento inicial por todo o burst (ver §4.2.1). Caso de teste dedicado: T-U-SZ-004.
2. **A máscara de WRAP passa a depender do tamanho.** A tabela fixa das linhas 106-113 do original assumia 4 bytes por beat e estava errada para qualquer outro tamanho. A forma `num_bytes × (axlen+1) - 1` é a `Wrap_Boundary` da norma e vale para todos os casos.

**Captura do tamanho (alteração A3):** o registrador `req_axsize_q` acompanha `req_axlen_q` e `req_axburst_q`, capturado nos mesmos três pontos (linhas 182, 192 e 204).

> **Armadilha a evitar:** nas chamadas das linhas 183 e 202, que calculam o endereço do **segundo** beat no mesmo ciclo em que o comando é aceito, deve-se usar o sinal de entrada (`axi_awsize_i`/`axi_arsize_i`), **não** o registrado — este só é atualizado na borda seguinte. Confundir os dois faz o segundo beat usar o tamanho da transação **anterior**. Caso de teste dedicado: T-S-SZ-007.

**FIXED e WRAP:** continuam sob `` `ifdef ``, caindo no `default` que é INCR (R-14). **Decisão mantida:** os defines não serão habilitados na Fase 1. WRAP é usado sobretudo por caches de linha, que não existem neste projeto, e FIXED é raro. A correção da máscara entra ainda assim, para não deixar código errado latente no caso de habilitação futura.

**§5.4.2 Ordenação de respostas (normativo, R-03)**

> Esta é a parte do módulo que cumpre uma exigência da norma, e por isso merece distinção do que é mera implementação.

O AXI4 exige que respostas de um mesmo ID retornem na ordem de emissão (IHI0022E §A5.3). Quem garante isso **não é o árbitro**, mas o **FIFO de requisições** instanciado na linha 255.

**Na IP original** o FIFO carregava 6 bits:

```verilog
asram16_axi4_pmem_fifo2 #( .WIDTH(1 + 1 + 4) ) u_requests ( ... );
// {é_leitura, é_último, id}
```

**No fork (alteração A5)** ele carrega 11 bits, para transportar também o contexto de alinhamento exigido pela regra 8 do contrato (§3.2):

```verilog
axi_transaction_fifo #( .WIDTH(1 + 1 + 4 + 2 + 3) ) u_requests ( ... );
```

| Bits | Campo | Uso |
|---|---|---|
| 10 | `é_leitura` | Distingue resposta R de B |
| 9 | `é_último` | Gera `rlast` e libera `bvalid` |
| 8:5 | `id` | Devolve `rid`/`bid` |
| **4:3** | **`addr[1:0]`** | **Novo (A5): posicionamento de byte lane (§5.6)** |
| **2:0** | **`size`** | **Novo (A5): largura do beat (§5.6)** |

> **Declaração explícita, por se tratar de requisito normativo:** o **mecanismo de ordenação não muda** — apenas a largura dos dados transportados. R-03 continua sendo cumprido pelo mesmo FIFO estritamente ordenado, com a mesma profundidade. A regressão da suíte T-S-ORD após esta alteração é **obrigatória**, não opcional, porque alargar a estrutura exige reindexar todos os campos e um erro de índice corromperia a ordenação de forma silenciosa.

**Consequência inalterada:** a profundidade de 4 limita as transações em voo (R-13). Um mestre que emita mais de 4 beats sem receber resposta verá `awready`/`arready` baixarem. Isso não é erro, e sim controle de fluxo.

**§5.4.3 Geração de `rlast` e `bvalid`**

`rlast` vem do bit `é_último` do FIFO. `bvalid` só é afirmado quando a resposta é de escrita **e** é a última do burst (linha 333), e as respostas intermediárias de escrita são descartadas em `resp_accept_w` (linha 344). Isso cumpre R-05.

**§5.4.4 Arbitragem leitura/escrita (D5, não normativa)**

> **O AXI4 não especifica política de arbitragem.** A norma define cinco canais independentes e deliberadamente omite quem é atendido primeiro quando leitura e escrita concorrem — isso é escolha de implementação. O termo *round-robin* não aparece na IHI0022E.

**Por que arbitrar é necessário:** a exigência vem da **placa, não da norma**. `SRAM_DQ[15:0]` é um barramento físico único (R-08), logo dois canais AXI independentes disputam um recurso que só atende um por vez.

**Mecanismo da IP:**

```verilog
// linha 195 e 206: alterna a cada comando aceito
req_prio_q <= !req_prio_q;

// linhas 306-307: combina alternância com retenção
wire write_prio_w = ((req_prio_q  & !req_hold_rd_q) | req_hold_wr_q);
wire read_prio_w  = ((!req_prio_q & !req_hold_wr_q) | req_hold_rd_q);
```

Os sinais `req_hold_rd_q` e `req_hold_wr_q` (linhas 218-226) impedem a troca de sentido no meio de um acesso já emitido e ainda não aceito, o que evitaria perder a requisição.

**Granularidade: por comando, não por beat.** Esta consequência precisa estar explícita porque afeta a latência. Os sinais `req_wr_q`/`req_rd_q` mantêm o sentido ativo em `write_active_w`/`read_active_w` (linhas 309-310) enquanto o burst não termina. Logo:

> Um burst de escrita de 256 beats em curso atrasa uma leitura concorrente por **todo o seu comprimento**, não por um beat.

Com o alvo de 4 a 6 ciclos por beat (R-17), isso significa latência de pior caso de **mais de 1000 ciclos**, ou cerca de 20 µs a 50 MHz, para a leitura. Não é inanição, pois a leitura é eventualmente atendida, mas é uma latência de cauda longa, que deve ser medida (T-S-ARB) e registrada, não tratada como falha.

**Comparação com a política atual do projeto:** o `axi_ram_adapter.v:21` usa `assign rd_grant = !wr_en`, prioridade fixa para escrita. Sob escrita contínua, a leitura **nunca** seria atendida — inanição verdadeira. A troca para round-robin é, portanto, uma melhoria de robustez, e é o que justifica D5.

**§5.4.5 Alterações em relação à IP original (v0.2, D10)**

Lista completa e fechada. Qualquer diferença entre `asram16_axi4_pmem.v` e `axi_transaction_manager.v` que **não** esteja nesta lista é alteração não documentada e deve ser revertida ou acrescentada aqui.

| # | Alteração | Motivo | Seção |
|---|---|---|---|
| **A1** | Portas `axi_awsize_i` e `axi_arsize_i` acrescentadas | A IP não recebia o tamanho | §3.1 |
| **A2** | `calculate_addr_next` recebe `axsize` e aplica `Aligned_Address` | Incremento fixo de 4 bytes violava §A3.4.1 | §5.4.1 |
| **A3** | Registrador `req_axsize_q` acrescentado | Preservar o tamanho ao longo do burst | §5.4.1 |
| **A4** | Saída `ram_size_o` acrescentada | A controladora precisa do tamanho na leitura, onde não há strobes | §3.2 |
| **A5** | FIFO de requisições alargado de 6 para 11 bits | Transportar `addr[1:0]` e `size` até a resposta, para o alinhamento | §5.4.2 |
| **A6** | Módulo de FIFO renomeado para `axi_transaction_fifo` | Evitar colisão de definição quando os dois arquivos forem compilados juntos na auditoria por `diff` | — |

**Conformidade com a LGPL.** O cabeçalho do fork preserva integralmente o aviso de copyright da Ultra-Embedded e acrescenta uma nota de obra derivada com esta mesma lista. O arquivo original permanece no repositório sem alteração, de modo que a procedência e o escopo das modificações sejam verificáveis por `diff`.

**Por que A6 é obrigatória e não cosmética.** O módulo de FIFO está definido **dentro** do mesmo arquivo da IP (linha 351). Compilar os dois arquivos no mesmo comando — necessário para a auditoria por `diff` e para testes comparativos — produziria duas definições com o mesmo nome e erro de compilação.

### §5.5 `sram_controller` (Fase 2 — núcleo do desempenho)

**Responsabilidade:** implementar o contrato `ram_*` (§3.2) com desempenho conforme R-17.

> O pipeline é a **técnica interna** deste módulo, descrita aqui. Conforme §0.4 regra 3, ela não entra no nome do módulo.

**§5.5.1 Fundamento: por que o pipeline é possível**

A SRAM é **assíncrona**: não tem clock, não tem comando, não tem latência de inicialização. Aplicar um endereço e esperar tAA = 10 ns é tudo o que uma leitura exige. Em particular, **nada impede que o próximo endereço seja apresentado no mesmo ciclo em que o dado atual é capturado**.

A FSM da IP não explora isso: ela apresenta o endereço, espera, captura, e só então apresenta o seguinte, com estados de espera dedicados entre cada passo. O custo é de cerca de 16 ciclos por beat de 32 bits, somando as duas metades de 16 bits.

**§5.5.2 Estrutura da FSM**

Com período de 20 ns e tAA de 10 ns, **um ciclo de clock é suficiente para um acesso de leitura**, pois o endereço fica estável por 20 ns, acima dos 10 ns exigidos. A escrita exige atenção ao pulso de `WE_N` (tPWE1 = 8 ns) e ao setup de dado (tSD = 6 ns), ambos também acomodáveis em um ciclo, conforme §6.2.

```
      ┌──────┐  requisição de leitura   ┌──────────┐
      │ IDLE │─────────────────────────►│ RD_LOW   │ apresenta A, captura
      │      │                          └─────┬────┘ nada ainda
      │      │                                │
      │      │                          ┌─────▼────┐
      │      │                          │ RD_HIGH  │ apresenta A+1,
      │      │◄─────────────────────────┤          │ captura D_low
      │      │   sem próxima requisição └─────┬────┘
      │      │                                │ captura D_high,
      │      │   próxima leitura pendente     │ emite ram_ack
      │      │◄───────────────────────────────┘
      │      │        (vai direto a RD_LOW, sem passar por IDLE)
      │      │
      │      │  requisição de escrita   ┌──────────┐
      │      │─────────────────────────►│ WR_LOW   │ A, D_low, WE_N=0
      │      │                          └─────┬────┘
      │      │                          ┌─────▼────┐
      │      │                          │ WR_HIGH  │ A+1, D_high, WE_N
      │      │◄─────────────────────────┤          │ pulsa; ram_ack
      │      │                          └──────────┘
      └──────┘
```

**§5.5.3 Orçamento de ciclos**

| Operação | Estados | Ciclos | Observação |
|---|---|---|---|
| Leitura isolada | `RD_LOW` → `RD_HIGH` → `IDLE` | 3 | Inclui retorno a IDLE |
| Leitura em regime (burst) | `RD_LOW` → `RD_HIGH` → `RD_LOW` … | **2** | Sem passar por IDLE |
| Escrita isolada | `WR_LOW` → `WR_HIGH` → `IDLE` | 3 | — |
| Escrita em regime | `WR_LOW` → `WR_HIGH` → `WR_LOW` … | **2** | — |
| Escrita parcial (só `wstrb[1:0]`) | `WR_LOW` → `IDLE` | 1–2 | Dispensa a metade alta |

**Resultado: 2 ciclos por beat de 32 bits em regime permanente**, o que supera a meta de 4 a 6 ciclos de R-17. A margem acomoda ciclos extras de turnaround (§5.5.4) e eventual necessidade de espera adicional se o orçamento de timing de §6.2 se mostrar otimista na placa.

**§5.5.4 Condições de contorno**

| Caso | Tratamento |
|---|---|
| **Burst de 1 beat** | Caminho isolado de 3 ciclos. Sem pipeline a explorar |
| **Turnaround leitura→escrita** | Um ciclo de espera entre liberar `OE_N` e ativar `data_out_enable`, conforme §5.2. A FSM inclui um estado de transição ou condiciona a saída de IDLE |
| **Escrita parcial** | `wstrb` = `4'b0011` acessa só a metade baixa; `4'b1100`, só a alta; `4'b0000` não acessa a SRAM e responde `ram_ack` imediatamente. `LB_N`/`UB_N` vêm de `~wstrb` da metade corrente |
| **`ram_accept` durante acesso** | A controladora aceita a próxima requisição no último estado do acesso corrente, sustentando o pipeline de duas requisições em voo |
| **Reset no meio do acesso** | `WE_N`, `OE_N` e `data_out_enable` vão a inativo de forma assíncrona, para não corromper a SRAM nem deixar o barramento em contenção. É o caso que justifica o *assert* assíncrono de §5.1 |

**§5.5.5 Caminho crítico**

O caminho mais longo é `ram_addr` → lógica de seleção de metade → registrador de endereço → pino. Por ser registrado no pino, a parcela interna é apenas a lógica de seleção, que é um multiplexador estreito. A folga esperada é ampla a 50 MHz.

### §5.6 `axi_narrow_read_align` (R-20, v0.2)

**Responsabilidade:** posicionar o dado lido da memória na byte lane que a norma determina para aquele beat. Módulo **puramente combinacional**, sem estado nem clock.

**Problema que resolve.** A SRAM sempre entrega 32 bits alinhados. A norma, porém, exige que numa leitura estreita o dado apareça em lanes específicas, que **variam a cada beat** do burst (IHI0022E §A3.4.3):

> "When a master generates a transfer that is narrower than its data bus, the address and control information determine which byte lanes the transfer uses: in incrementing or wrapping bursts, **different byte lanes are used on each beat of the burst**."

Sem este módulo, todo beat entregaria o dado nas mesmas lanes, e um mestre correto leria o byte errado em três de cada quatro beats.

**Equações implementadas** (§A3.4.1):

```
Lower_Byte_Lane = Address_N - INT(Address_N / 4) × 4   =  addr[1:0]
Upper_Byte_Lane = Lower_Byte_Lane + Number_Bytes - 1
Dado em: RDATA[(8 × Upper_Byte_Lane) + 7 : (8 × Lower_Byte_Lane)]
```

**Interface:**

| Sinal | Dir | Largura | Descrição |
|---|---|---|---|
| `rdata_raw` | in | 32 | Dado alinhado, vindo da memória |
| `addr_lo` | in | 2 | `addr[1:0]` do beat, recuperado do FIFO (§5.4.2) |
| `axsize` | in | 3 | Tamanho do beat, recuperado do FIFO |
| `rdata_aligned` | out | 32 | Dado posicionado na lane correta |

**Tabela completa de posicionamento** (todos os casos legais e alinhados):

| `axsize` | `addr[1:0]` | Lanes válidas | Operação sobre `rdata_raw` |
|---|---|---|---|
| `0b010` (4 B) | `00` | `[31:0]` | Passagem direta |
| `0b001` (2 B) | `00` | `[15:0]` | `{raw[15:0], raw[15:0]}` |
| `0b001` (2 B) | `10` | `[31:16]` | `{raw[31:16], raw[31:16]}` |
| `0b000` (1 B) | `00` | `[7:0]` | `{4{raw[7:0]}}` |
| `0b000` (1 B) | `01` | `[15:8]` | `{4{raw[15:8]}}` |
| `0b000` (1 B) | `10` | `[23:16]` | `{4{raw[23:16]}}` |
| `0b000` (1 B) | `11` | `[31:24]` | `{4{raw[31:24]}}` |

**Lanes não usadas (decisão D12).** A replicação acima é escolha de projeto, **não exigência normativa**: procurei na IHI0022E e não há cláusula que determine o valor das lanes não transferidas — a Figura A3-8 apenas as sombreia como "bytes que não são transferidos". A replicação faz o dado aparecer em todas as lanes, de modo que um mestre que leia a lane correta obtenha o byte certo, e um mestre com máscara frouxa obtenha o mesmo byte em vez de zeros espúrios. É o comportamento mais tolerante. Registrado em **P-06** para confirmação com o mestre real; trocar para zeros é uma alteração de uma linha.

**Casos desalinhados.** `axsize = 0b001` com `addr[1:0]` ∈ {`01`, `11`} é transferência de 2 bytes desalinhada. A norma a permite (§A3.4.3, "Unaligned transfers", e "the slave is not required to take special action based on any alignment information"), mas atendê-la exigiria dois acessos à SRAM de 16 bits. **Tratamento:** passagem direta, registrado em **P-07**. A combinação exige um mestre deliberadamente desalinhado, que este projeto não prevê.

**Casos ilegais.** `axsize > 0b010` nunca chega a este módulo, pois é barrado pelo `axi_address_decoder` (§5.3.1).

**Ponto de instanciação.** Entre a saída do FIFO de resposta do `axi_transaction_manager` e a porta `s_axi_rdata` do wrapper. A escolha de ficar **depois** do FIFO é deliberada: o endereço e o tamanho do beat já estão no FIFO de requisições (§5.4.2), de modo que o contexto chega naturalmente junto da resposta, sem caminho paralelo e sem risco de dessincronização.

**Fronteira de autoria.** O alinhamento fica **fora** do fork, em módulo próprio de autoria integral do projeto. Alternativa descartada: alinhar dentro do fork, o que reduziria o número de arquivos mas misturaria lógica nova com código derivado de terceiros, prejudicando o `diff` auditável que D10 exige.

---

## §6 Temporização

### §6.1 Domínio de clock único e ausência de CDC (justificativa de D2)

**O que é CDC.** *Clock Domain Crossing* ocorre quando um dado sai de um registrador comandado por um clock e entra em outro comandado por um clock diferente. Se a transição do dado cair perto da borda de captura, o flip-flop de destino pode entrar em **metaestabilidade**: a saída fica num nível indefinido, nem 0 nem 1, por tempo imprevisível. Pior, dois flip-flops que leiam o mesmo sinal podem resolver para valores **diferentes**, levando uma FSM a um estado inválido. É falha intermitente, que não aparece em simulação RTL e se manifesta de forma esporádica na placa.

**D2 elimina a classe inteira de problema.** Com um único clock de 50 MHz vindo do oscilador da placa (R-10), **todos os registradores do projeto pertencem ao mesmo domínio** e nenhum dado atravessa fronteira. Em consequência, este projeto **não tem**:

- sincronizadores de dois flip-flops para sinais de controle entre domínios;
- FIFO assíncrono com ponteiros em código Gray;
- constraints de `set_false_path` ou `set_max_skew` entre domínios.

**Custo da alternativa descartada.** Com AXI a 100 MHz e SRAM em domínio mais lento, a fronteira `ram_*` (§3.2) passaria a ser uma travessia de domínio. Seria preciso um FIFO assíncrono exatamente ali, com toda a verificação associada, e o contrato de §3.2 teria de especificar latência de travessia. O ganho de barramento não justifica esse custo num projeto cuja memória é o gargalo.

#### §6.1.1 Por que a SRAM assíncrona não constitui um CDC

Este ponto é contraintuitivo e precisa estar escrito, porque a conclusão errada leva a uma implementação pior.

A SRAM **não tem pino de clock**, o que sugere a existência de um "segundo domínio" ao qual a FPGA se conectaria. **Não existe segundo domínio.** A razão é que a SRAM **não amostra nada**: ela se comporta como lógica combinacional com atraso de propagação. Aplicado um endereço, após tAA o dado aparece e permanece. Não há borda de clock interna que possa capturar um sinal em transição, logo não há metaestabilidade possível do lado da memória.

O único elemento que amostra é o **flip-flop de entrada da FPGA**, comandado pelo clock único do projeto. Portanto:

> O problema **não é CDC, é timing de caminho combinacional**. Resolve-se com orçamento de tempo (§6.2) e constraints (§6.4), não com sincronizadores.

**Antipadrão a evitar.** Inserir um sincronizador de dois flip-flops em `sram_data_in` seria um **erro**: acrescentaria um ciclo de latência a cada leitura, degradando R-17, **sem mitigar risco algum**, porque não há metaestabilidade a mitigar. É o tipo de "cuidado" que parece defensivo e apenas custa desempenho.

**Única sincronização de fato necessária:** o **reset** (§5.1). E nem esse é CDC entre dois clocks: é a entrada de um sinal **assíncrono por natureza** — um botão, sem relação com clock algum — no domínio síncrono. Daí o padrão de *assert* assíncrono com *deassert* síncrono.

### §6.2 Orçamento de timing do caminho da SRAM

**Premissas** (folha de dados ISSI Rev. G, IS61WV102416BLL, grau **-10**, conforme D8):

| Parâmetro | Valor | Significado |
|---|---|---|
| tRC | 10 ns (mín.) | Tempo de ciclo de leitura |
| **tAA** | **10 ns (máx.)** | Endereço válido até dado válido |
| tOHA | 2,5 ns (mín.) | Dado permanece após mudança de endereço |
| tDOE | 6,5 ns (máx.) | `OE_N` até dado válido |
| tHZOE | 4 ns (máx.) | `OE_N` inativo até alta impedância |
| **tWC** | **10 ns (mín.)** | Tempo de ciclo de escrita |
| tPWE1 | 8 ns (mín.) | Largura do pulso de `WE_N`, com `OE_N` alto |
| tPWE2 | 10 ns (mín.) | Largura do pulso de `WE_N`, com `OE_N` baixo |
| tAW | 8 ns (mín.) | Endereço válido até fim da escrita |
| **tSD** | **6 ns (mín.)** | Setup de dado antes do fim da escrita |
| **tHD** | **0 ns (mín.)** | Hold de dado após o fim da escrita |
| tSA | 0 ns (mín.) | Setup de endereço |

> **Por que o grau -10 e não o -8 (D8):** a folha de dados especifica 8 ns apenas para `Vdd` de 3,3 V **+ 5%**, enquanto 10 ns vale para a faixa de 2,4 V a 3,6 V. A DE2-115 alimenta a SRAM em 3,3 V nominal (R-11), sem garantia do limite superior, logo o grau -10 é a premissa correta. Assumir -8 seria otimista e poderia resultar em falha intermitente na placa.

**Orçamento de leitura, em um ciclo de 20 ns:**

| Parcela | Estimativa | Fonte |
|---|---|---|
| Clock-to-out do registrador de pino da FPGA | ~3 ns | A confirmar no TimeQuest (P-02) |
| Atraso de propagação na placa, ida | ~1 ns | Estimativa; trilhas curtas |
| **tAA da SRAM** | **10 ns** | Folha de dados |
| Atraso de propagação na placa, volta | ~1 ns | Estimativa |
| Setup do registrador de entrada da FPGA | ~2 ns | A confirmar no TimeQuest (P-02) |
| **Total** | **~17 ns** | — |
| **Período disponível** | **20 ns** | R-10 |
| **Folga** | **~3 ns** | — |

**Conclusão:** um acesso de leitura cabe em **um ciclo de clock**, sem estado de espera. A folga de 3 ns é estreita, e por isso §6.4 exige confirmação no TimeQuest e §5.5.3 reserva margem no orçamento de ciclos.

**Orçamento de escrita:** o pulso de `WE_N` precisa de 8 ns (tPWE1) e o dado de 6 ns de setup (tSD). Com `WE_N` ativo por um ciclo inteiro de 20 ns e o dado apresentado no mesmo ciclo, ambos são satisfeitos com folga. O hold de dado é tHD = 0 ns, o que dispensa estado extra após o pulso.

**Parametrização da IP para a Fase 1 (L-05):** as esperas padrão de 7 ciclos equivalem a 140 ns por meio-acesso, cerca de 14 vezes o necessário. Conforme este orçamento, `WRITE_WAIT_CYCLES`, `READ_WAIT_CYCLES` e `WRITE_HOLD_CYCLES` devem ser **1**. O valor 0 não é recomendado na Fase 1, pois a FSM da IP usa os estados de espera também para separar as fases do acesso, e removê-los por completo exige análise que a Fase 2 torna desnecessária.

### §6.3 Parâmetros confirmados

Todos os valores de §6.2 provêm da folha de dados **ISSI IS61WV102416ALL/BLL, Rev. G, 06/02/2014**, tabelas "Read Cycle Switching Characteristics" e "Write Cycle Switching Characteristics", coluna do grau **-10**.

Pendência remanescente: os valores de clock-to-out e de setup da FPGA (P-02) são estimativas e só serão conhecidos após a primeira compilação no Quartus.

### §6.4 Requisitos de SDC

```tcl
# Clock da placa (R-10)
create_clock -name clk_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

# Caminhos de saída para a SRAM: endereço, controles e dados
# Os valores dependem do atraso de placa; preencher após a primeira análise
set_output_delay -clock clk_50 -max <tbd> [get_ports {SRAM_ADDR[*] SRAM_DQ[*] SRAM_WE_N SRAM_OE_N SRAM_LB_N SRAM_UB_N}]
set_output_delay -clock clk_50 -min <tbd> [get_ports {SRAM_ADDR[*] SRAM_DQ[*] SRAM_WE_N SRAM_OE_N SRAM_LB_N SRAM_UB_N}]

# Caminho de entrada da SRAM: tAA = 10 ns mais atraso de placa
set_input_delay -clock clk_50 -max 12.000 [get_ports {SRAM_DQ[*]}]
set_input_delay -clock clk_50 -min 1.000  [get_ports {SRAM_DQ[*]}]
```

**Nenhuma constraint entre domínios é necessária**, porque não há CDC (§6.1). Esse é um benefício direto de D2 e mantém o arquivo SDC simples.

---

## §7 Desempenho

### §7.1 Ciclos por beat de 32 bits

| Configuração | Leitura | Escrita | Fonte |
|---|---|---|---|
| IP original, esperas = 7 | ~16 | ~32 | Contagem de estados de `asram16_axi4.v` |
| **Fase 1**, esperas = 1 | ~6 | ~8 | Mesma FSM, esperas reduzidas (§6.2) |
| **Fase 2**, `sram_controller` | **2** | **2** | §5.5.3 |
| Mínimo teórico | 2 | 2 | Dois acessos de 16 bits por beat de 32 |

A Fase 2 **atinge o mínimo teórico** para um barramento de 16 bits, pois cada beat de 32 bits exige necessariamente dois acessos, e cada acesso cabe em um ciclo (§6.2).

### §7.2 Vazão a 50 MHz

| Configuração | Leitura | Escrita |
|---|---|---|
| IP original | ~12 MB/s | ~6 MB/s |
| Fase 1 | ~33 MB/s | ~25 MB/s |
| **Fase 2** | **100 MB/s** | **100 MB/s** |

Cálculo da Fase 2: 4 bytes por beat ÷ (2 ciclos × 20 ns) = 100 MB/s.

> Estes números são **estimativas derivadas da contagem de estados** das FSMs descritas, não medições. T-S-PERF os converte em requisito verificável.

**Impacto do suporte a `AxSIZE` (v0.2): nenhum.** Uma leitura estreita acessa a SRAM exatamente como uma larga — sempre 32 bits, ou seja, dois acessos de 16 bits —, pois o posicionamento de byte lane é puramente combinacional (§5.6) e não acrescenta ciclo algum. Uma escrita estreita pode ser até **mais rápida**, quando o `wstrb` cobre apenas uma das metades e dispensa o segundo acesso (§5.5.4). **Os ciclos por beat não aumentam e R-17 permanece válido.**

### §7.3 Gargalos remanescentes

| Gargalo | Impacto | Custo de remover |
|---|---|---|
| **Barramento de 16 bits** | Limita a 100 MB/s; é o teto físico | Impossível: é a placa |
| **FIFOs de profundidade 4** (R-13) | Limita transações em voo; pode ociosar a SRAM se o mestre for lento a aceitar respostas | Modificar a IP, contra D1 |
| **Turnaround leitura↔escrita** | Um ciclo perdido a cada troca de sentido | Inerente ao barramento bidirecional |
| **Arbitragem por comando** (§5.4.4) | Latência de cauda longa para o sentido preterido | Arbitragem por beat exigiria reescrever o frontend |

---

## §8 Síntese

### §8.1 Alvo e recursos

- **Dispositivo:** Cyclone IV E, EP4CE115F29C7.
- **Estimativa de recursos:** poucas centenas de elementos lógicos. Os FIFOs da IP têm 4 entradas e serão inferidos como registradores distribuídos, não como RAM de bloco.
- **Nenhuma RAM de bloco deve ser inferida** para a memória de dados: ela é externa. Se o relatório de síntese mostrar inferência de M9K, há erro de ligação.

### §8.2 Requisitos de `.qsf`

Os atributos `synthesis attribute IOB` presentes na IP são de Xilinx e **não têm efeito no Quartus** (L-04). O equivalente precisa ser declarado:

```tcl
# Registradores rápidos nos pinos da SRAM
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_ADDR[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_WE_N
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_OE_N

# Padrão de I/O (R-11)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SRAM_ADDR[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SRAM_DQ[*]
```

A pinagem completa segue a Tabela 4-27 do manual da DE2-115 (§3.3).

---

## §9 Rastreabilidade e pendências

### §9.1 Matriz de rastreabilidade

| Requisito | Módulo responsável | Seção desta MAS | Caso de teste |
|---|---|---|---|
| R-01 | `axi_transaction_manager` | §5.4 | T-S-AXI-001..010 |
| R-02 | `axi_transaction_manager` | §5.4.1 | T-S-AXI-011..015 |
| R-03 | `axi_transaction_manager` (FIFO) | §5.4.2 | T-S-ORD-001..003 |
| R-04, R-05 | `axi_transaction_manager` | §5.4.3 | T-S-AXI-016..018 |
| R-06 | Mestre (checker verifica) | §4.4 | T-S-4KB-001 |
| R-07, R-09, R-15 | `axi_address_decoder` | §4.3, §5.3 | T-U-DEC-001..006 |
| R-08 | `sram_io_buffer` | §5.2 | T-U-IOB-001..004 |
| R-10, R-18 | Projeto inteiro | §6.1 | Síntese |
| R-11 | `.qsf` | §8.2 | Síntese |
| R-12 | `sram_controller` | §5.5, §6.2 | T-S-SRAM-001..005 |
| R-13 | `axi_transaction_manager` | §5.4.2 | T-I-RAM-004 |
| R-14 | `axi_transaction_manager` | §5.4.1 | T-S-AXI-019 |
| R-16 | `axi_transaction_manager` | §5.4.4 | T-S-ARB-001..003 |
| R-17 | `sram_controller` | §5.5.3, §7 | T-S-PERF-001..003 |
| **R-19** | `axi_transaction_manager` | §4.2.1, §5.4.1 | T-U-SZ-001..004 |
| **R-20** | `axi_narrow_read_align` | §5.6 | T-U-SZ-005..008, T-S-SZ-001 |
| **R-21** | `axi_address_decoder` | §5.3.1 | T-S-SZ-005 |

Os identificadores de teste são definidos em `VERIFICATION_PLAN_axi4_sram.md`.

### §9.2 Pendências abertas

| ID | Pendência | Bloqueia | Como fechar |
|---|---|---|---|
| **P-01** | Confirmar a ordem de `sram_be_n_o[1:0]` → `LB_N`/`UB_N` (§3.3) | Escrita parcial correta | Teste T-U-IOB com `wstrb` assimétrico |
| **P-02** | Clock-to-out e setup reais da FPGA (§6.2) | Validação da folga de 3 ns | Primeira compilação com TimeQuest |
| **P-04** | Valores de `set_output_delay` dependem do atraso de placa (§6.4) | Fechamento de timing | Medir ou estimar a partir do esquemático da DE2-115 |
| **P-05** | Decidir se a Fase 2 mantém a IP `asram16_axi4` no repositório como referência | Organização do código | Decisão ao concluir a Fase 2 |
| **P-06** | Confirmar D12 (lanes não usadas em leitura recebem dado replicado) com o mestre real | Nada: é escolha tolerante | Observar o comportamento do mestre. Trocar para zeros é alteração de uma linha em `axi_narrow_read_align` |
| **P-07** | Transferência de 2 bytes desalinhada (`AxSIZE = 0b001`, `addr[1:0]` ímpar) tratada como passagem direta (§5.6) | Conformidade com §A3.4.3 em caso desalinhado | Decidir se há mestre que a emita. Atendê-la exige dois acessos à SRAM de 16 bits |

### §9.2.1 Pendências fechadas

| ID | Pendência | Fechada em | Como foi resolvida |
|---|---|---|---|
| **P-03** | `awsize`/`arsize` ignorados: leitura estreita retornava 32 bits e os endereços do burst eram calculados com incremento fixo de 4 bytes | **v0.2** | Fork `axi_transaction_manager` com `calculate_addr_next` dependente de `AxSIZE` e aplicação de `Aligned_Address` (§5.4.1); módulo `axi_narrow_read_align` para o posicionamento de byte lane (§5.6); validação de tamanho com SLVERR no decoder (§5.3.1). Requisitos R-19, R-20 e R-21. Verificação: área `SZ` do plano de verificação |

> O fechamento de P-03 fica condicionado aos 15 casos da área `SZ` em PASS e à regressão das suítes T-S-AXI, T-S-ORD e T-S-PERF, conforme o critério de saída do plano de verificação.

### §9.3 Trabalho futuro

- Integração com um mestre real, seja processador soft-core ou DMA.
- Avaliação da SDRAM de 128 MB como alternativa de maior capacidade, com controladora própria.
- Reavaliar o habilitamento de WRAP se um mestre com cache for integrado (§5.4.1).

---

## Referências

1. ARM. *AMBA AXI and ACE Protocol Specification*, IHI0022E. Disponível em `docs/AXI4/IHI0022E_amba_axi_and_ace_protocol_spec_4.pdf`.
2. Terasic. *DE2-115 User Manual*, 2013. Disponível em `docs/doc_DE_2_115_cv/`.
3. ISSI. *IS61WV102416ALL/BLL, IS64WV102416BLL — 1024K × 16 CMOS Static RAM with 3.3V Supply*, Rev. G, junho de 2014.
4. Ultra-Embedded. *AXI4 to Async SRAM (16-bit) Interface*, v0.1, 2019. Licença LGPL. Código em `rtl/asram16_axi4.v` e `rtl/asram16_axi4_pmem.v`.
