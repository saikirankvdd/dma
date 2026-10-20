# DMA Demonstrator Starter Project

## What this is
A small, synthesizable educational memory-to-memory DMA controller and testbench.
It is inspired by the transfer concept in the PR200 DMA reference guide.

**It is not the original PR200 IP.** It does not implement AXI, APB3, dual cores,
PR200 registers, command lists, or all of the reference guide's optional features.
Use the public PR200-based repository linked below if the submission requires the
original-derived Verilog core.

## Files
- `rtl/dma_demo.v` — simplified DMA state machine
- `tb/tb_dma_demo.v` — testbench with a small memory model
- `run_sim.sh` — simulation command for Icarus Verilog
- `PROJECT_NOTES.md` — suggested report structure and scope statement

## Run simulation
Install Icarus Verilog (`iverilog` and `vvp`), then run:
```sh
./run_sim.sh
```
Expected successful testbench messages:
```text
PASS: DMA copied 8 words (32 bytes) from byte address 0 to byte address 64.
PASS: All destination words match the source data.
RESULT: FUNCTIONAL TEST PASSED
```
These are the testbench's expected messages; run the simulator to establish the
actual result on your machine.

## Original PR200-based source
https://github.com/freecores/dma_axi
The repository README identifies the source as based on Provartec PR200 and says
it contains 32-bit and 64-bit Verilog cores. Inspect the repository license and
source before reuse and acknowledge it in your submission.

## Scope and honest reporting
This starter can demonstrate basic transfer control and functional checking.
It is not enough to claim full PR200 compliance or a completed ASIC physical design.
Physical design also requires compatible technology libraries, timing constraints,
and tools. Only report synthesis, placement, routing, timing, DRC/LVS, or GDS outputs
if those stages were actually run and their outputs saved.
