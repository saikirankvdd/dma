###############################################################################
# SDC Design Constraints for Provartec PR200 AXI DMA (dma_axi32)
# Target Process: SkyWater 130nm (sky130_fd_sc_hd)
# Target Frequency: 50 MHz (Clock Period = 20.0 ns)
###############################################################################

# Set current design
current_design dma_axi32

# Define Primary Clock (50 MHz)
create_clock -name clk -period 20.000 [get_ports clk]

# Clock Uncertainty and Transition
set_clock_uncertainty 0.250 [get_clocks clk]
set_clock_transition  0.150 [get_clocks clk]

# Set Input / Output Delays (20% of 20ns = 4.0ns)
set_input_delay  -clock clk -max 4.000 [all_inputs -no_clocks]
set_input_delay  -clock clk -min 0.500 [all_inputs -no_clocks]

set_output_delay -clock clk -max 4.000 [all_outputs]
set_output_delay -clock clk -min 0.500 [all_outputs]

# Driving Cell and Output Load
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X [all_inputs -no_clocks]
set_load 0.035 [all_outputs]

# Timing Derate / Margins (PVT Variation)
set_timing_derate -early 0.95
set_timing_derate -late  1.05
