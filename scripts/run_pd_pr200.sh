#!/bin/bash
set -e

PROJECT_ROOT="/home/saikiran/dma"
LOG_FILE="$PROJECT_ROOT/pd/reports/openroad_pnr.log"

echo "=========================================================="
echo " Starting Physical Design Flow: PR200 AXI DMA (dma_axi32)"
echo " Process: SkyWater 130nm (sky130_fd_sc_hd)"
echo " Tool: OpenROAD v2.0 Native Execution"
echo "=========================================================="

mkdir -p "$PROJECT_ROOT/pd/reports" "$PROJECT_ROOT/pd/floorplan" \
         "$PROJECT_ROOT/pd/placement" "$PROJECT_ROOT/pd/cts" "$PROJECT_ROOT/pd/routing"

export LD_LIBRARY_PATH="/home/saikiran/.local/openroad/usr/lib:/home/saikiran/.local/openroad/usr/lib/x86_64-linux-gnu:/home/saikiran/.local/openroad/opt/or-tools/lib:/home/saikiran/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

openroad -exit "$PROJECT_ROOT/pd/scripts/run_pd_flow.tcl" 2>&1 | tee "$LOG_FILE"

echo ""
echo "=========================================================="
echo " Physical Design Run Completed!"
echo " Log: $LOG_FILE"
echo "=========================================================="
