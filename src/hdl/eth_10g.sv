`default_nettype none

module eth_10g #(
    parameter SCRAMBLER_BYPASS = 0,
    parameter real INIT_CLK_FREQ = 100.0
) (
    // Reset + initiliaszation
    input wire reset,
    input wire init_clk,

    // Differential reference clock inputs
    input wire mgtrefclk0_x0y3_p,
    input wire mgtrefclk0_x0y3_n,

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

    // Serial data ports for transceiver channel 0
    input  wire ch0_gtyrxn_in,
    input  wire ch0_gtyrxp_in,
    output wire ch0_gtytxn_out,
    output wire ch0_gtytxp_out
);

    // MAC/PCS reset
    wire gtwiz_tx_ready;
    wire gtwiz_rx_ready;
    wire mac_pcs_tx_reset;
    wire mac_pcs_rx_reset;
    
    assign mac_pcs_tx_reset = !gtwiz_tx_ready;
    assign mac_pcs_rx_reset = !gtwiz_rx_ready;

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
        .EXTERNAL_GEARBOX(1)
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
        .xver_rx_clk(gtwiz_rx_usrclk2),
        .xver_rx_data(pcs_xver_rx_data),
        .xver_rx_header(pcs_xver_rx_header),
        .xver_rx_data_valid(pcs_xver_rx_data_valid),
        .xver_rx_header_valid(pcs_xver_rx_header_valid),
        .xver_rx_gearbox_slip(pcs_xver_rx_gearbox_slip),
        .xver_tx_clk(gtwiz_tx_usrclk2),
        .xver_tx_data(pcs_xver_tx_data),
        .xver_tx_header(pcs_xver_tx_header),
        .xver_tx_gearbox_sequence(pcs_xver_tx_gearbox_sequence)
    );



    gtwizard_wrapper #( 
        .INIT_CLK_FREQ(INIT_CLK_FREQ)
    ) u_gtwizard_wrapper (

        // Differential reference clock inputs
        .mgtrefclk0_x0y3_p(mgtrefclk0_x0y3_p),
        .mgtrefclk0_x0y3_n(mgtrefclk0_x0y3_n),

        // Serial data ports for transceiver channel 0
        .ch0_gtyrxn_in(ch0_gtyrxn_in),
        .ch0_gtyrxp_in(ch0_gtyrxp_in),
        .ch0_gtytxn_out(ch0_gtytxn_out),
        .ch0_gtytxp_out(ch0_gtytxp_out),

        // User-provided ports for reset helper block(s)
        .hb_gtwiz_reset_clk_freerun_in(init_clk),
        .hb_gtwiz_reset_all_in(reset),

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