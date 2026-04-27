# 1. Setup library
#set_db library /home/user01/JScanLib/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.lib
set_db library {/home/user01/JScanLib/PRASSynthesis/cadsl_ffcell_lib-1.1.lib /home/user01/JScanLib/PRASSynthesis/cadsl_ffcell_lib_updated.lib /home/user01/JScanLib/Faraday65nm/fse0k_d_generic_core_ff1p32v125c.lib}


#don't use cells
set_dont_use lib_cell:default_emulate_libset_max/fse0k_d_generic_core_ff1p32v125c/*DF*
set_dont_use lib_cell:default_emulate_libset_max/fse0k_d_generic_core_ff1p32v125c/*DB*

set_dont_use lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/SDFF
#set_dont_use lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/VJA
#set_dont_use lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/PRAS

#lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/SDFF lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/VJA lib_cell:default_emulate_libset_max/cadsl_ffcell_lib/PRAS


# 2. Read RTL
read_hdl [glob /home/user01/riscv_testability/RTL/*.v]

# 3. Elaborate
elaborate
set_top_module picorv_top

# 4. Read constraints
read_sdc /home/user01/riscv_testability/sdc/constraints.sdc

# 5. DFT configuration
#set_db dft_scan_style muxed_scan
#set_db dft_prefix dft_

# 6. Define shift enable
define_shift_enable -name SEL -active high -create_port SEL

# 7. Check DFT rules
check_dft_rules

# 8. Synthesis
set_db syn_generic_effort medium
syn_generic

set_db syn_map_effort medium
syn_map

set_db syn_opt_effort medium
syn_opt

# 9. Check DFT rules post-synthesis
check_dft_rules > /home/user01/riscv_testability/outputs/serial_scan/dft.rpt

# 10. Set number of scan chains
set_db design:picorv_top .dft_min_number_of_scan_chains 4

# 11. Define 4 scan chains
define_scan_chain -name chain1 -sdi scan_in_1 -sdo scan_out_1 -create_ports
define_scan_chain -name chain2 -sdi scan_in_2 -sdo scan_out_2 -create_ports
define_scan_chain -name chain3 -sdi scan_in_3 -sdo scan_out_3 -create_ports
define_scan_chain -name chain4 -sdi scan_in_4 -sdo scan_out_4 -create_ports

# 12. Connect scan chains (INSERT SCAN CELLS)
connect_scan_chains -auto_create_chains

# 13. Incremental optimization
syn_opt -incremental

# 14. Report scan chains
report_scan_chains > /home/user01/riscv_testability/outputs/serial_scan/scan_chains_1.rpt

# 15. Write ATPG library
write_dft_atpg -library /home/user01/JScanLib/Faraday65nm/fse0k_d_generic_core_21.v

# 16. Write netlist
write_hdl > /home/user01/riscv_testability/outputs/serial_scan/op_netlist_sdc/serialscan_1.v

# 17. Write SDC
write_sdc > /home/user01/riscv_testability/outputs/serial_scan/op_netlist_sdc/serialscan_1.sdc

# 18. Write SDF
write_sdf -nonegchecks -edges check_edge -timescale ns -recrem split -setuphold split > /home/user01/riscv_testability/outputs/serial_scan/op_netlist_sdc/serialscan_1.sdf

# 19. Write SCANDEF
write_scandef > /home/user01/riscv_testability/outputs/serial_scan/serialscan_scanDEF_1.scandef

# 20. Reports
report_area > /home/user01/riscv_testability/outputs/serial_scan/area_1.rpt
report_gates > /home/user01/riscv_testability/outputs/serial_scan/gates_1.rpt
report_qor > /home/user01/riscv_testability/outputs/serial_scan/qor_1.rpt
report_timing > /home/user01/riscv_testability/outputs/serial_scan/timing_1.rpt
