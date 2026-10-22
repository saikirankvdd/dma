#!/bin/bash
set -e

echo "=========================================================="
echo " Stage 0: Compiling & Simulating PR200 dma_axi32 RTL"
echo "=========================================================="

cd $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Gather all 48 source files
RTL_DIR="dma_axi/src/dma_axi32"
FILES=$(awk '{print "dma_axi/src/dma_axi32/" $1}' $RTL_DIR/filelist.txt | tr '\n' ' ')

mkdir -p sim/build sim/logs sim/waveforms

echo "[1/2] Compiling with Icarus Verilog..."
iverilog -g2005 -Wall -I$RTL_DIR -o sim/build/tb_dma_axi32 tb/tb_dma_axi32.v $FILES 2>&1 | tee sim/logs/compile_pr200.log

echo "[2/2] Running simulation..."
vvp sim/build/tb_dma_axi32 2>&1 | tee sim/logs/sim_pr200.log

echo "=========================================================="
echo " Simulation Complete! VCD saved to sim/waveforms/dma_axi32.vcd"
echo "=========================================================="
