# ==============================================================================
# Yosys Synthesis Script: PR200 AXI DMA (dma_axi32)
# Target Technology: SkyWater 130nm (sky130_fd_sc_hd)
# ==============================================================================

set RTL_DIR "dma_axi/src/dma_axi32"
set PDK_LIB "/home/saikiran/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

yosys -import

puts "=== Step 1/5: Reading Verilog RTL Files ==="
read_verilog -I$RTL_DIR $RTL_DIR/dma_axi32_defines.v

# Read all files from filelist.txt
set fp [open "$RTL_DIR/filelist.txt" r]
set file_data [read $fp]
close $fp
set data [split $file_data "\n"]
foreach line $data {
    set file_name [string trim $line]
    if {$file_name != "" && [file exists "$RTL_DIR/$file_name"]} {
        read_verilog -I$RTL_DIR "$RTL_DIR/$file_name"
    }
}

puts "=== Step 2/5: Elaborating Design Hierarchy (Top: dma_axi32) ==="
hierarchy -check -top dma_axi32

puts "=== Step 3/5: High-Level Logic Optimization & FSM Extraction ==="
proc
opt_expr
opt_clean
check
fsm
opt
wreduce
peepopt
opt_clean
share
opt
memory -nomap
opt_clean

puts "=== Step 4/5: Technology Mapping to SkyWater 130nm Standard Cells ==="
# Map D-Flip-Flops to SkyWater HD library
dfflibmap -liberty $PDK_LIB

# ABC Logic Optimization and Technology Gate Mapping
abc -liberty $PDK_LIB

opt_clean

puts "=== Step 5/5: Writing Synthesized Gate-Level Netlist & Statistics ==="
write_verilog -noattr synth/reports/dma_axi32_synth.v
tee -o synth/reports/synth_stat.txt stat -liberty $PDK_LIB

puts "=============================================================================="
puts " Synthesis Complete! Gate netlist: synth/reports/dma_axi32_synth.v"
puts " Area & Cell Statistics: synth/reports/synth_stat.txt"
puts "=============================================================================="
