// GERADO por tb/uvm/sim/bundle_edaplayground.py - NAO EDITAR
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// ==== arquivo: tb/uvm/interfaces/axi4_if.sv ====
// axi4_if.sv - interface AXI4 (ID 4b, ADDR 32b, DATA 32b, STRB 4b, LEN 8b).
// Cobre: T-S-AXI, T-S-ARB, T-S-ORD
// Sinais sem prefixo s_axi_. Sem awlock/awcache/awprot/awqos/*user (MAS §3.1: ignorados).
// aresetn deve vir do reset ja sincronizado do DUT (aresetn_w); ver tb_top.
interface axi4_if (input logic aclk, input logic aresetn);
  logic [3:0]  awid, arid, bid, rid;
  logic [31:0] awaddr, araddr, wdata, rdata;
  logic [7:0]  awlen, arlen;
  logic [2:0]  awsize, arsize;
  logic [1:0]  awburst, arburst, bresp, rresp;
  logic [3:0]  wstrb;
  logic        awvalid, awready, arvalid, arready;
  logic        wvalid, wready, wlast;
  logic        bvalid, bready, rvalid, rready, rlast;

  // Driver (manager): dirige aw*/w*/ar*/bready/rready e amostra as respostas do DUT.
  // output #1ns evita corrida com o RTL; input #1step le o valor pre-borda.
  clocking drv_cb @(posedge aclk);
    default input #1step output #1ns;
    output awid, awaddr, awlen, awsize, awburst, awvalid;
    output wdata, wstrb, wlast, wvalid;
    output arid, araddr, arlen, arsize, arburst, arvalid;
    output bready, rready;
    input  awready, wready, arready;
    input  bid, bresp, bvalid;
    input  rid, rdata, rresp, rlast, rvalid;
  endclocking : drv_cb

  // Monitor: todos os sinais como input.
  clocking mon_cb @(posedge aclk);
    default input #1step;
    input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
    input wdata, wstrb, wlast, wvalid, wready;
    input bid, bresp, bvalid, bready;
    input arid, araddr, arlen, arsize, arburst, arvalid, arready;
    input rid, rdata, rresp, rlast, rvalid, rready;
  endclocking : mon_cb

  modport DRV (clocking drv_cb, input aresetn);
  modport MON (clocking mon_cb, input aresetn);
endinterface : axi4_if

// ==== arquivo: tb/uvm/interfaces/sram_if.sv ====
// sram_if.sv - pinos da SRAM IS61WV102416 (1M x 16); somente observacao.
// Cobre: T-S-SRAM, R-12
// NOTA: a SRAM e assincrona e captura a escrita na subida de we_n. O mon_cb amostra por aclk
// e so ve o que esta estavel na borda. O sram_monitor decide se tambem precisa de
// @(posedge we_n) (nao implementado aqui).
interface sram_if (input logic aclk);
  logic [19:0] addr;
  wire  [15:0] dq;
  logic        oe_n, we_n, lb_n, ub_n, ce_n;

  clocking mon_cb @(posedge aclk);
    default input #1step;
    input addr, dq, oe_n, we_n, lb_n, ub_n, ce_n;
  endclocking : mon_cb

  modport MON (clocking mon_cb);
endinterface : sram_if

// ==== arquivo: tb/uvm/agents/sram_agent/sram_agent_pkg.sv ====
// sram_agent_pkg.sv - package sram_agent_pkg.
// Cobre: T-S-SRAM, R-12
// TODO: conferir a ordem de dependencia dos includes
package sram_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
// ---- inicio sram_agent_cfg.svh ----
// sram_agent_cfg.svh - configuracao do agente SRAM (vif, checagem de temporizacao).
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_AGENT_CFG_SVH
`define SRAM_AGENT_CFG_SVH

class sram_agent_cfg extends uvm_object;
  `uvm_object_utils(sram_agent_cfg)

  // TODO: vif sram_if e flag de checagem de temporizacao

  function new(string name = "sram_agent_cfg");
    super.new(name);
  endfunction

endclass : sram_agent_cfg

`endif // SRAM_AGENT_CFG_SVH
// ---- fim sram_agent_cfg.svh ----
// ---- inicio sram_seq_item.svh ----
// sram_seq_item.svh - acesso fisico a SRAM (addr, data, lb/ub, rd/wr, timestamp).
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_SEQ_ITEM_SVH
`define SRAM_SEQ_ITEM_SVH

class sram_seq_item extends uvm_sequence_item;
  `uvm_object_utils(sram_seq_item)

  // TODO: campos addr, data, lb/ub, rd/wr, timestamp

  function new(string name = "sram_seq_item");
    super.new(name);
  endfunction

endclass : sram_seq_item

`endif // SRAM_SEQ_ITEM_SVH
// ---- fim sram_seq_item.svh ----
// ---- inicio sram_monitor.svh ----
// sram_monitor.svh - monitor passivo; amostra pinos da SRAM e checa temporizacao.
// Cobre: T-S-SRAM, R-12
`ifndef SRAM_MONITOR_SVH
`define SRAM_MONITOR_SVH

class sram_monitor extends uvm_monitor;
  `uvm_component_utils(sram_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: amostrar pinos, publicar sram_seq_item e checar temporizacao (R-12)
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: amostrar pinos, publicar sram_seq_item e checar temporizacao (R-12)
  endtask

endclass : sram_monitor

`endif // SRAM_MONITOR_SVH
// ---- fim sram_monitor.svh ----
// ---- inicio sram_agent.svh ----
// sram_agent.svh - agente SRAM, sempre UVM_PASSIVE (so monitor).
// Cobre: T-S-SRAM
`ifndef SRAM_AGENT_SVH
`define SRAM_AGENT_SVH

class sram_agent extends uvm_agent;
  `uvm_component_utils(sram_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar apenas o monitor; forcar UVM_PASSIVE
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de sram_agent
  endfunction

endclass : sram_agent

`endif // SRAM_AGENT_SVH
// ---- fim sram_agent.svh ----
endpackage : sram_agent_pkg

// ==== arquivo: tb/uvm/agents/axi4_agent/axi4_agent_pkg.sv ====
// axi4_agent_pkg.sv - package axi4_agent_pkg.
// Cobre: T-S-AXI
// TODO: conferir a ordem de dependencia dos includes
package axi4_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
// ---- inicio axi4_types.svh ----
// axi4_types.svh - enums e typedefs AXI4 (burst, resp, size).
// Cobre: T-S-AXI, T-S-SZ
`ifndef AXI4_TYPES_SVH
`define AXI4_TYPES_SVH

// TODO: enum burst  {FIXED=0, INCR=1, WRAP=2}
// TODO: enum resp   {OKAY=0, EXOKAY=1, SLVERR=2, DECERR=3}
// TODO: enum size   {SZ_1B=0, SZ_2B=1, SZ_4B=2}  (largura de dado de 32 bits)
// TODO: typedefs de id (4b), addr (32b), data (32b), strb (4b), len (8b)

`endif // AXI4_TYPES_SVH
// ---- fim axi4_types.svh ----
// ---- inicio axi4_agent_cfg.svh ----
// axi4_agent_cfg.svh - configuracao do agente AXI4 (is_active, vif, knobs de backpressure).
// Cobre: VP §3 (todos os T-S-*)
`ifndef AXI4_AGENT_CFG_SVH
`define AXI4_AGENT_CFG_SVH

class axi4_agent_cfg extends uvm_object;
  `uvm_object_utils(axi4_agent_cfg)

  virtual axi4_if vif;

  // TODO: is_active, knobs de backpressure (atrasos de ready/valid)

  function new(string name = "axi4_agent_cfg");
    super.new(name);
  endfunction

endclass : axi4_agent_cfg

`endif // AXI4_AGENT_CFG_SVH
// ---- fim axi4_agent_cfg.svh ----
// ---- inicio axi4_seq_item.svh ----
// axi4_seq_item.svh - transacao AXI4 (rw, id, addr, len, size, burst, data[], strb[], resp[]).
// Cobre: T-S-AXI, T-S-SZ, T-S-ORD
`ifndef AXI4_SEQ_ITEM_SVH
`define AXI4_SEQ_ITEM_SVH

class axi4_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi4_seq_item)

  // TODO: campos rw, id, addr, len, size, burst, data[], strb[], resp[] (sem constraints ainda)

  function new(string name = "axi4_seq_item");
    super.new(name);
  endfunction

endclass : axi4_seq_item

`endif // AXI4_SEQ_ITEM_SVH
// ---- fim axi4_seq_item.svh ----
// ---- inicio axi4_sequencer.svh ----
// axi4_sequencer.svh - sequencer do agente AXI4.
// Cobre: T-S-AXI
`ifndef AXI4_SEQUENCER_SVH
`define AXI4_SEQUENCER_SVH

typedef uvm_sequencer #(axi4_seq_item) axi4_sequencer;
// TODO: trocar por classe propria somente se forem necessarios knobs/arbitragem extras

`endif // AXI4_SEQUENCER_SVH
// ---- fim axi4_sequencer.svh ----
// ---- inicio axi4_driver.svh ----
// axi4_driver.svh - driver manager AXI4; canais AW/W/B/AR/R independentes.
// Cobre: T-S-AXI, T-S-ARB, T-S-ORD, T-S-ROB
`ifndef AXI4_DRIVER_SVH
`define AXI4_DRIVER_SVH

class axi4_driver extends uvm_driver#(axi4_seq_item);
  `uvm_component_utils(axi4_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: driver dos 5 canais com handshake valid/ready e atrasos
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: driver dos 5 canais com handshake valid/ready e atrasos
  endtask

endclass : axi4_driver

`endif // AXI4_DRIVER_SVH
// ---- fim axi4_driver.svh ----
// ---- inicio axi4_monitor.svh ----
// axi4_monitor.svh - monitor AXI4; reconstroi transacoes e publica na analysis_port.
// Cobre: T-S-AXI, T-S-ORD, R-03
`ifndef AXI4_MONITOR_SVH
`define AXI4_MONITOR_SVH

class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: amostrar canais via vif e reconstruir transacoes (ap.write)
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: amostrar canais via vif e reconstruir transacoes (ap.write)
  endtask

endclass : axi4_monitor

`endif // AXI4_MONITOR_SVH
// ---- fim axi4_monitor.svh ----
// ---- inicio axi4_agent.svh ----
// axi4_agent.svh - agente AXI4 (sequencer + driver + monitor).
// Cobre: T-S-AXI
`ifndef AXI4_AGENT_SVH
`define AXI4_AGENT_SVH

class axi4_agent extends uvm_agent;
  `uvm_component_utils(axi4_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar monitor sempre; sequencer/driver se is_active
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_agent
  endfunction

endclass : axi4_agent

`endif // AXI4_AGENT_SVH
// ---- fim axi4_agent.svh ----
endpackage : axi4_agent_pkg

// ==== arquivo: tb/uvm/env/axi4_sram_env_pkg.sv ====
// axi4_sram_env_pkg.sv - package axi4_sram_env_pkg.
// Cobre: VP §3, §4.1
// TODO: conferir a ordem de dependencia dos includes
package axi4_sram_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_agent_pkg::*;
  import sram_agent_pkg::*;
// ---- inicio axi4_sram_env_cfg.svh ----
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
// ---- fim axi4_sram_env_cfg.svh ----
// ---- inicio axi4_sram_ref_model.svh ----
// axi4_sram_ref_model.svh - memoria de referencia 1M x 16 com byte lanes.
// Cobre: T-S-SRAM, T-S-SZ
`ifndef AXI4_SRAM_REF_MODEL_SVH
`define AXI4_SRAM_REF_MODEL_SVH

class axi4_sram_ref_model extends uvm_component;
  `uvm_component_utils(axi4_sram_ref_model)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: alocar memoria 1M x 16 e metodos de leitura/escrita com strb
  endfunction

endclass : axi4_sram_ref_model

`endif // AXI4_SRAM_REF_MODEL_SVH
// ---- fim axi4_sram_ref_model.svh ----
// ---- inicio axi4_sram_scoreboard.svh ----
// axi4_sram_scoreboard.svh - scoreboard: AXI esperado x observado; ordenacao por ID.
// Cobre: T-S-AXI, T-S-ORD, R-03
`ifndef AXI4_SRAM_SCOREBOARD_SVH
`define AXI4_SRAM_SCOREBOARD_SVH

class axi4_sram_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_sram_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: comparar respostas AXI com ref_model e checar ordem por ID
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_sram_scoreboard
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: comparar respostas AXI com ref_model e checar ordem por ID
  endtask

endclass : axi4_sram_scoreboard

`endif // AXI4_SRAM_SCOREBOARD_SVH
// ---- fim axi4_sram_scoreboard.svh ----
// ---- inicio axi4_sram_coverage.svh ----
// axi4_sram_coverage.svh - cobertura funcional (covergroups).
// Cobre: VP §4.1
`ifndef AXI4_SRAM_COVERAGE_SVH
`define AXI4_SRAM_COVERAGE_SVH

class axi4_sram_coverage extends uvm_subscriber#(axi4_seq_item);
  `uvm_component_utils(axi4_sram_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: definir covergroups (burst, len, size, id, resp) e amostrar em write()
  endfunction

  // uvm_subscriber exige write()
  virtual function void write(axi4_seq_item t);
    // TODO: amostrar covergroups com a transacao t
  endfunction

endclass : axi4_sram_coverage

`endif // AXI4_SRAM_COVERAGE_SVH
// ---- fim axi4_sram_coverage.svh ----
// ---- inicio axi4_sram_virtual_sequencer.svh ----
// axi4_sram_virtual_sequencer.svh - sequenciador virtual com handle do sequencer AXI4.
// Cobre: T-S-ARB
`ifndef AXI4_SRAM_VIRTUAL_SEQUENCER_SVH
`define AXI4_SRAM_VIRTUAL_SEQUENCER_SVH

class axi4_sram_virtual_sequencer extends uvm_sequencer#(uvm_sequence_item);
  `uvm_component_utils(axi4_sram_virtual_sequencer)

  // TODO: handle do axi4_sequencer (atribuido no connect_phase do env)
  // axi4_sequencer axi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: declarar handle axi4_sequencer
  endfunction

endclass : axi4_sram_virtual_sequencer

`endif // AXI4_SRAM_VIRTUAL_SEQUENCER_SVH
// ---- fim axi4_sram_virtual_sequencer.svh ----
// ---- inicio axi4_sram_env.svh ----
// axi4_sram_env.svh - ambiente: agentes, ref_model, scoreboard, coverage.
// Cobre: VP §3
`ifndef AXI4_SRAM_ENV_SVH
`define AXI4_SRAM_ENV_SVH

class axi4_sram_env extends uvm_env;
  `uvm_component_utils(axi4_sram_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar agentes/scoreboard/coverage; conectar analysis ports
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TODO: conectar portas/exports/vif de axi4_sram_env
  endfunction

endclass : axi4_sram_env

`endif // AXI4_SRAM_ENV_SVH
// ---- fim axi4_sram_env.svh ----
endpackage : axi4_sram_env_pkg

// ==== arquivo: tb/uvm/sequences/axi4_sram_seq_pkg.sv ====
// axi4_sram_seq_pkg.sv - package axi4_sram_seq_pkg.
// Cobre: T-S-AXI, T-S-SZ, T-S-ORD, T-S-ARB, T-S-ROB
// TODO: conferir a ordem de dependencia dos includes
package axi4_sram_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_agent_pkg::*;
  import axi4_sram_env_pkg::*;
// ---- inicio axi4_base_seq.svh ----
// axi4_base_seq.svh - sequencia base (utilitarios comuns).
// Cobre: VP §3
`ifndef AXI4_BASE_SEQ_SVH
`define AXI4_BASE_SEQ_SVH

class axi4_base_seq extends uvm_sequence#(axi4_seq_item);
  `uvm_object_utils(axi4_base_seq)

  function new(string name = "axi4_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: utilitarios comuns (obter cfg, helpers de leitura/escrita)
  endtask

endclass : axi4_base_seq

`endif // AXI4_BASE_SEQ_SVH
// ---- fim axi4_base_seq.svh ----
// ---- inicio axi4_single_rw_seq.svh ----
// axi4_single_rw_seq.svh - sequencia: escrita/leitura de um beat.
// Cobre: T-S-AXI
`ifndef AXI4_SINGLE_RW_SEQ_SVH
`define AXI4_SINGLE_RW_SEQ_SVH

class axi4_single_rw_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_single_rw_seq)

  function new(string name = "axi4_single_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: escrita/leitura de um beat
  endtask

endclass : axi4_single_rw_seq

`endif // AXI4_SINGLE_RW_SEQ_SVH
// ---- fim axi4_single_rw_seq.svh ----
// ---- inicio axi4_burst_seq.svh ----
// axi4_burst_seq.svh - sequencia: bursts INCR/WRAP/FIXED, len 0..255.
// Cobre: T-S-AXI
`ifndef AXI4_BURST_SEQ_SVH
`define AXI4_BURST_SEQ_SVH

class axi4_burst_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_burst_seq)

  function new(string name = "axi4_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: bursts INCR/WRAP/FIXED, len 0..255
  endtask

endclass : axi4_burst_seq

`endif // AXI4_BURST_SEQ_SVH
// ---- fim axi4_burst_seq.svh ----
// ---- inicio axi4_narrow_seq.svh ----
// axi4_narrow_seq.svh - sequencia: acessos narrow (AxSIZE < 2, byte lanes).
// Cobre: T-S-SZ
`ifndef AXI4_NARROW_SEQ_SVH
`define AXI4_NARROW_SEQ_SVH

class axi4_narrow_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_narrow_seq)

  function new(string name = "axi4_narrow_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: acessos narrow (AxSIZE < 2, byte lanes)
  endtask

endclass : axi4_narrow_seq

`endif // AXI4_NARROW_SEQ_SVH
// ---- fim axi4_narrow_seq.svh ----
// ---- inicio axi4_id_ordering_seq.svh ----
// axi4_id_ordering_seq.svh - sequencia: ordenacao por ID.
// Cobre: T-S-ORD, R-03
`ifndef AXI4_ID_ORDERING_SEQ_SVH
`define AXI4_ID_ORDERING_SEQ_SVH

class axi4_id_ordering_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_id_ordering_seq)

  function new(string name = "axi4_id_ordering_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: ordenacao por ID
  endtask

endclass : axi4_id_ordering_seq

`endif // AXI4_ID_ORDERING_SEQ_SVH
// ---- fim axi4_id_ordering_seq.svh ----
// ---- inicio axi4_concurrent_rw_seq.svh ----
// axi4_concurrent_rw_seq.svh - sequencia: leitura e escrita concorrentes (round-robin).
// Cobre: T-S-ARB
`ifndef AXI4_CONCURRENT_RW_SEQ_SVH
`define AXI4_CONCURRENT_RW_SEQ_SVH

class axi4_concurrent_rw_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_concurrent_rw_seq)

  function new(string name = "axi4_concurrent_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: leitura e escrita concorrentes (round-robin)
  endtask

endclass : axi4_concurrent_rw_seq

`endif // AXI4_CONCURRENT_RW_SEQ_SVH
// ---- fim axi4_concurrent_rw_seq.svh ----
// ---- inicio axi4_error_seq.svh ----
// axi4_error_seq.svh - sequencia: endereco fora da faixa / SLVERR/DECERR (decoder).
// Cobre: T-S-ROB
`ifndef AXI4_ERROR_SEQ_SVH
`define AXI4_ERROR_SEQ_SVH

class axi4_error_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_error_seq)

  function new(string name = "axi4_error_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: endereco fora da faixa / SLVERR/DECERR (decoder)
  endtask

endclass : axi4_error_seq

`endif // AXI4_ERROR_SEQ_SVH
// ---- fim axi4_error_seq.svh ----
// ---- inicio axi4_random_stress_seq.svh ----
// axi4_random_stress_seq.svh - sequencia: estresse aleatorio.
// Cobre: T-S-ROB
`ifndef AXI4_RANDOM_STRESS_SEQ_SVH
`define AXI4_RANDOM_STRESS_SEQ_SVH

class axi4_random_stress_seq extends axi4_base_seq;
  `uvm_object_utils(axi4_random_stress_seq)

  function new(string name = "axi4_random_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    // TODO: estresse aleatorio
  endtask

endclass : axi4_random_stress_seq

`endif // AXI4_RANDOM_STRESS_SEQ_SVH
// ---- fim axi4_random_stress_seq.svh ----
endpackage : axi4_sram_seq_pkg

// ==== arquivo: tb/uvm/tests/axi4_sram_test_pkg.sv ====
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
// ---- inicio axi4_sram_base_test.svh ----
// axi4_sram_base_test.svh - teste base: constroi env/cfg, le vif do config_db, timeout.
// Cobre: VP §3
`ifndef AXI4_SRAM_BASE_TEST_SVH
`define AXI4_SRAM_BASE_TEST_SVH

class axi4_sram_base_test extends uvm_test;
  `uvm_component_utils(axi4_sram_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: criar cfg/env, obter vifs do config_db, configurar timeout
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: criar cfg/env, obter vifs do config_db, configurar timeout
  endtask

endclass : axi4_sram_base_test

`endif // AXI4_SRAM_BASE_TEST_SVH
// ---- fim axi4_sram_base_test.svh ----
// ---- inicio axi4_sram_smoke_test.svh ----
// axi4_sram_smoke_test.svh - teste: teste de fumaca (escrita+leitura simples).
// Cobre: T-S-AXI
`ifndef AXI4_SRAM_SMOKE_TEST_SVH
`define AXI4_SRAM_SMOKE_TEST_SVH

class axi4_sram_smoke_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: teste de fumaca (escrita+leitura simples)
  endtask

endclass : axi4_sram_smoke_test

`endif // AXI4_SRAM_SMOKE_TEST_SVH
// ---- fim axi4_sram_smoke_test.svh ----
// ---- inicio axi4_sram_burst_test.svh ----
// axi4_sram_burst_test.svh - teste: bursts INCR/WRAP/FIXED.
// Cobre: T-S-AXI
`ifndef AXI4_SRAM_BURST_TEST_SVH
`define AXI4_SRAM_BURST_TEST_SVH

class axi4_sram_burst_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_burst_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: bursts INCR/WRAP/FIXED
  endtask

endclass : axi4_sram_burst_test

`endif // AXI4_SRAM_BURST_TEST_SVH
// ---- fim axi4_sram_burst_test.svh ----
// ---- inicio axi4_sram_narrow_test.svh ----
// axi4_sram_narrow_test.svh - teste: acessos narrow.
// Cobre: T-S-SZ
`ifndef AXI4_SRAM_NARROW_TEST_SVH
`define AXI4_SRAM_NARROW_TEST_SVH

class axi4_sram_narrow_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_narrow_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: acessos narrow
  endtask

endclass : axi4_sram_narrow_test

`endif // AXI4_SRAM_NARROW_TEST_SVH
// ---- fim axi4_sram_narrow_test.svh ----
// ---- inicio axi4_sram_ordering_test.svh ----
// axi4_sram_ordering_test.svh - teste: ordenacao por ID.
// Cobre: T-S-ORD, R-03
`ifndef AXI4_SRAM_ORDERING_TEST_SVH
`define AXI4_SRAM_ORDERING_TEST_SVH

class axi4_sram_ordering_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_ordering_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: ordenacao por ID
  endtask

endclass : axi4_sram_ordering_test

`endif // AXI4_SRAM_ORDERING_TEST_SVH
// ---- fim axi4_sram_ordering_test.svh ----
// ---- inicio axi4_sram_arbitration_test.svh ----
// axi4_sram_arbitration_test.svh - teste: arbitragem round-robin.
// Cobre: T-S-ARB
`ifndef AXI4_SRAM_ARBITRATION_TEST_SVH
`define AXI4_SRAM_ARBITRATION_TEST_SVH

class axi4_sram_arbitration_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_arbitration_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: arbitragem round-robin
  endtask

endclass : axi4_sram_arbitration_test

`endif // AXI4_SRAM_ARBITRATION_TEST_SVH
// ---- fim axi4_sram_arbitration_test.svh ----
// ---- inicio axi4_sram_perf_test.svh ----
// axi4_sram_perf_test.svh - teste: desempenho (ciclos/beat).
// Cobre: T-S-PERF
`ifndef AXI4_SRAM_PERF_TEST_SVH
`define AXI4_SRAM_PERF_TEST_SVH

class axi4_sram_perf_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_perf_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: desempenho (ciclos/beat)
  endtask

endclass : axi4_sram_perf_test

`endif // AXI4_SRAM_PERF_TEST_SVH
// ---- fim axi4_sram_perf_test.svh ----
// ---- inicio axi4_sram_error_test.svh ----
// axi4_sram_error_test.svh - teste: enderecos invalidos / respostas de erro.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_ERROR_TEST_SVH
`define AXI4_SRAM_ERROR_TEST_SVH

class axi4_sram_error_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: enderecos invalidos / respostas de erro
  endtask

endclass : axi4_sram_error_test

`endif // AXI4_SRAM_ERROR_TEST_SVH
// ---- fim axi4_sram_error_test.svh ----
// ---- inicio axi4_sram_reset_test.svh ----
// axi4_sram_reset_test.svh - teste: reset no meio de uma transacao.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_RESET_TEST_SVH
`define AXI4_SRAM_RESET_TEST_SVH

class axi4_sram_reset_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_reset_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: reset no meio de uma transacao
  endtask

endclass : axi4_sram_reset_test

`endif // AXI4_SRAM_RESET_TEST_SVH
// ---- fim axi4_sram_reset_test.svh ----
// ---- inicio axi4_sram_random_test.svh ----
// axi4_sram_random_test.svh - teste: estresse aleatorio com seeds.
// Cobre: T-S-ROB
`ifndef AXI4_SRAM_RANDOM_TEST_SVH
`define AXI4_SRAM_RANDOM_TEST_SVH

class axi4_sram_random_test extends axi4_sram_base_test;
  `uvm_component_utils(axi4_sram_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // TODO: iniciar sequencia(s) de: estresse aleatorio com seeds
  endtask

endclass : axi4_sram_random_test

`endif // AXI4_SRAM_RANDOM_TEST_SVH
// ---- fim axi4_sram_random_test.svh ----
endpackage : axi4_sram_test_pkg

// ==== arquivo: tb/uvm/top/axi4_sram_bind.sv ====
// axi4_sram_bind.sv - bind do axi_protocol_checker (copia em tb/uvm/checkers/) ao DUT.
// Cobre: T-S-AXI (conformidade de protocolo)
// Observa os pinos s_axi_* do wrapper axi_interface_subordinate_sram (aresetn ja sincronizado).
// TIMEOUT/RESP_TIMEOUT ficam nos padroes (200/2000). A porta errors fica em u_chk.errors;
// quem le esse contador e falha o teste sera definido no plano do scoreboard.
  bind axi_interface_subordinate_sram axi_protocol_checker #(.AXI4_FULL(1)) u_chk (
    .aclk(aclk), .aresetn(aresetn),
    .awaddr(s_axi_awaddr), .awvalid(s_axi_awvalid), .awready(s_axi_awready),
    .wdata(s_axi_wdata), .wstrb(s_axi_wstrb), .wvalid(s_axi_wvalid), .wready(s_axi_wready),
    .bresp(s_axi_bresp), .bvalid(s_axi_bvalid), .bready(s_axi_bready),
    .araddr(s_axi_araddr), .arvalid(s_axi_arvalid), .arready(s_axi_arready),
    .rdata(s_axi_rdata), .rresp(s_axi_rresp), .rvalid(s_axi_rvalid), .rready(s_axi_rready),
    .errors(),
    .awid(s_axi_awid), .awlen(s_axi_awlen), .awsize(s_axi_awsize), .awburst(s_axi_awburst),
    .wlast(s_axi_wlast),
    .bid(s_axi_bid),
    .arid(s_axi_arid), .arlen(s_axi_arlen), .arsize(s_axi_arsize), .arburst(s_axi_arburst),
    .rid(s_axi_rid), .rlast(s_axi_rlast));

// ==== arquivo: tb/uvm/top/tb_top.sv ====
// tb_top.sv - topo: clock 50 MHz, reset, DUT #(PHASE), modelo SRAM, ifs, config_db, run_test().
// Cobre: VP §3 (todos), R-12
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi4_sram_test_pkg::*;

  // Fase do DUT (padrao 2); override opcional por -defparam tb_top.PHASE=1
  parameter PHASE = 2;

  // clock de 50 MHz (periodo 20 ns)
  logic aclk = 0;
  always #10 aclk = ~aclk;

  // reset: KEY[0] ativo-baixo por 4 ciclos; o DUT o sincroniza (aresetn_w)
  logic [3:0] key = 4'hE;
  initial begin
    repeat (4) @(posedge aclk);
    key[0] = 1'b1;
  end

  // a axi_if usa o reset ja sincronizado do DUT
  wire aresetn_axi = dut.aresetn_w;

  axi4_if axi_if (aclk, aresetn_axi);
  sram_if sram_if_i (aclk);

  // saidas de observacao do modelo da SRAM
  wire [31:0] sram_errors, sram_access_count, sram_we_pulse_count;

  de2_115_top #(.PHASE(PHASE)) dut (
    .CLOCK_50(aclk), .KEY(key),
    .SRAM_ADDR(sram_if_i.addr), .SRAM_DQ(sram_if_i.dq),
    .SRAM_OE_N(sram_if_i.oe_n), .SRAM_WE_N(sram_if_i.we_n),
    .SRAM_CE_N(sram_if_i.ce_n), .SRAM_LB_N(sram_if_i.lb_n), .SRAM_UB_N(sram_if_i.ub_n),
    .s_axi_awid(axi_if.awid), .s_axi_awaddr(axi_if.awaddr), .s_axi_awlen(axi_if.awlen),
    .s_axi_awsize(axi_if.awsize), .s_axi_awburst(axi_if.awburst),
    .s_axi_awvalid(axi_if.awvalid), .s_axi_awready(axi_if.awready),
    .s_axi_wdata(axi_if.wdata), .s_axi_wstrb(axi_if.wstrb), .s_axi_wlast(axi_if.wlast),
    .s_axi_wvalid(axi_if.wvalid), .s_axi_wready(axi_if.wready),
    .s_axi_bid(axi_if.bid), .s_axi_bresp(axi_if.bresp),
    .s_axi_bvalid(axi_if.bvalid), .s_axi_bready(axi_if.bready),
    .s_axi_arid(axi_if.arid), .s_axi_araddr(axi_if.araddr), .s_axi_arlen(axi_if.arlen),
    .s_axi_arsize(axi_if.arsize), .s_axi_arburst(axi_if.arburst),
    .s_axi_arvalid(axi_if.arvalid), .s_axi_arready(axi_if.arready),
    .s_axi_rid(axi_if.rid), .s_axi_rdata(axi_if.rdata), .s_axi_rresp(axi_if.rresp),
    .s_axi_rlast(axi_if.rlast), .s_axi_rvalid(axi_if.rvalid), .s_axi_rready(axi_if.rready));

  // modelo comportamental da SRAM (copia propria em tb/uvm/models/)
  sram_is61wv102416_behavioral_model sram_model (
    .addr(sram_if_i.addr), .dq(sram_if_i.dq),
    .ce_n(sram_if_i.ce_n), .oe_n(sram_if_i.oe_n), .we_n(sram_if_i.we_n),
    .lb_n(sram_if_i.lb_n), .ub_n(sram_if_i.ub_n),
    .sample_clk(aclk),
    .errors(sram_errors), .access_count(sram_access_count),
    .we_pulse_count(sram_we_pulse_count));

  initial begin
    uvm_config_db#(virtual axi4_if)::set(null, "*", "axi_vif", axi_if);
    uvm_config_db#(virtual sram_if)::set(null, "*", "sram_vif", sram_if_i);
    run_test();
  end

  // formas de onda opcionais (+dump)
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("tb_top.vcd");
      $dumpvars(0, tb_top);
    end
  end
endmodule : tb_top

