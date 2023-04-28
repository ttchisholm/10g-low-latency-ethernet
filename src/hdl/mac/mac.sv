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
*   Module: mac
*
*   Description: Top Level 10G MAC with 32-bit XGMII interface. Note non-standard
*                pause/valid for XGMII to support integration with synchronus
*                gearbox.
*/

`timescale 1ns/1ps
`default_nettype none
`include "code_defs_pkg.svh"

module mac #(
    localparam int DATA_WIDTH = 32,
    localparam int DATA_NBYTES = DATA_WIDTH / 8
) (
    input wire i_tx_reset,
    input wire i_rx_reset,

    // Tx PHY
    input wire i_tx_clk,
    output logic [DATA_WIDTH-1:0] o_xgmii_tx_data,
    output logic [DATA_NBYTES-1:0] o_xgmii_tx_ctl,
    input wire i_phy_tx_ready,

    // Rx PHY
    input wire i_rx_clk,
    input wire [DATA_WIDTH-1:0] i_xgmii_rx_data,
    input wire [DATA_NBYTES-1:0] i_xgmii_rx_ctl,
    input wire i_phy_rx_valid,
    input wire [DATA_NBYTES-1:0] i_term_loc,

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
    output logic m00_axis_tuser
    /* svlint on prefix_input */
    /* svlint on prefix_output */
);

    import code_defs_pkg::*;

    wire [DATA_WIDTH-1:0] phy_tx_data;
    wire [DATA_NBYTES-1:0] phy_tx_ctl;

    tx_mac u_tx(
        .reset(i_tx_reset),
        .clk(i_tx_clk),

        // Tx PHY
        .xgmii_tx_data(phy_tx_data),
        .xgmii_tx_ctl(phy_tx_ctl),
        .phy_tx_ready(i_phy_tx_ready),

        // Tx User AXIS
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast)
    );

    always_ff @(posedge i_tx_clk)
    if (i_tx_reset) begin
        o_xgmii_tx_data <= '0;
        o_xgmii_tx_ctl <= '0;
    end else begin
        if (i_phy_tx_ready) begin
            o_xgmii_tx_data <= phy_tx_data;
            o_xgmii_tx_ctl <= phy_tx_ctl;
        end else begin
            o_xgmii_tx_data <= o_xgmii_tx_data;
            o_xgmii_tx_ctl <= o_xgmii_tx_ctl;
        end
    end

    // Register AXIS out
    wire [DATA_WIDTH-1:0] rx_tdata;
    wire [DATA_NBYTES-1:0] rx_tkeep;
    wire rx_tvalid;
    wire rx_tlast;
    wire rx_tuser;

    rx_mac u_rx (
        .i_reset(i_rx_reset),
        .i_clk(i_rx_clk),

        // Rx PHY
        .xgmii_rxd(i_xgmii_rx_data),
        .xgmii_rxc(i_xgmii_rx_ctl),
        .phy_rx_valid(i_phy_rx_valid),
        .term_loc(i_term_loc),

        // Rx AXIS
        .m00_axis_tdata(rx_tdata),
        .m00_axis_tkeep(rx_tkeep),
        .m00_axis_tvalid(rx_tvalid),
        .m00_axis_tlast(rx_tlast),
        .m00_axis_tuser(rx_tuser)
    );

    always_ff @(posedge i_rx_clk)
    if (i_rx_reset) begin
        m00_axis_tdata <= '0;
        m00_axis_tkeep <= '0;
        m00_axis_tvalid <= '0;
        m00_axis_tlast <= '0;
        m00_axis_tuser <= '0;
    end else begin
        m00_axis_tdata <= rx_tdata;
        m00_axis_tkeep <= rx_tkeep;
        m00_axis_tvalid <= rx_tvalid;
        m00_axis_tlast <= rx_tlast;
        m00_axis_tuser <= rx_tuser;
    end

endmodule
