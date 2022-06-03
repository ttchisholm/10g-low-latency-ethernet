import encoder_pkg::*;

module encode_6466b #() (

    input wire i_reset,
    input wire i_init_done,

    // TX Interface from MAC
    input wire i_txc,
    input wire[63:0] i_txd,
    input wire[7:0] i_txctl,

    // Input from gearbox
    input wire i_tx_pause, 

    // TX Interface out
    output wire [63:0] o_txd,
    output wire [1:0] o_tx_header
);
    
    //*********** Transmit **********//

    // 32-bit input to 64 bit internal
    // wire [63:0] internal_txd;
    // wire [7:0] internal_txctl;
    // logic [31:0] delayed_i_txd;
    // logic [3:0] delayed_i_txctl;

    // always @(posedge i_txc) begin
    //     if(i_reset) begin
    //         delayed_i_txd <= '0;
    //         delayed_i_txctl <= '0;
    //     end else begin
    //         if(!i_tx_pause) begin
    //             delayed_i_txd <= i_txd;
    //             delayed_i_txctl <= i_txctl;
    //         end
    //     end
    // end

    // assign internal_txd = {i_txd, delayed_i_txd};
    // assign internal_txctl = {i_txctl, delayed_i_txctl};

    // Tx encoding
    wire [7:0] tx_type;
    logic [63:0] enc_tx_data;
    wire [63:0] tx_ctl_mask, tx_ctl_mask_data;

    assign o_tx_header = (i_txctl == '0) ? SYNC_DATA : SYNC_CTL;

    // Data is transmitted lsb first, first byte is in txd[7:0]
    function logic [7:0] get_rs_code(input logic [63:0] idata, input logic [7:0] ictl, input int lane);
        assert(lane < 8);
        return ictl[lane] == 1'b1 ? idata[8*lane +: 8] : RS_ERROR;
    endfunction

    function bit get_all_rs_code(input logic [63:0] idata, input logic [7:0] ictl, input int lanes[8], input logic[7:0] code);
        for(int i = 0; i < 8; i++) begin
            if(lanes[i] == 1)
                if(get_rs_code(idata, ictl, i) != code) return 0;
        end
        return 1;
    endfunction

    function bit is_rs_ocode(input logic[7:0] code);
        return code == RS_OSEQ || code == RS_OSIG;
    endfunction

    function bit is_all_lanes_data(input logic [7:0] ictl, input int lanes[8]);
        for(int i = 0; i < 8; i++) begin
            if(lanes[i] == 1)
                if (ictl[lanes[i]] == 1'b0) return 0;
        end
        return 1;
    endfunction

    function logic [63:0] encode_frame(input logic [63:0] idata, input logic [7:0] ictl);
        if(ictl == '0) begin
            return idata;
        end else begin
            if(get_all_rs_code(idata, ictl, '{1,1,1,1,1,1,1,1}, RS_IDLE))
                return {{7{CC_IDLE}}, BT_IDLE};

            else if (is_rs_ocode(get_rs_code(idata, ictl, 4)) && is_all_lanes_data(ictl, '{0,0,0,0,0,1,1,1}))
                return {idata[63:40], rs_to_cc_ocode(get_rs_code(idata, ictl, 4)), {4{CC_IDLE}}, BT_O4};

            else if (get_all_rs_code(idata, ictl, '{1,1,1,1,0,0,0,0}, RS_IDLE) && (get_rs_code(idata, ictl, 4) == RS_START) && 
                    is_all_lanes_data(ictl, '{0,0,0,0,0,1,1,1}))
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

    assign enc_tx_data = encode_frame(i_txd, i_txctl);

    assign o_txd = (i_reset || !i_init_done) ? {{7{RS_ERROR}}, BT_IDLE} : enc_tx_data;

endmodule