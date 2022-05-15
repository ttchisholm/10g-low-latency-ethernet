import encoder_pkg::*;

module decode_6466b #() (

    input wire i_reset,
    input wire i_init_done,   // Rx interface from pcs
    input wire i_rxc,
    input wire i_rxc2, //rxc/2
    input wire [63:0] i_rxd,
    input wire [1:0] i_rx_header,
    input wire i_rx_valid,

    //Rx interface out
    output logic [31:0] o_rxd,
    output logic [3:0] o_rxctl,
    output logic o_rx_valid
);


    function void control_code_to_rs_lane(input logic [63:0] idata, input int lanes[8], output logic [63:0] odata);
        odata = {8{RS_ERROR}};
        for( int i = 0; i < 8; i++) begin
            if (lanes[i] == 1) begin
                odata[8*i +: 8] = control_to_rs_code(idata[8 + (7*i) +: 7]); // todo check part-select
            end
        end
    endfunction;


    function void decode_frame(input logic [63:0] idata, input logic [1:0] iheader,
                          output logic [63:0] odata, output logic [7:0] octl);

        // If data header, pass through

        // Else
        /*
        switch on block type, assign data, ctl as appropriate
        */
        odata = '0;
        octl = '0;

        if (iheader == SYNC_DATA) begin
            odata = idata;
            octl = '0;
        end else begin
            case (idata[7:0])
                
                BT_IDLE: begin
                    control_code_to_rs_lane(idata, '{1,1,1,1,1,1,1,1}, odata);
                    octl = '1;
                end
                BT_O4: begin
                    control_code_to_rs_lane(idata, '{1,1,1,1,0,0,0,0}, odata);
                    odata[63:40] = idata[63:40];
                    odata[39:32] = cc_to_rs_ocode(idata[39:36]);
                    octl = 8'h0F;
                end
                BT_S4: begin
                    control_code_to_rs_lane(idata, '{1,1,1,1,0,0,0,0}, odata);
                    odata[63:40] = idata[63:40];
                    odata[39:32] = RS_START;
                    octl = 8'h0F;
                end
                BT_O0S4: begin
                    odata[63:40] = idata[63:40];
                    odata[39:32] = RS_START;
                    odata[31: 8] = idata[31: 8];
                    odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    octl = 8'h11;
                end
                BT_O0O4: begin
                    odata[63:40] = idata[63:40];
                    odata[39:32] = cc_to_rs_ocode(idata[35:32]);
                    odata[31: 8] = idata[31: 8];
                    odata[ 7: 0] = cc_to_rs_ocode(idata[39:36]);
                    octl = 8'h11;
                end
                BT_S0: begin
                    odata[63: 8] = idata[63: 8];
                    odata[ 7: 0] = RS_START;
                    octl = 8'h01;
                end
                BT_O0: begin
                    control_code_to_rs_lane(idata, '{0,0,0,0,1,1,1,1}, odata);
                    odata[31: 8] = idata[31: 8];
                    odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    octl = 8'hF1;
                end
                BT_T0: begin
                    control_code_to_rs_lane(idata, '{0,1,1,1,1,1,1,1}, odata);
                    odata[ 7: 0] = RS_TERM;
                    octl = 8'hFF;
                end
                BT_T1: begin
                    control_code_to_rs_lane(idata, '{0,0,1,1,1,1,1,1}, odata);
                    odata[ 7: 0] = idata[15: 8];
                    odata[15: 8] = RS_TERM;
                    octl = 8'hFE;
                end
                BT_T2: begin
                    control_code_to_rs_lane(idata, '{0,0,0,1,1,1,1,1}, odata);
                    odata[15: 0] = idata[23: 8];
                    odata[23:16] = RS_TERM;
                    octl = 8'hFC;
                end
                BT_T3: begin
                    control_code_to_rs_lane(idata, '{0,0,0,0,1,1,1,1}, odata);
                    odata[23: 0] = idata[31: 8];
                    odata[31:24] = RS_TERM;
                    octl = 8'hF8;
                end
                BT_T4: begin
                    control_code_to_rs_lane(idata, '{0,0,0,0,0,1,1,1}, odata);
                    odata[31: 0] = idata[39: 8];
                    odata[39:32] = RS_TERM;
                    octl = 8'hF0;
                end
                BT_T5: begin
                    control_code_to_rs_lane(idata, '{0,0,0,0,0,0,1,1}, odata);
                    odata[39: 0] = idata[47: 8];
                    odata[47:40] = RS_TERM;
                    octl = 8'hE0;
                end
                BT_T6: begin
                    control_code_to_rs_lane(idata, '{0,0,0,0,0,0,0,1}, odata);
                    odata[47: 0] = idata[55: 8];
                    odata[55:48] = RS_TERM;
                    octl = 8'hC0;
                end
                BT_T7: begin
                    odata[55: 0] = idata[63: 8];
                    odata[63:56] = RS_TERM;
                    octl = 8'h80;
                end
                default: begin
                    octl = 8'hFF;
                    odata[63:0] = {8{RS_ERROR}};
                end
            endcase
        end

    endfunction


    logic [63:0] internal_rxd;
    logic [7:0] internal_rxctl;

    always_comb begin
        decode_frame(i_rxd, i_rx_header, internal_rxd, internal_rxctl);
    end


    // 64 to 32bit
    // Init done must be active on rising edge of both clocks

    logic output_low;
    always @(posedge i_rxc) begin
        if(i_reset || !i_init_done) begin
            output_low <= '0;
        end else begin
            output_low <= !output_low;
        end
    end

    always_comb begin
        if(output_low) begin
            o_rxd = internal_rxd[31:0];
            o_rxctl = internal_rxctl[3:0];
        end else begin
            o_rxd = internal_rxd[63:32];
            o_rxctl = internal_rxctl[7:4];
        end
    end
    
    endmodule