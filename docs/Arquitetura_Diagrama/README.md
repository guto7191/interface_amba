# Diagrama de arquitetura — subordinado AXI4 + SRAM (Fase 2)

Arquivo: [`arquitetura_axi4_sram_fase2.drawio`](arquitetura_axi4_sram_fase2.drawio). Abrir em
[diagrams.net](https://app.diagrams.net) ou na extensão "Draw.io Integration" do VS Code.

Representa a arquitetura **implementada** com `PHASE = 2` (padrão de `de2_115_top`). Os nomes de
módulos, instâncias e sinais são os do RTL; as decisões (Dn), requisitos (R-nn) e seções (§) citados
são os da [MAS](../MAS_axi4_sram.md).

## Páginas

| Página | Conteúdo | Fontes |
|---|---|---|
| **Fase 2 — Visão geral** | Diagrama de blocos no estilo da figura ARM NIC-400: mestre AXI4 no topo, `axi_address_decoder`, `axi_transaction_manager` (fork), `axi_narrow_read_align`, fronteira do contrato `ram_*`, `sram_controller`, `sram_io_buffer` e a SRAM externa. `sram_controller_baseline` aparece como alternativa não instanciada | MAS §2, §0.3; `rtl/board/de2_115_top.v`, `rtl/axi4_sram/axi_interface_subordinate_sram.v` |
| **Fase 2 — Sinais e contrato ram_*** | Um sinal (ou um canal AXI) por ligação, com largura; tabela de bits do FIFO de requisições; regras normativas do contrato `ram_*` | MAS §3.1–§3.3, §5.4.2; portas do RTL |
| **sram_controller — FSM com pipeline** | Os 7 estados e as transições do `always @*`, com as transições de pipeline em destaque; linhas do tempo de leitura (2 ciclos/beat) e escrita (4 ciclos/beat); orçamento de ciclos | MAS §5.5; `rtl/sram/sram_controller.v` |

## Legenda de cores

A MAS não define cores; elas codificam a **origem** (§0.3) e a **camada de diretório** (§0.4 regra 9).

| Cor | Hex | Significado |
|---|---|---|
| Azul escuro | `#0091BD` | Agente externo AXI4 (fora do escopo, §1.2) |
| Verde | `#95D600` | `rtl/axi4_sram/` — autoria do projeto |
| Verde com borda laranja tracejada | `#95D600` / `#E07B00` | `rtl/axi4_sram/derived/` — fork LGPL (D10) |
| Ciano | `#00C1DE` | `rtl/sram/` — controladora |
| Ciano claro | `#7FE0EE` | `rtl/sram/` — buffer de pinos / tri-state |
| Roxo | `#8C6BB1` | `rtl/board/` |
| Cinza médio | `#7D868C` | Componente da placa / externo |
| Contorno cinza tracejado | `#9AA0A4` | Alternativa não instanciada (`PHASE = 1`) |
| Faixas cinza-claras | `#E6E8E9`, `#D3D7D9` | Hierarquia: `de2_115_top`, `axi_interface_subordinate_sram` |

| Ligação | Significado |
|---|---|
| Preta | Canal AXI4 (seta no sentido do payload; *ready* corre ao contrário) |
| Laranja | Contrato `ram_*`; tracejada = fronteira do contrato |
| Azul | Sinais da SRAM; grossa com duas pontas = `SRAM_DQ` (inout) |
| Cinza pontilhada | Clock e reset |
| Verde grossa | Transição de pipeline (página 3) |

`⁄ N` sobre uma ligação = largura em bits. Sem marcador = 1 bit.

## Observações

- `ram_size` chega ao `sram_controller`, mas não é usado: a leitura é sempre de 32 bits (comentário em `sram_controller.v`).
- `ram_len_o` e `ram_error_i` existem no fork, mas não fazem parte do contrato; `ram_error_i` é ligado a `1'b0`.
- Nenhuma divergência entre o RTL e a MAS foi encontrada nos pontos representados.
