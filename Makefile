TB       = tb/testbench_legado
IV       = iverilog -g2012 -Wall -Wno-portbind -Irtl/include -I. -I$(TB)
FL_LITE  = -c rtl/filelists/axi4_lite_ram.f
CHK      = $(TB)/common/axi_protocol_checker.v
LITE_TB  = $(TB)/axi4_lite_ram
BUILD    = build

# cada teste imprime "RESULT: PASS" ou "RESULT: FAIL"; a receita falha se nao houver PASS
RUN    = vvp -n $(BUILD)/$(1) | tee $(BUILD)/$(1).log; grep -q "RESULT: PASS" $(BUILD)/$(1).log

.PHONY: all test_all coverage report cov_reset test_system test_s_axi test_s_ord test_s_arb test_s_perf test_s_sram test_s_rob test_s_sz test_s_rob_seeds test_s_sram_pessimistic test_integ test_i_ram test_i_stub test_i_equiv test_unit test_u_rst test_u_iob test_u_ctl test_u_ctl1 test_u_align test_u_atm test_u_dec audit_fork test_neg test_regress test_ram test_write test_read test_top test_param lint wave clean
all: test
test: test_ram test_write test_read test_top
# T-S-REG-001..005: regressao do caminho AXI4-Lite
test_regress: test test_param

$(BUILD):
	mkdir -p $(BUILD)

MODEL    = $(TB)/models/sram_is61wv102416_behavioral_model.v
SRAM_P2  = rtl/sram/sram_io_buffer.v rtl/sram/sram_controller.v

# compila e roda um testbench: $(1)=nome do binario, $(2)=fontes
define BUILD_RUN
	$(IV) -o $(BUILD)/$(1) $(2)
	@$(call RUN,$(1))
endef

# ---------------- relatorio e execucao completa ----------------
cov_reset:
	@mkdir -p $(BUILD)/cov; rm -f $(BUILD)/cov/*.cov

coverage:
	scripts/merge_functional_coverage_bins.sh

report:
	scripts/generate_verification_report.sh

# U -> I -> S, mais regressao Lite, negativos e auditoria dos forks; relatorio ao final
test_all: cov_reset
	$(MAKE) test_regress test_neg audit_fork test_unit test_integ test_system
	$(MAKE) report

# ---------------- nivel S: sistema ----------------
# cada testbench roda nas duas fases (2 = pipeline, 1 = fork da IP); +TEST=<id> e +SEED=<n> repassados
SYS_PHASES = 2 1
SEED      ?= 1
SEEDS      = 11 22 33 44 55 66 77 88 99 111
SYS_FILES  = $(MODEL) $(CHK)

# $(1)=nome do modulo de teste
define SYS_RUN
	@set -e; for ph in $(SYS_PHASES); do \
	  echo "== $(1) PHASE=$$ph"; \
	  $(IV) -s $(1) -P$(1).PHASE=$$ph -o $(BUILD)/$(1)_p$$ph -c rtl/filelists/axi4_sram_common.f -c rtl/filelists/axi4_sram_phase$$ph.f $(SYS_FILES) $(TB)/system/$(1).v; \
	  vvp -n $(BUILD)/$(1)_p$$ph +SEED=$(SEED) | tee $(BUILD)/$(1)_p$$ph.log | grep -E "RESULT|CASE.*FAIL|INFO: T-S"; \
	  grep -q "RESULT: PASS" $(BUILD)/$(1)_p$$ph.log; \
	done
endef

S_AXI  = tb_system_axi4_protocol_compliance_and_bursts
S_ORD  = tb_system_axi4_response_ordering_by_id
S_ARB  = tb_system_read_write_round_robin_arbitration
S_PERF = tb_system_throughput_cycles_per_beat
S_SRAM = tb_system_sram_datasheet_timing_compliance
S_ROB  = tb_system_robustness_reset_and_random_stress
S_SZ   = tb_system_narrow_transfers_axsize_byte_lanes

test_system: test_s_axi test_s_ord test_s_arb test_s_perf test_s_sram test_s_sram_pessimistic test_s_rob test_s_rob_seeds test_s_sz

test_s_axi:  | $(BUILD) ; $(call SYS_RUN,$(S_AXI))
test_s_ord:  | $(BUILD) ; $(call SYS_RUN,$(S_ORD))
test_s_arb:  | $(BUILD) ; $(call SYS_RUN,$(S_ARB))
test_s_perf: | $(BUILD) ; $(call SYS_RUN,$(S_PERF))
test_s_sram: | $(BUILD) ; $(call SYS_RUN,$(S_SRAM))
test_s_rob:  | $(BUILD) ; $(call SYS_RUN,$(S_ROB))
test_s_sz:   | $(BUILD) ; $(call SYS_RUN,$(S_SZ))

# T-S-SRAM-006: repete T-S-SRAM-001..005 com tAA = 12 ns no modelo (premissa de D8). Informativo:
# uma falha aqui nao quebra o build, mas aparece no relatorio como margem real.
test_s_sram_pessimistic: | $(BUILD)
	@echo "== $(S_SRAM) T_AA=12 (T-S-SRAM-006, informativo)"
	@$(IV) -s $(S_SRAM) -P$(S_SRAM).SRAM_T_AA=12.0 -o $(BUILD)/$(S_SRAM)_aa12 -c rtl/filelists/axi4_sram_common.f -c rtl/filelists/axi4_sram_phase2.f $(SYS_FILES) $(TB)/system/$(S_SRAM).v
	@vvp -n $(BUILD)/$(S_SRAM)_aa12 | tee $(BUILD)/$(S_SRAM)_aa12.log | grep -E "RESULT|CASE.*FAIL"; \
	  if grep -q "RESULT: PASS" $(BUILD)/$(S_SRAM)_aa12.log; then echo "CASE T-S-SRAM-006 [Inform]: PASS (sem violacao com tAA = 12 ns)"; \
	  else echo "CASE T-S-SRAM-006 [Inform]: FAIL (ver $(BUILD)/$(S_SRAM)_aa12.log)"; fi

# T-S-ROB-006: o estresse T-S-ROB-005 com 10 sementes distintas, todas registradas no log
test_s_rob_seeds: | $(BUILD)
	@set -e; $(IV) -s $(S_ROB) -P$(S_ROB).PHASE=2 -o $(BUILD)/$(S_ROB)_seeds -c rtl/filelists/axi4_sram_common.f -c rtl/filelists/axi4_sram_phase2.f $(SYS_FILES) $(TB)/system/$(S_ROB).v; \
	for sd in $(SEEDS); do \
	  vvp -n $(BUILD)/$(S_ROB)_seeds +TEST=T-S-ROB-005 +SEED=$$sd > $(BUILD)/$(S_ROB)_seed$$sd.log; \
	  grep -E "INFO: T-S-ROB-005 SEED" $(BUILD)/$(S_ROB)_seed$$sd.log | tail -1; \
	  grep -q "RESULT: PASS" $(BUILD)/$(S_ROB)_seed$$sd.log || { echo "CASE T-S-ROB-006 [Bloq]: FAIL (semente $$sd)"; exit 1; }; \
	done; echo "CASE T-S-ROB-006 [Bloq]: PASS (10 sementes: $(SEEDS))"

# ---------------- nivel I: integracao ----------------
FL_P1 = -c rtl/filelists/axi4_sram_common.f -c rtl/filelists/axi4_sram_phase1.f
FL_P2 = -c rtl/filelists/axi4_sram_common.f -c rtl/filelists/axi4_sram_phase2.f
T_RAM = tb_integration_ram_contract_handshake_and_ordering
T_STB = tb_integration_ram_contract_backpressure_with_stub
T_EQ  = tb_integration_ram_contract_phase1_vs_phase2_equivalence

test_integ: test_i_ram test_i_stub test_i_equiv

# montagem A (wrapper completo + modelo), nas duas fases
test_i_ram: | $(BUILD)
	$(IV) -s $(T_RAM) -P$(T_RAM).PHASE=2 -o $(BUILD)/tb_i_ram_p2 $(FL_P2) $(MODEL) $(CHK) $(TB)/integration/$(T_RAM).v
	@$(call RUN,tb_i_ram_p2)
	$(IV) -s $(T_RAM) -P$(T_RAM).PHASE=1 -o $(BUILD)/tb_i_ram_p1 $(FL_P1) $(MODEL) $(CHK) $(TB)/integration/$(T_RAM).v
	@$(call RUN,tb_i_ram_p1)

# montagem B (frontend + controladora falsa)
test_i_stub: | $(BUILD)
	$(IV) -s $(T_STB) -o $(BUILD)/tb_i_stub rtl/axi4_sram/derived/axi_transaction_manager.v $(TB)/models/ram_contract_programmable_controller_stub.v $(CHK) $(TB)/integration/$(T_STB).v
	@$(call RUN,tb_i_stub)

# T-I-RAM-007: mesmo roteiro nas duas fases, respostas identicas (cmp)
test_i_equiv: | $(BUILD)
	$(IV) -s $(T_EQ) -P$(T_EQ).PHASE=1 -o $(BUILD)/tb_i_eq1 $(FL_P1) $(MODEL) $(CHK) $(TB)/integration/$(T_EQ).v
	@$(call RUN,tb_i_eq1)
	$(IV) -s $(T_EQ) -P$(T_EQ).PHASE=2 -o $(BUILD)/tb_i_eq2 $(FL_P2) $(MODEL) $(CHK) $(TB)/integration/$(T_EQ).v
	@$(call RUN,tb_i_eq2)
	@if cmp -s $(BUILD)/ram007_p1.txt $(BUILD)/ram007_p2.txt; then \
	   echo "RESULT: PASS T-I-RAM-007 (Fase 1 == Fase 2, $$(wc -l < $(BUILD)/ram007_p2.txt) linhas)" | tee $(BUILD)/T-I-RAM-007.log; \
	 else \
	   echo "RESULT: FAIL T-I-RAM-007 (respostas diferentes entre as fases)" | tee $(BUILD)/T-I-RAM-007.log; \
	   diff $(BUILD)/ram007_p1.txt $(BUILD)/ram007_p2.txt | head -20; exit 1; \
	 fi

# ---------------- nivel U: unitarios ----------------
UNIT_TARGETS = test_u_rst test_u_iob test_u_ctl test_u_ctl1 test_u_align test_u_atm test_u_dec
test_unit: $(UNIT_TARGETS)

test_u_rst: | $(BUILD)
	$(call BUILD_RUN,tb_u_rst,rtl/board/reset_synchronizer.v $(SRAM_P2) $(MODEL) $(TB)/unit/tb_unit_reset_synchronizer_async_assert_sync_release.v)

test_u_iob: | $(BUILD)
	$(call BUILD_RUN,tb_u_iob,$(SRAM_P2) $(MODEL) $(TB)/unit/tb_unit_sram_io_buffer_tristate_and_lane_mapping.v)

test_u_ctl1: | $(BUILD)
	$(call BUILD_RUN,tb_u_ctl1,rtl/sram/sram_io_buffer.v rtl/sram/derived/sram_controller_baseline.v $(MODEL) $(TB)/unit/tb_unit_sram_controller_baseline_phase1_smoke.v)

test_u_dec: | $(BUILD)
	$(call BUILD_RUN,tb_u_dec,rtl/axi4_sram/axi_address_decoder.v $(TB)/models/axi4_downstream_subordinate_stub.v $(CHK) $(TB)/unit/tb_unit_axi_address_decoder_range_and_size_errors.v)

test_u_align: | $(BUILD)
	$(call BUILD_RUN,tb_u_align,rtl/axi4_sram/axi_narrow_read_align.v $(TB)/unit/tb_unit_axi_narrow_read_align_byte_lanes.v)

test_u_atm: | $(BUILD)
	$(call BUILD_RUN,tb_u_atm,rtl/axi4_sram/derived/axi_transaction_manager.v $(TB)/unit/tb_unit_axi_transaction_manager_burst_address_calc.v)

# criterio de saida 13: forks so com as alteracoes registradas; IP original intocada;
# IP + fork compilam juntos (V-06)
THIRD = rtl/third_party/ultra_embedded_asram16_axi4
audit_fork: | $(BUILD)
	scripts/audit_transaction_manager_fork_diff.sh $(THIRD)/asram16_axi4_pmem.v rtl/axi4_sram/derived/axi_transaction_manager.v A
	@git diff --quiet HEAD -- rtl/third_party/ && echo "AUDIT PASS: rtl/third_party/ sem alteracao" || { echo "AUDIT FAIL: rtl/third_party/ foi alterado"; exit 1; }
	scripts/audit_transaction_manager_fork_diff.sh $(THIRD)/asram16_axi4.v rtl/sram/derived/sram_controller_baseline.v B
	$(IV) -o /dev/null -c rtl/filelists/third_party_reference.f rtl/axi4_sram/derived/axi_transaction_manager.v rtl/sram/derived/sram_controller_baseline.v
	@echo "AUDIT PASS: IP original e forks compilam juntos"

test_u_ctl: | $(BUILD)
	$(call BUILD_RUN,tb_u_ctl,$(SRAM_P2) $(MODEL) $(TB)/unit/tb_unit_sram_controller_pipelined_phase2.v)

# T-N-*: testes negativos (PASS quando a assertiva dispara)
test_neg: | $(BUILD)
	$(IV) -o $(BUILD)/tb_neg_sram_model $(MODEL) $(TB)/negative/tb_negative_sram_model_timing_assertions.v
	@$(call RUN,tb_neg_sram_model)
	$(IV) -o $(BUILD)/tb_neg_checker $(CHK) $(TB)/negative/tb_negative_axi_protocol_checker_assertions.v
	@$(call RUN,tb_neg_checker)

test_ram: | $(BUILD)
	$(IV) -o $(BUILD)/tb_ram rtl/axi4_lite_ram/ram.v $(LITE_TB)/tb_ram.v
	@$(call RUN,tb_ram)

test_write: | $(BUILD)
	$(IV) -o $(BUILD)/tb_write rtl/axi4_lite_ram/axi_subordinate_write.v $(CHK) $(LITE_TB)/tb_write.v
	@$(call RUN,tb_write)

test_read: | $(BUILD)
	$(IV) -o $(BUILD)/tb_read rtl/axi4_lite_ram/axi_subordinate_read.v $(CHK) $(LITE_TB)/tb_read.v
	@$(call RUN,tb_read)

test_top: | $(BUILD)
	$(IV) -o $(BUILD)/tb_top $(FL_LITE) $(CHK) $(LITE_TB)/tb_top.v
	@$(call RUN,tb_top)

# repete o teste de topo com outros parametros (continua mesmo se uma configuracao falhar)
PARAMS = DATA_WIDTH=64 DEPTH=1 DEPTH=2 DEPTH=64 ADDR_WIDTH=16
test_param: | $(BUILD)
	@for p in $(PARAMS); do \
	  echo "== tb_top $$p =="; \
	  $(IV) -Ptb_top.$$p -o $(BUILD)/tb_top_p $(FL_LITE) $(CHK) $(LITE_TB)/tb_top.v && \
	  vvp -n $(BUILD)/tb_top_p | grep -E "RESULT|FAIL" | sort | uniq -c | head -5; \
	done

lint: | $(BUILD)
	$(IV) -o /dev/null $(FL_LITE)

wave: | $(BUILD)
	$(IV) -o $(BUILD)/tb_top $(FL_LITE) $(CHK) $(LITE_TB)/tb_top.v && vvp -n $(BUILD)/tb_top +dump

clean:
	rm -rf $(BUILD)
