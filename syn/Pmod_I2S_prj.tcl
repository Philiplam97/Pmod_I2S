set src_dir [file join [file dirname [info script]] .. src]

read_vhdl -vhdl2008 [file join $src_dir common I2S_util_pkg.vhd]
read_vhdl -vhdl2008 [file join $src_dir common button_debouncer.vhd]
read_vhdl -vhdl2008 [file join $src_dir common sync_ff.vhd]

read_vhdl -vhdl2008 [file join $src_dir I2S I2S.vhd]
read_vhdl -vhdl2008 [file join $src_dir arty_top.vhd]
