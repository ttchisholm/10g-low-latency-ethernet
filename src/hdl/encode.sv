// 32 bit data to 64/66b encoding


// In spec, everything is written LSB -> MSB
// For ease of constant declaration, everything here is MSB -> LSB, and then reversed at the end

module encode_6466b #() (
    // TX Interface from MAC
    input wire txc,
    input wire txc2, // txc2 = txc / 2 
    input wire[31:0] txd,
    input wire[3:0] txctl,
    output wire tx_pause, 

    // TX Interface out
    output wire [65:0] data
);

    // 32 bit input to 64 bit internal
    wire [63:0] txd64;
    wire [7:0] txctl64;
    logic tick = '0;

    logic [31:0] r_txd;
    logic [3:0] r_txctl;

    always @(posedge txc) begin
        r_txd <= txd;
        r_txctl <= txctl;
        tick <= !tick;
    end

    assign txd64 = {r_txd, txd};
    assign txctl64 = {r_txctl, txctl};

    // Tx encoding

    wire [1:0] tx_header = (txctl64 == '0) ? 2'b01 : 2'b10;

    // check if this is a start frame
    wire [63:0] tx_ctl_mask, tx_ctl_mask_data;

    // Set non control data to 0 for comparison of codes
    genvar i;
    generate;
        for (i = 0; i < 8; i++) begin
            assign tx_ctl_mask_data[((i+1)*8) -1:i*8] = txctl64[i] ? txd64[((i+1)*8) -1:i*8] : 8'h00; //todo cleaner indexing
        end
    endgenerate

    wire [7:0] tx_type;
    logic [63:0] tx_data;

    //Construct tx data (MSB first)
    always_comb begin
        if(txctl64 == '0) begin
            tx_data = txd64;
        end else begin
            if(txctl64 ==  8'hff && tx_ctl_mask_data == 64'h0707070707070707) tx_data = 64'h1e00000000000000; // Full IDLE
            else if(txctl64 ==  8'hf8 && tx_ctl_mask_data == 64'h07070707fb000000) tx_data = {40'h3300000000, txd64[23:0]}; // Start 1
            else if(txctl64 ==  8'h80 && tx_ctl_mask_data == 64'hfb00000000000000) tx_data = {8'h78, txd64[55:0]}; // Start 2
            else if(txctl64 ==  8'hff && tx_ctl_mask_data == 64'hfd07070707070707) tx_data = 64'h8700000000000000; //T then idle
            else if(txctl64 ==  8'h7f && tx_ctl_mask_data == 64'h00fd070707070707) tx_data = {txd64[63:56], 56'h87000000000000}; //D, T then idle
            else if(txctl64 ==  8'h3f && tx_ctl_mask_data == 64'h0000fd0707070707) tx_data = {txd64[63:48], 48'h870000000000}; //D, T then idle
            else if(txctl64 ==  8'h1f && tx_ctl_mask_data == 64'h000000fd07070707) tx_data = {txd64[63:40], 40'h8700000000}; //D, T then idle
            else if(txctl64 ==  8'h0f && tx_ctl_mask_data == 64'h00000000fd070707) tx_data = {txd64[63:32], 32'h87000000}; //D, T then idle
            else if(txctl64 ==  8'h07 && tx_ctl_mask_data == 64'h0000000000fd0707) tx_data = {txd64[63:24], 24'h870000}; //D, T then idle
            else if(txctl64 ==  8'h03 && tx_ctl_mask_data == 64'h000000000000fd07) tx_data = {txd64[63:16], 16'h8700}; //D, T then idle
            else if(txctl64 ==  8'h01 && tx_ctl_mask_data == 64'h00000000000000fd) tx_data = {txd64[63: 8],  8'h87}; //D, T then idle
            else tx_data = 64'h1e1e1e1e1e1e1e1e; //Error
        end
    end

    




endmodule