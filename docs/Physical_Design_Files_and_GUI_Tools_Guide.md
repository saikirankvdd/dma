# ASIC Physical Design: File Formats, Stage Deliverables & Cadence Innovus Equivalents

> **Reference**: ASIC Physical Design Reference Book (Chapters 1–17)  
> **Technology**: SkyWater 130nm (`sky130_fd_sc_hd`)  
> **Core**: PR200 32-bit AXI DMA Controller (`dma_axi32`)

---

## 1. The Fundamental Transformation: "Am I Right?"

**YES!** Your mental model is completely on target:
> We take abstract, human-written Verilog code (`.v`) and convert it into real, physical silicon cells that have geometry, area, power consumption, and picosecond timing delays.

### The Key Distinction to Understand (Foundry vs. Your Design)
To keep the terminology completely clear:
1. **The Foundry Files (The "Lego Catalog")**:
   - You do **not** convert Verilog into `.lib` or `.lef`.
   - The foundry (SkyWater) **gives** you `.lib` and `.lef`.
   - **`.lib` (Liberty File)**: A text file describing every gate's delay, setup/hold requirements, and power (e.g., "A 2-input NAND gate takes 45 picoseconds and 1.2 microwatts").
   - **`.lef` (Library Exchange Format)**: A file describing every gate's physical shape, bounding box, and pin connection coordinates (e.g., "NAND gate is 1.38 µm wide, 2.72 µm high, with pin A on Metal 1").
2. **Your Verilog Files (The "Blueprint")**:
   - `dma_axi32.v` is your logical blueprint. It contains behavioral equations like `if (start) state <= READ;`.
3. **The Synthesis Tool (The "Builder")**:
   - **Yosys** reads your blueprint (`.v`) **and** reads the foundry's catalog (`.lib`), and builds the **Gate-Level Netlist (`.v`)** using only the real standard cells in the catalog.

---

## 2. Complete File Format Map Across All Physical Design Stages

Here is the exact breakdown of the files used and produced at every single stage of the flow (matching the Physical Design Reference book):

| Stage | What Happens | Input Files Needed | Output Files Produced |
| :--- | :--- | :--- | :--- |
| **0. RTL Simulation** | Verify logic behavior before synthesis | • `dma_axi32.v` (RTL)<br>• `tb_dma_axi32.v` (Testbench) | • `sim.log` (Console test log)<br>• `waveforms.vcd` (Signal traces) |
| **1. Logic Synthesis** (Yosys) | Translates behavioral Verilog into logic gates | • `dma_axi32.v` (RTL)<br>• `sky130_fd_sc_hd.lib` (Cell timing/logic catalog) | • `dma_axi32_synth.v` (Gate-level netlist)<br>• `synth_stat.txt` (Gate count, area report) |
| **2. Design Constraints** | Specifies clock speed, delays, uncertainties | • User timing requirements | • `dma_axi32.sdc` (Synopsys Design Constraints) |
| **3. Floorplanning** | Defines die boundary, core area, and IO pin positions | • `dma_axi32_synth.v`<br>• `sky130.tlef` (Tech rules)<br>• `sky130.lef` (Cell shapes)<br>• `dma_axi32.sdc` | • `floorplan.def` (Die size & pin coordinates)<br>• `floorplan.fp` |
| **4. Power Planning (PDN)** | Builds VDD and VSS power rings and vertical/horizontal stripes | • `floorplan.def`<br>• Tech LEF | • `pdn.def` (Contains power grid metal tracks) |
| **5. Standard Cell Placement** | Places thousands of standard cells into rows | • `pdn.def`<br>• `sky130.lef`<br>• `dma_axi32.sdc` | • `placement.def` (X,Y locations of every single gate)<br>• Placement congestion report |
| **6. Clock Tree Synthesis (CTS)** | Builds balanced buffer tree for clock net; minimizes skew | • `placement.def`<br>• `sky130.lib` (Clock buffers)<br>• `dma_axi32.sdc` | • `cts.def` (Includes inserted clock buffers)<br>• `cts_skew.rpt` (Skew & latency report) |
| **7. Routing (Global & Detailed)** | Wires all pins together with real copper/aluminum metal layers (M1–M5) | • `cts.def`<br>• Tech LEF (Metal pitch & spacing rules) | • `routed.def` (Complete physical wire routing)<br>• `drc_violations.rpt` |
| **8. Parasitic Extraction (RC Extraction)** | Calculates actual wire resistance (R) and capacitance (C) | • `routed.def`<br>• RC technology rules | • `dma_axi32.spef` (Standard Parasitic Exchange Format) |
| **9. Static Timing Analysis (STA)** | Checks if the chip runs at target clock speed ($WNS \ge 0$) | • `dma_axi32_synth.v`<br>• `dma_axi32.spef`<br>• `sky130.lib`<br>• `dma_axi32.sdc` | • `sta_setup.rpt` (Worst Negative Slack, Setup)<br>• `sta_hold.rpt` (Hold Slack)<br>• `dma_axi32.sdf` (Back-annotated delays) |
| **10. Physical Verification (DRC & LVS)** | Design Rule Checking & Layout vs. Schematic verification | • `routed.def` / GDS<br>• DRC rule deck (`sky130A.magicrc`)<br>• Netlist (`.v`) | • `drc.rpt` (Zero DRC errors)<br>• `lvs.rpt` (Netlist vs Layout match report) |
| **11. Chip Finishing & Tapeout** | Adds decap & filler cells, generates mask file | • `routed.def`<br>• Filler LEF | • `dma_axi32.gds` (Final GDSII silicon file!)<br>• Final Silicon Layout View |

---

## 3. Cadence Innovus vs. Open-Source Equivalents

### The Commercial Reality: What is Cadence Innovus?
**Cadence Innovus** is the leading commercial EDA software used by companies like Apple, NVIDIA, and Qualcomm for ASIC Place and Route (P&R).
- **The problem**: An Innovus license costs **$50,000+ to $100,000+ per year** and requires proprietary commercial PDKs (TSMC, Intel, Samsung) locked behind strict non-disclosure agreements (NDAs). Academic textbooks and university courses teach the conceptual steps using Innovus terminology.

### The Open-Source Solution: OpenROAD GUI & KLayout
You do **NOT** need Cadence Innovus to achieve a full, visually stunning, industry-grade ASIC physical design! The open-source community created 1-to-1 functional equivalents:

```
+---------------------------------------+---------------------------------------+
|          Cadence Commercial Flow      |         Open-Source Flow (Our Setup)  |
+---------------------------------------+---------------------------------------+
| Cadence Genus (Synthesis)             | Yosys                                 |
| Cadence Innovus GUI (Floorplan & P&R) | OpenROAD GUI (openroad -gui)          |
| Cadence Tempus (Timing / STA)         | OpenSTA                               |
| Cadence Quantus (Extraction)          | OpenROAD OpenRCX (SPEF generator)     |
| Cadence Pegasus / Mentor Calibre(DRC) | Magic & KLayout DRC                   |
| Final GDSII Mask Viewer               | KLayout                               |
+---------------------------------------+---------------------------------------+
```

---

## 4. How to View & Present Your Results Visually (The GUI Experience)

When you present your project to professors, evaluators, or in your technical report, you can show **rich, colorful, interactive layout views just like Cadence Innovus**:

### 1. OpenROAD GUI (`openroad -gui`)
This is the direct graphical equivalent of Innovus:
- **What it shows**:
  - The purple/blue die outline and IO pin pads.
  - The thick horizontal and vertical power straps (VDD 1.8V and VSS).
  - Individual standard cell rows and standard cells (NAND, Flip-Flops, MUXes).
  - The **Clock Tree flylines**: Visualizing the H-tree distributing clock pulses from the central root buffer to thousands of flip-flops.
  - **Metal Routing Layers**: Metal 1 (blue), Metal 2 (red), Metal 3 (green), Metal 4 (yellow), Metal 5 (orange).
  - Routing congestion heatmaps (green = clear, red = congested).

### 2. KLayout (`klayout`)
This is the industry standard for viewing the finished silicon chip:
- Loads the final `.def` or `.gds` file.
- Shows real microscopic transistor diffusions, polysilicon gates, contact vias, and multi-layer metallization.
- Allows zooming in from the millimeter-scale chip level down to the sub-micron scale of an individual inverter gate.

### 3. Visual Screenshots for Your Academic Report:
In the report, you will include:
1. **Floorplan view**: Core boundary, aspect ratio, IO pin placement.
2. **PDN view**: Power ring and strap distribution.
3. **Placement view**: Standard cell distribution and row utilization.
4. **Clock Tree view**: Clock skew distribution and clock buffer locations.
5. **Final Routed Layout**: All 5 metal layers fully routed with 0 DRC violations.

---

## 5. Summary: What This Means for Your Next Step

1. **All the tools needed to generate every one of these files and GUIs are already installed on your machine.**
2. You do **not** need to buy Cadence Innovus. Everything required by the reference book and your academic evaluation is fully supported with real silicon accuracy using **Yosys + OpenROAD + SKY130A + KLayout**.
3. We are ready to run the flow step-by-step, saving the logs, `.v` netlists, `.def` layouts, `.spef` parasitics, and layout images at each milestone!
