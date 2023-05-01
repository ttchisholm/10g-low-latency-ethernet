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
*   Module: mac_pcs
*
*   Description: Integrated 10G MAC and PCS with AXIS user I/O.
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

module mac_pcs #(
    parameter bit SCRAMBLER_BYPASS = 0,
    parameter bit EXTERNAL_GEARBOX = 0,
    localparam int DATA_WIDTH = 32,

    localparam int DATA_NBYTES = DATA_WIDTH / 8
) (
    input wire i_tx_reset,
    input wire i_rx_reset,

    /* svlint off prefix_input */
    /* svlint off prefix_output */
    // Tx AXIS
    input wire [DATA_WIDTH-1:0] s00_axis_tdata,
    input wire [DATA_NBYTES-1:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,

    // Rx AXIS
    output logic [DATA_WIDTH-1:0] m00_axis_tdata,
    output logic [DATA_NBYTES-1:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser,
    /* svlint on prefix_input */
    /* svlint on prefix_output */

    // Rx XVER
    input wire i_xver_rx_clk,
    input wire [DATA_WIDTH-1:0] i_xver_rx_data,
    input wire [1:0] i_xver_rx_header,
    input wire i_xver_rx_data_valid,
    input wire i_xver_rx_header_valid,
    output wire o_xver_rx_gearbox_slip,

    // TX XVER
    input wire i_xver_tx_clk,
    output wire [DATA_WIDTH-1:0] o_xver_tx_data,
    output wire [1:0] o_xver_tx_header,
    output wire [5:0] o_xver_tx_gearbox_sequence
);

    wire [DATA_WIDTH-1:0] xgmii_rx_data, xgmii_tx_data;
    wire [DATA_NBYTES-1:0] xgmii_rx_ctl, xgmii_tx_ctl;
    wire phy_rx_valid, phy_tx_ready;
    wire [DATA_NBYTES-1:0] term_loc;

    mac u_mac (
        .i_tx_reset(i_tx_reset),
        .i_rx_reset(i_rx_reset),

        // Tx PHY
        .i_tx_clk(i_xver_tx_clk),
        .o_xgmii_tx_data(xgmii_tx_data),
        .o_xgmii_tx_ctl(xgmii_tx_ctl),
        .i_phy_tx_ready(phy_tx_ready),

        // Tx AXIS
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast),

        // Rx PHY
        .i_rx_clk(i_xver_rx_clk),
        .i_xgmii_rx_data(xgmii_rx_data),
        .i_xgmii_rx_ctl(xgmii_rx_ctl),
        .i_phy_rx_valid(phy_rx_valid),
        .i_term_loc(term_loc),

        // Rx AXIS
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tkeep(m00_axis_tkeep),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tuser(m00_axis_tuser)
    );


    pcs #(
        .SCRAMBLER_BYPASS(SCRAMBLER_BYPASS),
        .EXTERNAL_GEARBOX(EXTERNAL_GEARBOX),
        .ENCODER_OCODE_SUPPORT(0) // Mac doesn't generate OCODES, disable to relieve timing pressure
    ) u_pcs (

        // Reset logic
        .i_tx_reset(i_tx_reset),
        .i_rx_reset(i_rx_reset),

        // Rx from tranceiver
        .i_xver_rx_clk(i_xver_rx_clk),
        .i_xver_rx_data(i_xver_rx_data),
        .i_xver_rx_header(i_xver_rx_header),
        .i_xver_rx_data_valid(i_xver_rx_data_valid),
        .i_xver_rx_header_valid(i_xver_rx_header_valid),
        .o_xver_rx_gearbox_slip(o_xver_rx_gearbox_slip),

        //Rx interface out
        .o_xgmii_rx_data(xgmii_rx_data),
        .o_xgmii_rx_ctl(xgmii_rx_ctl),
        .o_xgmii_rx_valid(phy_rx_valid), // Non standard XGMII - required for no CDC
        .o_term_loc(term_loc),

        .i_xver_tx_clk(i_xver_tx_clk),
        .i_xgmii_tx_data(xgmii_tx_data),
        .i_xgmii_tx_ctl(xgmii_tx_ctl),
        .o_xgmii_tx_ready(phy_tx_ready), // Non standard XGMII - required for no CDC

        // TX Interface out
        .o_xver_tx_data(o_xver_tx_data),
        .o_xver_tx_header(o_xver_tx_header),
        .o_xver_tx_gearbox_sequence(o_xver_tx_gearbox_sequence)
    );

endmodule
