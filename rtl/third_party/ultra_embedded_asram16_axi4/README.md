# IP de terceiros: AXI4 -> Async SRAM (16-bit)

- Origem: Ultra-Embedded, v0.1, 2019 (admin@ultra-embedded.com). Licença: LGPL 2.1 ou posterior.
- **Estes arquivos não podem ser editados** (MAS §0.4 regra 9, D10, D14). `make audit_fork` falha se houver diferença em relação ao `HEAD`.
- Obras derivadas do projeto, com alterações marcadas no código:
  - `asram16_axi4_pmem.v` -> `rtl/axi4_sram/derived/axi_transaction_manager.v` (alterações A1-A7)
  - `asram16_axi4.v`      -> `rtl/sram/derived/sram_controller_baseline.v` (alterações B1-B3)
