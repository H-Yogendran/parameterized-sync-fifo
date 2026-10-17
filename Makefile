# Build + run the FIFO testbench with Icarus Verilog.
#   make           -> run the testbench on every configuration in CONFIGS
#   make sim       -> run only the default configuration (WIDTH=8, DEPTH=4)
#   make waveform  -> regenerate the README waveform VCD (build/waveform/)
#   make wave      -> open the default-configuration waveform in GTKWave
#   make clean     -> remove build outputs
#
# The testbench calls $fatal on any failure, so vvp exits non-zero and make stops.

RTL   := rtl/sync_fifo.v
TB    := tb/sync_fifo_tb.v
TOP   := sync_fifo_tb
BUILD := build

# WIDTH:DEPTH pairs. Covers the smallest legal depth, non-powers of two,
# the RTL default (8x16), and a wide/deep case.
CONFIGS := 8:4 8:2 8:3 8:5 8:16 16:16 32:33

.PHONY: all test sweep sim waveform wave clean

all: sweep
test: sweep

sweep:
	@set -e; for cfg in $(CONFIGS); do \
	  w=$${cfg%%:*}; d=$${cfg##*:}; dir=$(BUILD)/w$${w}_d$${d}; \
	  echo "=== WIDTH=$$w DEPTH=$$d ==="; \
	  mkdir -p $$dir; \
	  iverilog -g2012 -Wall -o $$dir/sim.vvp -s $(TOP) \
	    -P$(TOP).WIDTH=$$w -P$(TOP).DEPTH=$$d $(RTL) $(TB); \
	  (cd $$dir && vvp -n sim.vvp | tee sim.log); \
	  grep -q "TEST PASSED" $$dir/sim.log; \
	done; echo "=== ALL CONFIGURATIONS PASSED ==="

sim:
	@$(MAKE) --no-print-directory sweep CONFIGS=8:4

waveform:
	@mkdir -p $(BUILD)/waveform
	iverilog -g2012 -Wall -o $(BUILD)/waveform/sim.vvp -s waveform_tb $(RTL) tb/waveform_tb.v
	cd $(BUILD)/waveform && vvp -n sim.vvp

wave: sim
	gtkwave $(BUILD)/w8_d4/sync_fifo_tb.vcd &

clean:
	rm -rf $(BUILD)
