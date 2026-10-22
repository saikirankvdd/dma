#!/usr/bin/env bash
# ==============================================================================
# PR200 OpenROAD GUI Layout & Flip-Flop Viewer
# Loads the complete routed DEF with standard cell LEFs
# ==============================================================================
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PDK_ROOT="${PDK_ROOT:-$HOME/.volare/sky130A}"
SCL_LIB="sky130_fd_sc_hd"
DEF_FILE="$REPO_DIR/pd/routing/dma_axi32_routed.def"
TCL_CMD="$REPO_DIR/pd/scripts/.openroad_view.tcl"

cat <<EOF > "$TCL_CMD"
read_lef $PDK_ROOT/libs.ref/$SCL_LIB/techlef/${SCL_LIB}__nom.tlef
read_lef $PDK_ROOT/libs.ref/$SCL_LIB/lef/${SCL_LIB}.lef
read_def $DEF_FILE
puts "=========================================================================="
puts " Design Loaded Successfully!"
puts " To find a Flip-Flop: Press Ctrl+F and search for _15540_ or dfxtp"
puts "=========================================================================="
EOF

echo "Launching OpenROAD GUI with routed DMA layout..."
openroad -gui "$TCL_CMD"
