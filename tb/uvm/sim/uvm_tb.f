// uvm_tb.f - lista de compilacao do UVM TB (executar a partir da raiz do repo).
// TODO: confirmar caminhos/flags (-uvm, -timescale) no Xcelium
-incdir tb/uvm/interfaces
-incdir tb/uvm/agents/axi4_agent
-incdir tb/uvm/agents/sram_agent
-incdir tb/uvm/env
-incdir tb/uvm/sequences
-incdir tb/uvm/tests
// RTL do DUT (via filelists) e copias proprias do modelo SRAM e do checker AXI
-f rtl/filelists/axi4_sram_common.f
-f rtl/filelists/axi4_sram_phase2.f
tb/uvm/models/sram_is61wv102416_behavioral_model.v
tb/uvm/checkers/axi_protocol_checker.v
// ordem: interfaces -> pkgs -> bind -> top
tb/uvm/interfaces/axi4_if.sv
tb/uvm/interfaces/sram_if.sv
tb/uvm/agents/sram_agent/sram_agent_pkg.sv
tb/uvm/agents/axi4_agent/axi4_agent_pkg.sv
tb/uvm/env/axi4_sram_env_pkg.sv
tb/uvm/sequences/axi4_sram_seq_pkg.sv
tb/uvm/tests/axi4_sram_test_pkg.sv
tb/uvm/top/axi4_sram_bind.sv
tb/uvm/top/tb_top.sv
