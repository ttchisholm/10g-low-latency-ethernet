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
*   Module: rx_gearbox
*
*   Description: 64b66b receive synchronus gearbox with 32-bit interface. Takes
*                2-3 32-bit words and outputs a 64-bit frame and two bit header over
*                two cycles. The header is valid when the lower 32-bits of the frame is output.
*
*                The design was modelled in python which can be found in src/tb/gearbox.
*
*                Input data is constructed in an output buffer depending on the input sequence
*                which counts from 0-32. No data is output when seq == 0. By default, obuf[1:0] is output
*                as the header, obuf[33:2] is output as the first (lower) 32-bits of the frame, and obuf[65:34]
*                is output as the second (higher) 32-bits of the frame.
*
*                Frame alignment is performed with the i_slip input. This pauses the sequence counter
*                and slips the input data by two positions. Every other assertation of i_slip causes a
*                half slip, where the data output from the buffer is shifted up by one - i.e. the header
*                output is obuf[2:1] and data obuf[34:3] / obuf[66:35]. Bit 66 of obuf is mirrored to bit 0 to
*                support this. Additionaly, the cycle at which the data output is paused is modified when
*                half slipping.
*
*/

`timescale 1ns/1ps
`default_nettype none

module rx_gearbox #(
    parameter bit REGISTER_OUTPUT = 1,
    localparam int DATA_WIDTH = 32,
    localparam int HEADER_WIDTH = 2,
    localparam int SEQUENCE_WIDTH = 6
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_data,

    input wire i_slip,

    output logic [DATA_WIDTH-1:0] o_data,
    output logic [HEADER_WIDTH-1:0] o_header,
    output logic o_data_valid,
    output logic o_header_valid
);

    localparam int BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH + 1; // Extra bit at top of buffer to allow for single bit slip

    /********* Sequence Counter ********/
    // Re-use the gearbox sequnce counter method as used in gty - this time counting every clock

    // Create the sequence counter - 0 to 32
    logic [SEQUENCE_WIDTH-1:0] gearbox_seq;
    logic half_slip;

    always_ff @(posedge i_clk)
    if (i_reset) begin
        gearbox_seq <= '0;
        half_slip <= '0;
    end else begin
        if (!i_slip) begin
            gearbox_seq <= gearbox_seq < 32 ? gearbox_seq + 1 : '0;
        end

        if (i_slip) begin
            half_slip <= ~half_slip;
        end
    end

    /********* Buffer Construction ********/

    logic [BUF_SIZE-1:0] obuf, next_obuf;
    wire frame_word;
    logic [6:0] data_idxs[33]; // For each counter value, the start buffer index to load the data
    logic [6:0] current_data_idx;

    assign frame_word = (half_slip) ? !gearbox_seq[0] && gearbox_seq != SEQUENCE_WIDTH'(32) : 
                                        !gearbox_seq[0];
    assign current_data_idx = data_idxs[gearbox_seq];

    // Need to assign single bits as iverilog does not support variable width assignments
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin: l_assign_obuf

        always @(*) begin

            next_obuf[gi] = obuf[gi];

            if (gi == BUF_SIZE - 1) begin
                next_obuf[gi] = next_obuf[0]; // Mirror top/bottom bits to allow for half sequence slip
            end else begin
                if (frame_word) begin
                    if (gearbox_seq != 0 && gi >= current_data_idx) begin
                        next_obuf[gi] = i_data[gi - current_data_idx];
                    end else if (gi < DATA_WIDTH - gearbox_seq) begin
                        next_obuf[gi] = i_data[gi + gearbox_seq];
                    end
                
                end else begin
                    if (gi >= current_data_idx && gi < current_data_idx + 32) begin
                        next_obuf[gi] = i_data[gi - current_data_idx];
                    end
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

    /********* Output Data ********/

    wire [DATA_WIDTH-1:0] odata_int;
    wire [HEADER_WIDTH-1:0] oheader_int;
    wire odata_valid_int;
    wire oheader_valid_int;

    assign odata_valid_int = half_slip ? gearbox_seq != 31 : gearbox_seq != 0;
    assign oheader_int = half_slip ? next_obuf[2:1] : next_obuf[1:0];
    assign oheader_valid_int = !frame_word && odata_valid_int;
    assign odata_int = half_slip ? (!frame_word ? next_obuf[34:3] : next_obuf[66:35]) :
                               (!frame_word ? next_obuf[33:2] : next_obuf[65:34]);

    generate if (REGISTER_OUTPUT) begin: l_register_output
        always_ff @(posedge i_clk)
        if (i_reset) begin
            o_data_valid <= '0;
            o_header <= '0;
            o_header_valid <= '0;
            o_data <= '0;
        end else begin
            o_data_valid <= odata_valid_int;
            o_header <= (oheader_valid_int) ? oheader_int : o_header;
            o_header_valid <= oheader_valid_int;
            o_data <= (odata_valid_int) ? odata_int : o_data;
        end
    end else begin: l_comb_output
        assign o_data_valid = odata_valid_int;
        assign o_header = oheader_int;
        assign o_header_valid = oheader_valid_int;
        assign o_data = odata_int;
    end endgenerate

    // Clearest way to sequence loading of data as modelled
    // iverilog doesn't support entire array assignment
    initial begin
        data_idxs[0] = 00;
        data_idxs[1] = 32;
        data_idxs[2] = 64;
        data_idxs[3] = 30;
        data_idxs[4] = 62;
        data_idxs[5] = 28;
        data_idxs[6] = 60;
        data_idxs[7] = 26;
        data_idxs[8] = 58;
        data_idxs[9] = 24;
        data_idxs[10] = 56;
        data_idxs[11] = 22;
        data_idxs[12] = 54;
        data_idxs[13] = 20;
        data_idxs[14] = 52;
        data_idxs[15] = 18;
        data_idxs[16] = 50;
        data_idxs[17] = 16;
        data_idxs[18] = 48;
        data_idxs[19] = 14;
        data_idxs[20] = 46;
        data_idxs[21] = 12;
        data_idxs[22] = 44;
        data_idxs[23] = 10;
        data_idxs[24] = 42;
        data_idxs[25] = 8;
        data_idxs[26] = 40;
        data_idxs[27] = 6;
        data_idxs[28] = 38;
        data_idxs[29] = 4;
        data_idxs[30] = 36;
        data_idxs[31] = 2;
        data_idxs[32] = 34;
    end

endmodule
