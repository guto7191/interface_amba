// axi4_sram_env_pkg.sv - package axi4_sram_env_pkg.
// Cobre: VP §3, §4.1
// TODO: conferir a ordem de dependencia dos includes
package axi4_sram_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_agent_pkg::*;
  import sram_agent_pkg::*;
  `include "axi4_sram_env_cfg.svh"
  `include "axi4_sram_ref_model.svh"
  `include "axi4_sram_scoreboard.svh"
  `include "axi4_sram_coverage.svh"
  `include "axi4_sram_virtual_sequencer.svh"
  `include "axi4_sram_env.svh"
endpackage : axi4_sram_env_pkg
