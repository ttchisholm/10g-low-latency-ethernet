module pcs #(
    parameter SCRAMBLER_BYPASS = 0,
    parameter INTERNAL_GEARBOX = 1,

    localparam XVER_DATA_WIDTH = INTERNAL_GEARBOX ? 64 : 66
)(

    // Clocks
    input wire xver_rx_clk,
    input wire xver_tx_clk,
    
    // Reset logic
    input wire tx_reset,
    input wire rx_reset,

    // Rx from tranceiver
    input wire [XVER_DATA_WIDTH-1:0] xver_rx_data,

    // Rx XGMII
    output logic [63:0] xgmii_rx_data,
    output logic [7:0] xgmii_rx_ctl,
    output logic xgmii_rx_valid, // Non standard XGMII - required for no CDC
    
    // Tx XGMII
    input wire[63:0] xgmii_tx_data,
    input wire[7:0] xgmii_tx_ctl,
    output wire xgmii_tx_ready, // Non standard XGMII - required for no CDC

    // TX Interface out
    output wire [XVER_DATA_WIDTH-1:0] xver_tx_data

);

    // ************* TX DATAPATH ************* //
    wire [63:0] tx_encoded_data, tx_scrambled_data;
    wire [1:0] tx_header;
    wire tx_gearbox_pause;

    // Encoder
    encode_6466b u_encoder(
        .i_reset(tx_reset),
        .i_init_done(!tx_reset),
        .i_txc(xver_tx_clk),
        .i_txd(xgmii_tx_data),
        .i_txctl(xgmii_tx_ctl),
        .i_tx_pause(tx_gearbox_pause),
        .o_txd(tx_encoded_data),
        .o_tx_header(tx_header)
    );
    
    // Scrambler
    generate
        if(SCRAMBLER_BYPASS) begin
            assign tx_scrambled_data = tx_encoded_data;
        end else begin
            scrambler u_scrambler(
                .i_reset(tx_reset),
                .i_init_done(!tx_reset),
                .i_txc(xver_tx_clk),
                .i_tx_pause(tx_gearbox_pause),
                .i_txd(tx_encoded_data),
                .o_txd(tx_scrambled_data)
            );
        end
    endgenerate

    // Gearbox
    gearbox #(.INPUT_WIDTH(66), .OUTPUT_WIDTH(64)) 
    u_tx_gearbox(
        .i_reset(tx_reset),
        .i_init_done(!tx_reset),
        .i_clk(xver_tx_clk),
        .i_data({tx_scrambled_data, tx_header}),
        .i_slip(1'b0),
        .o_data(xver_tx_data),
        .o_pause(tx_gearbox_pause),
        .o_valid() // Always valid when gearing down
    );

    assign xgmii_tx_ready = !tx_gearbox_pause;

    /// ************* RX DATAPATH ************* //
    wire [65:0] rx_gearbox_out;
    wire [63:0] rx_gearbox_data_out, rx_descrambled_data;
    wire [1:0] rx_header;
    wire rx_gearbox_slip;


    // Gearbox
    gearbox  #(.INPUT_WIDTH(64), .OUTPUT_WIDTH(66)) 
    u_rx_gearbox(
        .i_reset(rx_reset),
        .i_init_done(!rx_reset),
        .i_clk(xver_rx_clk),
        .i_data(xver_rx_data),
        .i_slip(rx_gearbox_slip),
        .o_data(rx_gearbox_out),
        .o_pause(), // Never pauses when gearing up
        .o_valid(xgmii_rx_valid)
    );
    assign rx_gearbox_data_out = rx_gearbox_out[65:2];
    assign rx_header = rx_gearbox_out[1:0];

    // Lock state machine
    lock_state u_lock_state(
        .i_clk(xver_rx_clk),
        .i_reset(rx_reset),
        .i_header(rx_header),
        .i_valid(xgmii_rx_valid),
        .o_slip(rx_gearbox_slip)
    );

    // Descrambler
    generate
        if(SCRAMBLER_BYPASS) begin
            assign rx_descrambled_data = rx_gearbox_data_out;
        end else begin
            descrambler u_descrambler(
                .i_reset(rx_reset),
                .i_init_done(!rx_reset),
                .i_rx_valid(xgmii_rx_valid),
                .i_rxc(xver_rx_clk),
                .i_rxd(rx_gearbox_data_out),
                .o_rxd(rx_descrambled_data)
            );
        end
    endgenerate

    // Decoder
    decode_6466b u_decoder(
        .i_reset(rx_reset),
        .i_init_done(!rx_reset),
        .i_rxc(xver_rx_clk),
        .i_rxd(rx_descrambled_data),
        .i_rx_header(rx_header),
        .i_rx_valid(xgmii_rx_valid),
        .o_rxd(xgmii_rx_data),
        .o_rxctl(xgmii_rx_ctl)
    );

endmodule