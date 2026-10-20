module probe_reset;
initial begin
    $monitor("Time=%0t clk=%b reset=%b pready=%b psel0=%b penable=%b", 
             $time, tb_dma_axi32.clk, tb_dma_axi32.reset, tb_dma_axi32.pready, 
             tb_dma_axi32.dut.dma_axi32_dual_core.psel0, tb_dma_axi32.penable);
end
endmodule
