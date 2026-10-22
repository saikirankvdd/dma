#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/pd/reports/openroad_resume_route.log"
PDK_ROOT="${PDK_ROOT:-$HOME/.volare/sky130A}"

echo "=========================================================="
echo " Launching 12-Thread Accelerated Resume Routing & Signoff"
echo " Top: PR200 AXI DMA (dma_axi32)"
echo " Checkpoint: pd/cts/dma_axi32_cts.def"
echo " Threads: 12 (Parallel CPU Workers)"
echo "=========================================================="

mkdir -p "$PROJECT_ROOT/pd/reports" "$PROJECT_ROOT/pd/routing"

export LD_LIBRARY_PATH="$HOME/.local/openroad/usr/lib:$HOME/.local/openroad/usr/lib/x86_64-linux-gnu:$HOME/.local/openroad/opt/or-tools/lib:$HOME/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

openroad -exit "$PROJECT_ROOT/pd/scripts/run_resume_route.tcl" 2>&1 | tee "$LOG_FILE"

echo ""
echo "=========================================================="
echo " Detailed Routing Complete! Streaming out final GDSII..."
echo "=========================================================="

python3 $HOME/.local/lib/python3.12/site-packages/openlane/scripts/klayout/stream_out.py \
    -o "$PROJECT_ROOT/pd/routing/dma_axi32_routed.gds" \
    -l "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef" \
    -l "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef" \
    -T "$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyt" \
    -P "$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyp" \
    -M "$PDK_ROOT/libs.tech/klayout/tech/sky130A.map" \
    -w "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds" \
    -t dma_axi32 \
    "$PROJECT_ROOT/pd/routing/dma_axi32_routed.def"

echo ""
echo "=========================================================="
echo " Rendering Final Layout Snapshot..."
echo "=========================================================="

python3 $HOME/.local/lib/python3.12/site-packages/openlane/scripts/klayout/render.py \
    -o "$PROJECT_ROOT/pd/routing/dma_axi32_routed.png" \
    -l "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef" \
    -l "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef" \
    -T "$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyt" \
    -P "$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyp" \
    -M "$PDK_ROOT/libs.tech/klayout/tech/sky130A.map" \
    "$PROJECT_ROOT/pd/routing/dma_axi32_routed.def"

echo ""
echo "=========================================================="
echo " ALL PHYSICAL DESIGN & GDSII TASKS COMPLETED!"
echo " Log: $LOG_FILE"
echo " GDS: $PROJECT_ROOT/pd/routing/dma_axi32_routed.gds"
echo " PNG: $PROJECT_ROOT/pd/routing/dma_axi32_routed.png"
echo "=========================================================="
