set search_path {/home/vlsi2/riscv_testability/Faraday65nm/ \
                 /home/vlsi2/riscv_testability/RTL/ \
                 /home/vlsi2/riscv_testability/sdc/}

set link_library {/home/vlsi2/riscv_testability/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.db}

set target_library {/home/vlsi2/riscv_testability/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.db}

read_verilog {/home/vlsi2/riscv_testability/RTL/picorv32.v \
              /home/vlsi2/riscv_testability/RTL/picorv_scan_top.v}

set_design_top picorv_top
current_design $DESIGN
current_design

read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}
read_sdc {/home/vlsi2/riscv_testability/sdc/constraints.sdc}

analyze -library work -format verilog -top picorv_top -autoread
analyze -library work -format verilog -top $top -autoread
analyze
analyze -library work -format verilog -top picorv_top -autoread \
        {/home/vlsi2/riscv_testability/RTL/picorv32.v \
         /home/vlsi2/riscv_testability/RTL/picorv_scan_top.v}

elaborate picorv_top -library work
link

compile_ultra

write_file -format verilog picorv_syn.v
write_file -format verilog -output picorv_syn.v

set link_library {/home/vlsi2/riscv_testability/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.db \
                  /home/vlsi2/riscv_testability/cadsl_ffcell_lib_updated.lib}

set link_library {/home/vlsi2/riscv_testability/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.db \
                  /home/vlsi2/riscv_testability/cadsl_ffcell_lib_updated.db}

set target_library {/home/vlsi2/riscv_testability/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.db \
                    /home/vlsi2/riscv_testability/cadsl_ffcell_lib_updated.db}

read_verilog {/home/vlsi2/riscv_testability/RTL/picorv32.v \
              /home/vlsi2/riscv_testability/RTL/picorv_scan_top.v}

analyze -library work -format verilog -top picorv_top -autoread \
        {/home/vlsi2/riscv_testability/RTL/picorv32.v \
         /home/vlsi2/riscv_testability/RTL/picorv_scan_top.v}

elaborate picorv_top -library work
link

compile_ultra
report_gates
report_area
