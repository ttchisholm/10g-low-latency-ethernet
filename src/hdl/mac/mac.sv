`default_nettype none
`include "code_defs_pkg.svh"

module mac #(
    localparam DATA_WIDTH = 32,
    localparam DATA_NBYTES = DATA_WIDTH / 8
) (
    
    input wire tx_reset,
    input wire rx_reset,

    // Tx PHY
    input wire tx_clk,
    output logic [DATA_WIDTH-1:0] xgmii_tx_data,
    output logic [DATA_NBYTES-1:0] xgmii_tx_ctl,
    input wire phy_tx_ready,

    // Tx AXIS
    input wire [DATA_WIDTH-1:0] s00_axis_tdata,
    input wire [DATA_NBYTES-1:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,
    

    // Rx PHY
    input wire rx_clk,
    input wire [DATA_WIDTH-1:0] xgmii_rx_data,
    input wire [DATA_NBYTES-1:0] xgmii_rx_ctl,
    input wire phy_rx_valid,
    input wire [DATA_NBYTES-1:0] term_loc,

    // Rx AXIS
    output logic [DATA_WIDTH-1:0] m00_axis_tdata,
    output logic [DATA_NBYTES-1:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser
);

    import code_defs_pkg::*;

    // generate if (DATA_WIDTH != 32 && DATA_WIDTH != 64)
    //     $error("Only 32-bit and 64-bit interface mode supported\n");
    // endgenerate
    

    localparam MIN_PAYLOAD_SIZE = 46;
    localparam IPG_SIZE = 12;

    tx_mac u_tx(
    
        .reset(tx_reset),
        .clk(tx_clk),

        // Tx PHY
        .xgmii_tx_data(xgmii_tx_data),
        .xgmii_tx_ctl(xgmii_tx_ctl),
        .phy_tx_ready(phy_tx_ready),

        // Tx User AXIS
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast)
    );

    // Register AXIS out
    wire [DATA_WIDTH-1:0] rx_tdata;
    wire [DATA_NBYTES-1:0] rx_tkeep;
    wire rx_tvalid;
    wire rx_tlast;
    wire rx_tuser;

    rx_mac u_rx (
    
        .i_reset(rx_reset),
        .i_clk(rx_clk),

        // Rx PHY
        .xgmii_rxd(xgmii_rx_data),
        .xgmii_rxc(xgmii_rx_ctl),
        .phy_rx_valid(phy_rx_valid),
        .term_loc(term_loc),

        // Rx AXIS
        .m00_axis_tdata(rx_tdata),
        .m00_axis_tkeep(rx_tkeep),
        .m00_axis_tvalid(rx_tvalid),
        .m00_axis_tlast(rx_tlast),
        .m00_axis_tuser(rx_tuser)
    );

    always @(posedge rx_clk)
    if (rx_reset) begin
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