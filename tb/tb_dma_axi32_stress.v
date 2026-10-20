`timescale 1ns/1ps

module tb_dma_axi32_stress;

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

    // Backpressure control flag
    reg inject_backpressure;

    // 50 MHz Clock generation (Period = 20 ns)
    always #10 clk = ~clk;

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

    // 4096-word (16 KB) memory model
    reg [31:0] mem [0:4095];
    integer i;
    integer total_errors = 0;
    integer total_words_tested = 0;

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

    // Fully Protocol-Compliant AXI Slave Read Engine
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
                $display("[AXI-SLAVE] >>> AR Burst Accepted: Addr=0x%08h Len=%0d", r_addr, r_len);
                ARREADY0 <= 1'b0; // Deassert during burst

                for (r_count = 0; r_count <= r_len; r_count = r_count + 1) begin
                    // If backpressure is active, inject a 1-cycle bubble before asserting VALID
                    if (inject_backpressure && (r_count[0] == 1'b1)) begin
                        RVALID0 <= 1'b0;
                        RLAST0  <= 1'b0;
                        @(posedge clk);
                    end

                    // Present data and assert RVALID
                    RVALID0 <= 1'b1;
                    RID0    <= ARID0;
                    RDATA0  <= mem[r_addr[13:2]];
                    RLAST0  <= (r_count == r_len);

                    // Wait until DMA asserts RREADY on posedge clk
                    @(posedge clk);
                    while (!RREADY0) @(posedge clk);

                    // Advance address
                    r_addr = r_addr + 4;
                end

                // End of burst: clear RVALID
                RVALID0  <= 1'b0;
                RLAST0   <= 1'b0;
                ARREADY0 <= 1'b1;
            end
        end
    end

    // AXI Slave Write Engine (Decoupled AW, W, B FIFO queues)
    reg [31:0] aw_fifo_addr [0:15];
    reg [0:0]  aw_fifo_id   [0:15];
    reg [3:0]  aw_fifo_len  [0:15];
    integer aw_wr_ptr = 0;
    integer aw_rd_ptr = 0;

    reg [0:0]  b_fifo_id [0:15];
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
                $display("[AXI-SLAVE] >>> AW Burst Queued: Addr=0x%08h Len=%0d", AWADDR0, AWLEN0);
                aw_wr_ptr <= (aw_wr_ptr + 1) % 16;
            end
        end
    end

    // W Channel: Accepts WDATA
    reg [31:0] cur_waddr;
    reg        in_burst;
    reg [2:0]  stall_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            WREADY0   <= 1'b0;
            aw_rd_ptr <= 0;
            b_wr_ptr  <= 0;
            in_burst  <= 1'b0;
            cur_waddr <= 32'h0;
            stall_cnt <= 0;
        end else begin
            if (!in_burst) begin
                if (aw_rd_ptr != aw_wr_ptr) begin
                    cur_waddr <= aw_fifo_addr[aw_rd_ptr];
                    in_burst  <= 1'b1;
                    WREADY0   <= 1'b1;
                    stall_cnt <= 0;
                end else begin
                    WREADY0   <= 1'b0;
                end
            end else begin
                // Handle optional backpressure: stall WREADY every 3 beats for 1 cycle
                if (inject_backpressure && (stall_cnt == 2) && WREADY0) begin
                    WREADY0   <= 1'b0;
                    stall_cnt <= 0;
                end else if (!WREADY0) begin
                    WREADY0   <= 1'b1;
                end

                if (WVALID0 && WREADY0) begin
                    mem[cur_waddr[13:2]] <= WDATA0;
                    cur_waddr <= cur_waddr + 4;
                    stall_cnt <= stall_cnt + 1;
                    if (WLAST0) begin
                        $display("[AXI-SLAVE]   WDATA LAST received for burst Addr=0x%08h", aw_fifo_addr[aw_rd_ptr]);
                        b_fifo_id[b_wr_ptr] <= aw_fifo_id[aw_rd_ptr];
                        b_wr_ptr            <= (b_wr_ptr + 1) % 16;
                        aw_rd_ptr           <= (aw_rd_ptr + 1) % 16;
                        in_burst            <= 1'b0;
                        WREADY0             <= 1'b0;
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
                b_rd_ptr <= (b_rd_ptr + 1) % 16;
            end else if (!BVALID0 && (b_rd_ptr != b_wr_ptr)) begin
                BVALID0 <= 1'b1;
                BID0    <= b_fifo_id[b_rd_ptr];
                BRESP0  <= 2'b00; // OKAY
            end
        end
    end

    // Helper task to execute a full DMA transfer and verify
    task execute_and_verify_transfer(
        input [31:0] src_addr,
        input [31:0] dst_addr,
        input [31:0] byte_size,
        input [31:0] base_pattern,
        input [8*30:1] test_name
    );
        integer num_words;
        integer timeout;
        integer w;
        reg [31:0] actual_val;
        reg [31:0] expected_val;
        reg [31:0] ch_active_reg;
        integer mismatch_in_test;
    begin
        num_words = byte_size / 4;
        mismatch_in_test = 0;
        $display("\n--------------------------------------------------------------");
        $display("[TEST START] %0s", test_name);
        $display("  Src=0x%08h -> Dst=0x%08h | Size=%0d Bytes (%0d Words)", src_addr, dst_addr, byte_size, num_words);
        $display("--------------------------------------------------------------");

        // Clear any previous interrupt flag and reset int_counter
        apb_write(13'h00A4, 32'hFFFF_FFFF);

        // Initialize source memory pattern and clear destination
        for (w = 0; w < num_words; w = w + 1) begin
            mem[(src_addr >> 2) + w] = base_pattern + w;
            mem[(dst_addr >> 2) + w] = 32'hDEAD_BEEF; // Poison destination
        end

        // 1. Program Command Line Registers
        apb_write(13'h0000, src_addr);
        apb_write(13'h0004, dst_addr);
        apb_write(13'h0008, byte_size);
        apb_write(13'h000C, 32'h0000_0003); // Last=1, SetInt=1

        // 2. Start Transfer
        apb_write(13'h0040, 32'h0000_0001); // CH_ENABLE = 1
        apb_write(13'h0044, 32'h0000_0001); // CH_START  = 1
        apb_write(13'h1048, 32'h0000_0001); // CORE0_START = 1

        // Clear interrupt again right after start resets the internal counter
        apb_write(13'h00A4, 32'hFFFF_FFFF);

        // 3. Monitor execution by polling CH_ACTIVE
        repeat (15) @(posedge clk);
        timeout = 0;
        ch_active_reg = 32'h1;
        while (ch_active_reg[0] && timeout < 5000) begin
            apb_read(13'h0048, ch_active_reg); // Read CH_ACTIVE
            repeat (5) @(posedge clk);
            timeout = timeout + 5;
        end

        // Wait a few cycles for final AXI write burst completions to land in memory
        repeat (20) @(posedge clk);

        // Clear interrupt status for clean slate
        apb_write(13'h00A4, 32'hFFFF_FFFF);

        // 4. Verification Check
        for (w = 0; w < num_words; w = w + 1) begin
            actual_val = mem[(dst_addr >> 2) + w];
            expected_val = base_pattern + w;
            total_words_tested = total_words_tested + 1;
            if (actual_val === expected_val) begin
                // Match
            end else begin
                $display("  [MISMATCH] Word %0d at 0x%08h: Actual=0x%08h Expected=0x%08h",
                         w, dst_addr + (w*4), actual_val, expected_val);
                mismatch_in_test = mismatch_in_test + 1;
                total_errors = total_errors + 1;
            end
        end

        if (mismatch_in_test == 0) begin
            $display("  [RESULT] PASSED: All %0d words transferred accurately!", num_words);
        end else begin
            $display("  [RESULT] FAILED: %0d word mismatches detected!", mismatch_in_test);
        end
    end
    endtask

    // Main Test Stimulus
    initial begin
        $dumpfile("sim/waveforms/dma_axi32_stress.vcd");
        $dumpvars(0, tb_dma_axi32_stress);

        clk                 = 0;
        reset               = 1;
        scan_en             = 0;
        pclken              = 1;
        psel                = 0;
        penable             = 0;
        paddr               = 0;
        pwrite              = 0;
        pwdata              = 0;
        periph_tx_req       = 0;
        periph_rx_req       = 0;
        inject_backpressure = 0;

        for (i = 0; i < 4096; i = i + 1) mem[i] = 32'h0000_0000;

        $display("================================================================");
        $display("   PR200 AXI DMA (dma_axi32) EXTENDED STRESS TEST REGRESSION    ");
        $display("================================================================");

        // Hardware Reset Sequence
        repeat (10) @(posedge clk);
        #1 reset = 0;
        repeat (10) @(posedge clk);

        // Global Static Setup
        $display("[SETUP] Configuring Channel 0 Static Parameters...");
        apb_write(13'h0010, 32'h8201_0010); // STATIC_LINE0: burst=16, tok=1, out=2, incr=1
        apb_write(13'h0014, 32'h8201_0010); // STATIC_LINE1: burst=16, tok=1, out=2, incr=1
        apb_write(13'h0018, 32'h0001_0000); // STATIC_LINE2: joint=1

        // TEST 1: Standard 32-Byte Burst (8 Words)
        execute_and_verify_transfer(
            32'h0000_0100, 32'h0000_0200, 32'd32, 32'hA000_0000, "TEST 1: 32-Byte Burst (8 Words)"
        );

        // TEST 2: Medium 64-Byte Burst (16 Words)
        execute_and_verify_transfer(
            32'h0000_0300, 32'h0000_0400, 32'd64, 32'hB000_0000, "TEST 2: 64-Byte Burst (16 Words)"
        );

        // TEST 3: Large 128-Byte Burst (32 Words)
        execute_and_verify_transfer(
            32'h0000_0500, 32'h0000_0600, 32'd128, 32'hC000_0000, "TEST 3: 128-Byte Large (32 Words)"
        );

        // TEST 4: Heavy 256-Byte Burst (64 Words)
        execute_and_verify_transfer(
            32'h0000_0700, 32'h0000_0900, 32'd256, 32'hD000_0000, "TEST 4: 256-Byte Heavy (64 Words)"
        );

        // TEST 5: Stress with Memory Wait-States / Backpressure Stalls
        inject_backpressure = 1;
        $display("\n>>> ACTIVATING AXI BACKPRESSURE (Simulating Slow/Stalling Memory) <<<");
        execute_and_verify_transfer(
            32'h0000_0B00, 32'h0000_0D00, 32'd128, 32'hE000_0000, "TEST 5: Backpressure Stalls"
        );
        inject_backpressure = 0;

        // TEST 6: Rapid Back-to-Back Consecutive Transfer (No Reset in Between)
        execute_and_verify_transfer(
            32'h0000_1000, 32'h0000_1200, 32'd64, 32'hF000_0000, "TEST 6: Rapid Consecutive Transfer"
        );

        repeat (20) @(posedge clk);

        // Final Stress Test Summary Report
        $display("\n================================================================");
        $display("                 EXTENDED STRESS TEST REPORT                     ");
        $display("================================================================");
        $display("  Total Tests Executed    : 6 Comprehensive Scenarios           ");
        $display("  Total Words Tested      : %0d Words (%0d Bytes)               ", 
                 total_words_tested, total_words_tested * 4);
        $display("  Total Mismatches/Errors : %0d                                 ", total_errors);

        if (total_errors == 0) begin
            $display("  STATUS                  : >>> 100%% PASSED (ZERO DEFECTS) <<< ");
            $display("================================================================");
        end else begin
            $display("  STATUS                  : >>> FAILED (%0d DEFECTS FOUND) <<<  ", total_errors);
            $display("================================================================");
        end

        $finish;
    end

endmodule
