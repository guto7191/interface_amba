// axi4_sram_seq_pkg.sv - package axi4_sram_seq_pkg.
// Cobre: T-S-AXI, T-S-SZ, T-S-ORD, T-S-ARB, T-S-ROB
// TODO: conferir a ordem de dependencia dos includes
package axi4_sram_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_agent_pkg::*;
  import axi4_sram_env_pkg::*;
  `include "axi4_base_seq.svh"
  `include "axi4_single_rw_seq.svh"
  `include "axi4_burst_seq.svh"
  `include "axi4_narrow_seq.svh"
  `include "axi4_id_ordering_seq.svh"
  `include "axi4_concurrent_rw_seq.svh"
  `include "axi4_error_seq.svh"
  `include "axi4_random_stress_seq.svh"
endpackage : axi4_sram_seq_pkg
