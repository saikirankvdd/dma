#!/bin/bash
set -e

echo "=========================================================="
echo " Stage 1: Running Yosys Synthesis for PR200 (dma_axi32)"
echo " Target: SkyWater 130nm (sky130_fd_sc_hd)"
echo "=========================================================="

cd $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p synth/reports

# Run Yosys with our TCL script
yosys -c synth/scripts/synth_pr200.tcl 2>&1 | tee synth/reports/yosys_synth.log

echo "=========================================================="
echo " Synthesis Finished Successfully!"
echo " Log file:       synth/reports/yosys_synth.log"
echo " Netlist:        synth/reports/dma_axi32_synth.v"
echo " Cell Stats:     synth/reports/synth_stat.txt"
echo "=========================================================="
grep -A 35 "Printing statistics" synth/reports/synth_stat.txt || true
