IV       = iverilog -g2012 -Wall -Wno-portbind -Irtl/include -I.
FL_LITE  = -c rtl/filelists/axi4_lite_ram.f
CHK      = tb/common/axi_protocol_checker.v
LITE_TB  = tb/axi4_lite_ram
BUILD    = build

# cada teste imprime "RESULT: PASS" ou "RESULT: FAIL"; a receita falha se nao houver PASS
RUN    = vvp -n $(BUILD)/$(1) | tee $(BUILD)/$(1).log; grep -q "RESULT: PASS" $(BUILD)/$(1).log

.PHONY: all test test_unit test_u_rst test_u_iob test_u_ctl test_u_ctl1 test_u_align test_u_atm test_u_dec audit_fork test_neg test_regress test_ram test_write test_read test_top test_param lint wave clean
all: test
test: test_ram test_write test_read test_top
# T-S-REG-001..005: regressao do caminho AXI4-Lite
test_regress: test test_param

$(BUILD):
	mkdir -p $(BUILD)

MODEL    = tb/models/sram_is61wv102416_behavioral_model.v
SRAM_P2  = rtl/sram/sram_io_buffer.v rtl/sram/sram_controller.v

# compila e roda um testbench: $(1)=nome do binario, $(2)=fontes
define BUILD_RUN
	$(IV) -o $(BUILD)/$(1) $(2)
	@$(call RUN,$(1))
endef

# ---------------- nivel U: unitarios ----------------
UNIT_TARGETS = test_u_rst test_u_iob test_u_ctl test_u_ctl1 test_u_align test_u_atm test_u_dec
test_unit: $(UNIT_TARGETS)

test_u_rst: | $(BUILD)
	$(call BUILD_RUN,tb_u_rst,rtl/board/reset_synchronizer.v $(SRAM_P2) $(MODEL) tb/unit/tb_unit_reset_synchronizer_async_assert_sync_release.v)

test_u_iob: | $(BUILD)
	$(call BUILD_RUN,tb_u_iob,$(SRAM_P2) $(MODEL) tb/unit/tb_unit_sram_io_buffer_tristate_and_lane_mapping.v)

test_u_ctl1: | $(BUILD)
	$(call BUILD_RUN,tb_u_ctl1,rtl/sram/sram_io_buffer.v rtl/sram/derived/sram_controller_baseline.v $(MODEL) tb/unit/tb_unit_sram_controller_baseline_phase1_smoke.v)

test_u_dec: | $(BUILD)
	$(call BUILD_RUN,tb_u_dec,rtl/axi4_sram/axi_address_decoder.v tb/models/axi4_downstream_subordinate_stub.v $(CHK) tb/unit/tb_unit_axi_address_decoder_range_and_size_errors.v)

test_u_align: | $(BUILD)
	$(call BUILD_RUN,tb_u_align,rtl/axi4_sram/axi_narrow_read_align.v tb/unit/tb_unit_axi_narrow_read_align_byte_lanes.v)

test_u_atm: | $(BUILD)
	$(call BUILD_RUN,tb_u_atm,rtl/axi4_sram/derived/axi_transaction_manager.v tb/unit/tb_unit_axi_transaction_manager_burst_address_calc.v)

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
	$(call BUILD_RUN,tb_u_ctl,$(SRAM_P2) $(MODEL) tb/unit/tb_unit_sram_controller_pipelined_phase2.v)

# T-N-*: testes negativos (PASS quando a assertiva dispara)
test_neg: | $(BUILD)
	$(IV) -o $(BUILD)/tb_neg_sram_model $(MODEL) tb/negative/tb_negative_sram_model_timing_assertions.v
	@$(call RUN,tb_neg_sram_model)
	$(IV) -o $(BUILD)/tb_neg_checker $(CHK) tb/negative/tb_negative_axi_protocol_checker_assertions.v
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
