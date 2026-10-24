IV     = iverilog -g2012 -Wall -Irtl -I.
RTL    = rtl/ram.v rtl/axi_slave_write.v rtl/axi_slave_read.v rtl/axi_ram_adapter.v rtl/axi_interface_subordinate_ram.v
CHK    = tb/common/axi_protocol_checker.v
BUILD  = build

# cada teste imprime "RESULT: PASS" ou "RESULT: FAIL"; a receita falha se nao houver PASS
RUN    = vvp -n $(BUILD)/$(1) | tee $(BUILD)/$(1).log; grep -q "RESULT: PASS" $(BUILD)/$(1).log

.PHONY: all test test_ram test_write test_read test_top test_param lint wave clean
all: test
test: test_ram test_write test_read test_top

$(BUILD):
	mkdir -p $(BUILD)

test_ram: | $(BUILD)
	$(IV) -o $(BUILD)/tb_ram rtl/ram.v tb/unit/tb_ram.v
	@$(call RUN,tb_ram)

test_write: | $(BUILD)
	$(IV) -o $(BUILD)/tb_write rtl/axi_slave_write.v $(CHK) tb/unit/tb_write.v
	@$(call RUN,tb_write)

test_read: | $(BUILD)
	$(IV) -o $(BUILD)/tb_read rtl/axi_slave_read.v $(CHK) tb/unit/tb_read.v
	@$(call RUN,tb_read)

test_top: | $(BUILD)
	$(IV) -o $(BUILD)/tb_top $(RTL) $(CHK) tb/top/tb_top.v
	@$(call RUN,tb_top)

# repete o teste de topo com outros parametros (continua mesmo se uma configuracao falhar)
PARAMS = DATA_WIDTH=64 DEPTH=1 DEPTH=2 DEPTH=64 ADDR_WIDTH=16
test_param: | $(BUILD)
	@for p in $(PARAMS); do \
	  echo "== tb_top $$p =="; \
	  $(IV) -Ptb_top.$$p -o $(BUILD)/tb_top_p $(RTL) $(CHK) tb/top/tb_top.v && \
	  vvp -n $(BUILD)/tb_top_p | grep -E "RESULT|FAIL" | sort | uniq -c | head -5; \
	done

lint: | $(BUILD)
	$(IV) -o /dev/null $(RTL)

wave: | $(BUILD)
	$(IV) -o $(BUILD)/tb_top $(RTL) $(CHK) tb/top/tb_top.v && vvp -n $(BUILD)/tb_top +dump

clean:
	rm -rf $(BUILD)
