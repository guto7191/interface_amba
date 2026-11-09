// sram_agent_pkg.sv - package sram_agent_pkg.
// Cobre: T-S-SRAM, R-12
// TODO: conferir a ordem de dependencia dos includes
package sram_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "sram_agent_cfg.svh"
  `include "sram_seq_item.svh"
  `include "sram_monitor.svh"
  `include "sram_agent.svh"
endpackage : sram_agent_pkg
