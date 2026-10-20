#!/bin/sh
set -eu
mkdir -p build
iverilog -g2012 -Wall -o build/tb_dma_demo rtl/dma_demo.v tb/tb_dma_demo.v
vvp build/tb_dma_demo
