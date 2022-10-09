module pcs #(
    parameter SCRAMBLER_BYPASS = 0
)(
    
    // Reset logic
    input wire i_reset,

    // Rx from tranceiver
    input wire i_rxc,
    input wire [63:0] i_rxd,

    //Rx interface out
    output logic [63:0] o_rxd,
    output logic [7:0] o_rxctl,
    output logic o_rx_valid, // Non standard XGMII - required for no CDC
    
    input wire i_txc,
    input wire[63:0] i_txd,
    input wire[7:0] i_txctl,
    output wire o_tx_ready, // Non standard XGMII - required for no CDC

    // TX Interface out
    output wire [63:0] o_txd
);

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

    // ************* TX DATAPATH ************* //
    wire [63:0] tx_encoded_data, tx_scrambled_data;
    wire [1:0] tx_header;
    wire tx_gearbox_pause;

    // Encoder
    encode_6466b u_encoder(
        .i_reset(tx_reset),
        .i_init_done(!tx_reset),
        .i_txc(i_txc),
        .i_txd(i_txd),
        .i_txctl(i_txctl),
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
                .i_txc(i_txc),
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
        .i_clk(i_txc),
        .i_data({tx_header, tx_scrambled_data}),
        .i_slip(1'b0),
        .o_data(o_txd),
        .o_pause(tx_gearbox_pause),
        .o_valid() // Always valid when gearing down
    );

    assign o_tx_ready = !tx_gearbox_pause;

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
        .i_clk(i_rxc),
        .i_data(i_rxd),
        .i_slip(rx_gearbox_slip),
        .o_data(rx_gearbox_out),
        .o_pause(), // Never pauses when gearing up
        .o_valid(o_rx_valid)
    );
    assign rx_gearbox_data_out = rx_gearbox_out[63:0];
    assign rx_header = rx_gearbox_out[65:64];

    // Lock state machine
    lock_state u_lock_state(
        .i_clk(i_rxc),
        .i_reset(rx_reset),
        .i_header(rx_header),
        .i_valid(o_rx_valid),
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
                .i_rx_valid(o_rx_valid),
                .i_rxc(i_rxc),
                .i_rxd(rx_gearbox_data_out),
                .o_rxd(rx_descrambled_data)
            );
        end
    endgenerate

    // Decoder

    decode_6466b u_decoder(
        .i_reset(rx_reset),
        .i_init_done(!rx_reset),
        .i_rxc(i_rxc),
        .i_rxd(rx_descrambled_data),
        .i_rx_header(rx_header),
        .i_rx_valid(o_rx_valid),
        .o_rxd(o_rxd),
        .o_rxctl(o_rxctl)
    );

    `ifdef COCOTB_SIM
    initial begin
    $dumpfile ("pcs.vcd");
    $dumpvars (0, pcs);
    #1;
    end
    `endif

endmodule