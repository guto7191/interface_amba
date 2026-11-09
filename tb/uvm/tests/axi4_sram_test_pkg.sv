// axi4_sram_test_pkg.sv - package axi4_sram_test_pkg.
// Cobre: T-S-AXI, T-S-ORD, T-S-ARB, T-S-PERF, T-S-ROB, T-S-SZ
// TODO: conferir a ordem de dependencia dos includes
package axi4_sram_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_agent_pkg::*;
  import sram_agent_pkg::*;
  import axi4_sram_env_pkg::*;
  import axi4_sram_seq_pkg::*;
  `include "axi4_sram_base_test.svh"
  `include "axi4_sram_smoke_test.svh"
  `include "axi4_sram_burst_test.svh"
  `include "axi4_sram_narrow_test.svh"
  `include "axi4_sram_ordering_test.svh"
  `include "axi4_sram_arbitration_test.svh"
  `include "axi4_sram_perf_test.svh"
  `include "axi4_sram_error_test.svh"
  `include "axi4_sram_reset_test.svh"
  `include "axi4_sram_random_test.svh"
endpackage : axi4_sram_test_pkg
