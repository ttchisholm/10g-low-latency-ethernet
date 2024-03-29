# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../../hdl/pcs/rx_gearbox.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/tx_gearbox.sv


# MODULE is the basename of the Python test file
MODULE ?= test_rx_gearbox


ifeq ($(MODULE), test_tx_gearbox)
	TOPLEVEL ?= tx_gearbox
endif

ifeq ($(MODULE), test_rx_gearbox)
	TOPLEVEL ?= rx_gearbox
endif

export REGISTER_OUTPUT ?= 0

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).REGISTER_OUTPUT=$(REGISTER_OUTPUT)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim


iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf crc32.mem
	@rm -rf dump.fst $(TOPLEVEL).fst