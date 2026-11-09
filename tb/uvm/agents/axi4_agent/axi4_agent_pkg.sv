// axi4_agent_pkg.sv - package axi4_agent_pkg.
// Cobre: T-S-AXI
// TODO: conferir a ordem de dependencia dos includes
package axi4_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "axi4_types.svh"
  `include "axi4_agent_cfg.svh"
  `include "axi4_seq_item.svh"
  `include "axi4_sequencer.svh"
  `include "axi4_driver.svh"
  `include "axi4_monitor.svh"
  `include "axi4_agent.svh"
endpackage : axi4_agent_pkg
