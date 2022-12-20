`default_nettype none

module mac (
    
    input wire i_reset,

    // Tx PHY
    input wire i_txc,
    output logic [63:0] xgmii_txd,
    output logic [7:0] xgmii_txc,
    input wire phy_tx_ready,

    // Tx AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,
    

    // Rx PHY
    input wire i_rxc,
    input wire [63:0] xgmii_rxd,
    input wire [7:0] xgmii_rxc,
    input wire phy_rx_valid,

    // Rx AXIS
    output logic [63:0] m00_axis_tdata,
    output logic [7:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser
);

    import encoder_pkg::*;
    

    localparam MIN_PAYLOAD_SIZE = 46;
    localparam IPG_SIZE = 12;

    // ************* RESET ************* //
    logic [1:0] rx_reset_sync, tx_reset_sync;
    wire rx_reset, tx_reset;

    always @(posedge i_rxc) begin
        rx_reset_sync <= {rx_reset_sync[0], i_reset};
    end
    assign rx_reset = rx_reset_sync[1];

    always @(posedge i_txc) begin
        tx_reset_sync <= {tx_reset_sync[0], i_reset};
    end
    assign tx_reset = tx_reset_sync[1];

    tx_mac u_tx(
    
        .i_reset(i_reset),
        .i_clk(i_txc),

        // Tx PHY
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc),
        .phy_tx_ready(phy_tx_ready),

        // Tx User AXIS
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast)
    );

    rx_mac u_rx (
    
        .i_reset(i_reset),
        .i_clk(i_rxc),

        // Rx PHY
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

    

endmodule