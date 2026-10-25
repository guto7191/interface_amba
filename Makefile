IV       = iverilog -g2012 -Wall -Irtl/include -I.
FL_LITE  = -c rtl/filelists/axi4_lite_ram.f
CHK      = tb/common/axi_protocol_checker.v
LITE_TB  = tb/axi4_lite_ram
BUILD    = build

# cada teste imprime "RESULT: PASS" ou "RESULT: FAIL"; a receita falha se nao houver PASS
RUN    = vvp -n $(BUILD)/$(1) | tee $(BUILD)/$(1).log; grep -q "RESULT: PASS" $(BUILD)/$(1).log

.PHONY: all test test_regress test_ram test_write test_read test_top test_param lint wave clean
all: test
test: test_ram test_write test_read test_top
# T-S-REG-001..005: regressao do caminho AXI4-Lite
test_regress: test test_param

$(BUILD):
	mkdir -p $(BUILD)

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
