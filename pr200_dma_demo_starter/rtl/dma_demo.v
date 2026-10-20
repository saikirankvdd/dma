// Educational DMA demonstrator inspired by the PR200 reference guide.
// IMPORTANT: This is NOT the original PR200 IP and does not implement AXI/APB3.
// It demonstrates a simple memory-to-memory transfer using a generic memory port.
module dma_demo #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  reset_n,
    input  wire                  start,
    input  wire [ADDR_WIDTH-1:0] src_addr,
    input  wire [ADDR_WIDTH-1:0] dst_addr,
    input  wire [15:0]           length_words,
    output reg                   busy,
    output reg                   done,
    output reg                   error,

    output reg                   mem_req,
    output reg                   mem_we,
    output reg [ADDR_WIDTH-1:0]  mem_addr,
    output reg [DATA_WIDTH-1:0]  mem_wdata,
    input  wire [DATA_WIDTH-1:0]  mem_rdata,
    input  wire                  mem_ready
);
    localparam IDLE  = 3'd0;
    localparam READ  = 3'd1;
    localparam WRITE = 3'd2;
    localparam FINISH= 3'd3;
    localparam FAIL  = 3'd4;

    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] src_ptr, dst_ptr;
    reg [15:0] remaining;
    reg [DATA_WIDTH-1:0] data_buf;

    always @(*) begin
        mem_req   = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = {ADDR_WIDTH{1'b0}};
        mem_wdata = data_buf;
        case (state)
            READ: begin
                mem_req  = 1'b1;
                mem_we   = 1'b0;
                mem_addr = src_ptr;
            end
            WRITE: begin
                mem_req   = 1'b1;
                mem_we    = 1'b1;
                mem_addr  = dst_ptr;
                mem_wdata = data_buf;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state     <= IDLE;
            busy      <= 1'b0;
            done      <= 1'b0;
            error     <= 1'b0;
            src_ptr   <= {ADDR_WIDTH{1'b0}};
            dst_ptr   <= {ADDR_WIDTH{1'b0}};
            remaining <= 16'd0;
            data_buf  <= {DATA_WIDTH{1'b0}};
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        if (length_words == 0) begin
                            error <= 1'b1;
                            state <= FAIL;
                        end else begin
                            src_ptr   <= src_addr;
                            dst_ptr   <= dst_addr;
                            remaining <= length_words;
                            busy      <= 1'b1;
                            state     <= READ;
                        end
                    end
                end
                READ: begin
                    if (mem_ready) begin
                        data_buf <= mem_rdata;
                        state <= WRITE;
                    end
                end
                WRITE: begin
                    if (mem_ready) begin
                        if (remaining == 1) begin
                            remaining <= 0;
                            state <= FINISH;
                        end else begin
                            remaining <= remaining - 1'b1;
                            src_ptr <= src_ptr + (DATA_WIDTH/8);
                            dst_ptr <= dst_ptr + (DATA_WIDTH/8);
                            state <= READ;
                        end
                    end
                end
                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                FAIL: begin
                    busy <= 1'b0;
                    error <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    error <= 1'b1;
                end
            endcase
        end
    end
endmodule
