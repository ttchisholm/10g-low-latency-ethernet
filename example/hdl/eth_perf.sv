// MIT License

// Copyright (c) 2023 Tom Chisholm

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/*
*   Module: eth_perf
*
*   Description: Measure time between i_tx_start and i_rx_stop with CDC.
*
*/

`timescale 1ns/1ps
`default_nettype none

module eth_perf (
    input wire i_tx_reset,
    input wire i_tx_clk,
    input wire i_tx_start,
    output logic [15:0] o_latency,
    output logic o_test_complete,

    input wire i_rx_stop
);

    logic test_running;
    logic [1:0] rx_stop_sync;

    always_ff @(posedge i_tx_clk)
    if (i_tx_reset) begin
        test_running <= '0;
        rx_stop_sync <= 2'b0;
        o_latency <= '0;
        o_test_complete <= '0;
    end else begin
        rx_stop_sync <= {rx_stop_sync[0], i_rx_stop};

        if (!test_running && i_tx_start) begin
            test_running <= 1'b1;
            o_test_complete <= 1'b0;
            o_latency <= '0;
        end else if (test_running && rx_stop_sync[1]) begin
            test_running <= 1'b0;
            o_test_complete <= 1'b1;
            o_latency <= o_latency;
        end else if (test_running) begin
            test_running <= test_running;
            o_test_complete <= 1'b0;
            o_latency <= o_latency + 1;
        end
    end

endmodule
