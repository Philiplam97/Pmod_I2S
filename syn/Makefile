PART ?= XC7A35TICSG324-1L #Default part xc7a3t on arty A7
PROJECT ?= Pmod_I2S
TOP ?= arty_top

OUTPUT_DIR ?= $(PROJECT)_build
PRJ_DIR ?= ../

.PHONY: all clean  synth route write_bitstream program

all : synth route write_bitstream program

synth : $(OUTPUT_DIR)/$(TOP)_synth.dcp

$(OUTPUT_DIR)/$(TOP)_synth.dcp : 
	@mkdir -p $(OUTPUT_DIR)
	@echo "source $(PROJECT)_prj.tcl" > synth.tcl
	@echo "read_xdc Arty-A7-35-Master.xdc" >> synth.tcl
	@echo "synth_design -flatten_hierarchy rebuilt -top $(TOP) -part $(PART) -assert" >> synth.tcl
	@echo "write_checkpoint -force $(OUTPUT_DIR)/$(TOP)_synth.dcp" >> synth.tcl
	@echo "report_timing_summary -file $(OUTPUT_DIR)/synth_timing_summary.txt" >> synth.tcl
	vivado -mode batch -source synth.tcl -journal $(OUTPUT_DIR)/$(TOP)_synth.jou -log $(OUTPUT_DIR)/$(TOP)_synth.log

route : $(OUTPUT_DIR)/$(TOP)_route.dcp

$(OUTPUT_DIR)/$(TOP)_route.dcp : $(OUTPUT_DIR)/$(TOP)_synth.dcp
	@echo "open_checkpoint $(OUTPUT_DIR)/$(TOP)_synth.dcp" > route.tcl
	@echo "opt_design" >> route.tcl
	@echo "place_design" >> route.tcl
	@echo "phys_opt_design" >> route.tcl
	@echo "route_design" >> route.tcl
	@echo "write_checkpoint -force $(OUTPUT_DIR)/$(TOP)_route.dcp" >> route.tcl
	@echo "report_timing_summary -file $(OUTPUT_DIR)/route_timing_summary.txt" >> route.tcl
	@echo "report_timing -sort_by group -max_paths 100 -path_type summary -file $(OUTPUT_DIR)/route_timing.txt" >> route.tcl
	@echo "report_utilization -file $(OUTPUT_DIR)/route_util.txt" >> route.tcl
	# @echo "write_debug_probes -force probes.ltx" >> route.tcl
	vivado -mode batch -source route.tcl -journal $(OUTPUT_DIR)/$(TOP)_route.jou -log $(OUTPUT_DIR)/$(TOP)_route.log

write_bitstream : $(OUTPUT_DIR)/$(PROJECT).bit

$(OUTPUT_DIR)/$(PROJECT).bit : $(OUTPUT_DIR)/$(TOP)_route.dcp
	@echo "open_checkpoint $(OUTPUT_DIR)/$(TOP)_route.dcp" > write_bitstream.tcl
	@echo "write_bitstream $(OUTPUT_DIR)/$(PROJECT).bit -force" >> write_bitstream.tcl
	vivado -nojournal -nolog -mode batch -source write_bitstream.tcl

# UG835 Vivado Design Suite Tcl Command Reference Guide open_hw_manager
# outlines the process below

program: $(OUTPUT_DIR)/$(PROJECT).bit
	@echo "open_hw_manager" > prog.tcl
	@echo "connect_hw_server" >> prog.tcl
	@echo "open_hw_target" >> prog.tcl
	@echo "current_hw_device [lindex [get_hw_devices] 0]" >> prog.tcl
	@echo "set_property PROGRAM.FILE {$(OUTPUT_DIR)/$(PROJECT).bit} [current_hw_device]" >> prog.tcl
	@echo "program_hw_devices [current_hw_device]" >> prog.tcl
	@echo "exit" >> prog.tcl
	vivado -nojournal -nolog -mode batch -source prog.tcl

clean:
	rm -rf $(OUTPUT_DIR)
