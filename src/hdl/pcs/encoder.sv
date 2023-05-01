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
*   Module: encoder
*
*   Description: XGMII RS to 64b66b encoder. 32-bit data I/O.
*
*/

`timescale 1ns/1ps
`default_nettype none
`include "code_defs_pkg.svh"

module encoder #(
    parameter bit OCODE_SUPPORT = 0,
    localparam int DATA_WIDTH = 32,
    localparam int DATA_NBYTES = DATA_WIDTH / 8
) (

    input wire i_reset,
    input wire i_init_done,

    // TX Interface from MAC
    input wire i_txc,
    input wire[DATA_WIDTH-1:0] i_txd,
    input wire[DATA_NBYTES-1:0] i_txctl,

    // Input from gearbox
    input wire i_tx_pause,
    input wire i_frame_word,

    // TX Interface out
    output wire [DATA_WIDTH-1:0] o_txd,
    output wire [1:0] o_tx_header
);

    import code_defs_pkg::*;

    // 32-bit input to 64 bit internal

    logic [31:0] delayed_itxd;
    logic [3:0] delayed_itxctl;
    wire [63:0] internal_itxd;
    wire [7:0] internal_itxctl;

    wire [63:0] internal_otxd;
    wire [1:0] internal_oheader;
    // verilator lint_off UNUSED
    // While lower word unused, useful for debugging
    logic [63:0] delayed_internal_otxd;
    logic [1:0] delayed_internal_header;
    // verilator lint_on UNUSED

    always_ff @(posedge i_txc) begin
        if (i_reset) begin
            delayed_itxd <= '0;
            delayed_itxctl <= '0;
            delayed_internal_otxd <= '0;
            delayed_internal_header <= '0;
        end else begin
            if (!i_tx_pause) begin
                delayed_itxd <= i_txd;
                delayed_itxctl <= i_txctl;

                if (!i_frame_word) begin
                    delayed_internal_otxd <= internal_otxd;
                    delayed_internal_header <= internal_oheader;
                end
            end
        end
    end

    assign internal_itxd = {i_txd, delayed_itxd};
    assign internal_itxctl = {i_txctl, delayed_itxctl};

    assign o_tx_header = i_frame_word ? delayed_internal_header : internal_oheader;
    assign o_txd = i_frame_word ? delayed_internal_otxd[32 +: 32] : internal_otxd[0 +: 32];


    // Tx encoding
    logic [63:0] enc_tx_data;
    assign internal_oheader = (internal_itxctl == '0) ? SYNC_DATA : SYNC_CTL;

    // Data is transmitted lsb first, first byte is in txd[7:0]
    function automatic logic [7:0] get_rs_code(input logic [63:0] idata, input logic [7:0] ictl, input int lane);
        assert (lane < 8);
        return ictl[lane] == 1'b1 ? idata[8*lane +: 8] : RS_ERROR;
    endfunction

    function automatic bit get_all_rs_code(input logic [63:0] idata, input logic [7:0] ictl,
                                    input bit [7:0] lanes, input logic[7:0] code);
        for (int i = 0; i < 8; i++) begin
            if (lanes[i] == 1 && get_rs_code(idata, ictl, i) != code) return 0;
        end
        return 1;
    endfunction

    function automatic bit is_rs_ocode(input logic[7:0] code);
        return code == RS_OSEQ || code == RS_OSIG;
    endfunction

    function automatic bit is_all_lanes_data(input logic [7:0] ictl, input bit [7:0] lanes);
        for (int i = 0; i < 8; i++) begin
            if (lanes[i] == 1 && ictl[i] == 1) return 0;
        end
        return 1;
    endfunction

    // Ref 802.3 49.2.4.4
    function automatic logic [63:0] encode_frame(input logic [63:0] idata, input logic [7:0] ictl);
        if (ictl == '0) begin
            return idata;
        end else begin
            // All Control (IDLE) = CCCCCCCC
            if (get_all_rs_code(idata, ictl, 8'hFF, RS_IDLE)) begin
                return {{8{CC_IDLE}}, BT_IDLE};
            end
            // O4 = CCCCODDD
            else if (OCODE_SUPPORT && is_rs_ocode(get_rs_code(idata, ictl, 4)) && is_all_lanes_data(ictl, 8'h07)) begin
                return {idata[63:40], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), {4{CC_IDLE}}, BT_O4};
            end
            // S4 = CCCCSDDD
            else if (get_all_rs_code(idata, ictl, 8'h0F, RS_IDLE) && (get_rs_code(idata, ictl, 4) == RS_START) &&
                    is_all_lanes_data(ictl, 8'hE0)) begin
                return {idata[63:40], 4'b0, {4{CC_IDLE}}, BT_S4};
            end
            // O0S4 = ODDDSDDD
            else if (OCODE_SUPPORT && is_rs_ocode(get_rs_code(idata, ictl, 0)) && get_rs_code(idata, ictl, 4) == RS_START) begin
                return {idata[63:40], 4'b0, rs_to_cc_ocode(get_rs_code(idata, ictl, 0)), idata[23:0], BT_O0S4};
            end
            // O0O4 = ODDDODDD
            else if (OCODE_SUPPORT && is_rs_ocode(get_rs_code(idata, ictl, 0)) && is_rs_ocode(get_rs_code(idata, ictl, 4))) begin
                return {idata[63:40], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), rs_to_cc_ocode(get_rs_code(idata, ictl, 0)),
                            idata[23:0], BT_O0O4};
            end
            // S0 = SDDDDDDD
            else if (get_rs_code(idata, ictl, 0) == RS_START) begin
                return {idata[63:8], BT_S0};
            end
            // O0 = ODDDCCCC
            else if (OCODE_SUPPORT && is_rs_ocode(get_rs_code(idata, ictl, 4))) begin
                return {idata[63:36], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), idata[31:8], BT_O0};
            end
            // T0 = TCCCCCCC
            else if (get_rs_code(idata, ictl, 0) == RS_TERM) begin
                return {56'd0, BT_T0};
            end
            // T1 = DTCCCCCC
            else if (get_rs_code(idata, ictl, 1) == RS_TERM) begin
                return {48'd0, idata[7:0], BT_T1};
            end
            // T2 = DDTCCCCC
            else if (get_rs_code(idata, ictl, 2) == RS_TERM) begin
                return {40'd0, idata[15:0], BT_T2};
            end
            // T3 = DDDTCCCC
            else if (get_rs_code(idata, ictl, 3) == RS_TERM) begin
                return {32'd0, idata[23:0], BT_T3};
            end
            // T4 = DDDDTCCC
            else if (get_rs_code(idata, ictl, 4) == RS_TERM) begin
                return {24'd0, idata[31:0], BT_T4};
            end
            // T5 = DDDDDTCC
            else if (get_rs_code(idata, ictl, 5) == RS_TERM) begin
                return {16'd0, idata[39:0], BT_T5};
            end
            // T6 = DDDDDDTC
            else if (get_rs_code(idata, ictl, 6) == RS_TERM) begin
                return {8'd0, idata[47:0], BT_T6};
            end
            // T7 = DDDDDDDT
            else if (get_rs_code(idata, ictl, 7) == RS_TERM) begin
                return {idata[55:0], BT_T7};
            end
            else begin
                return {{7{RS_ERROR}}, BT_IDLE};
            end
        end
    endfunction

    assign enc_tx_data = encode_frame(internal_itxd, internal_itxctl);

    assign internal_otxd = (i_reset || !i_init_done) ? {{7{RS_ERROR}}, BT_IDLE} : enc_tx_data;

endmodule
