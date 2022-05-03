// 32 bit data to 64/66b encoding


// In spec, everything is written LSB -> MSB
// For ease of constant declaration, everything here is MSB -> LSB, and then reversed at the end

module encode_6466b #() (
    // TX Interface from MAC
    input wire i_txc,
    input wire i_txc2, // txc/2
    input wire[31:0] i_txd,
    input wire[3:0] i_txctl,
    output wire i_tx_pause, 

    // TX Interface out
    output wire [65:0] o_txd,

    // Rx interface from pcs
    input wire i_rxc,
    input wire i_rxc2, //rxc/2
    input wire [65:0] i_rxd,
    input wire i_rx_valid,

    //Rx interface out
    output logic [31:0] o_rxd,
    output logic [3:0] o_rxctl,
    output logic o_rx_valid
);

    //*********** Transmit **********//

    // 32-bit input to 64 bit internal
    wire [63:0] internal_txd;
    wire [7:0] internal_txctl;
    logic [31:0] delayed_i_txd;
    logic [3:0] delayed_i_txctl;

    always @(posedge i_txc) begin
        delayed_i_txd <= i_txd;
        delayed_i_txctl <= i_txctl;
    end

    assign internal_txd = {delayed_i_txd, i_txd};
    assign internal_txctl = {delayed_i_txctl, i_txctl};




    // Tx encoding
    wire [7:0] tx_type;
    logic [63:0] enc_tx_data;
    wire [1:0] tx_header;
    wire [63:0] tx_ctl_mask, tx_ctl_mask_data;

    assign tx_header = (internal_txctl == '0) ? 2'b01 : 2'b10;

    // Set non control data to 0 for comparison of codes
    genvar i;
    generate;
        for (i = 0; i < 8; i++) begin
            assign tx_ctl_mask_data[((i+1)*8) -1:i*8] = internal_txctl[i] ? internal_txd[((i+1)*8) -1:i*8] : 8'h00; //todo cleaner indexing
        end
    endgenerate

    //Construct tx data (MSB first)
    always_comb begin
        if(internal_txctl == '0) begin
            enc_tx_data = internal_txd;
        end else begin
            if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'h0707070707070707) enc_tx_data = 64'h1e00000000000000; // Full IDLE
            else if(internal_txctl ==  8'hf8 && tx_ctl_mask_data == 64'h07070707fb000000) enc_tx_data = {40'h3300000000, internal_txd[23:0]}; // Start 1
            else if(internal_txctl ==  8'h80 && tx_ctl_mask_data == 64'hfb00000000000000) enc_tx_data = {8'h78, internal_txd[55:0]}; // Start 2
            else if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'hfd07070707070707) enc_tx_data = 64'h8700000000000000; //T then idle
            else if(internal_txctl ==  8'h7f && tx_ctl_mask_data == 64'h00fd070707070707) enc_tx_data = {internal_txd[63:56], 56'h87000000000000}; //D, T then idle
            else if(internal_txctl ==  8'h3f && tx_ctl_mask_data == 64'h0000fd0707070707) enc_tx_data = {internal_txd[63:48], 48'h870000000000}; //D, T then idle
            else if(internal_txctl ==  8'h1f && tx_ctl_mask_data == 64'h000000fd07070707) enc_tx_data = {internal_txd[63:40], 40'h8700000000}; //D, T then idle
            else if(internal_txctl ==  8'h0f && tx_ctl_mask_data == 64'h00000000fd070707) enc_tx_data = {internal_txd[63:32], 32'h87000000}; //D, T then idle
            else if(internal_txctl ==  8'h07 && tx_ctl_mask_data == 64'h0000000000fd0707) enc_tx_data = {internal_txd[63:24], 24'h870000}; //D, T then idle
            else if(internal_txctl ==  8'h03 && tx_ctl_mask_data == 64'h000000000000fd07) enc_tx_data = {internal_txd[63:16], 16'h8700}; //D, T then idle
            else if(internal_txctl ==  8'h01 && tx_ctl_mask_data == 64'h00000000000000fd) enc_tx_data = {internal_txd[63: 8],  8'h87}; //D, T then idle
            else enc_tx_data = 64'h1e1e1e1e1e1e1e1e; //Error
        end
    end

    assign o_txd = {tx_header, enc_tx_data};






    
    // Rx

    

    //Rx
    wire [63:0] rxd64;
    wire [7:0] rxctl64;
    logic rx_tick = '0;

    always @(posedge i_rxc) begin
        rx_tick <= rx_tick;
        o_rxd <= (rx_tick) ? rxd64[31:0] : rxd64[63:32];
        o_rxctl <= (rx_tick) ? rxctl64[31:0] : rxctl64[63:32];
    end
endmodule