#!/bin/bash
###############################################################################
# Interactive KLayout GDSII Viewer with SkyWater 130nm Layer Properties
###############################################################################

GDS_FILE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pd/routing/dma_axi32_routed.gds}"
PDK_ROOT="${PDK_ROOT:-$HOME/.volare/sky130A}"
LYP="$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyp"

export LD_LIBRARY_PATH="$HOME/.local/usr/lib/klayout:$HOME/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

echo "Opening production GDSII: $GDS_FILE in KLayout GUI..."
klayout -l "$LYP" "$GDS_FILE" 2>/dev/null &
echo "KLayout GDSII viewer launched successfully!"
