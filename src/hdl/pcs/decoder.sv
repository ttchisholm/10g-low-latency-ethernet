`timescale 1ns/1ps
`include "code_defs_pkg.svh"
`default_nettype none

module decoder #(
    localparam DATA_WIDTH = 32,

    localparam DATA_NBYTES = DATA_WIDTH / 8
) (

    input wire i_reset,
    input wire i_rxc,
    input wire [DATA_WIDTH-1:0] i_rxd,
    input wire [1:0] i_rx_header,
    input wire i_rx_data_valid,
    input wire i_rx_header_valid,

    //Rx interface out
    output wire [DATA_WIDTH-1:0] o_rxd,
    output wire [DATA_NBYTES-1:0] o_rxctl
);

    import code_defs_pkg::*;

   
    typedef struct packed {
        logic [63:0] odata; 
        logic [7:0] octl;
        logic frame_valid;
   } xgmii_data_ctl_t;

    /**** 32-bit input to 64 bit internal ****/
    // Input declarations
    logic [DATA_WIDTH-1:0] delayed_i_rxd;
    wire [63:0] internal_irxd;

    // Output declarations
    xgmii_data_ctl_t decoded_frame;
    wire output_decode_frame;

    // verilator lint_off UNUSED
    // While lower word unused, useful for debugging
    logic [63:0] internal_orxd;
    logic [7:0] internal_orxctl;
    wire frame_valid;
    // verilator lint_on UNUSED

    // I/O delays for width conversion
    always @(posedge i_rxc) begin
        if(i_reset) begin
            delayed_i_rxd <= '0;
            internal_orxd <= '0;
            internal_orxctl <= '0;
        end else begin
            if(i_rx_data_valid) begin
                delayed_i_rxd <= i_rxd;
                if (output_decode_frame) begin // Header is invalid on second part of frame
                    internal_orxd <= decoded_frame.odata; 
                    internal_orxctl <= decoded_frame.octl;
                end
            end
        end
    end

    // Internal assignments
    assign internal_irxd = {i_rxd, delayed_i_rxd};
    assign output_decode_frame = !i_rx_header_valid  && i_rx_data_valid; // When header invalid - we have second word
    assign frame_valid = decoded_frame.frame_valid;

    // Output assignments
    assign o_rxd = !output_decode_frame ? internal_orxd[32 +: 32] : decoded_frame.odata[0 +: 32];
    assign o_rxctl = !output_decode_frame ? internal_orxctl[4 +: 4] : decoded_frame.octl[0 +: 4];
    
    /**** Decoder functions ****/
    /*
    * Function `control_code_to_rs_lane`
    *
    * A 64b66b control frame can contain up to 8 7-bit control codes and the 8-bit block type.
    *   This function converts the 64b66b control codes into XGMII RS Codes and places into XGMII
    *   frame. The location of the 64b66b control codes are determined by the bits set in the 'lanes' 
    *   input.
    */
    function logic [63:0] control_code_to_rs_lane(input logic [63:0] idata, input bit [7:0] lanes);
        control_code_to_rs_lane = {8{RS_ERROR}};
        for( int i = 0; i < 8; i++) begin
            if (lanes[7-i] == 1) begin
                control_code_to_rs_lane[8*i +: 8] = control_to_rs_code(idata[8 + (7*i) +: 7]);
            end
        end
    endfunction

    /*
    * Function `decode_frame`
    *
    * Decodes 64b66b 64-bit input data and 2-bit header into XGMII 64-bit data and 8-bit control 
    */
    function xgmii_data_ctl_t decode_frame(input logic [63:0] idata, input logic [1:0] iheader);

        decode_frame.odata = '0;
        decode_frame.octl = '0;
        decode_frame.frame_valid = 1;

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
                    decode_frame.octl = 8'h1F;
                end
                BT_S4: begin
                    decode_frame.odata = control_code_to_rs_lane(idata, 8'hF0);
                    decode_frame.odata[63:40] = idata[63:40];
                    decode_frame.odata[39:32] = RS_START;
                    decode_frame.octl = 8'h1F;
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
                    decode_frame.frame_valid = 0;
                end
            endcase
        end

    endfunction

    assign decoded_frame = decode_frame(internal_irxd, i_rx_header);
    
endmodule
