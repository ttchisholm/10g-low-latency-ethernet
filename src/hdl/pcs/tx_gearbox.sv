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
*   Module: tx_gearbox
*
*   Description: 64b66b transmit synchronus gearbox with 32-bit interface. Takes
*                64-bit frame and 2-bit header over two cycles, taking header with
*                first (lower) 32-bits of frame.
*
*                The design was modelled in python which can be found in src/tb/gearbox.
*
*                Input data is constructed in an output buffer depending on the input sequence
*                which counts from 0-32. No data is loaded when seq == 32. The lower 32-bits are
*                ouput from the buffer.
*
*                Output buffer construction:
*                               |			output data					|
*                buffer index:	0	1	2	3	4	5	6	7	...	31	| 32	33	...	63	64	65
*                cycle:
*                0				H0	H1	D0	D1	D2	D3	D4	D5	...	D29	| D30	D31	...	X	X	X
*                1				D30	D31	D32	D33	D34	D35	D36	D37	...	D61	| D62	D63	...	X	X	X
*                2				D62	D63	H0	H1	D0	D1	D2	D3	...	D27	| D28	D29	...	X	X	X
*                3				D28	D29	D30	D31	D32	D33	D34	D35	...	D59	| D60	D61	...	X	X	X
*                4				D60	D61	D62	D63	H0	H1	D0	D1	...	D25	| D26	D27	...	X	X	X
*                ...
*                30				D34	D35	D36	D37	D38	D39	D40	D41	...	H1	| D0	D1	...	D31
*                31				D0	D1	D2	D3	D4	D5	D6	D7	...	D31	| D32	D33	...	D63
*                32	*			D32	D33	D34	D35	D36	D37	D38	D39	...	D63	| X		X	...	X
*
*/

`timescale 1ns/1ps
`default_nettype none

module tx_gearbox #(
    localparam int DATA_WIDTH = 32,
    localparam int HEADER_WIDTH = 2,
    localparam int SEQUENCE_WIDTH = 6
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_data,
    input wire [HEADER_WIDTH-1:0] i_header,
    input wire [SEQUENCE_WIDTH-1:0] i_gearbox_seq,
    input wire i_pause,
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_frame_word
);

    localparam int BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH;

    /********* Buffer Construction ********/

    // Re-use the gearbox sequnce counter method as used in gty
    wire load_header;
    logic [2*DATA_WIDTH + HEADER_WIDTH -1:0] obuf, next_obuf, shifted_obuf;
    wire [SEQUENCE_WIDTH-1:0] header_idx;
    wire [SEQUENCE_WIDTH-1:0] data_idx;

    assign load_header = !i_gearbox_seq[0]; // Load header on even cycles
    assign o_frame_word =  i_gearbox_seq[0]; // Load bottom word on even cycles (with header), top on odd
    assign o_data = next_obuf[0 +: DATA_WIDTH];

    assign header_idx = i_gearbox_seq; // Location to load H0
    assign data_idx = load_header ? i_gearbox_seq + 2 : i_gearbox_seq + 1; // Location to load D0 or D32

    assign shifted_obuf = {{DATA_WIDTH{1'b0}}, obuf[DATA_WIDTH +: BUF_SIZE-DATA_WIDTH]};

    // Need to assign single bits as iverilog does not support variable width assignments
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin: l_assign_obuf

        // Next bit can come from three sources:
        //      1. New data (header and data word or just data word)
        //      2. Data previously in the buffer shifted down
        //      3. Existing data at that index
        //  The data source depends on the bit in the buffer and current
        //  sequence value (which informs header_idx and data_idx).

        always @(*) begin

            next_obuf[gi] = obuf[gi]; // Source 3

            if (gi < DATA_WIDTH) begin // Source 2
                next_obuf[gi] = shifted_obuf[gi];
            end

            if (!i_pause) begin // Source 1
                if (load_header) begin
                    if (gi >= header_idx && gi < header_idx + 2) begin
                        next_obuf[gi] = i_header[gi-header_idx];
                    end
                end

                if (gi >= data_idx && gi < data_idx + DATA_WIDTH) begin
                    next_obuf[gi] = o_frame_word ? i_data[gi-data_idx] : i_data[gi-data_idx];
                end
            end

        end

    end endgenerate

    always_ff @(posedge i_clk)
    if (i_reset) begin
        obuf <= '0;
    end else begin
        obuf <= next_obuf;
    end

endmodule
