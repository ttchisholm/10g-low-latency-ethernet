`timescale 1ns/1ps
`default_nettype none
`include "code_defs_pkg.svh"

module pcs #(
    parameter bit SCRAMBLER_BYPASS = 0,
    parameter bit EXTERNAL_GEARBOX = 0,

    localparam int DATA_WIDTH = 32,
    localparam int DATA_NBYTES = DATA_WIDTH / 8
) (

    // Clocks
    input wire i_xver_rx_clk,
    input wire i_xver_tx_clk,

    // Reset logic
    input wire i_tx_reset,
    input wire i_rx_reset,

    // Rx from tranceiver
    input wire [DATA_WIDTH-1:0] i_xver_rx_data,
    /* verilator lint_off UNUSED */
    input wire [1:0] i_xver_rx_header,
    input wire i_xver_rx_data_valid,
    input wire i_xver_rx_header_valid,
    output wire o_xver_rx_gearbox_slip,
    /* verilator lint_on UNUSED */

    // Rx XGMII
    output logic [DATA_WIDTH-1:0] o_xgmii_rx_data,
    output logic [DATA_NBYTES-1:0] o_xgmii_rx_ctl,
    output logic o_xgmii_rx_valid, // Non standard XGMII - required for no CDC
    output logic [DATA_NBYTES-1:0] o_term_loc,

    // Tx XGMII
    input wire[DATA_WIDTH-1:0] i_xgmii_tx_data,
    input wire[DATA_NBYTES-1:0] i_xgmii_tx_ctl,
    output wire o_xgmii_tx_ready, // Non standard XGMII - required for no CDC

    // TX Interface out
    output wire [DATA_WIDTH-1:0] o_xver_tx_data,
    output wire [1:0] o_xver_tx_header,
    output wire [5:0] o_xver_tx_gearbox_sequence
);

    import code_defs_pkg::*;

    // ************* TX DATAPATH ************* //
    wire [DATA_WIDTH-1:0] tx_encoded_data, tx_scrambled_data;
    wire [1:0] tx_header;
    wire tx_gearbox_pause;
    wire [DATA_WIDTH-1:0] rx_decoded_data;
    wire [DATA_NBYTES-1:0] rx_decoded_ctl;
    wire rx_data_valid, rx_header_valid;
    wire enc_frame_word;

    // Encoder
    encoder u_encoder (
        .i_reset(i_tx_reset),
        .i_init_done(!i_tx_reset),
        .i_txc(i_xver_tx_clk),
        .i_txd(i_xgmii_tx_data),
        .i_txctl(i_xgmii_tx_ctl),
        .i_tx_pause(tx_gearbox_pause),
        .i_frame_word(enc_frame_word),
        .o_txd(tx_encoded_data),
        .o_tx_header(tx_header)
    );

    // Scrambler
    generate if (SCRAMBLER_BYPASS) begin: l_tx_scrambler_bypass
            assign tx_scrambled_data = tx_encoded_data;
        end else begin: l_tx_scrambler

            // Delay the scrambler reset for tb validation - todo force in tb?
            // logic scram_reset;
            // always @ (posedge i_xver_tx_clk)
            //     scram_reset <= i_tx_reset;

            scrambler #(
            ) u_scrambler(
                .clk(i_xver_tx_clk),
                .reset(i_tx_reset),
                .init_done(!i_tx_reset),
                .pause(tx_gearbox_pause),
                .idata(tx_encoded_data),
                .odata(tx_scrambled_data)
            );
        end
    endgenerate

    // Gearbox
    generate
        if (EXTERNAL_GEARBOX != 0) begin: l_tx_ext_gearbox

            logic [5:0] prev_tx_seq;

            assign o_xver_tx_data = tx_scrambled_data;
            assign o_xver_tx_header = tx_header;

            // This assumes gearbox counter counting every other TXUSRCLK when
            //      TX_DATAWIDTH == TX_INT_DATAWIDTH == 32 ref UG578 v1.3.1 pg 120 on
            gearbox_seq #(.WIDTH(6), .MAX_VAL(32), .PAUSE_VAL(32), .HALF_STEP(1))
            u_tx_gearbox_seq (
                .clk(i_xver_tx_clk),
                .reset(i_tx_reset),
                .slip(1'b0),
                .count(o_xver_tx_gearbox_sequence),
                .pause(tx_gearbox_pause)
            );

            // Encode top word on second cycle of sequence
            assign enc_frame_word = o_xver_tx_gearbox_sequence == prev_tx_seq;

            always_ff @(posedge i_xver_tx_clk)
            if (i_tx_reset) begin
                prev_tx_seq <= '0;
            end else begin
                prev_tx_seq <= o_xver_tx_gearbox_sequence;
            end

        end else begin: l_tx_int_gearbox

            wire [5:0] int_tx_gearbox_seq;

            gearbox_seq #(.WIDTH(6), .MAX_VAL(32), .PAUSE_VAL(32), .HALF_STEP(0))
            u_tx_gearbox_seq (
                .clk(i_xver_tx_clk),
                .reset(i_tx_reset),
                .slip(1'b0),
                .count(int_tx_gearbox_seq),
                .pause(tx_gearbox_pause)
            );

            tx_gearbox u_tx_gearbox (
                .i_clk(i_xver_tx_clk),
                .i_reset(i_tx_reset),
                .i_data(tx_scrambled_data),
                .i_header(tx_header),
                .i_gearbox_seq(int_tx_gearbox_seq),
                .i_pause(tx_gearbox_pause),
                .o_frame_word(enc_frame_word),
                .o_data(o_xver_tx_data)
            );

            assign o_xver_tx_gearbox_sequence = '0;
            assign o_xver_tx_header = '0;

        end
    endgenerate

    assign o_xgmii_tx_ready = !tx_gearbox_pause;

    /// ************* RX DATAPATH ************* //
    wire [DATA_WIDTH-1:0] rx_gearbox_data_out, rx_descrambled_data;
    wire [1:0] rx_header;
    wire rx_gearbox_slip;

    generate
        if (EXTERNAL_GEARBOX != 0) begin: l_rx_ext_gearbox

            assign o_xver_rx_gearbox_slip = rx_gearbox_slip;
            assign rx_gearbox_data_out = i_xver_rx_data;
            assign rx_header = i_xver_rx_header;
            assign rx_data_valid = i_xver_rx_data_valid;
            assign rx_header_valid = i_xver_rx_header_valid;

        end else begin: l_rx_int_gearbox

            rx_gearbox #(.REGISTER_OUTPUT(1))
            u_rx_gearbox (
                .i_clk(i_xver_rx_clk),
                .i_reset(i_tx_reset),
                .i_data(i_xver_rx_data),
                .i_slip(rx_gearbox_slip),
                .o_data(rx_gearbox_data_out),
                .o_header(rx_header),
                .o_data_valid(rx_data_valid),
                .o_header_valid(rx_header_valid)
            );

            assign o_xver_rx_gearbox_slip = 1'b0;

        end
    endgenerate

    // Lock state machine
    lock_state u_lock_state(
        .i_clk(i_xver_rx_clk),
        .i_reset(i_rx_reset),
        .i_header(rx_header),
        .i_valid(rx_header_valid),
        .o_slip(rx_gearbox_slip)
    );

    // Descrambler
    generate
        if (SCRAMBLER_BYPASS) begin: l_rx_scrambler_bypass

            assign rx_descrambled_data = rx_gearbox_data_out;

        end else begin: l_rx_scrambler

            scrambler #(
                .DESCRAMBLE(1)
            ) u_descrambler(
                .clk(i_xver_rx_clk),
                .reset(i_rx_reset),
                .init_done(!i_rx_reset),
                .pause(!rx_data_valid),
                .idata(rx_gearbox_data_out),
                .odata(rx_descrambled_data)
            );

        end
    endgenerate

    // Decoder
    decoder #(
    ) u_decoder(
        .i_reset(i_rx_reset),
        .i_rxc(i_xver_rx_clk),
        .i_rxd(rx_descrambled_data),
        .i_rx_header(rx_header),
        .i_rx_data_valid(rx_data_valid),
        .i_rx_header_valid(rx_header_valid),
        .o_rxd(rx_decoded_data),
        .o_rxctl(rx_decoded_ctl)
    );

    // Calulate the term location here to help with timing in the MAC
    wire [DATA_NBYTES-1:0] early_term_loc;
    generate for (genvar gi = 0; gi < DATA_NBYTES; gi++) begin: l_early_term_loc
        assign early_term_loc[gi] = rx_data_valid && rx_decoded_data[gi*8 +: 8] == RS_TERM && rx_decoded_ctl[gi];
    end endgenerate

    always_ff @(posedge i_xver_rx_clk)
    if (i_rx_reset) begin
        o_xgmii_rx_data <= '0;
        o_xgmii_rx_ctl <= '0;
        o_xgmii_rx_valid <= '0;
        o_term_loc <= '0;
    end else begin
        o_xgmii_rx_data <= rx_decoded_data;
        o_xgmii_rx_ctl <= rx_decoded_ctl;
        o_xgmii_rx_valid <= rx_data_valid;
        o_term_loc <= early_term_loc;
    end

endmodule
