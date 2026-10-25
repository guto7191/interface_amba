# Atribuicoes do Quartus para a SRAM da DE2-115 (MAS §8.2, §3.3). Dispositivo EP4CE115F29C7.
set_global_assignment -name DEVICE EP4CE115F29C7
set_global_assignment -name TOP_LEVEL_ENTITY de2_115_top

# Registradores rapidos nos pinos da SRAM (substituem os atributos IOB, que sao da Xilinx - L-04)
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_ADDR[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_OUTPUT_ENABLE_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_INPUT_REGISTER ON -to SRAM_DQ[*]
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_WE_N
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_OE_N
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_LB_N
set_instance_assignment -name FAST_OUTPUT_REGISTER ON -to SRAM_UB_N

# Padrao de I/O 3,3 V em todos os pinos da SRAM (R-11)
foreach pin {SRAM_ADDR[*] SRAM_DQ[*] SRAM_OE_N SRAM_WE_N SRAM_CE_N SRAM_LB_N SRAM_UB_N CLOCK_50 KEY[*]} {
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $pin
}

# Pinos citados na MAS §3.3 (Tabela 4-27 do manual). CONFERIR com o manual antes de compilar.
set_location_assignment PIN_AD5 -to SRAM_OE_N
set_location_assignment PIN_AE8 -to SRAM_WE_N
set_location_assignment PIN_AF8 -to SRAM_CE_N
set_location_assignment PIN_AD4 -to SRAM_LB_N
set_location_assignment PIN_AC4 -to SRAM_UB_N
set_location_assignment PIN_AB7 -to SRAM_ADDR[0]
set_location_assignment PIN_T8  -to SRAM_ADDR[19]
set_location_assignment PIN_AH3 -to SRAM_DQ[0]
set_location_assignment PIN_AG3 -to SRAM_DQ[15]
# TODO: SRAM_ADDR[1..18], SRAM_DQ[1..14], CLOCK_50 e KEY[0] - copiar da Tabela 4-27 e da secao de
#       clock/botoes do manual da DE2-115 (docs/doc_DE_2_115_cv/, nao versionado).
