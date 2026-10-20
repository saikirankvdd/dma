module diag;
initial begin
    #10;
    $display("DIAG: mux.clk=%b mux.reset=%b mux.pready=%b mux.pclken=%b",
             tb_dma_axi32.dut.dma_axi32_dual_core.dma_axi32_apb_mux.clk,
             tb_dma_axi32.dut.dma_axi32_dual_core.dma_axi32_apb_mux.reset,
             tb_dma_axi32.dut.dma_axi32_dual_core.dma_axi32_apb_mux.pready,
             tb_dma_axi32.dut.dma_axi32_dual_core.dma_axi32_apb_mux.pclken);
    #100;
    $display("DIAG 100: mux.pready=%b", tb_dma_axi32.dut.dma_axi32_dual_core.dma_axi32_apb_mux.pready);
    $finish;
end
endmodule
