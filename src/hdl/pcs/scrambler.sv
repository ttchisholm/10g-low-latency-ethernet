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
*   Module: scrambler
*
*   Description: 10G Ethernet scrambler/descrabler as per IEEE 802.3-2008, 49.2.6 and
*                49.2.11. 32-bit data I/O.
*
*/

`timescale 1ns/1ps
`default_nettype none

module scrambler #(
    parameter bit DESCRAMBLE = 0,

    localparam int DATA_WIDTH = 32
) (
    input wire i_clk,
    input wire i_reset,
    input wire i_init_done,
    input wire i_pause,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH-1:0] o_data
);

    // verilator lint_off UNUSED
    logic[127:0] scrambler_data;
    // verilator lint_on UNUSED

    logic [127:0] next_scrambler_data;
    logic [95:0] next_scrambler_data_split;

    always_ff @(posedge i_clk) begin
        if (i_reset || !i_init_done) begin
            scrambler_data <= '1;
        end
        else if (!i_pause) begin
            scrambler_data <= next_scrambler_data;
        end
    end

    // Data here is reversed wrt. polynomial index
    // We need to split the scrambler data to avoid circular comb (verilator)
    // Shift the scrambler data down by DATA_WIDTH
    assign next_scrambler_data_split = {scrambler_data[DATA_WIDTH +: 128 - DATA_WIDTH]};

    // If descrambling, shift in input data, else scrambler output
    assign next_scrambler_data = DESCRAMBLE ? {i_data, next_scrambler_data_split} :
                                                {o_data, next_scrambler_data_split};

    // Parallel scrambler
    // Polynomial is 1 + x^39 + x^58, easier to write as inverse 1 + x^19 + x^58
    //  and say S0 is first transmitted bit (lsb)
    // S58 = D58 + S19 + S0
    // ...
    // S64 = D64 + S25 + S6
    // S65 = D65 + S26 + S7
    // ...
    // S127 = D127 + S88 + S69

    // For 32-bit mode, as we only shift the scrambler data by 32 each time, need to offset index with (64-DATA_WIDTH)

    generate
        for (genvar gi = 0; gi < DATA_WIDTH; gi++) begin: l_assign_odata
            assign o_data[gi] = next_scrambler_data_split[(64-DATA_WIDTH) + 6+gi] ^ next_scrambler_data_split[(64-DATA_WIDTH) + 25+gi] ^ i_data[gi];
        end
    endgenerate

endmodule
