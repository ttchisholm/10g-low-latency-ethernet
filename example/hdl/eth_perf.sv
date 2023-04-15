`default_nettype none


// Measure time between tx_start and rx_stop with cdc



module eth_perf (
    
    input wire tx_reset,
    input wire tx_clk,
    input wire tx_start,
    output logic [15:0] latency,
    output logic test_complete,
    
    input wire rx_reset,
    input wire rx_clk,
    input wire rx_stop
);

    logic test_running;
    logic [1:0] rx_stop_sync;
    

    always @(posedge tx_clk)
    if (tx_reset) begin
        test_running <= '0;
        rx_stop_sync <= 2'b0;
        latency <= 1'b0;
        test_complete <= '0;
    end else begin
        rx_stop_sync <= {rx_stop_sync[0], rx_stop};

        if (!test_running && tx_start) begin
            test_running <= 1'b1;
            test_complete <= 1'b0;
            latency <= '0;
        end else if (test_running && rx_stop_sync[1]) begin
            test_running <= 1'b0;
            test_complete <= 1'b1;
            latency <= latency;
        end else if (test_running) begin
            test_running <= test_running;
            test_complete <= 1'b0;
            latency <= latency + 1;
        end

    end
  
endmodule