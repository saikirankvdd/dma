#!/bin/bash
###############################################################################
# Interactive KLayout GUI Viewer with SkyWater 130nm PDK Technology Stack
###############################################################################

DEF_FILE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pd/routing/dma_axi32_routed.def}"
PDK_ROOT="${PDK_ROOT:-$HOME/.volare/sky130A}"
TECH_LEF="$PDK_ROOT/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef"
CELL_LEF="$PDK_ROOT/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
LYT="$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyt"
LYP="$PDK_ROOT/libs.tech/klayout/tech/sky130A.lyp"
LYM="$PDK_ROOT/libs.tech/klayout/tech/sky130A.map"
SCRIPT="$HOME/.local/lib/python3.12/site-packages/openlane/scripts/klayout/open_design.py"

export LD_LIBRARY_PATH="$HOME/.local/usr/lib/klayout:$HOME/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

echo "Opening $DEF_FILE in KLayout GUI with Sky130 technology..."
export KLAYOUT_ARGV="-l $TECH_LEF -l $CELL_LEF -T $LYT -P $LYP -M $LYM $DEF_FILE"

klayout -rx -rm "$SCRIPT" 2>/dev/null &
echo "KLayout launched in background successfully!"
