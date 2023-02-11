`default_nettype none

module mac_pcs #(
    parameter SCRAMBLER_BYPASS = 0,
    parameter EXTERNAL_GEARBOX = 0
) (
    input wire i_tx_reset,
    input wire i_rx_reset,

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
    input wire xver_rx_clk,
    input wire [63:0] xver_rx_data,
    input wire [1:0] xver_rx_header,
    input wire xver_rx_gearbox_valid,
    output wire xver_rx_gearbox_slip,

    // TX XVER
    input wire xver_tx_clk,
    output wire [63:0] xver_tx_data,
    output wire [1:0] xver_tx_header,
    output wire [5:0] xver_tx_gearbox_sequence
);

    wire [63:0] xgmii_rxd, xgmii_txd;
    wire [7:0] xgmii_rxc, xgmii_txc;
    wire phy_rx_valid, phy_tx_ready;

    mac u_mac (
        
        .i_tx_reset(i_tx_reset),
        .i_rx_reset(i_rx_reset),

        // Tx PHY
        .i_txc(xver_tx_clk),
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
        .i_rxc(xver_rx_clk),
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
        .SCRAMBLER_BYPASS(SCRAMBLER_BYPASS),
        .EXTERNAL_GEARBOX(EXTERNAL_GEARBOX)
    ) u_pcs (
        
        // Reset logic
        .tx_reset(i_tx_reset),
        .rx_reset(i_rx_reset),

        // Rx from tranceiver
        .xver_rx_clk(xver_rx_clk),
        .xver_rx_data(xver_rx_data),
        .xver_rx_header(xver_rx_header),
        .xver_rx_gearbox_valid(xver_rx_gearbox_valid),
        .xver_rx_gearbox_slip(xver_rx_gearbox_slip),

        //Rx interface out
        .xgmii_rx_data(xgmii_rxd),
        .xgmii_rx_ctl(xgmii_rxc),
        .xgmii_rx_valid(phy_rx_valid), // Non standard XGMII - required for no CDC
        
        .xver_tx_clk(xver_tx_clk),
        .xgmii_tx_data(xgmii_txd),
        .xgmii_tx_ctl(xgmii_txc),
        .xgmii_tx_ready(phy_tx_ready), // Non standard XGMII - required for no CDC

        // TX Interface out
        .xver_tx_data(xver_tx_data),
        .xver_tx_header(xver_tx_header),
        .xver_tx_gearbox_sequence(xver_tx_gearbox_sequence)
    );

endmodule