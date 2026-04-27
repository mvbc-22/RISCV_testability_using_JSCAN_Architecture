# =============================================================
# extract_and_cluster_ff.tcl
# Goal 1: Extract only the FF cell instances (not all registers)
# Goal 2: Cluster them into 70% JSCAN / 30% Existing
# Tested with Cadence Genus / Innovus
# =============================================================

set JSCAN_RATIO  0.70
set EXIST_RATIO  0.30

# --- FF cell name patterns for this library (QDF*) ---
# Adjust this list to match your exact library cell names
set FF_CELLS {
    QDFZRMX1
    QDFFRMX1
    QDFCRBRMX1
    QDFCLRBRMX1
    QDFZCRBRMX1
    QDFFLRMX1
    QDFFRMXLP
}
set JSCAN_Cells{
    PRAS 
}
# -------------------------------------------------------
# GOAL 1: Collect only FF instances (filter by cell name)
# -------------------------------------------------------
set all_ff_inst [get_cells -hierarchical -filter "ref_name =~ QDF*"]
# Alternatively, if you want to be explicit:
# set all_ff_inst {}
# foreach cell_type $FF_CELLS {
#     append_to_collection all_ff_inst [get_cells -hierarchical -filter "ref_name == $cell_type"]
# }

set total_ff [sizeof_collection $all_ff_inst]
puts "INFO: Total FF instances found: $total_ff"

# Write all FF instance names
set ff_report [open "outputs/all_ff_instances.list" w]
puts $ff_report "# All FF instances: $total_ff"
foreach_in_collection ff $all_ff_inst {
    set ff_name [get_property $ff full_name]
    set cell_ref [get_property $ff ref_name]
    puts $ff_report "$cell_ref  $ff_name"
}
close $ff_report

# -------------------------------------------------------
# GOAL 2: Cluster into 70% JSCAN / 30% Existing
# Strategy: keep functional bus groups intact (same base name)
# -------------------------------------------------------
set n_jscan  [expr {int(ceil($total_ff * $JSCAN_RATIO))}]
set n_exist  [expr {$total_ff - $n_jscan}]

puts "INFO: Target JSCAN  (70%): $n_jscan"
puts "INFO: Target Existing (30%): $n_exist"

# Build a list of {base_name inst_name cell_type}
set ff_data {}
foreach_in_collection ff $all_ff_inst {
    set full [get_property $ff full_name]
    set cell [get_property $ff ref_name]
    # Strip trailing [N][M] or [N] index and _reg suffix -> group key
    regsub -all {\[\d+\](\[\d+\])?$} $full {} base
    regsub {_reg$} $base {} base
    lappend ff_data [list $base $full $cell]
}

# Sort by base name so bus bits group together
set ff_data [lsort -index 0 $ff_data]

# Group by base name
set groups {}
set prev_base ""
set cur_group {}
foreach entry $ff_data {
    set base [lindex $entry 0]
    if {$base ne $prev_base} {
        if {[llength $cur_group] > 0} {
            lappend groups $cur_group
        }
        set cur_group [list $entry]
        set prev_base $base
    } else {
        lappend cur_group $entry
    }
}
if {[llength $cur_group] > 0} { lappend groups $cur_group }

# Sort groups largest-first to fill JSCAN bucket efficiently
set groups [lsort -decreasing -command {apply {{a b} {
    expr {[llength $a] - [llength $b]}
}}} $groups]

# Assign groups to JSCAN until quota is met
set jscan_insts {}
set exist_insts {}
foreach grp $groups {
    if {[llength $jscan_insts] < $n_jscan} {
        foreach entry $grp {
            lappend jscan_insts [lindex $entry 1]
        }
    } else {
        foreach entry $grp {
            lappend exist_insts [lindex $entry 1]
        }
    }
}

# -------------------------------------------------------
# Write output files
# -------------------------------------------------------
set jscan_file [open "outputs/jscan_ff_70pct.list" w]
puts $jscan_file "# JSCAN parallel scan flop instances: [llength $jscan_insts]"
foreach inst $jscan_insts { puts $jscan_file $inst }
close $jscan_file

set exist_file [open "outputs/existing_ff_30pct.list" w]
puts $exist_file "# Existing flop instances: [llength $exist_insts]"
foreach inst $exist_insts { puts $exist_file $inst }
close $exist_file

puts "INFO: JSCAN list written  -> outputs/jscan_ff_70pct.list   ([llength $jscan_insts] FFs)"
puts "INFO: Existing list written -> outputs/existing_ff_30pct.list ([llength $exist_insts] FFs)"
puts "INFO: Done."
