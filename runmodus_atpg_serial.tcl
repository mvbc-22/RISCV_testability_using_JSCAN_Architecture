#!/usr/bin/env modus
#==============================================================================
# Modus ATPG Script for PicoRV32 - WORKING VERSION
# Fixed: Inline comments and file paths
#==============================================================================

#-------------------------------------------------------------------------------
# INITIALIZE VARIABLES
#-------------------------------------------------------------------------------
set_db workdir ./test_scripts
set WORKDIR [get_db workdir]

# Configure the database - NO INLINE COMMENTS!
set_option stdout summary
set ::env(CDS_LIC_REPORT) yes

# Load test_checks.tcl for error checking
source $::env(Install_Dir)/bin/64bit/test_checks.tcl
set STOP_ON_MSG_SEV ERROR
set LOGDIR $WORKDIR/testresults/logs

# Clean previous run
file delete -force $WORKDIR/tbdata
file delete -force $WORKDIR/testresults

# Create working directory
exec mkdir -p $WORKDIR

puts "\n=============================================="
puts "Modus ATPG - PicoRV32 Serial Scan"
puts "=============================================="
puts "Working Directory: $WORKDIR"
puts "Mode: BLACKBOX (no library models)"
puts "==============================================\n"

#-------------------------------------------------------------------------------
# FILE PATHS - UPDATE THESE TO MATCH YOUR SETUP!
#-------------------------------------------------------------------------------
puts "=== Configuring file paths ==="

# OPTION 1: If files are in outputs/serial_scan/
set SOURCE_DIR "/home/user01/riscv_testability/outputs/serial_scan"

# OPTION 2: If files are in Desktop/Cadence_Work/test_scripts/
# set SOURCE_DIR "/home/user01/Desktop/Cadence_Work/test_scripts"

# OPTION 3: If files are in current directory
# set SOURCE_DIR "."

set NETLIST_SOURCE "$SOURCE_DIR/picorv_top.test_netlist.v"
set PINASSIGN_SOURCE "$SOURCE_DIR/picorv_top.FULLSCAN.pinassign"

# Check if source files exist
if {![file exists $NETLIST_SOURCE]} {
    puts "\nERROR: Netlist not found!"
    puts "Looking for: $NETLIST_SOURCE"
    puts "\nSearching for the file..."
    
    # Try to find the file
    catch {
        set found [exec find /home/user01 -name "picorv_top.test_netlist.v" 2>/dev/null | head -1]
        if {$found != ""} {
            puts "Found at: $found"
            puts "\nPlease update SOURCE_DIR in script to:"
            puts "set SOURCE_DIR \"[file dirname $found]\""
        }
    }
    exit 1
}

if {![file exists $PINASSIGN_SOURCE]} {
    puts "\nERROR: Pin assignment file not found!"
    puts "Looking for: $PINASSIGN_SOURCE"
    puts "\nSearching for the file..."
    
    # Try to find the file
    catch {
        set found [exec find /home/user01 -name "picorv_top.FULLSCAN.pinassign" 2>/dev/null | head -1]
        if {$found != ""} {
            puts "Found at: $found"
            puts "\nPlease update SOURCE_DIR in script to:"
            puts "set SOURCE_DIR \"[file dirname $found]\""
        }
    }
    exit 1
}

# Copy files to workdir
exec cp $NETLIST_SOURCE $WORKDIR/picorv_top.test_netlist.v
exec cp $PINASSIGN_SOURCE $WORKDIR/picorv_top.FULLSCAN.pinassign

puts "✓ Netlist copied: $WORKDIR/picorv_top.test_netlist.v"
puts "✓ Pin assignment copied: $WORKDIR/picorv_top.FULLSCAN.pinassign"

#-------------------------------------------------------------------------------
# BUILD THE LOGIC MODEL (BLACKBOX MODE)
#-------------------------------------------------------------------------------
puts "\n=== Step 1: Building Logic Model (Blackbox Mode) ==="

build_model \
    -designtop picorv_top \
    -source $WORKDIR/picorv_top.test_netlist.v \
    -allowmissingmodules yes

check_log log_build_model

puts "✓ Logic model built successfully"

#-------------------------------------------------------------------------------
# BUILD THE TEST MODEL
#-------------------------------------------------------------------------------
puts "\n=== Step 2: Building Test Mode ==="

build_testmode \
    -testmode FULLSCAN \
    -assignfile $WORKDIR/picorv_top.FULLSCAN.pinassign \
    -modedef FULLSCAN

check_log log_build_testmode_FULLSCAN

puts "✓ Test mode built successfully"

#-------------------------------------------------------------------------------
# REPORT THE TEST MODEL
#-------------------------------------------------------------------------------
puts "\n=== Step 3: Reporting Test Structures ==="

report_test_structures \
    -testmode FULLSCAN

check_log log_report_test_structures_FULLSCAN

puts "✓ Test structures reported"

#-------------------------------------------------------------------------------
# VERIFY THE TEST MODEL
#-------------------------------------------------------------------------------
puts "\n=== Step 4: Verifying Test Structures ==="

verify_test_structures \
    -messagecount TSV-016=10,TSV-024=10,TSV-315=10,TSV-027=10 \
    -testmode FULLSCAN

check_log log_verify_test_structures_FULLSCAN

puts "✓ Test structures verified"

#-------------------------------------------------------------------------------
# BUILD THE FAULT MODEL
#-------------------------------------------------------------------------------
puts "\n=== Step 5: Building Fault Model ==="

build_faultmodel \
    -includedynamic no

check_log log_build_faultmodel

puts "✓ Fault model built"

#-------------------------------------------------------------------------------
# ATPG - TEST GENERATION
#-------------------------------------------------------------------------------
puts "\n=== Step 6: Running ATPG (Test Generation) ==="

create_logic_tests \
    -experiment picorv_top_atpg \
    -testmode FULLSCAN

check_log log_create_logic_tests_FULLSCAN_picorv_top_atpg

puts "✓ ATPG test generation complete"

#-------------------------------------------------------------------------------
# ATPG - Report Scan and Capture Switching
#-------------------------------------------------------------------------------
puts "\n=== Step 7: Generating Toggle Report ==="

write_toggle_gram \
    -experiment picorv_top_atpg \
    -testmode FULLSCAN

puts "✓ Toggle report generated"

#-------------------------------------------------------------------------------
# VERILOG VECTORS - For PARALLEL Simulation
#-------------------------------------------------------------------------------
puts "\n=== Step 8: Writing Verilog Test Vectors ==="

write_vectors \
    -inexperiment picorv_top_atpg \
    -testmode FULLSCAN \
    -language verilog \
    -scanformat parallel

check_log log_write_vectors_FULLSCAN_picorv_top_atpg

puts "✓ Verilog vectors written (parallel format)"

#-------------------------------------------------------------------------------
# STIL VECTORS - For ATE
#-------------------------------------------------------------------------------
puts "\n=== Step 9: Writing STIL Test Vectors ==="

write_vectors \
    -inexperiment picorv_top_atpg \
    -testmode FULLSCAN \
    -language stil

puts "✓ STIL vectors written"

#-------------------------------------------------------------------------------
# ATPG - Save Experiment to Master Database
#-------------------------------------------------------------------------------
puts "\n=== Step 10: Committing Tests ==="

commit_tests \
    -inexperiment picorv_top_atpg \
    -testmode FULLSCAN

check_log log_commit_tests_FULLSCAN_picorv_top_atpg

puts "✓ Tests committed to database"

#-------------------------------------------------------------------------------
# GENERATE FINAL REPORTS
#-------------------------------------------------------------------------------
puts "\n=== Step 11: Generating Final Reports ==="

report_fault_statistics \
    -testmode FULLSCAN

report_test_structures \
    -testmode FULLSCAN

report_patterns \
    -testmode FULLSCAN

puts "✓ Reports generated"

#-------------------------------------------------------------------------------
# COPY RESULTS TO OUTPUT DIRECTORY
#-------------------------------------------------------------------------------
puts "\n=== Copying results to output directory ==="

set OUTPUT_DIR "/home/user01/riscv_testability/outputs/serial_scan/modus_results"
exec mkdir -p $OUTPUT_DIR

if {[file exists $WORKDIR/testresults]} {
    catch {exec cp -rf $WORKDIR/testresults/* $OUTPUT_DIR/}
    puts "✓ Results copied to: $OUTPUT_DIR"
}

# Create summary report
set summary_file "$OUTPUT_DIR/ATPG_SUMMARY.txt"
set fp [open $summary_file w]
puts $fp "=========================================="
puts $fp "Modus ATPG Summary - PicoRV32 Serial Scan"
puts $fp "=========================================="
puts $fp "Date: [clock format [clock seconds]]"
puts $fp ""
puts $fp "Configuration:"
puts $fp "  Design: picorv_top"
puts $fp "  Test Mode: FULLSCAN"
puts $fp "  Scan Chains: 4"
puts $fp "  Mode: Blackbox (no library models)"
puts $fp ""
puts $fp "Output Files:"
puts $fp "  Verilog Vectors: testresults/verilog/"
puts $fp "  STIL Vectors: testresults/stil/"
puts $fp "  Logs: testresults/logs/"
puts $fp ""
puts $fp "Key Reports:"
puts $fp "  - Check logs/ for fault statistics"
puts $fp "  - Check logs/ for test structures"
puts $fp "  - Check logs/ for pattern summary"
puts $fp ""
puts $fp "Next Steps:"
puts $fp "  1. Check fault coverage in logs"
puts $fp "  2. Verify patterns in verilog/ directory"
puts $fp "  3. Run simulation with xrun"
puts $fp "=========================================="
close $fp

puts "✓ Summary report created: $summary_file"

#-------------------------------------------------------------------------------
# FINAL SUMMARY
#-------------------------------------------------------------------------------
puts "\n=============================================="
puts "Modus ATPG Complete!"
puts "=============================================="
puts "\nResults Location: $OUTPUT_DIR"
puts "\nKey Files:"
puts "  - testresults/verilog/VER.FULLSCAN.picorv_top_atpg.*.verilog"
puts "  - testresults/stil/*.stil"
puts "  - testresults/logs/log_* (detailed logs)"
puts "  - ATPG_SUMMARY.txt (this run summary)"
puts ""
puts "Database: $WORKDIR/tbdata"
puts ""
puts "Configuration:"
puts "  Design: picorv_top"
puts "  Test Mode: FULLSCAN"
puts "  Scan Chains: 4 (scan_in/out_1/2/3/4)"
puts "  Scan Enable: SE"
puts "  Clock: clk (-ES)"
puts ""
puts "Mode: BLACKBOX"
puts "  - Library cells treated as blackboxes"
puts "  - Expected coverage: 70-85%"
puts "  - Sufficient for scan chain validation"
puts ""
puts "Check the logs for detailed results!"
puts "==============================================\n"

exit
