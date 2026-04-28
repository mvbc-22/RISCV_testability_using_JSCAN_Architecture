# =============================================================
# extract_and_cluster_ff.tcl - PRAS-aware clustering
# 70% Parallel (PRAS) / 30% Serial (Standard FFs)
# =============================================================

# Read netlist
read_netlist /home/user01/riscv_testability/outputs/serial_scan/op_netlist_sdc/*.v
set JSCAN_RATIO  0.70
set EXIST_RATIO  0.30

# Standard FF cells (for serial scan)
set STANDARD_FF_CELLS {
    QDFZRMX1 QDFFRMX1 QDFCRBRMX1 QDFCLRBRMX1
    QDFZCRBRMX1 QDFFLRMX1 QDFFRMXLP QBDFFRMX1
    AN2QDFFRMX1 AN2QBDFFRMX1 QBDFFLRMX1 QDFFRMXL
}

# PRAS cells (for parallel scan)
set PRAS_CELLS {PRAS}

# Collect PRAS and Standard FF instances
set pras_inst [get_cells -hierarchical -filter "ref_name == PRAS"]
set total_pras [sizeof_collection $pras_inst]

set standard_ff_inst {}
foreach cell_type $STANDARD_FF_CELLS {
    set found [get_cells -hierarchical -filter "ref_name == $cell_type" -quiet]
    if {[sizeof_collection $found] > 0} {
        append_to_collection standard_ff_inst $found
    }
}
set total_standard [sizeof_collection $standard_ff_inst]

set all_ff_inst $pras_inst
append_to_collection all_ff_inst $standard_ff_inst
set total_ff [sizeof_collection $all_ff_inst]

puts "Total FFs: $total_ff (PRAS: $total_pras, Standard: $total_standard)"

# Calculate target counts with validation
set n_jscan  [expr {int(ceil($total_ff * $JSCAN_RATIO))}]
set n_exist  [expr {$total_ff - $n_jscan}]

if {$total_pras < $n_jscan} {
    puts "WARNING: Insufficient PRAS cells. Adjusting ratios."
    set n_jscan $total_pras
    set n_exist [expr {$total_ff - $n_jscan}]
}

if {$total_standard < $n_exist} {
    puts "WARNING: Insufficient standard FFs. Adjusting ratios."
    set n_exist $total_standard
    set n_jscan [expr {$total_ff - $n_exist}]
}

puts "Target: Parallel=$n_jscan, Serial=$n_exist"

# Process PRAS for parallel scan
set pras_data {}
foreach_in_collection ff $pras_inst {
    set full [get_property $ff full_name]
    set cell [get_property $ff ref_name]
    regsub -all {\[\d+\](\[\d+\])?$} $full {} base
    regsub {_reg$} $base {} base
    lappend pras_data [list $base $full $cell]
}

set pras_data [lsort -index 0 $pras_data]

set pras_groups {}
set prev_base ""
set cur_group {}
foreach entry $pras_data {
    set base [lindex $entry 0]
    if {$base ne $prev_base} {
        if {[llength $cur_group] > 0} {
            lappend pras_groups $cur_group
        }
        set cur_group [list $entry]
        set prev_base $base
    } else {
        lappend cur_group $entry
    }
}
if {[llength $cur_group] > 0} { lappend pras_groups $cur_group }

set pras_groups [lsort -decreasing -command {apply {{a b} {
    expr {[llength $a] - [llength $b]}
}}} $pras_groups]

set jscan_insts {}
foreach grp $pras_groups {
    if {[llength $jscan_insts] < $n_jscan} {
        foreach entry $grp {
            if {[llength $jscan_insts] < $n_jscan} {
                lappend jscan_insts [lindex $entry 1]
            }
        }
    }
}

# Process Standard FFs for serial scan
set standard_data {}
foreach_in_collection ff $standard_ff_inst {
    set full [get_property $ff full_name]
    set cell [get_property $ff ref_name]
    regsub -all {\[\d+\](\[\d+\])?$} $full {} base
    regsub {_reg$} $base {} base
    lappend standard_data [list $base $full $cell]
}

set standard_data [lsort -index 0 $standard_data]

set standard_groups {}
set prev_base ""
set cur_group {}
foreach entry $standard_data {
    set base [lindex $entry 0]
    if {$base ne $prev_base} {
        if {[llength $cur_group] > 0} {
            lappend standard_groups $cur_group
        }
        set cur_group [list $entry]
        set prev_base $base
    } else {
        lappend cur_group $entry
    }
}
if {[llength $cur_group] > 0} { lappend standard_groups $cur_group }

set standard_groups [lsort -decreasing -command {apply {{a b} {
    expr {[llength $a] - [llength $b]}
}}} $standard_groups]

set exist_insts {}
foreach grp $standard_groups {
    if {[llength $exist_insts] < $n_exist} {
        foreach entry $grp {
            if {[llength $exist_insts] < $n_exist} {
                lappend exist_insts [lindex $entry 1]
            }
        }
    }
}

# Write output files

set jscan_file [open "/home/user01/riscv_testability/outputs/jscan_ff_70pct.list" w]
puts $jscan_file "# Parallel scan (PRAS): [llength $jscan_insts]"
foreach inst $jscan_insts { puts $jscan_file $inst }
close $jscan_file

set exist_file [open "/home/user01/riscv_testability/outputs/existing_ff_30pct.list" w]
puts $exist_file "# Serial scan (Standard): [llength $exist_insts]"
foreach inst $exist_insts { puts $exist_file $inst }
close $exist_file

set all_file [open "/home/user01/riscv_testability/outputs/all_ff_instances.list" w]
puts $all_file "# Total: $total_ff (PRAS: $total_pras, Standard: $total_standard)"
foreach_in_collection ff $all_ff_inst {
    set ff_name [get_property $ff full_name]
    set cell_ref [get_property $ff ref_name]
    puts $all_file "$cell_ref  $ff_name"
}
close $all_file

puts "Parallel (PRAS): [llength $jscan_insts] -> /home/user01/riscv_testability/outputs/jscan_ff_70pct.list"
puts "Serial (Standard): [llength $exist_insts] -> /home/user01/riscv_testability/outputs/existing_ff_30pct.list"
puts "Done."
