# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../../hdl/include/code_defs_pkg.svh
VERILOG_SOURCES += $(PWD)/../../hdl/mac/mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/tx_mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/rx_mac.sv
VERILOG_SOURCES += $(PWD)/../../lib/slicing_crc/hdl/slicing_crc.sv



CUSTOM_SIM_DEPS += crc_tables.mem


# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = mac

# MODULE is the basename of the Python test file
MODULE = test_mac



# module parameters
export DATA_WIDTH ?= 32

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(DATA_WIDTH)
	COMPILE_ARGS += -I $(PWD)/../../hdl/include

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim



crc_tables.mem: $(PWD)/../../lib/slicing_crc/hdl/crc_tables.mem 
	cp $< $@

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