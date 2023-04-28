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
*   Module: eth_10g
*
*   Description: Top-level low-latency 10G Ethernet Core. Includes MAC, PCS and Xilinx
*                GTY instantiation.
*
*                Note:
*                A non-standard implementation of TUSER is used for the AXIS master.
*                If TUSER is not asserted with TLAST, this indicates a packet was recieved with
*                incorrect CRC. However, TLAST/TUSER can be asserted when all TKEEP == 0, this is to
*                provide data for processing ASAP. This may cause TUSER to be dropped if routing
*                the AXIS interface through interconnect.
*
*/

`timescale 1ns/1ps
`default_nettype none

module eth_10g #(
    parameter bit SCRAMBLER_BYPASS = 0,
    parameter bit EXTERNAL_GEARBOX = 0,
    parameter real INIT_CLK_FREQ = 100.0
) (
    // Reset + initiliaszation
    input wire i_reset,
    input wire i_init_clk,

    // Differential reference clock inputs
    input wire i_mgtrefclk0_x0y3_p,
    input wire i_mgtrefclk0_x0y3_n,

    /* svlint off prefix_input */
    /* svlint off prefix_output */
    // Tx AXIS
    output wire s00_axis_aclk,
    input wire [31:0] s00_axis_tdata,
    input wire [3:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,

    // Rx AXIS
    output wire m00_axis_aclk,
    output logic [31:0] m00_axis_tdata,
    output logic [3:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser,
    /* svlint on prefix_input */
    /* svlint on prefix_output */

    // Serial data ports for transceiver channel 0
    input  wire i_ch0_gtyrxn_in,
    input  wire i_ch0_gtyrxp_in,
    output wire o_ch0_gtytxn_out,
    output wire o_ch0_gtytxp_out,

    // Output tx/rx mac/pcs i_reset ports
    output wire o_mac_pcs_tx_reset,
    output wire o_mac_pcs_rx_reset
);

    // MAC/PCS i_reset
    wire gtwiz_tx_ready;
    wire gtwiz_rx_ready;

    assign o_mac_pcs_tx_reset = !gtwiz_tx_ready;
    assign o_mac_pcs_rx_reset = !gtwiz_rx_ready;

    // Datapath
    wire [31:0] pcs_xver_tx_data;
    wire [1:0] pcs_xver_tx_header;
    wire [31:0] pcs_xver_rx_data;
    wire [1:0] pcs_xver_rx_header;

    // Clock
    wire gtwiz_tx_usrclk2;
    wire gtwiz_rx_usrclk2;

    // Gearbox
    wire [5:0] pcs_xver_tx_gearbox_sequence;
    wire pcs_xver_rx_data_valid;
    wire pcs_xver_rx_header_valid;
    wire pcs_xver_rx_gearbox_slip;

    assign m00_axis_aclk = gtwiz_rx_usrclk2;
    assign s00_axis_aclk = gtwiz_tx_usrclk2;

    mac_pcs #(
        .SCRAMBLER_BYPASS(SCRAMBLER_BYPASS),
        .EXTERNAL_GEARBOX(EXTERNAL_GEARBOX)
    ) u_mac_pcs (
        .i_tx_reset(o_mac_pcs_tx_reset),
        .i_rx_reset(o_mac_pcs_rx_reset),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tkeep(m00_axis_tkeep),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tuser(m00_axis_tuser),
        .i_xver_rx_clk(gtwiz_rx_usrclk2),
        .i_xver_rx_data(pcs_xver_rx_data),
        .i_xver_rx_header(pcs_xver_rx_header),
        .i_xver_rx_data_valid(pcs_xver_rx_data_valid),
        .i_xver_rx_header_valid(pcs_xver_rx_header_valid),
        .o_xver_rx_gearbox_slip(pcs_xver_rx_gearbox_slip),
        .i_xver_tx_clk(gtwiz_tx_usrclk2),
        .o_xver_tx_data(pcs_xver_tx_data),
        .o_xver_tx_header(pcs_xver_tx_header),
        .o_xver_tx_gearbox_sequence(pcs_xver_tx_gearbox_sequence)
    );


    gtwizard_wrapper #(
        .INIT_CLK_FREQ(INIT_CLK_FREQ),
        .EXTERNAL_GEARBOX(EXTERNAL_GEARBOX)
    ) u_gtwizard_wrapper (

        // Differential reference clock inputs
        .mgtrefclk0_x0y3_p(i_mgtrefclk0_x0y3_p),
        .mgtrefclk0_x0y3_n(i_mgtrefclk0_x0y3_n),

        // Serial data ports for transceiver channel 0
        .ch0_gtyrxn_in(i_ch0_gtyrxn_in),
        .ch0_gtyrxp_in(i_ch0_gtyrxp_in),
        .ch0_gtytxn_out(o_ch0_gtytxn_out),
        .ch0_gtytxp_out(o_ch0_gtytxp_out),

        // User-provided ports for i_reset helper block(s)
        .hb_gtwiz_reset_clk_freerun_in(i_init_clk),
        .hb_gtwiz_reset_all_in(i_reset),

        // User data ports
        .hb0_gtwiz_userdata_tx_int(pcs_xver_tx_data),
        .hb0_gtwiz_header_tx(pcs_xver_tx_header),
        .hb0_gtwiz_userdata_rx_int(pcs_xver_rx_data),
        .hb0_gtwiz_header_rx(pcs_xver_rx_header),

        .hb0_gtwiz_rx_gearbox_slip(pcs_xver_rx_gearbox_slip),
        .hb0_gtwiz_rx_data_valid(pcs_xver_rx_data_valid),
        .hb0_gtwiz_rx_header_valid(pcs_xver_rx_header_valid),
        .hb0_gtwiz_tx_gearbox_sequence(pcs_xver_tx_gearbox_sequence),

        // Transceiver user clock outputs
        .hb0_gtwiz_userclk_tx_usrclk2(gtwiz_tx_usrclk2),
        .hb0_gtwiz_userclk_rx_usrclk2(gtwiz_rx_usrclk2),

        // Transceiver ready/error outputs
        .tx_ready(gtwiz_tx_ready),
        .rx_ready(gtwiz_rx_ready)
    );

endmodule
