# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES ?= 1

VERILOG_SOURCES += $(PWD)/../../hdl/include/code_defs_pkg.svh
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/pcs.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/decoder.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/encoder.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/rx_gearbox.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/tx_gearbox.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/gearbox_seq.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/lock_state.sv
VERILOG_SOURCES += $(PWD)/../../hdl/pcs/scrambler.sv

VERILOG_SOURCES += $(PWD)/../../hdl/mac/mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/tx_mac.sv
VERILOG_SOURCES += $(PWD)/../../hdl/mac/rx_mac.sv

VERILOG_SOURCES += $(PWD)/../../hdl/mac_pcs.sv

VERILOG_SOURCES += $(PWD)/../../lib/slicing_crc/hdl/slicing_crc.sv


CUSTOM_SIM_DEPS += crc_tables.mem


# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = mac_pcs

# MODULE is the basename of the Python test file
MODULE = test_mac_pcs

# module parameters
export SCRAMBLER_BYPASS ?= 0
export EXTERNAL_GEARBOX ?= 0
export DATA_WIDTH ?= 32

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).SCRAMBLER_BYPASS=$(SCRAMBLER_BYPASS)
	COMPILE_ARGS += -P $(TOPLEVEL).EXTERNAL_GEARBOX=$(EXTERNAL_GEARBOX)
	COMPILE_ARGS += -I $(PWD)/../../hdl/include

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), modelsim)
	COMPILE_ARGS += "+incdir+$(PWD)/../../hdl/include"
	COMPILE_ARGS += +cover=sbceft

	SIM_ARGS += -GSCRAMBLER_BYPASS=$(SCRAMBLER_BYPASS)
	SIM_ARGS += -GEXTERNAL_GEARBOX=$(EXTERNAL_GEARBOX)

	SIM_ARGS += -coverage
	SIM_ARGS += -no_autoacc
	SIM_ARGS +=  -do \" coverage save -onexit $(TOPLEVEL).ucdb; run -all;exit\"
endif
# "Veriliator currently does not work with cocotb verilog-axi"
# else ifeq ($(SIM), verilator)

# 	COMPILE_ARGS += -GSCRAMBLER_BYPASS=$(SCRAMBLER_BYPASS)
# 	COMPILE_ARGS += -GEXTERNAL_GEARBOX=$(EXTERNAL_GEARBOX)
# 	COMPILE_ARGS += -I$(PWD)/../../hdl/include

# 	ifeq ($(WAVES), 1)
# 		COMPILE_ARGS += --trace-fst --trace-structs
# 	endif 
# endif

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
	@rm -rf crc_tables.mem
	@rm -rf dump.fst $(TOPLEVEL).fst