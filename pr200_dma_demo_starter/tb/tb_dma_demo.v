`timescale 1ns/1ps
module tb_dma_demo;
    localparam ADDR_WIDTH = 8;
    localparam DATA_WIDTH = 32;
    localparam WORDS = 64;

    reg clk = 0;
    always #5 clk = ~clk;

    reg reset_n = 0;
    reg start = 0;
    reg [ADDR_WIDTH-1:0] src_addr = 8'd0;
    reg [ADDR_WIDTH-1:0] dst_addr = 8'd64;
    reg [15:0] length_words = 16'd8;
    wire busy, done, error;
    wire mem_req, mem_we;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_wdata;
    reg [DATA_WIDTH-1:0] mem_rdata;
    wire mem_ready = 1'b1;

    reg [DATA_WIDTH-1:0] mem [0:WORDS-1];
    integer i;
    integer cycles;

    dma_demo #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .reset_n(reset_n), .start(start),
        .src_addr(src_addr), .dst_addr(dst_addr), .length_words(length_words),
        .busy(busy), .done(done), .error(error),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_ready(mem_ready)
    );

    // Simple single-cycle memory model. Addresses are byte addresses.
    always @(*) begin
        mem_rdata = mem[mem_addr >> 2];
    end

    always @(posedge clk) begin
        if (mem_req && mem_ready && mem_we)
            mem[mem_addr >> 2] <= mem_wdata;
    end

    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h0;
        for (i = 0; i < 8; i = i + 1)
            mem[i] = 32'hA500_0000 + i;

        repeat (3) @(posedge clk);
        reset_n = 1;
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        cycles = 0;
        while (!done && cycles < 100) begin
            @(negedge clk);
            cycles = cycles + 1;
        end

        if (!done) begin
            $display("FAIL: timeout waiting for DMA completion");
            $finish;
        end
        if (error) begin
            $display("FAIL: DMA asserted error");
            $finish;
        end

        for (i = 0; i < 8; i = i + 1) begin
            if (mem[16+i] !== (32'hA500_0000 + i)) begin
                $display("FAIL: word %0d mismatch expected=%h actual=%h",
                         i, (32'hA500_0000 + i), mem[16+i]);
                $finish;
            end
        end

        $display("PASS: DMA copied 8 words (32 bytes) from byte address 0 to byte address 64.");
        $display("PASS: All destination words match the source data.");
        $display("RESULT: FUNCTIONAL TEST PASSED");
        $finish;
    end
endmodule
