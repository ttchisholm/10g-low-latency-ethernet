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
*   Module: rx_mac
*
*   Description: 10G Ethernet MAC, receive channel. XGMII and valid from PCS,
*                AXIS user out. Note terminator location (i_term_loc) input from PCS, this
*                is to ease timing pressure here.
*
*                Note:
*                A non-standard implementation of TUSER is used for the AXIS master.
*                If TUSER is not asserted with TLAST, this indicates a packet was recieved with
*                incorrect CRC. However, TLAST/TUSER can be asserted when all TKEEP == 0, this is to
*                provide data for processing ASAP. This may cause TUSER to be dropped if routing
*                the AXIS interface through interconnect.
*/

`timescale 1ns/1ps
`default_nettype none
`include "code_defs_pkg.svh"

module rx_mac #(
    localparam int DATA_WIDTH = 32,
    localparam int DATA_NBYTES = DATA_WIDTH / 8
) (
    input wire i_reset,
    input wire i_clk,

    // Rx PHY
    input wire [DATA_WIDTH-1:0] i_xgmii_rxd,
    input wire [DATA_NBYTES-1:0] i_xgmii_rxc,
    input wire i_phy_rx_valid,
    input wire [DATA_NBYTES-1:0] i_term_loc,

    /* svlint off prefix_input */
    /* svlint off prefix_output */
    // Rx AXIS
    output logic [DATA_WIDTH-1:0] m00_axis_tdata,
    output logic [DATA_NBYTES-1:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser
    /* svlint on prefix_input */
    /* svlint on prefix_output */
);
    import code_defs_pkg::*;

    /********* Declarations ********/
    // Rx states
    typedef enum logic[1:0] {IDLE, PREAMBLE, DATA, TERM} rx_state_t;
    rx_state_t rx_state, rx_next_state;

    // Start detect
    wire sfd_found;
    logic [DATA_NBYTES-1:0] start_keep;
    logic sfd_found_del;
    wire start_valid;

    // Term detect
    wire term_found;
    wire [DATA_NBYTES-1:0] term_keep;

    wire ctl_found;
    wire data_invalid;

    // CRC
    wire  rx_crc_reset;
    logic [DATA_WIDTH-1:0] rx_crc_input_del;
    logic [31:0] rx_calc_crc, rx_calc_crc_del;
    logic [31:0] rx_captured_crc;
    logic [DATA_NBYTES-1:0] crc_input_valid;
    logic [DATA_NBYTES-1:0] rx_crc_input_valid_del;
    wire crc_good;

    /********* Implementation ********/

    // State
    always_ff @(posedge i_clk)
    if (i_reset) begin
        rx_state <= IDLE;
    end else begin
        rx_state <= rx_next_state;
    end

    always @(*) begin

        m00_axis_tdata = i_xgmii_rxd;

        case (rx_state)
            IDLE: begin
                rx_next_state = bit '(sfd_found) ? DATA : IDLE;

                m00_axis_tvalid = '0;
                m00_axis_tlast = '0;
                m00_axis_tkeep = '0;
                m00_axis_tuser = '0;
            end
            DATA: begin
                // Abandon packet on any ctl char
                if (i_phy_rx_valid && (term_found || ctl_found || data_invalid)) begin
                    rx_next_state = IDLE;
                end else begin
                    rx_next_state = DATA;
                end

                m00_axis_tvalid = i_phy_rx_valid && !data_invalid && (!sfd_found_del || (sfd_found_del && start_valid));
                m00_axis_tlast = rx_next_state == IDLE;
                m00_axis_tkeep = sfd_found_del ? start_keep :
                                    term_found ? term_keep  :
                                                '1;
                m00_axis_tuser = term_found && crc_good;
            end
            default: begin
                rx_next_state = IDLE;
                m00_axis_tvalid = '0;
                m00_axis_tlast = '0;
                m00_axis_tkeep = '0;
                m00_axis_tuser = '0;
            end

        endcase

    end

    // Any control character found
    assign ctl_found = |i_xgmii_rxc;

    // Detect xgmii error
    assign data_invalid = (i_xgmii_rxc[3] && i_xgmii_rxd[31:24] == RS_ERROR) ||
                            (i_xgmii_rxc[2] && i_xgmii_rxd[23:16] == RS_ERROR) ||
                            (i_xgmii_rxc[1] && i_xgmii_rxd[15: 8] == RS_ERROR) ||
                            (i_xgmii_rxc[0] && i_xgmii_rxd[ 7: 0] == RS_ERROR);

    // Start detect
    assign sfd_found = i_phy_rx_valid && (i_xgmii_rxd == {{3{8'h55}}, RS_START}) && (i_xgmii_rxc == 4'b1);

    always_ff @(posedge i_clk) // Record sfd loc for next cycle output
    if (i_reset) begin
        sfd_found_del <= '0;
    end else begin
        sfd_found_del <= (i_phy_rx_valid) ? sfd_found : sfd_found_del;
    end

    // Term detect - now done in PCS for better timing
    // genvar gi;
    // generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
    //     assign i_term_loc[gi] = i_phy_rx_valid && i_xgmii_rxd[gi*8 +: 8] == RS_TERM && i_xgmii_rxc[gi];
    // end endgenerate
    assign term_found = |i_term_loc;


    // Keep
    assign start_keep = 4'b0000;
    assign start_valid = 1'b0; // If data width is 32, start is all preamble

    generate for (genvar gi = 0; gi < DATA_NBYTES; gi++) begin: l_term_keep
        assign term_keep[gi] = (1 << gi) < i_term_loc ? 1'b1 : 1'b0;
    end endgenerate

    // CRC
    always_ff @(posedge i_clk)
    if (i_reset) begin
        rx_crc_input_del <= '0;
        rx_crc_input_valid_del <= '0;
        rx_calc_crc_del <= '0;
    end else begin
        rx_crc_input_del <= i_phy_rx_valid ? m00_axis_tdata : rx_crc_input_del;
        rx_crc_input_valid_del <= i_phy_rx_valid ? m00_axis_tkeep : {DATA_NBYTES{1'b0}};
        rx_calc_crc_del <= i_phy_rx_valid ? rx_calc_crc : rx_calc_crc_del;
    end

    always @(*) begin
        if (!term_found) begin
            crc_input_valid = rx_crc_input_valid_del;
        end else begin
            // We need to stop the CRC itself from being input
            case (i_term_loc)
                1: crc_input_valid = 4'b0000;
                2: crc_input_valid = 4'b0001;
                4: crc_input_valid = 4'b0011;
                8: crc_input_valid = 4'b0111;
                default: crc_input_valid = 4'b1111;
            endcase
        end

        case (i_term_loc)
            1: rx_captured_crc = rx_crc_input_del;
            2: rx_captured_crc = {i_xgmii_rxd[0+:8], rx_crc_input_del[8+:24]};
            4: rx_captured_crc = {i_xgmii_rxd[0+:16], rx_crc_input_del[16+:16]};
            8: rx_captured_crc = {i_xgmii_rxd[0+:24], rx_crc_input_del[24+:8]};
            default: rx_captured_crc = i_xgmii_rxd;
        endcase
    end

    assign rx_crc_reset = rx_state == IDLE;

    // We check this on last cycle of packet - if previous cycle was invalid (!phy_rx_ready)
    //  take the previous crc result - as the updated result will have the CRC input to it
    assign crc_good = |rx_crc_input_valid_del ? rx_calc_crc == rx_captured_crc :
                                                rx_calc_crc_del == rx_captured_crc;

    slicing_crc #(
        .SLICE_LENGTH(DATA_NBYTES),
        .INITIAL_CRC(32'hFFFFFFFF),
        .INVERT_OUTPUT(1),
        .REGISTER_OUTPUT(0)
    ) u_rx_crc (
        .i_clk(i_clk),
        .i_reset(rx_crc_reset),
        .i_data(rx_crc_input_del),
        .i_valid(crc_input_valid),
        .o_crc(rx_calc_crc)
    );

endmodule
