###########################################################################
## Xilinx ISE Makefile
##
## To the extent possible under law, the author(s) have dedicated all copyright
## and related and neighboring rights to this software to the public domain
## worldwide. This software is distributed without any warranty.
###########################################################################

XILINX  ?= =/opt/Xilinx/14.7/ISE_DS/ISE
PROJECT ?= spartan3a-evl
CONFIG  ?= $(PROJECT).cfg

include $(CONFIG)


###########################################################################
# Default values
###########################################################################

ifndef XILINX
    $(error XILINX must be defined)
endif

ifndef PROJECT
    $(error PROJECT must be defined)
endif

ifndef TARGET_PART
    $(error TARGET_PART must be defined)
endif

BUILD_DIR       ?= build/$(PROJECT)

TOPLEVEL        ?= $(PROJECT)
CONSTRAINTS     ?= $(PROJECT).ucf
BITFILE         ?= $(BUILD_DIR)/$(PROJECT).bit

COMMON_OPTS     ?= -intstyle xflow
XST_OPTS        ?=
NGDBUILD_OPTS   ?=
MAP_OPTS        ?=
PAR_OPTS        ?=
BITGEN_OPTS     ?=
TRACE_OPTS      ?=
FUSE_OPTS       ?= -incremental

PROGRAMMER      ?= none

IMPACT_OPTS     ?= -batch impact.cmd

DJTG_EXE        ?= djtgcfg
DJTG_DEVICE     ?= DJTG_DEVICE-NOT-SET
DJTG_INDEX      ?= 0

XC3SPROG_EXE    ?= xc3sprog
XC3SPROG_CABLE  ?= none
XC3SPROG_OPTS   ?=

AVS3A_EXE       ?= avs3a
AVS3A_CABLE     ?= /dev/ttyACM1
AVS3A_OPTS      ?= -s -b

PAPILIO_PROG_EXE  ?= papilio-prog
PAPILIO_PROG_OPTS ?= 


###########################################################################
# Internal variables, platform-specific definitions, and macros
###########################################################################

ifeq ($(OS),Windows_NT)
    XILINX := $(shell cygpath -m $(XILINX))
    CYG_XILINX := $(shell cygpath $(XILINX))
    EXE := .exe
    XILINX_PLATFORM ?= nt64
    PATH := $(PATH):$(CYG_XILINX)/bin/$(XILINX_PLATFORM)
else
    EXE :=
    XILINX_PLATFORM ?= lin64
    PATH := $(PATH):$(XILINX)/bin/$(XILINX_PLATFORM)
endif

TEST_NAMES = $(foreach file,$(VTEST) $(VHDTEST),$(basename $(file)))
TEST_EXES = $(foreach test,$(TEST_NAMES),$(BUILD_DIR)/isim_$(test)$(EXE))

RUN = @/bin/echo -ne "\n\n\e[1;33m======== $(1) ========\e[m\n\n"; \
	cd $(BUILD_DIR) && $(XILINX)/bin/$(XILINX_PLATFORM)/$(1)

# isim executables don't work without this
export XILINX


###########################################################################
# Default build
###########################################################################

default: $(BITFILE)

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/$(PROJECT).prj: $(CONFIG)
	@echo "Updating $@"
	@mkdir -p $(BUILD_DIR)
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../../$(file)\"" >> $@;)
	@$(foreach file,$(VHDSOURCE),echo "vhdl work \"../../$(file)\"" >> $@;)

$(BUILD_DIR)/$(PROJECT)_sim.prj: $(BUILD_DIR)/$(PROJECT).prj
	@cp $(BUILD_DIR)/$(PROJECT).prj $@
	@$(foreach file,$(VTEST),echo "verilog work \"../../$(file)\"" >> $@;)
	@$(foreach file,$(VHDTEST),echo "vhdl work \"../../$(file)\"" >> $@;)
	@echo "verilog work $(XILINX)/verilog/src/glbl.v" >> $@

$(BUILD_DIR)/$(PROJECT).scr: $(CONFIG)
	@echo "Updating $@"
	@mkdir -p $(BUILD_DIR)
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "$(XST_OPTS)" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p $(TARGET_PART)" \
	    > $(BUILD_DIR)/$(PROJECT).scr

$(BITFILE): $(CONFIG) $(VSOURCE) $(VHDSOURCE) $(CONSTRAINTS) $(BUILD_DIR)/$(PROJECT).prj $(BUILD_DIR)/$(PROJECT).scr
	@mkdir -p $(BUILD_DIR)
	$(call RUN,xst) $(COMMON_OPTS) \
	    -ifn $(PROJECT).scr
	$(call RUN,ngdbuild) $(COMMON_OPTS) $(NGDBUILD_OPTS) \
	    -p $(TARGET_PART) -uc ../../$(CONSTRAINTS) \
	    $(PROJECT).ngc $(PROJECT).ngd
	$(call RUN,map) $(COMMON_OPTS) $(MAP_OPTS) \
	    -p $(TARGET_PART) \
	    -w $(PROJECT).ngd -o $(PROJECT).map.ncd $(PROJECT).pcf
	$(call RUN,par) $(COMMON_OPTS) $(PAR_OPTS) \
	    -w $(PROJECT).map.ncd $(PROJECT).ncd $(PROJECT).pcf
	$(call RUN,bitgen) $(COMMON_OPTS) $(BITGEN_OPTS) \
	    -w $(PROJECT).ncd $(PROJECT).bit
	@/bin/echo -ne "\e[1;32m======== OK ========\e[m\n"


###########################################################################
# Testing (work in progress)
###########################################################################

trace: $(CONFIG) $(BITFILE)
	$(call RUN,trce) $(COMMON_OPTS) $(TRACE_OPTS) \
	    $(PROJECT).ncd $(PROJECT).pcf

test: $(TEST_EXES)

$(BUILD_DIR)/isim_%$(EXE): $(BUILD_DIR)/$(PROJECT)_sim.prj $(VSOURCE) $(VHDSOURCE) $(VTEST) $(VHDTEST)
	$(call RUN,fuse) $(COMMON_OPTS) $(FUSE_OPTS) \
	    -prj $(PROJECT)_sim.prj \
	    -o isim_$*$(EXE) \
	    work.$* work.glbl

isim: $(BUILD_DIR)/isim_$(TB)$(EXE)
	@grep --no-filename --no-messages 'ISIM:' $(TB).{v,vhd} | cut -d: -f2 > $(BUILD_DIR)/isim_$(TB).cmd
	@echo "run all" >> $(BUILD_DIR)/isim_$(TB).cmd
	cd $(BUILD_DIR) ; ./isim_$(TB)$(EXE) -tclbatch isim_$(TB).cmd

isimgui: $(BUILD_DIR)/isim_$(TB)$(EXE)
	@grep --no-filename --no-messages 'ISIM:' $(TB).{v,vhd} | cut -d: -f2 > $(BUILD_DIR)/isim_$(TB).cmd
	@echo "run all" >> $(BUILD_DIR)/isim_$(TB).cmd
	cd $(BUILD_DIR) ; ./isim_$(TB)$(EXE) -gui -tclbatch isim_$(TB).cmd


###########################################################################
# Programming
###########################################################################

ifeq ($(PROGRAMMER), impact)
prog: $(BITFILE)
	$(XILINX)/bin/$(XILINX_PLATFORM)/impact $(IMPACT_OPTS)
endif

ifeq ($(PROGRAMMER), digilent)
prog: $(BITFILE)
	$(DJTG_EXE) prog -d $(DJTG_DEVICE) -i $(DJTG_INDEX) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), xc3sprog)
prog: $(BITFILE)
	$(XC3SPROG_EXE) -c $(XC3SPROG_CABLE) $(XC3SPROG_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), avs3a)
prog: $(BITFILE)
	$(AVS3A_EXE) -p $(AVS3A_CABLE) $(AVS3A_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), papilio-prog)
prog: $(BITFILE)
	$(PAPILIO_PROG_EXE) $(PAPILIO_PROG_OPTS) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), none)
prog:
	$(error PROGRAMMER must be set to use 'make prog')
endif


###########################################################################

# vim: set filetype=make: #
