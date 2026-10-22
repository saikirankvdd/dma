#!/bin/bash
###############################################################################
# Isolated Layer Viewer for SkyWater 130nm PR200 AXI DMA Controller
# Usage:
#   ./scripts/view_layer.sh feol     (Combined Front-End: Wells + Diff/Tap + Poly)
#   ./scripts/view_layer.sh routing  (Combined Back-End: Contacts + Vias + Metals 1-5)
#   ./scripts/view_layer.sh wells    (View only Wells - nwell, pwell, dnwell)
#   ./scripts/view_layer.sh diff     (View only Diffusion & Taps)
#   ./scripts/view_layer.sh poly     (View only Polysilicon Gates)
#   ./scripts/view_layer.sh contacts (View Contacts - licon, li1, mcon)
#   ./scripts/view_layer.sh vias     (View all Inter-metal Vias - via1 to via4)
#   ./scripts/view_layer.sh met1     (View only Layer 1 - Standard Cell Rails)
#   ./scripts/view_layer.sh met2     (View only Layer 2 - Vertical Routing & Pins)
#   ./scripts/view_layer.sh met3     (View only Layer 3 - Horizontal Routing & Pins)
#   ./scripts/view_layer.sh met4     (View only Layer 4 - Horizontal Power Straps)
#   ./scripts/view_layer.sh met5     (View only Layer 5 - Vertical Power Mesh)
#   ./scripts/view_layer.sh all      (View all 5 metal layers combined)
###############################################################################

LAYER="${1:-all}"
GDS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pd/routing/dma_axi32_routed.gds"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/layers"

case "$LAYER" in
    feol|device|devices|wells_all|silicon)
        LYP="$SCRIPT_DIR/feol.lyp"
        DESC="All Silicon/Device Layers Combined (Wells, Diffusion, Taps, Poly)"
        ;;
    routing|beol|interconnect|routing_all)
        LYP="$SCRIPT_DIR/routing_all.lyp"
        DESC="All Interconnect & Routing Combined (Contacts, Vias, Metals 1 to 5)"
        ;;
    contacts|contact|mcon|licon)
        LYP="$SCRIPT_DIR/contacts.lyp"
        DESC="Contacts & Local Interconnect (licon, li1, mcon)"
        ;;
    vias|via)
        LYP="$SCRIPT_DIR/vias.lyp"
        DESC="All Inter-Metal Vias (via1, via2, via3, via4)"
        ;;
    wells|well|nwell|pwell)
        LYP="$SCRIPT_DIR/wells.lyp"
        DESC="Wells (nwell, pwell, dnwell) — Substrate & Well Tubs"
        ;;
    poly|gate)
        LYP="$SCRIPT_DIR/poly.lyp"
        DESC="Polysilicon (poly) — Transistor Gates"
        ;;
    diff|active|tap)
        LYP="$SCRIPT_DIR/diff.lyp"
        DESC="Diffusion & Tap (diff, tap) — Active Source/Drain Regions"
        ;;
    met1|m1|1)
        LYP="$SCRIPT_DIR/met1.lyp"
        DESC="Layer 1 (met1) — Standard Cell Power Rails & Local Logic"
        ;;
    met2|m2|2)
        LYP="$SCRIPT_DIR/met2.lyp"
        DESC="Layer 2 (met2) — Vertical Signal Interconnects & I/O Pins"
        ;;
    met3|m3|3)
        LYP="$SCRIPT_DIR/met3.lyp"
        DESC="Layer 3 (met3) — Horizontal Long-Distance Routing & I/O Pins"
        ;;
    met4|m4|4)
        LYP="$SCRIPT_DIR/met4.lyp"
        DESC="Layer 4 (met4) — Upper Horizontal Power Straps"
        ;;
    met5|m5|5)
        LYP="$SCRIPT_DIR/met5.lyp"
        DESC="Layer 5 (met5) — Top Thick Vertical Power Distribution Grid"
        ;;
    all|5|*)
        LYP="$SCRIPT_DIR/metals_all.lyp"
        DESC="All 5 Metal Layers Combined (met1 to met5)"
        ;;
esac

export LD_LIBRARY_PATH="$HOME/.local/usr/lib/klayout:$HOME/.local/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

echo "=========================================================================="
echo " Launching KLayout for: $DESC"
echo " Target GDSII: $GDS_FILE"
echo " Layer Properties: $LYP"
echo "=========================================================================="

klayout -l "$LYP" "$GDS_FILE" 2>/dev/null &
echo "KLayout viewer launched in background!"
