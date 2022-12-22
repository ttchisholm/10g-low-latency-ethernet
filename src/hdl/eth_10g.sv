module eth_10g #(
    parameter SCRAMBLER_BYPASS = 0,
    parameter real INIT_CLK_FREQ = 100.0
) (
    // Reset + initiliaszation
    input wire reset,
    input wire init_clk,

    // Differential reference clock inputs
    input  wire mgtrefclk0_x0y3_p,
    input  wire mgtrefclk0_x0y3_n,
    input  wire mgtrefclk0_x0y4_p,
    input  wire mgtrefclk0_x0y4_n,

    // Tx AXIS
    output wire s00_axis_aclk,
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,

    // Rx AXIS
    output wire m00_axis_aclk,
    output logic [63:0] m00_axis_tdata,
    output logic [7:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser,

    // Serial data ports for transceiver channel 0
    input  wire ch0_gtyrxn_in,
    input  wire ch0_gtyrxp_in,
    output wire ch0_gtytxn_out,
    output wire ch0_gtytxp_out,

    // Serial data ports for transceiver channel 1
    input  wire ch1_gtyrxn_in,
    input  wire ch1_gtyrxp_in,
    output wire ch1_gtytxn_out,
    output wire ch1_gtytxp_out,
);

    // MAC/PCS reset
    wire gtwiz_tx_ready;
    wire gtwiz_rx_ready;
    wire mac_pcs_tx_reset;
    wire mac_pcs_rx_reset;
    
    assign mac_pcs_tx_reset = !gtwiz_tx_ready;
    assign mac_pcs_rx_reset = !gtwiz_rx_ready;

    // Datapath
    wire [63:0] pcs_xver_tx_data;
    wire [63:0] pcs_xver_rx_data;

    // Clock
    wire gtwiz_tx_usrclk2;
    wire gtwiz_rx_usrclk2;

    assign m00_axis_aclk = gtwiz_tx_usrclk2;
    assign s00_axis_aclk = gtwiz_rx_usrclk2;
    
    mac_pcs #(
        .SCRAMBLER_BYPASS(SCRAMBLER_BYPASS)
    ) u_mac_pcs (
        .i_tx_reset(mac_pcs_tx_reset),
        .i_rx_reset(mac_pcs_rx_reset),
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
        .i_xver_rxc(gtwiz_rx_usrclk2),
        .i_xver_rxd(pcs_xver_rx_data),
        .i_xver_txc(gtwiz_tx_usrclk2),
        .o_xver_txd(pcs_xver_tx_data),
    );



    gtwizard_wrapper #( 
        .INIT_CLK_FREQ(INIT_CLK_FREQ)
    ) u_gtwizard_wrapper (

        // Differential reference clock inputs
        .mgtrefclk0_x0y3_p(mgtrefclk0_x0y3_p),
        .mgtrefclk0_x0y3_n(mgtrefclk0_x0y3_n),
        .mgtrefclk0_x0y4_p(mgtrefclk0_x0y4_p),
        .mgtrefclk0_x0y4_n(mgtrefclk0_x0y4_n),

        // Serial data ports for transceiver channel 0
        .ch0_gtyrxn_in(ch0_gtyrxn_in),
        .ch0_gtyrxp_in(ch0_gtyrxp_in),
        .ch0_gtytxn_out(ch0_gtytxn_out),
        .ch0_gtytxp_out(ch0_gtytxp_out),

        // Serial data ports for transceiver channel 1
        .ch1_gtyrxn_in(ch1_gtyrxn_in),
        .ch1_gtyrxp_in(ch1_gtyrxp_in),
        .ch1_gtytxn_out(ch1_gtytxn_out),
        .ch1_gtytxp_out(ch1_gtytxp_out),

        // User-provided ports for reset helper block(s)
        .hb_gtwiz_reset_clk_freerun_in(init_clk),
        .hb_gtwiz_reset_all_in(reset),

        // User data ports
        .hb0_gtwiz_userdata_tx_int(pcs_xver_tx_data), // Configuration for external loopback - tx / rx on different quads
        .hb1_gtwiz_userdata_tx_int(),
        .hb0_gtwiz_userdata_rx_int(),
        .hb1_gtwiz_userdata_rx_int(pcs_xver_rx_data),

        // Transceiver user clock outputs
        .hb0_gtwiz_userclk_tx_usrclk2(gtwiz_tx_usrclk2),
        .hb0_gtwiz_userclk_rx_usrclk2(gtwiz_rx_usrclk2),

        // Transceiver ready/error outputs
        .tx_ready(tx_ready),
        .rx_ready(rx_ready),
    );



endmodule