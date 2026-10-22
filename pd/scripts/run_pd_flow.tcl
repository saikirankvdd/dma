###############################################################################
# OpenROAD Physical Design Automation Script for PR200 AXI DMA (dma_axi32)
# Target Process: SkyWater 130nm (sky130_fd_sc_hd)
# Target Clock: 50 MHz (Period = 20.0 ns)
###############################################################################

set DESIGN_NAME "dma_axi32"
if {[info exists ::env(PDK_ROOT)]} { set PDK_ROOT $::env(PDK_ROOT) } else { set PDK_ROOT "$::env(HOME)/.volare/sky130A" }
set SCL_LIB     "sky130_fd_sc_hd"
set NETLIST     "[file normalize [file dirname [info script]]/../..]/synth/reports/dma_axi32_synth.v"
set SDC_FILE    "[file normalize [file dirname [info script]]/../..]/constraints/dma_axi32.sdc"
set OUT_DIR     "[file normalize [file dirname [info script]]/../..]/pd"

puts "=========================================================================="
puts " Stage 2: Loading Tech LEFs, Standard Cell LEFs, and Liberty Models       "
puts "=========================================================================="
read_liberty $PDK_ROOT/libs.ref/$SCL_LIB/lib/${SCL_LIB}__tt_025C_1v80.lib
read_lef     $PDK_ROOT/libs.ref/$SCL_LIB/techlef/${SCL_LIB}__nom.tlef
read_lef     $PDK_ROOT/libs.ref/$SCL_LIB/lef/${SCL_LIB}.lef

puts "=========================================================================="
puts " Stage 2 (cont): Linking Synthesized Netlist & SDC Constraints            "
puts "=========================================================================="
read_verilog $NETLIST
link_design  $DESIGN_NAME
read_sdc     $SDC_FILE

set_dont_use {sky130_fd_sc_hd__dly* sky130_fd_sc_hd__probe_p_1}

puts "=========================================================================="
puts " Stage 3: Floorplanning & IO Pin Placement                                "
puts "=========================================================================="
# Core utilization 45%, Aspect ratio 1.0, 20um core-to-die margin
initialize_floorplan -utilization 45 -aspect_ratio 1.0 -core_space 20.0 -site unithd

# Create standard routing tracks
make_tracks li1  -x_pitch 0.46 -y_pitch 0.34 -x_offset 0.23 -y_offset 0.17
make_tracks met1 -x_pitch 0.34 -y_pitch 0.34 -x_offset 0.17 -y_offset 0.17
make_tracks met2 -x_pitch 0.46 -y_pitch 0.46 -x_offset 0.23 -y_offset 0.23
make_tracks met3 -x_pitch 0.68 -y_pitch 0.68 -x_offset 0.34 -y_offset 0.34
make_tracks met4 -x_pitch 0.92 -y_pitch 0.92 -x_offset 0.46 -y_offset 0.46
make_tracks met5 -x_pitch 3.40 -y_pitch 3.40 -x_offset 1.70 -y_offset 1.70

# Equidistantly place IO pins on Metal 2 (vertical) and Metal 3 (horizontal)
place_pins -hor_layers met3 -ver_layers met2

write_def $OUT_DIR/floorplan/${DESIGN_NAME}_floorplan.def

puts "=========================================================================="
puts " Stage 4: Welltap Placement & Power Distribution Network (PDN)            "
puts "=========================================================================="
# Insert substrate & nwell taps every 14 microns
tapcell -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1 -distance 14

# Global power and ground hookup
add_global_connection -net VPWR -pin_pattern "^VPWR$" -power
add_global_connection -net VPWR -pin_pattern "^VPB$"  -power
add_global_connection -net VGND -pin_pattern "^VGND$" -ground
add_global_connection -net VGND -pin_pattern "^VNB$"  -ground
global_connect

# Power distribution network definition
set_voltage_domain -name CORE -power VPWR -ground VGND
define_pdn_grid -name stdcell_grid -starts_with POWER -voltage_domain CORE -pins "met4 met5"
add_pdn_stripe  -grid stdcell_grid -layer met1 -width 0.48 -followpins -starts_with POWER
add_pdn_stripe  -grid stdcell_grid -layer met4 -width 1.60 -pitch 27.20 -offset 13.60 -starts_with POWER
add_pdn_stripe  -grid stdcell_grid -layer met5 -width 1.60 -pitch 27.20 -offset 13.60 -starts_with POWER
add_pdn_connect -grid stdcell_grid -layers "met1 met4"
add_pdn_connect -grid stdcell_grid -layers "met4 met5"
pdngen

write_def $OUT_DIR/floorplan/${DESIGN_NAME}_pdn.def

puts "=========================================================================="
puts " Stage 5: Standard Cell Placement & Legalization                          "
puts "=========================================================================="
set_wire_rc -signal -layer met2
set_wire_rc -clock  -layer met3

# Analytical global placement
global_placement -density 0.55 -timing_driven

# High fanout and tie net optimization
estimate_parasitics -placement
repair_design -max_wire_length 600 -buffer_gain 1.0
repair_tie_fanout "sky130_fd_sc_hd__conb_1/HI" -max_fanout 16
repair_tie_fanout "sky130_fd_sc_hd__conb_1/LO" -max_fanout 16

# Legalize all standard cells
detailed_placement
check_placement -verbose

write_def $OUT_DIR/placement/${DESIGN_NAME}_placed.def

puts "=========================================================================="
puts " Stage 6: Clock Tree Synthesis (CTS) & Hold Timing Optimization           "
puts "=========================================================================="
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_16 \
                     -buf_list "sky130_fd_sc_hd__clkbuf_16 sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_2" \
                     -clk_nets clk

set_propagated_clock [all_clocks]
estimate_parasitics -placement

# Hold buffer insertion post-CTS
repair_timing -hold -hold_margin 0.200 -allow_setup_violations
detailed_placement
check_placement

report_clock_skew -setup > $OUT_DIR/reports/cts_skew_setup.rpt
report_clock_skew -hold  > $OUT_DIR/reports/cts_skew_hold.rpt
write_def $OUT_DIR/cts/${DESIGN_NAME}_cts.def

puts "=========================================================================="
puts " Stage 7: Global & Detailed Routing & Physical Verification               "
puts "=========================================================================="
set_routing_layers -signal met1-met5 -clock met3-met5

# FastRoute Global Routing
global_route -guide_file $OUT_DIR/routing/route.guide -congestion_iterations 50

# TritonRoute Detailed Routing
detailed_route -output_drc $OUT_DIR/reports/droute_drc.rpt \
               -bottom_routing_layer met1 \
               -top_routing_layer met5 \
               -verbose 1

# Filler Cell Insertion
filler_placement "sky130_fd_sc_hd__fill_8 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_1"
check_placement

write_def $OUT_DIR/routing/${DESIGN_NAME}_routed.def

puts "=========================================================================="
puts " Stage 8: Signoff Parasitic Extraction & Static Timing Analysis (STA)     "
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
puts " PHYSICAL DESIGN FLOW COMPLETED SUCCESSFULLY!                             "
puts "=========================================================================="
