# PR200 AXI DMA: SoC Context, Hardware Architecture & ASIC Physical Design Methodology

> **Project Reference Guide**: PR200 TRM Rev 1.6  
> **Physical Design Reference**: ASIC Physical Design Reference Book (Chapters 1–17)  
> **Technology Target**: SkyWater 130nm (SKY130A High Density Standard Cells)  
> **Design Target**: 32-bit AXI DMA Controller (`dma_axi32`)

---

## Table of Contents
1. [The Big Picture: What is an SoC and Why Does it Need a DMA?](#1-the-big-picture-what-is-an-soc-and-why-does-it-need-a-dma)
2. [The Provartec PR200 IP and Repository Overview](#2-the-provartec-pr200-ip-and-repository-overview)
3. [Deep-Dive: PR200 Hardware Architecture](#3-deep-dive-pr200-hardware-architecture)
4. [Life of a DMA Transfer: Step-by-Step Flow](#4-life-of-a-dma-transfer-step-by-step-flow)
5. [The Physical Design Flow: Aligning with the Reference Book](#5-the-physical-design-flow-aligning-with-the-reference-book)
6. [Mapping Tools to the Physical Design Flow](#6-mapping-tools-to-the-physical-design-flow)
7. [Current Project Status & Roadmap](#7-current-project-status--roadmap)

---

## 1. The Big Picture: What is an SoC and Why Does it Need a DMA?

### 1.1 What is a System-on-Chip (SoC)?
A **System-on-Chip (SoC)** integrates all the essential components of a computer or electronic system into a single silicon chip. Rather than having separate chips on a motherboard, an SoC combines:
- **Processor Core(s)**: CPU (e.g., ARM Cortex-A/M, RISC-V) running the operating system and applications.
- **High-Speed Interconnect Bus**: High-bandwidth fabric (e.g., ARM AMBA **AXI4**, AXI3) connecting fast modules like DDR RAM controllers and high-speed peripherals.
- **Low-Speed Peripheral Bus**: Low-power, simple peripheral fabric (e.g., AMBA **APB3**) connecting control registers, timers, UART, SPI, and GPIO.
- **Memories**: On-chip SRAM, boot ROM, and external DDR/LPDDR memory controllers.
- **Peripherals**: Network controllers (Ethernet MAC), storage (eMMC/SD), crypto engines, video codecs, and serial interfaces.

```
       +-----------------------------------------------------------+
       |                        System-on-Chip (SoC)               |
       |                                                           |
       |  +-----------+     +------------+      +---------------+  |
       |  |  CPU Core |     | On-Chip    |      |  DDR Memory   |  |
       |  | (ARM/RV)  |     | SRAM       |      |  Controller   |  |
       |  +-----+-----+     +-----+------+      +-------+-------+  |
       |        |                 |                     |          |
       |  ======v=================v=====================v========  |
       |              AMBA AXI High-Performance Bus Fabric         |
       |  ======^=======================================^========  |
       |        |                                       |          |
       |  +-----+-----+                           +-----+-----+    |
       |  | DMA Master| (PR200 Controller)        | Ethernet/ |    |
       |  | (Offload) |                           | PCIe MAC  |    |
       |  +-----+-----+                           +-----------+    |
       |        | (Control)                                        |
       |  ======v================================================  |
       |              AMBA APB3 Peripheral Control Bus             |
       |  ======+===================+===================+========  |
       |        |                   |                   |          |
       |  +-----v----+        +-----v----+        +-----v----+     |
       |  |   UART   |        |   SPI    |        |  Timers  |     |
       |  +----------+        +----------+        +----------+     |
       +-----------------------------------------------------------+
```

---

### 1.2 The Problem: Why Can't the CPU Copy the Data?
Without a DMA engine, when 10 Megabytes of network packets arrive at an Ethernet interface and need to be stored into DDR RAM:
1. The CPU must execute a `LOAD` instruction from the peripheral address into a CPU register.
2. The CPU must execute a `STORE` instruction from the CPU register into the DDR RAM address.
3. The CPU increments pointers, decrements loop counters, and tests for zero.
4. **Result**: The multi-gigahertz CPU spends millions of clock cycles stuck in a memory-copy loop. The CPU cannot run application tasks, cache is polluted with streaming data, and battery power is wasted.

### 1.3 The Solution: Direct Memory Access (DMA)
A **DMA Controller** is a dedicated hardware co-processor whose entire job is to pump data from one address to another at wire speed, completely independent of the CPU:
1. The CPU tells the DMA: *"Copy 64 KB from Peripheral/Memory address `0x2000_0000` to Memory address `0x8000_0000`, then notify me."* (This takes just ~5 APB register writes).
2. The CPU goes back to running other programs or enters low-power sleep.
3. The DMA masters the AXI bus: it bursts data in through read channels (`AR`, `R`), buffers it inside an internal FIFO, and bursts data out through write channels (`AW`, `W`).
4. When the transfer completes, the DMA raises an **interrupt line (`INT`)** to the CPU.

---

## 2. The Provartec PR200 IP and Repository Overview

### 2.1 What is the PR200 IP?
The **PR200** (developed by Provartec) is a configurable, dual-core, high-performance DMA controller designed specifically for AMBA AXI-based SoCs.
- **Original Reference Guide**: `PR200_trm_rev1.6.pdf`
- **Original Source Paradigm**: Written in **RobustVerilog** (a pre-processor meta-language) and parsed/generated into synthesizable standard Verilog.

### 2.2 The Dual-Core Concept (Section 1.2 of TRM)
The PR200 architecture recognizes that SoCs have two completely different types of DMA tasks:
| Characteristic | Task 1: Memory Copy (Core 0) | Task 2: Peripheral Control (Core 1) |
| :--- | :--- | :--- |
| **Example Devices** | Framebuffers, DDR-to-SRAM, Cryptography | UART, SPI, I2C, Audio CODEC |
| **Latency Demand** | As low as possible | Can tolerate high latency |
| **Transfer Speed** | Maximum bus throughput (GB/s) | Slow (kilobytes to megabytes/s) |
| **FIFO Buffer Size** | Large buffers (deep FIFO) | Minimal FIFO (saves chip area) |
| **Burst Type** | Wide, aligned bursts (INCR16) | Small bursts or single beats |

In a full dual-core build, Core 0 handles high-speed memory streaming, while Core 1 handles slow peripherals (optionally running on a divided slower clock to save dynamic power).

### 2.3 What Does Our Checked-Out Repository (`dma_axi`) Contain?
In our cloned repository (`/home/saikiran/dma/dma_axi`), the author checked in two concrete, pre-generated configurations:
1. **`src/dma_axi32/`**: A fully elaborated **32-bit AXI** implementation.
2. **`src/dma_axi64/`**: A fully elaborated **64-bit AXI** implementation.

For our academic project, we focus on **`dma_axi32`** because 32-bit interfaces align directly with open-source microcontroller/embedded SoCs (e.g., standard RISC-V RV32I cores) and map efficiently to the SkyWater 130nm cell area budget.

#### Exact Build Parameters of `dma_axi32`:
- **AXI Data Width**: 32 bits (`WDATA[31:0]`, `RDATA[31:0]`)
- **AXI Address Width**: 32 bits (`AWADDR[31:0]`, `ARADDR[31:0]`)
- **Number of Channels**: 1 Channel (`core0_ch`)
- **Internal Data FIFO**: 32 Bytes
- **AXI Outstanding Commands**: 2 concurrent read commands, 2 concurrent write commands
- **Configuration Bus**: AMBA 3 APB (`paddr`, `pwdata`, `prdata`, `psel`, `penable`, `pready`)
- **Transfer Modes Supported**:
  - Independent mode (standard source-to-destination)
  - Joint mode (synchronized read/write processing)
  - Command lists (linked-list descriptor transfers without CPU intervention)
- **Error/Safety Features**: Watchdog timer (`dma_axi32_core0_wdt.v`), AXI bus timeout logic.

---

## 3. Deep-Dive: PR200 Hardware Architecture

The top-level Verilog module is **`dma_axi32`** (in `dma_axi32.v`). Below is its internal architectural decomposition:

```
+---------------------------------------------------------------------------------------------------+
|                                        dma_axi32 (Top Level)                                      |
|                                                                                                   |
|  +------------------------+                                                                       |
|  |  APB3 Slave Interface  |<==== APB Bus (psel, penable, paddr[12:0], pwdata[31:0], prdata)       |
|  |  (dma_axi32_apb_mux)   |                                                                       |
|  +-----------+------------+                                                                       |
|              |                                                                                    |
|              v                                                                                    |
|  +------------------------+        +-----------------------------------------------------------+  |
|  | Configuration & Status |------->| Watchdog Timer (dma_axi32_core0_wdt.v)                     |  |
|  | Registers (reg_core0)  |        +-----------------------------------------------------------+  |
|  +-----------+------------+                                                                       |
|              |                                                                                    |
|              v                                                                                    |
|  +---------------------------------------------------------------------------------------------+  |
|  |                                Core 0 Channel Engine (core0_ch)                             |  |
|  |                                                                                             |  |
|  |   +--------------------------+  +--------------------------+  +--------------------------+  |  |
|  |   | Address Calculator       |  | Size & Offset Engine     |  | Command Slicers          |  |  |
|  |   | (ch_calc_addr.v)         |  | (ch_calc_size.v)         |  | (rd_slicer / wr_slicer)  |  |  |
|  |   +--------------------------+  +--------------------------+  +--------------------------+  |  |
|  |                                                                                             |  |
|  |   +--------------------------------------------------------------------------------------+  |  |
|  |   | Internal Data FIFO (prgen_fifo.v / ch_fifo.v) - 32 Bytes Buffer                      |  |  |
|  |   +--------------------------------------------------------------------------------------+  |  |
|  +----------------------------------------------+----------------------------------------------+  |
|                                                 |                                                 |
|                                                 v                                                 |
|  +---------------------------------------------------------------------------------------------+  |
|  |                                AXI Master Command & Data Engines                            |  |
|  |                                                                                             |  |
|  |   +---------------------------+   +---------------------------+   +---------------------+   |  |
|  |   | AXI Read Engine (axim_rd) |   | AXI Write Engine(axim_wr) |   | Arbiter & Timeout   |   |  |
|  |   | (ARADDR, ARLEN, RDATA)    |   | (AWADDR, AWLEN, WDATA)    |   | (axim_cmd / axim_to)|   |  |
|  |   +-------------+-------------+   +-------------+-------------+   +----------+----------+   |  |
|  +-----------------|-------------------------------|----------------------------|--------------+  |
|                    |                               |                            |                 |
+--------------------|-------------------------------|----------------------------|-----------------+
                     |                               |                            |
                     v                               v                            v
               AXI Read Bus                    AXI Write Bus                 Interrupt Line
            (ARVALID, RVALID, etc.)         (AWVALID, WVALID, etc.)             (INT)
```

### 3.1 Sub-Module Breakdown
1. **`dma_axi32_apb_mux.v` & `dma_axi32_reg.v`**:
   - Decodes CPU register read/write accesses over the APB3 bus.
   - Holds channel parameters: Source Address (`SAR`), Destination Address (`DAR`), Byte Count/Transfer Length (`SZ`), Control Register (`CTL`).
2. **`dma_axi32_core0_ch.v`**:
   - The heart of the DMA channel. Tracks how many bytes have been read from the source and how many bytes have been safely written to the destination.
3. **`dma_axi32_core0_ch_calc_addr.v` & `dma_axi32_core0_ch_calc_size.v`**:
   - Splits a large transfer (e.g., 4096 bytes) into legal AXI burst lengths (e.g., 16 beats of 4 bytes = 64 bytes per burst) without crossing 4 KB AXI page boundaries.
4. **`prgen_fifo.v` (Channel FIFO)**:
   - Temporarily stores data read from the source memory before it is written out to the destination memory. Decouples read latency from write availability.
5. **`dma_axi32_core0_axim_rd.v` & `dma_axi32_core0_axim_wr.v`**:
   - Drives the AXI master signals (`ARVALID`, `RREADY`, `AWVALID`, `WVALID`, `BREADY`) adhering strictly to AMBA AXI handshake protocol.
6. **`dma_axi32_core0_wdt.v`**:
   - Watchdog timer that triggers an interrupt/error flag if the bus hangs (e.g., if a peripheral never replies with `READY`).

---

## 4. Life of a DMA Transfer: Step-by-Step Flow

How does a transfer actually execute in hardware?

```
 [ CPU ]               [ APB Interface ]             [ DMA Channel Engine ]          [ AXI Master Bus ]
    |                          |                              |                             |
    |-- 1. Write SAR (Src) --->|                              |                             |
    |-- 2. Write DAR (Dst) --->|                              |                             |
    |-- 3. Write Size (Bytes)->|                              |                             |
    |-- 4. Set START bit ----->|                              |                             |
    |                          |--- 5. Trigger Transfer ----->|                             |
    |                                                         |-- 6. Issue AR (Read Req) -->|
    |                                                         |                             |-- AXI Read Burst
    |                                                         |<= 7. RDATA into FIFO =======|
    |                                                         |                             |
    |                                                         |-- 8. Issue AW (Write Req) ->|
    |                                                         |                             |-- AXI Write Burst
    |                                                         |-- 9. WDATA from FIFO ======>|
    |                                                         |<= 10. BRESP (Write Ack) ====|
    |                                                         |                             |
    |                                                         |-- (Repeat until bytes = 0) -|
    |                                                         |                             |
    |<================ 11. Assert INT Pin ====================|                             |
    | (CPU ISR reads status, clears interrupt)
```

1. **Setup**: The CPU programs the DMA channel registers via APB writes:
   - `CH_SRC_ADDR`: Starting address to read from (e.g., `0x1000_0000`).
   - `CH_DST_ADDR`: Destination address to write to (e.g., `0x2000_0000`).
   - `CH_SIZE`: Total number of bytes to transfer.
   - `CH_CSR`: Enable bit, transfer mode (Joint/Independent), and interrupt enable.
2. **Read Phase**: The channel engine requests an AXI read burst. It asserts `ARVALID` with the calculated burst address. When the memory asserts `ARREADY`, address handshake completes. Memory returns `RDATA` beats, which are pushed directly into the DMA internal FIFO.
3. **Write Phase**: As soon as enough data is buffered in the FIFO, the write engine asserts `AWVALID` with the destination address. Once acknowledged (`AWREADY`), it pulls data beats from the FIFO and drives `WDATA` with `WVALID`.
4. **Completion & Handshake**: The slave acknowledges the write completion with `BVALID`/`BRESP`. The DMA decrements its internal remaining count.
5. **Interrupt**: When all requested bytes have been committed to the destination, the DMA asserts the external `INT` pin to signal the CPU interrupt controller.

---

## 5. The Physical Design Flow: Aligning with the Reference Book

The **Physical Design Reference Book** outlines the exact industry methodology for turning human-readable RTL code into a fabricated silicon chip. Here is how each chapter of the reference book translates to our project:

| Stage | Reference Book Chapter | Goal / Purpose in Our PR200 Project |
| :--- | :--- | :--- |
| **Inputs & Checks** | **Chapter 1 & 2** | Gather RTL netlist, Liberty (`.lib`) timing models, LEF physical layouts, and write SDC clock/reset constraints. |
| **Floorplanning** | **Chapter 3** | Define the physical silicon die boundary, core area, aspect ratio (e.g., 1.0 square), utilization (e.g., 40–50%), and assign IO pin positions along chip boundaries. |
| **Power Planning** | **Chapter 4** | Build the power grid: VDD (1.8V) and VSS (GND) power rings around the core, and vertical/horizontal power stripes to prevent voltage drop (IR-drop). |
| **Placement** | **Chapter 5** | Place ~6,000–10,000 SkyWater 130nm standard logic cells (AND gates, Flip-Flops, MUXes) into legal rows, minimizing wirelength and avoiding congestion. |
| **Clock Tree Synthesis (CTS)**| **Chapter 6 & 7** | Build an H-tree or balanced buffer tree for the `clk` signal so that clock edges arrive at all flip-flops simultaneously (minimizing clock skew and insertion delay). |
| **Routing** | **Chapter 8** | Connect all cell pins using physical metal wires (Metal 1 through Metal 5 in Sky130). Perform Global Routing (guide generation) followed by Detailed Routing (DRC-clean tracks). |
| **Physical Verification** | **Chapter 9 & 10** | **DRC** (Design Rule Checking with `Magic`) checks geometric rules (spacing, width). **LVS** (Layout Vs Schematic with `Netgen`) verifies that the routed silicon layout matches the synthesized netlist. |
| **Parasitic Extraction & STA**| **Chapter 11 & 15** | Extract wire resistance and capacitance (RC extraction -> SPEF), then run Static Timing Analysis (`OpenSTA`) across PVT corners to confirm Setup Slack ($WNS \ge 0$) and Hold Slack. |
| **Chip Finishing** | **Chapter 16** | Insert filler cells, antenna diodes, and generate the final silicon tapeout file (**GDSII**). |

---

## 6. Mapping Tools to the Physical Design Flow

We have set up an open-source ASIC EDA toolchain on your Linux machine. Here is how each tool executes a specific step of the flow:

```
    [ RTL Source Code ] (dma_axi32.v + filelist)
            |
            v  (Simulation & Verification)
    +------------------------------------------+
    | Tool: Icarus Verilog (iverilog + vvp)     | ----> Outputs: simulation.log, waveforms (.vcd)
    | Viewer: GTKWave / TerosHDL               |
    +------------------------------------------+
            |
            v  (Logic Synthesis & Tech Mapping)
    +------------------------------------------+
    | Tool: Yosys                              | ----> Inputs: sky130_fd_sc_hd__tt_025C_1v80.lib
    |                                          | ----> Outputs: synthesized netlist (.v), gate counts
    +------------------------------------------+
            |
            v  (ASIC Physical Implementation)
    +------------------------------------------+
    | Tool: OpenLane / OpenROAD                |
    |  - Floorplanning & IO Pin Placement      | ----> Inputs: SKY130 Tech LEF, Cell LEF, SDC
    |  - Power Grid Generation (PDN)           | ----> Engine: OpenROAD
    |  - Global & Detailed Placement           |
    |  - Clock Tree Synthesis (CTS)            |
    |  - Detailed Routing (TritonRoute)        |
    +------------------------------------------+
            |
            +--------------------+--------------------+
            | (Verification)     | (Timing Signoff)   | (GDS Layout)
            v                    v                    v
    +---------------+    +---------------+    +---------------+
    | Magic & Netgen|    | OpenSTA       |    | KLayout / DEF |
    | (DRC & LVS)   |    | (Slack/Timing)|    | (Final GDSII) |
    +---------------+    +---------------+    +---------------+
```

---

## 7. Current Project Status & Roadmap

### What is Completed:
1. ✅ **All EDA Tools Installed**: `iverilog`, `vvp`, `gtkwave`, `yosys`, `verilator`, `magic`, `netgen`, `openlane`, `klayout`.
2. ✅ **ASIC PDK Installed**: `SKY130A` standard cells, Liberty files, and LEFs ready in `~/.volare/sky130A`.
3. ✅ **IDE Extensions Installed**: `Verilog-HDL` and `TerosHDL` active.
4. ✅ **Repositories Ready**: Original PR200 code (`dma_axi32`) and demonstration starter package (`pr200_dma_demo_starter`).
5. ✅ **Baseline Simulation Proved**: The educational starter testbench (`tb_dma_demo`) successfully compiled, ran, and passed functional verification.

### Next Technical Milestones (Roadmap):
- **Phase 1: RTL Elaboration & Verification**:
  - Compile the actual `dma_axi32` core using the 48-file manifest.
  - Verify AXI handshake and APB register access via simulation.
- **Phase 2: Logic Synthesis with Yosys**:
  - Elaborate the `dma_axi32` hierarchy in Yosys.
  - Inspect warnings (inferring latches, multi-driven nets, bus width mismatches).
  - Map to `sky130_fd_sc_hd` logic gates; extract cell count, area, and flip-flop statistics.
- **Phase 3: SDC Timing Constraints**:
  - Create `dma_axi32.sdc`: Define clock frequency (e.g., 50 MHz / 20ns period), input delays, output delays, and clock uncertainties.
- **Phase 4: OpenLane / OpenROAD Physical Design**:
  - Run floorplanning, power distribution network, placement, CTS, and routing.
  - Generate DEF, check routing congestion, extract WNS/TNS timing reports.
- **Phase 5: Technical Report Generation**:
  - Compile real logs, cell counts, waveforms, area statistics, and physical layout evidence into the final academic report.
