###############################################################################
# OpenROAD Accelerated 12-Thread Resume Routing & Signoff for PR200 AXI DMA
# Technology: SkyWater 130nm (sky130_fd_sc_hd)
# Clock: 50 MHz (20.0 ns)
###############################################################################

set DESIGN_NAME "dma_axi32"
if {[info exists ::env(PDK_ROOT)]} { set PDK_ROOT $::env(PDK_ROOT) } else { set PDK_ROOT "$::env(HOME)/.volare/sky130A" }
set SCL_LIB     "sky130_fd_sc_hd"
set CTS_DEF     "[file normalize [file dirname [info script]]/../..]/pd/cts/dma_axi32_cts.def"
set SDC_FILE    "[file normalize [file dirname [info script]]/../..]/constraints/dma_axi32.sdc"
set OUT_DIR     "[file normalize [file dirname [info script]]/../..]/pd"

puts "=========================================================================="
puts " Step 1: Loading Technology & Cell LEFs and Liberty Timing Models        "
puts "=========================================================================="
read_liberty $PDK_ROOT/libs.ref/$SCL_LIB/lib/${SCL_LIB}__tt_025C_1v80.lib
read_lef     $PDK_ROOT/libs.ref/$SCL_LIB/techlef/${SCL_LIB}__nom.tlef
read_lef     $PDK_ROOT/libs.ref/$SCL_LIB/lef/${SCL_LIB}.lef

puts "=========================================================================="
puts " Step 2: Restoring CTS Checkpoint DEF & Design Constraints                "
puts "=========================================================================="
read_def     $CTS_DEF
read_sdc     $SDC_FILE

# Enable all 12 CPU threads for parallel acceleration
set_thread_count 12

set_dont_use {sky130_fd_sc_hd__dly* sky130_fd_sc_hd__probe_p_1}
set_propagated_clock [all_clocks]

puts "=========================================================================="
puts " Step 3: FastRoute Global Routing (12 Threads)                           "
puts "=========================================================================="
set_routing_layers -signal met1-met5 -clock met3-met5
global_route -guide_file $OUT_DIR/routing/route.guide -congestion_iterations 50

puts "=========================================================================="
puts " Step 4: TritonRoute Multi-Threaded Detailed Routing (12 Threads)         "
puts "=========================================================================="
detailed_route -output_drc $OUT_DIR/reports/droute_drc.rpt \
               -bottom_routing_layer met1 \
               -top_routing_layer met5 \
               -droute_end_iter 5 \
               -verbose 1

puts "=========================================================================="
puts " Step 5: Filler Cell Placement & Legalization Check                       "
puts "=========================================================================="
filler_placement "sky130_fd_sc_hd__fill_8 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_1"
check_placement

puts "=========================================================================="
puts " Step 6: Export Final Routed DEF                                          "
puts "=========================================================================="
write_def $OUT_DIR/routing/${DESIGN_NAME}_routed.def

puts "=========================================================================="
puts " Step 7: Signoff Parasitic Extraction & Static Timing Analysis (STA)     "
puts "=========================================================================="
extract_parasitics -lef_res
write_spef $OUT_DIR/reports/${DESIGN_NAME}.spef

# Report Timing
puts "\n--- REG-TO-REG SETUP TIMING ---"
report_checks -path_delay max -fields {input_pin slew cap net fanout} -digits 3 > $OUT_DIR/reports/sta_setup.rpt

puts "\n--- REG-TO-REG HOLD TIMING ---"
report_checks -path_delay min -fields {input_pin slew cap net fanout} -digits 3 > $OUT_DIR/reports/sta_hold.rpt

puts "\n--- TIMING SUMMARY METRICS ---"
report_worst_slack -max > $OUT_DIR/reports/worst_setup_slack.rpt
report_worst_slack -min > $OUT_DIR/reports/worst_hold_slack.rpt
report_tns              > $OUT_DIR/reports/total_negative_slack.rpt
report_wns              > $OUT_DIR/reports/worst_negative_slack.rpt

puts "=========================================================================="
puts " RESUMED ROUTING & SIGNOFF COMPLETED SUCCESSFULLY!                        "
puts "=========================================================================="
