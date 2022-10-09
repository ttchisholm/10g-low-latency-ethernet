

module decode_6466b (

    input wire i_reset,
    input wire i_init_done,   // Rx interface from pcs
    input wire i_rxc,
    input wire [63:0] i_rxd,
    input wire [1:0] i_rx_header,
    input wire i_rx_valid,

    //Rx interface out
    output wire [63:0] o_rxd,
    output wire [7:0] o_rxctl
);

    import encoder_pkg::*;

   typedef struct packed {
        logic [63:0] odata; 
        logic [7:0] octl;
   } xgmii_data_ctl;

    function logic [63:0] control_code_to_rs_lane(input logic [63:0] idata, input bit [3:0] lanes);
        logic [63:0] odata;
        odata = {8{RS_ERROR}};
        for( int i = 0; i < 8; i++) begin
            if (lanes[i] == 1) begin
                odata[8*i +: 8] = control_to_rs_code(idata[8 + (7*i) +: 7]); // todo check part-select
            end
        end
        return odata;
    endfunction


    function xgmii_data_ctl decode_frame(input logic [63:0] idata, input logic [1:0] iheader);

        // If data header, pass through

        // Else
        /*
        switch on block type, assign data, ctl as appropriate
        */
        decode_frame.odata = '0;
        decode_frame.octl = '0;

        if (iheader == SYNC_DATA) begin
            decode_frame.odata = idata;
            decode_frame.octl = '0;
        end else begin
            case (idata[7:0])
                
                BT_IDLE: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'hFF);
                    decode_frame.octl = '1;
                end
                BT_O4: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'hF0);
                    decode_frame.odata[63:40] = idata[63:40];
                    decode_frame.odata[39:32] = cc_to_rs_ocode(idata[39:36]);
                    decode_frame.octl = 8'h0F;
                end
                BT_S4: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'hF0);
                    decode_frame.odata[63:40] = idata[63:40];
                    decode_frame.odata[39:32] = RS_START;
                    decode_frame.octl = 8'h0F;
                end
                BT_O0S4: begin
                    decode_frame.odata[63:40] = idata[63:40];
                    decode_frame.odata[39:32] = RS_START;
                    decode_frame.odata[31: 8] = idata[31: 8];
                    decode_frame.odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    decode_frame.octl = 8'h11;
                end
                BT_O0O4: begin
                    decode_frame.odata[63:40] = idata[63:40];
                    decode_frame.odata[39:32] = cc_to_rs_ocode(idata[35:32]);
                    decode_frame.odata[31: 8] = idata[31: 8];
                    decode_frame.odata[ 7: 0] = cc_to_rs_ocode(idata[39:36]);
                    decode_frame.octl = 8'h11;
                end
                BT_S0: begin
                    decode_frame.odata[63: 8] = idata[63: 8];
                    decode_frame.odata[ 7: 0] = RS_START;
                    decode_frame.octl = 8'h01;
                end
                BT_O0: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h0F);
                    decode_frame.odata[31: 8] = idata[31: 8];
                    decode_frame.odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    decode_frame.octl = 8'hF1;
                end
                BT_T0: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h7F);
                    decode_frame.odata[ 7: 0] = RS_TERM;
                    decode_frame.octl = 8'hFF;
                end
                BT_T1: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h3F);
                    decode_frame.odata[ 7: 0] = idata[15: 8];
                    decode_frame.odata[15: 8] = RS_TERM;
                    decode_frame.octl = 8'hFE;
                end
                BT_T2: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h1F);
                    decode_frame.odata[15: 0] = idata[23: 8];
                    decode_frame.odata[23:16] = RS_TERM;
                    decode_frame.octl = 8'hFC;
                end
                BT_T3: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h0F);
                    decode_frame.odata[23: 0] = idata[31: 8];
                    decode_frame.odata[31:24] = RS_TERM;
                    decode_frame.octl = 8'hF8;
                end
                BT_T4: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h07);
                    decode_frame.odata[31: 0] = idata[39: 8];
                    decode_frame.odata[39:32] = RS_TERM;
                    decode_frame.octl = 8'hF0;
                end
                BT_T5: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h03);
                    decode_frame.odata[39: 0] = idata[47: 8];
                    decode_frame.odata[47:40] = RS_TERM;
                    decode_frame.octl = 8'hE0;
                end
                BT_T6: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'h01);
                    decode_frame.odata[47: 0] = idata[55: 8];
                    decode_frame.odata[55:48] = RS_TERM;
                    decode_frame.octl = 8'hC0;
                end
                BT_T7: begin
                    decode_frame.odata[55: 0] = idata[63: 8];
                    decode_frame.odata[63:56] = RS_TERM;
                    decode_frame.octl = 8'h80;
                end
                default: begin
                    decode_frame.octl = 8'hFF;
                    decode_frame.odata[63:0] = {8{RS_ERROR}};
                end
            endcase
        end

    endfunction


    
    xgmii_data_ctl decoded_frame;

    
    assign decoded_frame = decode_frame(i_rxd, i_rx_header);
    assign o_rxd = decoded_frame.odata;
    assign o_rxctl = decoded_frame.octl;
    


    // logic [63:0] internal_rxd;
    // logic [7:0] internal_rxctl;
    // 64 to 32bit
    // Init done must be active on rising edge of both clocks

    // logic output_low;
    // always @(posedge i_rxc) begin
    //     if(i_reset || !i_init_done) begin
    //         output_low <= '0;
    //     end else begin
    //         output_low <= !output_low;
    //     end
    // end

    // always_comb begin
    //     if(output_low) begin
    //         o_rxd = internal_rxd[31:0];
    //         o_rxctl = internal_rxctl[3:0];
    //     end else begin
    //         o_rxd = internal_rxd[63:32];
    //         o_rxctl = internal_rxctl[7:4];
    //     end
    // end
    
endmodule