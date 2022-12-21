`default_nettype none

module mac_pcs #(
    parameter SCRAMBLER_BYPASS = 0
) (
    input wire i_reset,

    // Tx AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,

    // Rx AXIS
    output logic [63:0] m00_axis_tdata,
    output logic [7:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser,

    // Rx XVER
    input wire i_xver_rxc,
    input wire [63:0] i_xver_rxd,

    // TX XVER
    input wire i_xver_txc,
    output wire [63:0] o_xver_txd
);

    wire [63:0] xgmii_rxd, xgmii_txd;
    wire [7:0] xgmii_rxc, xgmii_txc;
    wire phy_rx_valid, phy_tx_ready;

    mac u_mac (
        
        .i_reset(i_reset),

        // Tx PHY
        .i_txc(i_xver_txc),
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc),
        .phy_tx_ready(phy_tx_ready),

        // Tx AXIS
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast),

        // Rx PHY
        .i_rxc(i_xver_rxc),
        .xgmii_rxd(xgmii_rxd),
        .xgmii_rxc(xgmii_rxc),
        .phy_rx_valid(phy_rx_valid),

        // Rx AXIS
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tkeep(m00_axis_tkeep),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tuser(m00_axis_tuser)
    );

    pcs #(
        .SCRAMBLER_BYPASS(SCRAMBLER_BYPASS)
    ) u_pcs (
        
        // Reset logic
        .i_reset(i_reset),

        // Rx from tranceiver
        .i_rxc(i_xver_rxc),
        .i_rxd(i_xver_rxd),

        //Rx interface out
        .o_rxd(xgmii_rxd),
        .o_rxctl(xgmii_rxc),
        .o_rx_valid(phy_rx_valid), // Non standard XGMII - required for no CDC
        
        .i_txc(i_xver_txc),
        .i_txd(xgmii_txd),
        .i_txctl(xgmii_txc),
        .o_tx_ready(phy_tx_ready), // Non standard XGMII - required for no CDC

        // TX Interface out
        .o_txd(o_xver_txd)
    );

endmodule