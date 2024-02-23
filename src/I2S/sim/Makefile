TOPLEVEL_LANG ?= vhdl
SIM ?= ghdl

#Python test file
MODULE := tests

#VHDL top level name
TOPLEVEL := i2s

PRJ_DIR :=  $(shell pwd)/../../..

VHDL_SOURCES = $(PRJ_DIR)/src/I2S/I2S.vhd \

# Dump waves
SIM_ARGS +=--vcd=waves.vcd
EXTRA_ARGS += --std=08 --ieee=standard
SIM_BUILD = sim_build

include $(shell cocotb-config --makefiles)/Makefile.sim
