`include "code_defs_pkg.svh"

module decode_6466b #(
    localparam DATA_WIDTH = 64,

    localparam DATA_NBYTES = DATA_WIDTH / 8
) (

    input wire i_reset,
    input wire i_init_done,   // Rx interface from pcs
    input wire i_rxc,
    input wire [DATA_WIDTH-1:0] i_rxd,
    input wire [1:0] i_rx_header,
    input wire i_rx_valid,

    //Rx interface out
    output wire [DATA_WIDTH-1:0] o_rxd,
    output wire [DATA_NBYTES-1:0] o_rxctl
);

    import code_defs_pkg::*;

   
    typedef struct packed {
        logic [63:0] odata; 
        logic [7:0] octl;
        logic frame_valid;
   } xgmii_data_ctl; // Todo better name

   //32-bit input to 64 bit internal

    wire [63:0] internal_rxd;
    xgmii_data_ctl decoded_frame;


    logic [31:0] delayed_i_rxd;
    logic [63:0] delayed_int_orxd;
    logic [7:0] delayed_int_rxctl;
    logic tick; // Todo get from lock_state?
    logic last_tick_frame_valid;
    wire frame_valid;

    assign frame_valid = decoded_frame.frame_valid;

    always @(posedge i_rxc) begin
        if(i_reset) begin
            delayed_i_rxd <= '0;
            delayed_int_orxd <= '0;
            delayed_int_rxctl <= '0;
            tick <= '0;
            last_tick_frame_valid <= '0;
        end else begin
            if(i_rx_valid) begin
                delayed_i_rxd <= i_rxd;
                last_tick_frame_valid <= decoded_frame.frame_valid;
                
                // Detect whether we're out by one tick (i.e constructing 64-bit block incorrectly)
                if (!decoded_frame.frame_valid && last_tick_frame_valid) begin
                    tick <= decoded_frame.frame_valid; // Slip the tick
                end else begin
                    tick <= ~tick;
                end

                if (!tick) begin
                    delayed_int_orxd <= decoded_frame.odata;
                    delayed_int_rxctl <= decoded_frame.octl;
                end


            end
        end
    end

    assign internal_rxd = {i_rxd, delayed_i_rxd};

    assign o_rxctl = tick ? delayed_int_rxctl[4 +: 4] : decoded_frame.octl[0 +: 4];
    assign o_rxd = tick ? delayed_int_orxd[32 +: 32] : decoded_frame.odata[0 +: 32];




    // todo properly define parameters (esp. lanes ordering)
    function logic [63:0] control_code_to_rs_lane(input logic [63:0] idata, input bit [7:0] lanes);
        logic [63:0] odata;
        odata = {8{RS_ERROR}};
        for( int i = 0; i < 8; i++) begin
            if (lanes[7-i] == 1) begin
                odata[8*i +: 8] = control_to_rs_code(idata[8 + (7*i) +: 7]); // todo check part-select
            end
        end
        return odata;
    endfunction


    function xgmii_data_ctl decode_frame(input logic [63:0] idata, input logic [1:0] iheader);

        logic [63:0] decode_odata;
        logic [7:0] decode_octl;

        decode_frame.odata = '0;
        decode_frame.octl = '0;
        decode_frame.frame_valid = 1;

        if (iheader == SYNC_DATA) begin
            decode_odata = idata;
            decode_octl = '0;
        end else begin
            case (idata[7:0])
                
                BT_IDLE: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'hFF);
                    decode_octl = '1;
                end
                BT_O4: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'hF0);
                    decode_odata[63:40] = idata[63:40];
                    decode_odata[39:32] = cc_to_rs_ocode(idata[39:36]);
                    decode_octl = 8'h1F;
                end
                BT_S4: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'hF0);
                    decode_odata[63:40] = idata[63:40];
                    decode_odata[39:32] = RS_START;
                    decode_octl = 8'h1F;
                end
                BT_O0S4: begin
                    decode_odata[63:40] = idata[63:40];
                    decode_odata[39:32] = RS_START;
                    decode_odata[31: 8] = idata[31: 8];
                    decode_odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    decode_octl = 8'h11;
                end
                BT_O0O4: begin
                    decode_odata[63:40] = idata[63:40];
                    decode_odata[39:32] = cc_to_rs_ocode(idata[35:32]);
                    decode_odata[31: 8] = idata[31: 8];
                    decode_odata[ 7: 0] = cc_to_rs_ocode(idata[39:36]);
                    decode_octl = 8'h11;
                end
                BT_S0: begin
                    decode_odata[63: 8] = idata[63: 8];
                    decode_odata[ 7: 0] = RS_START;
                    decode_octl = 8'h01;
                end
                BT_O0: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h0F);
                    decode_odata[31: 8] = idata[31: 8];
                    decode_odata[ 7: 0] = cc_to_rs_ocode(idata[35:32]);
                    decode_octl = 8'hF1;
                end
                BT_T0: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h7F);
                    decode_odata[ 7: 0] = RS_TERM;
                    decode_octl = 8'hFF;
                end
                BT_T1: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h3F);
                    decode_odata[ 7: 0] = idata[15: 8];
                    decode_odata[15: 8] = RS_TERM;
                    decode_octl = 8'hFE;
                end
                BT_T2: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h1F);
                    decode_odata[15: 0] = idata[23: 8];
                    decode_odata[23:16] = RS_TERM;
                    decode_octl = 8'hFC;
                end
                BT_T3: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h0F);
                    decode_odata[23: 0] = idata[31: 8];
                    decode_odata[31:24] = RS_TERM;
                    decode_octl = 8'hF8;
                end
                BT_T4: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h07);
                    decode_odata[31: 0] = idata[39: 8];
                    decode_odata[39:32] = RS_TERM;
                    decode_octl = 8'hF0;
                end
                BT_T5: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h03);
                    decode_odata[39: 0] = idata[47: 8];
                    decode_odata[47:40] = RS_TERM;
                    decode_octl = 8'hE0;
                end
                BT_T6: begin
                    decode_odata = control_code_to_rs_lane(idata, 8'h01);
                    decode_odata[47: 0] = idata[55: 8];
                    decode_odata[55:48] = RS_TERM;
                    decode_octl = 8'hC0;
                end
                BT_T7: begin
                    decode_odata[55: 0] = idata[63: 8];
                    decode_odata[63:56] = RS_TERM;
                    decode_octl = 8'h80;
                end
                default: begin
                    decode_octl = 8'hFF;
                    decode_odata[63:0] = {8{RS_ERROR}};
                    decode_frame.frame_valid = 0;
                end
            endcase
        end

        decode_frame.odata = decode_odata;
        decode_frame.octl = decode_octl;

    endfunction

    assign decoded_frame = decode_frame(internal_rxd, i_rx_header);
    
endmodule