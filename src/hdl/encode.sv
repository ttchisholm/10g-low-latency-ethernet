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


    //********** Code Definitions **********//

    typedef enum logic [1:0] {
        SYNC_DATA = 2'b10,
        SYNC_CTL = 2'b01
    } sync_t;

    // Block Type
    typedef enum logic [7:0] {
        BT_IDLE = 8'h1e,
        BT_O4   = 8'h2d,
        BT_S4   = 8'h33,
        BT_O0S4 = 8'h66,
        BT_O0O4 = 8'h55,
        BT_S0   = 8'h78,
        BT_O0   = 8'h4b,
        BT_T0   = 8'h87,
        BT_T1   = 8'h99,
        BT_T2   = 8'haa,
        BT_T3   = 8'hb4,
        BT_T4   = 8'hcc,
        BT_T5   = 8'hd2,
        BT_T6   = 8'he1,
        BT_T7   = 8'hff
    } block_type_t;

    // Control Codes
    typedef enum logic [6:0] {
        CC_IDLE = 7'b00,
        CC_LPI = 7'h06,
        CC_ERROR = 7'h1e,
        CC_RES0 = 7'h2d,
        CC_RES1 = 7'h33,
        CC_RES2 = 7'h4b,
        CC_RES3 = 7'h55,
        CC_RES4 = 7'h66,
        CC_RES5 = 7'h78
    } control_code_t;

    // O-Codes
    typedef enum logic [3:0] {
        OC_SEQ = 4'h0,
        OC_SIG = 4'hf
    } o_code_t;

    // RS Codes
    typedef enum logic [7:0] {
        RS_IDLE = 8'h07,
        RS_LPI = 8'h06,
        RS_START = 8'hfb,
        RS_TERM = 8'hfd,
        RS_ERROR = 8'hfe,
        RS_OSEQ = 8'h9c,
        RS_RES0 = 8'h1c,
        RS_RES1 = 8'h3c,
        RS_RES2 = 8'h7c,
        RS_RES3 = 8'hbc,
        RS_RES4 = 8'hdc,
        RS_RES5 = 8'hf7,
        RS_OSIG = 8'h5c
    } rs_code_t;


    
    //*********** Transmit **********//

    // 32-bit input to 64 bit internal
    wire [63:0] internal_txd;
    wire [7:0] internal_txctl;
    logic [31:0] delayed_i_txd;
    logic [3:0] delayed_i_txctl;

    always @(posedge i_txc) begin
        if(i_reset) begin
            delayed_i_txd <= '0;
            delayed_i_txctl <= '0;
        end else begin
            delayed_i_txd <= i_txd;
            delayed_i_txctl <= i_txctl;
        end
    end

    assign internal_txd = {i_txd, delayed_i_txd};
    assign internal_txctl = {i_txctl, delayed_i_txctl};

    // Tx encoding
    wire [7:0] tx_type;
    logic [63:0] enc_tx_data;
    wire [1:0] tx_header;
    wire [63:0] tx_ctl_mask, tx_ctl_mask_data;

    assign tx_header = (internal_txctl == '0) ? SYNC_DATA : SYNC_CTL;


    // Data is transmitted lsb first, first byte is in txd[7:0]


    function logic [7:0] get_rs_code(input logic [63:0] idata, input logic [7:0] ictl, input int lane);
        assert(lane < 8);
        return ictl[lane] == 1'b1 ? idata[8*lane +: 8] : RS_ERROR;
    endfunction

    function bit get_all_rs_code(input logic [63:0] idata, input logic [7:0] ictl, input int lanes[], input logic[7:0] code);
        foreach(lanes[i]) begin
            //$display("%d", get_rs_code(idata, ictl, i));
            if(get_rs_code(idata, ictl, i) != code) return 0;
        end
        return 1;
    endfunction

    function bit is_rs_ocode(input logic[7:0] code);
        return code == RS_OSEQ || code == RS_OSIG;
    endfunction

    function logic [3:0] rs_to_cc_ocode (input logic [7:0] rs_code);
        return rs_code == RS_OSEQ ? OC_SEQ : OC_SIG;
    endfunction

    function bit is_all_lanes_data(input logic [7:0] ictl, input int lanes[]);
        foreach(lanes[i]) begin
            if (ictl[i] == 1'b0) return 0;
        end
        return 1;
    endfunction

    function logic [63:0] encode_frame(input logic [63:0] idata, input logic [7:0] ictl);
        if(ictl == '0) begin
            return idata;
        end else begin
            if(get_all_rs_code(idata, ictl, '{0,1,2,3,4,5,6,7}, RS_IDLE))
                return {{7{CC_IDLE}}, BT_IDLE};

            else if (is_rs_ocode(get_rs_code(idata, ictl, 4)) && is_all_lanes_data(ictl, '{5,6,7}))
                return {idata[63:40], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), {4{CC_IDLE}}, BT_O4};

            else if (get_all_rs_code(idata, ictl, '{0,1,2,3}, RS_IDLE) && (get_rs_code(idata, ictl, 4) == RS_START) && 
                    is_all_lanes_data(ictl, '{5,6,7}))
                return {idata[63:40], 4'b0, {4{CC_IDLE}}, BT_S4};

            else if (is_rs_ocode(get_rs_code(idata, ictl, 0)) && get_rs_code(idata, ictl, 4) == RS_START)
                return {idata[63:40], 4'b0, rs_to_cc_ocode(get_rs_code(idata, ictl, 0)), idata[23:0], BT_O0S4};

            else if (is_rs_ocode(get_rs_code(idata, ictl, 0)) && is_rs_ocode(get_rs_code(idata, ictl, 4)))
                return {idata[63:40], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), rs_to_cc_ocode(get_rs_code(idata, ictl, 0)), 
                            idata[23:0], BT_O0O4};

            else if (get_rs_code(idata, ictl, 0) == RS_START)
                return {idata[63:8], BT_S0};

            else if (is_rs_ocode(get_rs_code(idata, ictl, 4)))
                return {idata[63:35], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), idata[31:8], BT_O4};
            
            else if (get_rs_code(idata, ictl, 0) == RS_TERM)
                return {56'd0, BT_T0};
            else if (get_rs_code(idata, ictl, 1) == RS_TERM)
                return {48'd0, idata[7:0], BT_T1};
            else if (get_rs_code(idata, ictl, 2) == RS_TERM)
                return {40'd0, idata[15:0], BT_T2};
            else if (get_rs_code(idata, ictl, 3) == RS_TERM)
                return {32'd0, idata[23:0], BT_T3};
            else if (get_rs_code(idata, ictl, 4) == RS_TERM)
                return {24'd0, idata[31:0], BT_T4};
            else if (get_rs_code(idata, ictl, 5) == RS_TERM)
                return {16'd0, idata[39:0], BT_T5};
            else if (get_rs_code(idata, ictl, 6) == RS_TERM)
                return {8'd0, idata[47:0], BT_T6};
            else if (get_rs_code(idata, ictl, 7) == RS_TERM)
                return {idata[56:0], BT_T7};
            else
                return {{7{RS_ERROR}}, BT_IDLE};
            

        end
    endfunction



    assign enc_tx_data = encode_frame(internal_txd, internal_txctl);



    // Set non control data to 0 for comparison of codes
    // genvar i;
    // generate;
    //     for (i = 0; i < 64; i+=8) begin
    //         assign tx_ctl_mask_data[i+7:i] = internal_txctl[i/8] ? internal_txd[i+7:i] : 8'h00;
    //     end
    // endgenerate

    // //Construct tx data (MSB first)
    // always_comb begin
    //     if(internal_txctl == '0) begin
    //         enc_tx_data = internal_txd;
    //     end else begin
    //         if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'h0707070707070707) enc_tx_data = 64'h1e00000000000000; // Full IDLE
    //         else if(internal_txctl ==  8'hf8 && tx_ctl_mask_data == 64'h07070707fb000000) enc_tx_data = {40'h3300000000, internal_txd[23:0]}; // Start 1
    //         else if(internal_txctl ==  8'h80 && tx_ctl_mask_data == 64'hfb00000000000000) enc_tx_data = {8'h78, internal_txd[55:0]}; // Start 2
    //         else if(internal_txctl ==  8'hff && tx_ctl_mask_data == 64'hfd07070707070707) enc_tx_data = 64'h8700000000000000; //T then idle
    //         else if(internal_txctl ==  8'h7f && tx_ctl_mask_data == 64'h00fd070707070707) enc_tx_data = {internal_txd[63:56], 56'h87000000000000}; //D, T then idle
    //         else if(internal_txctl ==  8'h3f && tx_ctl_mask_data == 64'h0000fd0707070707) enc_tx_data = {internal_txd[63:48], 48'h870000000000}; //D, T then idle
    //         else if(internal_txctl ==  8'h1f && tx_ctl_mask_data == 64'h000000fd07070707) enc_tx_data = {internal_txd[63:40], 40'h8700000000}; //D, T then idle
    //         else if(internal_txctl ==  8'h0f && tx_ctl_mask_data == 64'h00000000fd070707) enc_tx_data = {internal_txd[63:32], 32'h87000000}; //D, T then idle
    //         else if(internal_txctl ==  8'h07 && tx_ctl_mask_data == 64'h0000000000fd0707) enc_tx_data = {internal_txd[63:24], 24'h870000}; //D, T then idle
    //         else if(internal_txctl ==  8'h03 && tx_ctl_mask_data == 64'h000000000000fd07) enc_tx_data = {internal_txd[63:16], 16'h8700}; //D, T then idle
    //         else if(internal_txctl ==  8'h01 && tx_ctl_mask_data == 64'h00000000000000fd) enc_tx_data = {internal_txd[63: 8],  8'h87}; //D, T then idle
    //         else enc_tx_data = 64'h1e1e1e1e1e1e1e1e; //Error // todo not correct (1e 7 bits)
    //     end
    // end

    // Tx State Machine
    // typedef enum logic[] { E,Z,S,D,T } tx_t;
    // tx_t tx_state;

    // function tx_t get_control_type(logic [0:1] sync, logic[0:7] data) 
    // begin
    //     if(sync == 2'b01) begin
    //         return D;
    //     else begin
    //         case (data)
    //             8'h1e: Z;
    //             8'h33: S;
    //             8'h78: S;
    //             8'h78: T;
    //             8'h87: T;
    //             8'h99: T;
    //             8'haa: T;
    //             8'hb4: T;
    //             8'hcc: T;
    //             8'hd2: T;
    //             8'he1: T;
    //             8'hff: T;
    //             default: begin
    //                 return E;
    //             end
    //         endcase
    //     end
    // end

    // always @(posedge i_txc) begin
    //     if(i_reset) begin
    //         tx_state <= E;
    //     end else begin
    //         case (tx_state)
    //             E: tx_state <= (i_init_done && get_control_type(tx_header, enc_tx_data) == Z) ? Z : E;
    //             Z: tx_state <= (get_control_type(tx_header, enc_tx_data) == Z) ? Z :
    //                            (get_control_type(tx_header, enc_tx_data) == S) ? S : E;
    //             S: tx_state <= (get_control_type(tx_header, enc_tx_data) == D) ? D : E;
    //             D: tx_state <= (get_control_type(tx_header, enc_tx_data) == D) ? D :
    //                            (get_control_type(tx_header, enc_tx_data) == T) ? T : E;
    //             T: tx_state <= (get_control_type(tx_header, enc_tx_data) == S) ? S :
    //                            (get_control_type(tx_header, enc_tx_data) == Z) ? Z : E;
    //             default: begin
    //                 tx_state <= E;
    //             end
    //         endcase
    //     end
    // end



    // assign o_txd = (tx_state == E) ? {0'b10, } : 
    //                                 {tx_header, enc_tx_data};




    //*********** Receive **********//

    // 64-bit input to 32-bit internal
    wire [63:0] internal_rxd;
    wire [7:0] internal_rxctl;
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