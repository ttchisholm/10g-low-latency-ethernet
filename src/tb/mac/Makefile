# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../../hdl/pcs/encoder_pkg.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/tx_mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/rx_mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/crc32.sv



CUSTOM_SIM_DEPS += crc32.mem


# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = mac

# MODULE is the basename of the Python test file
MODULE = test_mac



# module parameters
export INPUT_WIDTH_BYTES ?= 8

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif

endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim



crc32.mem: $(PWD)/../../hdl/mac/crc32.mem 
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