# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../../hdl/pcs/encoder_pkg.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/pcs.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/decoder.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/descrambler.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/encode.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/gearbox.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/lock_state.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/scrambler.sv
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = pcs

# MODULE is the basename of the Python test file
MODULE = test_pcs



# module parameters
export SCRAMBLER_BYPASS ?= 0

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).SCRAMBLER_BYPASS=$(SCRAMBLER_BYPASS)

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
	@rm -rf dump.fst $(TOPLEVEL).fst