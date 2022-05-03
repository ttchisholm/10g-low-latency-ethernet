// 32 bit data to 64/66b encoding


// In spec, everything is written LSB -> MSB
// For ease of constant declaration, everything here is MSB -> LSB, and then reversed at the end
//   ^ no, define IO lsb first

module encode_6466b #() (

    input wire i_reset,
    input wire i_init_done,

    // TX Interface from MAC
    input wire i_txc,
    input wire i_txc2, // txc/2
    input wire[0:31] i_txd,
    input wire[0:3] i_txctl,
    output wire i_tx_pause, 

    // TX Interface out
    output wire [0:65] o_txd,

    // Rx interface from pcs
    input wire i_rxc,
    input wire i_rxc2, //rxc/2
    input wire [0:65] i_rxd,
    input wire i_rx_valid,

    //Rx interface out
    output logic [0:31] o_rxd,
    output logic [0:3] o_rxctl,
    output logic o_rx_valid
);

    //*********** Transmit **********//

    // 32-bit input to 64 bit internal
    wire [0:63] internal_txd;
    wire [0:7] internal_txctl;
    logic [0:31] delayed_i_txd;
    logic [0:3] delayed_i_txctl;

    always @(posedge i_txc) begin
        if(i_reset) begin
            delayed_i_txd <= '0;
            delayed_i_txctl <= '0;
        end else begin
            delayed_i_txd <= i_txd;
            delayed_i_txctl <= i_txctl;
        end
    end

    assign internal_txd = {delayed_i_txd, i_txd};
    assign internal_txctl = {delayed_i_txctl, i_txctl};

    // Tx encoding
    wire [0:7] tx_type;
    logic [0:63] enc_tx_data;
    wire [0:1] tx_header;
    wire [0:63] tx_ctl_mask, tx_ctl_mask_data;

    assign tx_header = (internal_txctl == '0) ? 2'b01 : 2'b10;

    // Set non control data to 0 for comparison of codes
    genvar i;
    generate;
        for (i = 0; i < 64; i+=8) begin
            assign tx_ctl_mask_data[i:i+7] = internal_txctl[i/8] ? internal_txd[i:i+7] : 8'h00;
        end
    endgenerate

    //Construct tx data (MSB first)
    always_comb begin
        if(internal_txctl == '0) begin
            enc_tx_data = internal_txd;
        end else begin
            if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'h0707070707070707) enc_tx_data = 64'h1e00000000000000; // Full IDLE
            else if(internal_txctl ==  8'hf8 && tx_ctl_mask_data == 64'h07070707fb000000) enc_tx_data = {40'h3300000000, internal_txd[40:63]}; // Start 1
            else if(internal_txctl ==  8'h80 && tx_ctl_mask_data == 64'hfb00000000000000) enc_tx_data = {8'h78, internal_txd[8:63]}; // Start 2
            else if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'hfd07070707070707) enc_tx_data = 64'h8700000000000000; //T then idle
            else if(internal_txctl ==  8'h7f && tx_ctl_mask_data == 64'h00fd070707070707) enc_tx_data = {internal_txd[0: 7], 56'h87000000000000}; //D, T then idle
            else if(internal_txctl ==  8'h3f && tx_ctl_mask_data == 64'h0000fd0707070707) enc_tx_data = {internal_txd[0: 15], 48'h870000000000}; //D, T then idle
            else if(internal_txctl ==  8'h1f && tx_ctl_mask_data == 64'h000000fd07070707) enc_tx_data = {internal_txd[0: 23], 40'h8700000000}; //D, T then idle
            else if(internal_txctl ==  8'h0f && tx_ctl_mask_data == 64'h00000000fd070707) enc_tx_data = {internal_txd[0: 31], 32'h87000000}; //D, T then idle
            else if(internal_txctl ==  8'h07 && tx_ctl_mask_data == 64'h0000000000fd0707) enc_tx_data = {internal_txd[0: 39], 24'h870000}; //D, T then idle
            else if(internal_txctl ==  8'h03 && tx_ctl_mask_data == 64'h000000000000fd07) enc_tx_data = {internal_txd[0: 47], 16'h8700}; //D, T then idle
            else if(internal_txctl ==  8'h01 && tx_ctl_mask_data == 64'h00000000000000fd) enc_tx_data = {internal_txd[0: 55],  8'h87}; //D, T then idle
            else enc_tx_data = 64'h1e1e1e1e1e1e1e1e; //Error
        end
    end

    // Tx State Machine
    // typedef enum logic[] { E,Z,S,D,T } tx_t;
    // tx_t tx_state;

    // function get_control_type(logic[7:0] data) begin
    //     case (data)
            
    //         default: begin
    //             default_case
    //         end
    //     endcase
    // end

    // always @(posedge i_txc) begin
    //     if(i_reset) begin
    //         tx_state <= E;
    //     end else begin
    //         case (tx_state)
    //             E: tx_state <= i_init_done & 
    //             Z:
    //             S:
    //             D:
    //             T:
    //             default: begin
    //                 tx_state <= E;
    //             end
    //         endcase
    //     end
    // end

    assign o_txd = {tx_header, enc_tx_data};




    //*********** Receive **********//

    // 64-bit input to 32-bit internal
    wire [0:63] internal_rxd;
    wire [0:7] internal_rxctl;
    logic rx_tick = '0;

    // always @(posedge i_rxc) begin
    //     rx_tick <= rx_tick;
    //     o_rxd <= (rx_tick) ? internal_rxd[31:0] : internal_rxd[63:32];
    //     o_rxctl <= (rx_tick) ? internal_rxctl[31:0] : internal_rxctl[63:32];
    // end

    // Decode data
    // if 01 header -> output data as is
    // if 10, 


endmodule