#!/bin/bash
###############################################################################
# Interactive KLayout GDSII Viewer with SkyWater 130nm Layer Properties
###############################################################################

GDS_FILE="${1:-/home/saikiran/dma/pd/routing/dma_axi32_routed.gds}"
PDK_ROOT="/home/saikiran/.volare/sky130A"
LYP="$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyp"

export LD_LIBRARY_PATH="/home/saikiran/.local/usr/lib/klayout:/home/saikiran/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

echo "Opening production GDSII: $GDS_FILE in KLayout GUI..."
klayout -l "$LYP" "$GDS_FILE" 2>/dev/null &
echo "KLayout GDSII viewer launched successfully!"
