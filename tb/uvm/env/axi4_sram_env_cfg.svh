// axi4_sram_env_cfg.svh - configuracao do ambiente (PHASE, faixa de enderecos, cfgs dos agentes).
// Cobre: VP §3, parametro PHASE
`ifndef AXI4_SRAM_ENV_CFG_SVH
`define AXI4_SRAM_ENV_CFG_SVH

class axi4_sram_env_cfg extends uvm_object;
  `uvm_object_utils(axi4_sram_env_cfg)

  // TODO: PHASE, faixa de enderecos, handles das cfgs dos agentes

  function new(string name = "axi4_sram_env_cfg");
    super.new(name);
  endfunction

endclass : axi4_sram_env_cfg

`endif // AXI4_SRAM_ENV_CFG_SVH
