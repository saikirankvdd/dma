# PR200 AXI DMA Controller: Complete Commands & Execution Guide

**Author:** Physical Design & Verification Engineer  
**Target Process:** SkyWater 130nm CMOS (`sky130_fd_sc_hd`)  
**Design:** `dma_axi32` (32-bit Dual-Core AXI3 DMA Controller)  
**EDA Flow:** Icarus Verilog $\to$ Yosys $\to$ OpenROAD v2.0 $\to$ KLayout v0.28.16  

---

## 📌 Overview

This document provides a complete, step-by-step command reference for building, simulating, synthesizing, physically implementing, and visualizing the Provartec PR200 DMA controller on SkyWater 130nm silicon.

---

## 🛠️ Step 0: Set Working Directory

Always open your terminal and change to the project directory:

```bash
cd <project-root>
```

---

## 🧪 Step 1: RTL Simulation & Functional Verification

### 1.1 Baseline Functional Verification (8 Words / 32 Bytes)
Compiles all 48 RTL Verilog source files and executes an 8-word AXI3 burst transfer with cycle-accurate testbench checking:

```bash
./scripts/run_sim_pr200.sh
```
* **Output Log:** `sim/logs/sim_pr200.log`
* **Dumped Waveform:** `sim/waveforms/dma_axi32.vcd`
* **Expected Result:** `[TB] TEST PASSED! 8/8 words transferred with 0 errors!`

---

### 1.2 Extended Multi-Scenario Stress Test (6 Test Cases)
Tests 6 distinct burst transfer scenarios (up to 256 bytes) and memory wait-state stalls:

```bash
iverilog -g2005 -Wall -Idma_axi/src/dma_axi32 -o sim/build/tb_dma_axi32_stress tb/tb_dma_axi32_stress.v $(awk '{print "dma_axi/src/dma_axi32/" $1}' dma_axi/src/dma_axi32/filelist.txt)
vvp sim/build/tb_dma_axi32_stress
```
* **Output Log:** `sim/logs/sim_stress.log`
* **Dumped Waveform:** `sim/waveforms/dma_axi32_stress.vcd`
* **Expected Result:** `STATUS: >>> 100% PASSED (ZERO DEFECTS) <<<`

---

### 1.3 Ultra-Extreme Stress Test (Concurrent 3D Gaming + Edge AI)
Tests massive 512-byte AI weight streaming, 4KB page boundary auto-splitting (`0x1000` page line), and random DDR bus jitter:

```bash
iverilog -g2005 -Wall -Idma_axi/src/dma_axi32 -o sim/build/tb_dma_axi32_ultra_stress tb/tb_dma_axi32_ultra_stress.v $(awk '{print "dma_axi/src/dma_axi32/" $1}' dma_axi/src/dma_axi32/filelist.txt)
vvp sim/build/tb_dma_axi32_ultra_stress
```
* **Output Log:** `sim/logs/sim_ultra_stress.log`
* **Dumped Waveform:** `sim/waveforms/dma_axi32_ultra_stress.vcd`
* **Expected Result:** `FINAL CHIP VERDICT: >>> 100% VERIFIED — MILITARY-GRADE SILICON INTEGRITY <<<`

---

### 1.4 Viewing Digital Waveforms in GTKWave
Open the waveform viewer in the background:

```bash
# Baseline 32-Byte Transfer:
gtkwave sim/waveforms/dma_axi32.vcd &

# Ultra-Stress Workload:
gtkwave sim/waveforms/dma_axi32_ultra_stress.vcd &
```

#### What Signals to Add and Inspect:
1. **Clock & Reset:** `clk`, `reset`
2. **AXI Write Channel:** `M0_AWADDR`, `M0_AWVALID`, `M0_AWREADY`, `M0_WDATA`, `M0_WSTRB`, `M0_WLAST`, `M0_WVALID`, `M0_WREADY`, `M0_BVALID`, `M0_BREADY`
3. **AXI Read Channel:** `M0_ARADDR`, `M0_ARVALID`, `M0_ARREADY`, `M0_RDATA`, `M0_RLAST`, `M0_RVALID`, `M0_RREADY`
4. **DMA Interrupt Line:** `INT` (asserts high when transfer completes)

---

## 🧱 Step 2: Gate-Level Logic Synthesis (Yosys)

Translates RTL Verilog into 9,315 standard cells mapped to `sky130_fd_sc_hd`:

```bash
./scripts/run_synth_pr200.sh
```
* **Output Gate Netlist:** `synth/reports/dma_axi32_synth.v` (2.3 MB)
* **View Cell Count & Area Statistics:**
```bash
cat synth/reports/synth_stat.txt
```

---

## ⚡ Step 3: ASIC Physical Design Flow (OpenROAD)

Runs the automated multi-threaded physical design flow (Floorplanning $\to$ PDN $\to$ Placement $\to$ CTS $\to$ Routing $\to$ STA):

```bash
./scripts/run_pd_pr200.sh
```

---

## 🔍 Step 4: Timing & DRC Signoff Reports

Check electrical timing closure ($50\,\text{MHz}$ / $20.0\,\text{ns}$):

```bash
# 1. Setup Slack (Target: >= 0.00 ns)
cat pd/reports/worst_setup_slack.rpt
# Output: slack 11.10 (MET ✅)

# 2. Hold Slack (Target: >= 0.00 ns)
cat pd/reports/worst_hold_slack.rpt
# Output: slack 0.20 (MET ✅)

# 3. Total Negative Slack (Target: 0.00 ns)
cat pd/reports/total_negative_slack.rpt
# Output: tns 0.00 (MET ✅)

# 4. Detailed Worst Path Timing Breakdown
head -n 45 pd/reports/sta_setup.rpt

# 5. Routing DRC Violations (Target: 0)
wc -l pd/reports/droute_drc.rpt
```

---

## 🔬 Step 5: Interactive Silicon Layout Inspection (KLayout)

### 5.1 View Individual Metal Layers Separately
We created dedicated isolated layer viewers so you can inspect each metal level with zero visual clutter:

```bash
# View ONLY Layer 1 (met1 - Blue: Standard Cell Rails & Local Logic)
./scripts/view_layer.sh met1

# View ONLY Layer 2 (met2 - Red: Vertical Interconnects & I/O Pins)
./scripts/view_layer.sh met2

# View ONLY Layer 3 (met3 - Green: Horizontal Signal Buses & I/O Pins)
./scripts/view_layer.sh met3

# View ONLY Layer 4 (met4 - Purple: Horizontal Power Straps)
./scripts/view_layer.sh met4

# View ONLY Layer 5 (met5 - Orange: Top Vertical Power Mesh)
./scripts/view_layer.sh met5

# View All 5 Metal Layers Combined (Clean High-Contrast View)
./scripts/view_layer.sh all
```

### 5.2 View Full Production GDSII with All Layers
```bash
./scripts/view_gds_klayout.sh
```

### Useful KLayout Keyboard Shortcuts:
* **`F`**: Zoom-to-fit (view full die: $462.92\,\mu\text{m} \times 462.92\,\mu\text{m}$).
* **Right-Click Drag**: Draw a rectangle to zoom into any standard cell cluster or routing channel.
* **`R`**: Open the interactive ruler to measure wire widths, spacings, or pin pitches.
* **`Ctrl + Wheel`**: Zoom in / out smoothly.
* **`Ctrl + H`**: Make only the selected layer visible.

---

## 📦 Step 6: Git & GitHub Synchronization

To push modifications and new tests to your GitHub repository:

```bash
# 1. Check status
git status

# 2. Stage changes
git add .

# 3. Commit with a message
git commit -m "Your descriptive commit message"

# 4. Push to GitHub
git push origin main
```

* **Live GitHub Repository:** [https://github.com/<your-username>/dma](https://github.com/<your-username>/dma)
