PYTHON ?= python3
CC ?= gcc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Wpedantic -Werror
export IVERILOG ?= iverilog
export VVP ?= vvp
export YOSYS ?= yosys
VERILATOR ?= verilator
BUILD := build

.PHONY: all test test-rtl test-unit test-python test-c vectors sim wave lint synth demo figures clean
all: test
test: test-c test-python test-rtl
$(BUILD):
	mkdir -p $(BUILD)
$(BUILD)/golden: sw/golden.c | $(BUILD)
	$(CC) $(CFLAGS) $< -o $@
$(BUILD)/vector_gen: sw/vector_gen.c | $(BUILD)
	$(CC) $(CFLAGS) $< -o $@
test-c: $(BUILD)/golden
	./$(BUILD)/golden
vectors: $(BUILD)/vector_gen
	./$(BUILD)/vector_gen
	$(PYTHON) tools/generate_vectors.py
test-python:
	$(PYTHON) -m unittest discover -s tests -v
test-rtl:
	$(PYTHON) tools/run_tests.py
test-unit:
	$(PYTHON) tools/run_tests.py --unit
sim: test-rtl
wave:
	$(PYTHON) tools/run_tests.py --module edgegemm_core --vcd
	@echo "Open build/core.vcd with GTKWave."
lint:
	$(VERILATOR) --lint-only -Wall --top-module edgegemm_core -f rtl/files.f
	$(VERILATOR) --lint-only -Wall --top-module edgegemm_top -f rtl/files.f
synth:
	$(PYTHON) tools/synthesize.py
demo: | $(BUILD)
	$(PYTHON) sw/model.py --m 13 --k 37 --n 11 --array 4 --k-max 16 --bits 4 --output $(BUILD)/demo.json
figures:
	$(PYTHON) tools/draw_figures.py
clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"
