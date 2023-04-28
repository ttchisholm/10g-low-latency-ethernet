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
*   Module: gearbox_seq
*
*   Description: 64b666 gearbox sequence counter as per UG578 (v1.3.1) pg 119.
*                Note module was desinged for TX_DATA_WIDTH = 32, TX_INT_DATAWIDTH = 32.
*
*/

`timescale 1ns/1ps
`default_nettype none

module gearbox_seq #(
    parameter int WIDTH = 6,
    parameter bit [WIDTH-1:0] MAX_VAL = 32,
    parameter bit [WIDTH-1:0] PAUSE_VAL = 32,
    parameter bit HALF_STEP = 1
) (
    input wire i_clk,
    input wire i_reset,
    input wire i_slip,
    output logic [WIDTH-1:0] o_count,
    output wire o_pause
);

    logic step;

    always_ff @(posedge i_clk)
    if (i_reset) begin
        o_count <= '0;
    end else begin
        if (step && !i_slip) begin
            o_count <= (o_count < MAX_VAL) ? o_count + 1 : '0;
        end
    end

    generate if (HALF_STEP) begin: l_half_step
        always_ff @(posedge i_clk)
        if (i_reset) begin
            step <= '0;
        end else if (!i_slip) begin
            step <= ~step;
        end
    end else begin: l_full_step
        assign step = 1'b1;
    end endgenerate

    assign o_pause = o_count == PAUSE_VAL;

endmodule
