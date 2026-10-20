# Project Notes / Submission Outline

## Proposed title
Design and Functional Verification of a Simplified DMA Controller Inspired by PR200

## Objective
Demonstrate the core DMA concept: move a specified number of words from a source
memory address to a destination memory address without software copying each word.

## Architecture
- Start/configuration inputs: source address, destination address, transfer length
- Controller: IDLE, READ, WRITE, FINISH and error states
- Memory interface: request, read/write selection, address, write data, read data, ready
- Status: busy, done, error

## Test
The testbench initializes eight source words, starts a transfer of eight 32-bit words,
and checks that the destination memory contains the same values.

## Results
Record the actual simulator/tool version and paste the real console output here.
Do not claim a pass until the testbench has been run.

## Limitations
This is a simplified educational implementation, not original PR200 RTL. It does not
implement AXI/APB3 protocol timing or the full PR200 dual-core architecture.
The physical-design stages remain future work unless run with a compatible PDK,
libraries, constraints and place-and-route tools.

## Reference
- PR200 Configurable Dual-Core High Performance AXI DMA Reference Guide, Rev. 1.6
- https://github.com/freecores/dma_axi (PR200-based Verilog source; inspect license)
- Physical Design Reference book supplied for the project
