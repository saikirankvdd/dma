`timescale 1ns/1ps

module tb_dma_axi32;

    reg clk;
    reg reset;
    reg scan_en;

    wire idle;
    wire [0:0] INT;

    reg  [31:1] periph_tx_req;
    wire [31:1] periph_tx_clr;
    reg  [31:1] periph_rx_req;
    wire [31:1] periph_rx_clr;

    reg         pclken;
    reg         psel;
    reg         penable;
    reg  [12:0] paddr;
    reg         pwrite;
    reg  [31:0] pwdata;
    wire [31:0] prdata;
    wire        pslverr;
    wire        pready;

    wire [0:0]  AWID0;
    wire [31:0] AWADDR0;
    wire [3:0]  AWLEN0;
    wire [1:0]  AWSIZE0;
    wire        AWVALID0;
    reg         AWREADY0;

    wire [0:0]  WID0;
    wire [31:0] WDATA0;
    wire [3:0]  WSTRB0;
    wire        WLAST0;
    wire        WVALID0;
    reg         WREADY0;

    reg  [0:0]  BID0;
    reg  [1:0]  BRESP0;
    reg         BVALID0;
    wire        BREADY0;

    wire [0:0]  ARID0;
    wire [31:0] ARADDR0;
    wire [3:0]  ARLEN0;
    wire [1:0]  ARSIZE0;
    wire        ARVALID0;
    reg         ARREADY0;

    reg  [0:0]  RID0;
    reg  [31:0] RDATA0;
    reg  [1:0]  RRESP0;
    reg         RLAST0;
    reg         RVALID0;
    wire        RREADY0;

    always #5 clk = ~clk;

    dma_axi32 dut (
        .clk(clk), .reset(reset), .scan_en(scan_en), .idle(idle), .INT(INT),
        .periph_tx_req(periph_tx_req), .periph_tx_clr(periph_tx_clr),
        .periph_rx_req(periph_rx_req), .periph_rx_clr(periph_rx_clr),
        .pclken(pclken), .psel(psel), .penable(penable), .paddr(paddr),
        .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pslverr(pslverr), .pready(pready),
        .AWID0(AWID0), .AWADDR0(AWADDR0), .AWLEN0(AWLEN0), .AWSIZE0(AWSIZE0), .AWVALID0(AWVALID0), .AWREADY0(AWREADY0),
        .WID0(WID0), .WDATA0(WDATA0), .WSTRB0(WSTRB0), .WLAST0(WLAST0), .WVALID0(WVALID0), .WREADY0(WREADY0),
        .BID0(BID0), .BRESP0(BRESP0), .BVALID0(BVALID0), .BREADY0(BREADY0),
        .ARID0(ARID0), .ARADDR0(ARADDR0), .ARLEN0(ARLEN0), .ARSIZE0(ARSIZE0), .ARVALID0(ARVALID0), .ARREADY0(ARREADY0),
        .RID0(RID0), .RDATA0(RDATA0), .RRESP0(RRESP0), .RLAST0(RLAST0), .RVALID0(RVALID0), .RREADY0(RREADY0)
    );

    reg [31:0] mem [0:1023];
    integer i;

    // APB Write Task
    task apb_write(input [12:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        #1;
        psel    = 1'b1;
        pwrite  = 1'b1;
        paddr   = addr;
        pwdata  = data;
        penable = 1'b0;
        @(posedge clk);
        #1;
        penable = 1'b1;
        @(posedge clk);
        #1;
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
    end
    endtask

    // APB Read Task
    task apb_read(input [12:0] addr, output [31:0] data);
    begin
        @(posedge clk);
        #1;
        psel    = 1'b1;
        pwrite  = 1'b0;
        paddr   = addr;
        penable = 1'b0;
        @(posedge clk);
        #1;
        penable = 1'b1;
        @(posedge clk);
        #1;
        data    = prdata;
        psel    = 1'b0;
        penable = 1'b0;
    end
    endtask

    // AXI Slave Read Engine
    reg [31:0] r_addr;
    reg [3:0]  r_len;
    reg [3:0]  r_count;
    initial begin
        ARREADY0 = 1'b1;
        RVALID0  = 1'b0;
        RLAST0   = 1'b0;
        RID0     = 1'b0;
        RRESP0   = 2'b00;
        forever begin
            @(posedge clk);
            if (ARVALID0 && ARREADY0) begin
                r_addr  = ARADDR0;
                r_len   = ARLEN0;
                $display("[AXI-MEM] >>> AR Burst Accepted: Addr=0x%08h Len=%0d", r_addr, r_len);
                ARREADY0 <= 1'b0;
                for (r_count = 0; r_count <= r_len; r_count = r_count + 1) begin
                    @(posedge clk);
                    RVALID0 <= 1'b1;
                    RID0    <= ARID0;
                    RDATA0  <= mem[r_addr[11:2]];
                    RLAST0  <= (r_count == r_len);
                    $display("[AXI-MEM]   RDATA beat %0d: Data=0x%08h", r_count, mem[r_addr[11:2]]);
                    while (!RREADY0) @(posedge clk);
                    r_addr = r_addr + 4;
                end
                @(posedge clk);
                RVALID0  <= 1'b0;
                RLAST0   <= 1'b0;
                ARREADY0 <= 1'b1;
            end
        end
    end

    // AXI Slave Write Engine (Fully decoupled AW, W, B FIFO queues)
    reg [31:0] aw_fifo_addr [0:7];
    reg [0:0]  aw_fifo_id   [0:7];
    reg [3:0]  aw_fifo_len  [0:7];
    integer aw_wr_ptr = 0;
    integer aw_rd_ptr = 0;

    reg [0:0]  b_fifo_id [0:7];
    integer b_wr_ptr = 0;
    integer b_rd_ptr = 0;

    // AW Channel
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            AWREADY0  <= 1'b1;
            aw_wr_ptr <= 0;
        end else begin
            if (AWVALID0 && AWREADY0) begin
                aw_fifo_addr[aw_wr_ptr] <= AWADDR0;
                aw_fifo_len[aw_wr_ptr]  <= AWLEN0;
                aw_fifo_id[aw_wr_ptr]   <= AWID0;
                $display("[AXI-MEM] >>> AW Burst Queued: Addr=0x%08h Len=%0d", AWADDR0, AWLEN0);
                aw_wr_ptr <= (aw_wr_ptr + 1) % 8;
            end
        end
    end

    // W Channel: Only accept WDATA when an AW address is available in the queue!
    reg [31:0] cur_waddr;
    reg        in_burst;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            WREADY0   <= 1'b0;
            aw_rd_ptr <= 0;
            b_wr_ptr  <= 0;
            in_burst  <= 1'b0;
            cur_waddr <= 32'h0;
        end else begin
            if (!in_burst) begin
                if (aw_rd_ptr != aw_wr_ptr) begin
                    cur_waddr <= aw_fifo_addr[aw_rd_ptr];
                    in_burst  <= 1'b1;
                    WREADY0   <= 1'b1;
                end else begin
                    WREADY0   <= 1'b0;
                end
            end else begin
                // In burst
                WREADY0 <= 1'b1;
                if (WVALID0 && WREADY0) begin
                    mem[cur_waddr[11:2]] <= WDATA0;
                    $display("[AXI-MEM]   WDATA written to 0x%08h: Data=0x%08h", cur_waddr, WDATA0);
                    cur_waddr <= cur_waddr + 4;
                    if (WLAST0) begin
                        $display("[AXI-MEM]   WDATA LAST received for burst Addr=0x%08h", aw_fifo_addr[aw_rd_ptr]);
                        b_fifo_id[b_wr_ptr] <= aw_fifo_id[aw_rd_ptr];
                        b_wr_ptr            <= (b_wr_ptr + 1) % 8;
                        aw_rd_ptr           <= (aw_rd_ptr + 1) % 8;
                        in_burst            <= 1'b0;
                        WREADY0             <= 1'b0; // Deassert until next AW ready
                    end
                end
            end
        end
    end

    // B Channel: Return responses from B queue
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            BVALID0  <= 1'b0;
            BID0     <= 1'b0;
            BRESP0   <= 2'b00;
            b_rd_ptr <= 0;
        end else begin
            if (BVALID0 && BREADY0) begin
                BVALID0  <= 1'b0;
                b_rd_ptr <= (b_rd_ptr + 1) % 8;
            end else if (!BVALID0 && (b_rd_ptr != b_wr_ptr)) begin
                BVALID0 <= 1'b1;
                BID0    <= b_fifo_id[b_rd_ptr];
                BRESP0  <= 2'b00; // OKAY
            end
        end
    end

    // Main Test Stimulus
    integer timeout;
    reg [31:0] rdata;
    initial begin
        $dumpfile("sim/waveforms/dma_axi32.vcd");
        $dumpvars(0, tb_dma_axi32);

        clk     = 0;
        reset   = 1;
        scan_en = 0;
        pclken  = 1;
        psel    = 0;
        penable = 0;
        paddr   = 0;
        pwrite  = 0;
        pwdata  = 0;
        periph_tx_req = 0;
        periph_rx_req = 0;

        for (i = 0; i < 1024; i = i + 1) mem[i] = 32'h0000_0000;
        for (i = 0; i < 8; i = i + 1)    mem[64 + i] = 32'hCAFE_0000 + i; // Source at 0x100

        $display("==========================================================");
        $display("   PR200 AXI DMA (dma_axi32) Functional Verification      ");
        $display("==========================================================");

        repeat (10) @(posedge clk);
        #1 reset = 0;
        repeat (10) @(posedge clk);

        $display("[TB] Step 1: Configuring Channel 0 Static Parameters...");
        apb_write(13'h0010, 32'h8201_0010); // STATIC_LINE0: burst=16, tok=1, out=2, incr=1
        apb_write(13'h0014, 32'h8201_0010); // STATIC_LINE1: burst=16, tok=1, out=2, incr=1
        apb_write(13'h0018, 32'h0001_0000); // STATIC_LINE2: joint=1

        $display("[TB] Step 2: Configuring Command Line Registers (32 Bytes)...");
        apb_write(13'h0000, 32'h0000_0100); // Src = 0x100
        apb_write(13'h0004, 32'h0000_0200); // Dst = 0x200
        apb_write(13'h0008, 32'd32);         // Size = 32 bytes (8 words)
        apb_write(13'h000C, 32'h0000_0003); // Last=1, SetInt=1

        $display("[TB] Step 3: Verifying APB Register Read-Back...");
        apb_read(13'h0000, rdata);
        $display("  [REG READ] CMD_LINE0 (Src Addr): 0x%08h (Expected: 0x00000100)", rdata);
        apb_read(13'h0004, rdata);
        $display("  [REG READ] CMD_LINE1 (Dst Addr): 0x%08h (Expected: 0x00000200)", rdata);
        apb_read(13'h0008, rdata);
        $display("  [REG READ] CMD_LINE2 (Size):     0x%08h (Expected: 0x00000020)", rdata);

        $display("[TB] Step 4: Enabling and Starting Channel 0...");
        apb_write(13'h0040, 32'h0000_0001); // CH_ENABLE = 1
        apb_write(13'h0044, 32'h0000_0001); // CH_START  = 1
        apb_write(13'h1048, 32'h0000_0001); // CORE0_START = 1

        $display("[TB] Step 5: Waiting for DMA Transfer Completion...");
        timeout = 0;
        while (!INT && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        repeat (20) @(posedge clk);

        $display("[TB] Step 6: Verifying Destination Memory Contents (0x200..0x21C)...");
        for (i = 0; i < 8; i = i + 1) begin
            if (mem[128 + i] === (32'hCAFE_0000 + i)) begin
                $display("  [MATCH] Word %0d at 0x%03h: Actual=0x%08h Expected=0x%08h", 
                         i, (128 + i)*4, mem[128 + i], 32'hCAFE_0000 + i);
            end else begin
                $display("  [MISMATCH] Word %0d at 0x%03h: Actual=0x%08h Expected=0x%08h", 
                         i, (128 + i)*4, mem[128 + i], 32'hCAFE_0000 + i);
            end
        end

        $display("==========================================================");
        $display("   TESTBENCH COMPLETED — Waveform saved to:               ");
        $display("   sim/waveforms/dma_axi32.vcd                            ");
        $display("==========================================================");
        $finish;
    end

endmodule
