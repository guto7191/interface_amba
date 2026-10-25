# Restricoes de temporizacao (MAS §6.4). Clock unico de 50 MHz, sem CDC: nao ha constraint
# entre dominios (D2).
create_clock -name clk_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

# Saidas para a SRAM: endereco, controles e dado. Valores dependem do atraso de placa (P-04):
# preencher apos a primeira analise no TimeQuest. Enquanto isso, as linhas ficam comentadas.
# set_output_delay -clock clk_50 -max <tbd> [get_ports {SRAM_ADDR[*] SRAM_DQ[*] SRAM_WE_N SRAM_OE_N SRAM_LB_N SRAM_UB_N}]
# set_output_delay -clock clk_50 -min <tbd> [get_ports {SRAM_ADDR[*] SRAM_DQ[*] SRAM_WE_N SRAM_OE_N SRAM_LB_N SRAM_UB_N}]

# Entrada da SRAM: tAA = 10 ns mais atraso de placa
set_input_delay -clock clk_50 -max 12.000 [get_ports {SRAM_DQ[*]}]
set_input_delay -clock clk_50 -min 1.000  [get_ports {SRAM_DQ[*]}]

# KEY[0] e assincrono por natureza; o reset_synchronizer o trata (MAS §5.1)
set_false_path -from [get_ports {KEY[*]}]
