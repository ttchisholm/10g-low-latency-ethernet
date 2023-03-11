`default_nettype none
`include "code_defs_pkg.svh"

module rx_mac #(
    localparam DATA_WIDTH = 32,

    localparam DATA_NBYTES = DATA_WIDTH / 8
) (
    
    input wire i_reset,
    input wire i_clk,

     // Rx PHY
    input wire [DATA_WIDTH-1:0] xgmii_rxd,
    input wire [DATA_NBYTES-1:0] xgmii_rxc,
    input wire phy_rx_valid,

    // Rx AXIS
    output logic [DATA_WIDTH-1:0] m00_axis_tdata,
    output logic [DATA_NBYTES-1:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser
);

    // *********** Rx Datapath *********** //

    import code_defs_pkg::*;


    // Rx states
    typedef enum {IDLE, PREAMBLE, DATA, TERM} rx_state_t;
    rx_state_t rx_state, rx_next_state;

    // Start detect
    wire sfd_found, sfd_found_0, sfd_found_4;
    logic [1:0] sfd_found_loc;
    logic [DATA_NBYTES-1:0] start_keep;
    logic sfd_found_del;
    wire start_valid;

    // Term detect
    wire term_found;
    wire [DATA_NBYTES-1:0] term_loc;
    wire [DATA_NBYTES-1:0] term_keep;

    // Masked data out
    wire [DATA_WIDTH-1:0] masked_data;

    // CRC
    logic [31:0] rx_calc_crc, rx_crc_del, term_crc, frame_crc, prev_frame_crc;
    logic [DATA_NBYTES-1:0] rx_crc_input_valid, rx_crc_input_valid_del;
    wire  rx_crc_reset;
    logic [DATA_WIDTH-1:0] rx_crc_input, rx_crc_input_del;
    logic [31:0] rx_captured_crc;



    // State
    always @(posedge i_clk)
    if (i_reset) begin
        rx_state <= IDLE;
    
    end else begin
        rx_state <= rx_next_state;
    end

    always @(*) begin

        m00_axis_tdata = xgmii_rxd;
        

        case (rx_state)
            IDLE: begin
                if (sfd_found)
                    rx_next_state = DATA;
                else
                    rx_next_state = IDLE;
                
                m00_axis_tvalid = '0;
                m00_axis_tlast = '0;
                m00_axis_tkeep = '0;
                m00_axis_tuser = '0;
            end
            DATA: begin
                if (term_found)
                    rx_next_state = IDLE;
                else
                    rx_next_state = DATA;
                
                m00_axis_tvalid = phy_rx_valid && (!sfd_found_del || (sfd_found_del && start_valid));
                m00_axis_tlast = term_found;
                m00_axis_tkeep = |sfd_found_loc ? start_keep :
                                  term_found    ? term_keep  :
                                                '1; 
                m00_axis_tuser = term_found && (rx_calc_crc == rx_captured_crc);
            end
            default: begin
                rx_next_state = IDLE;
                m00_axis_tvalid = '0;
                m00_axis_tlast = '0;
                m00_axis_tkeep = '0;
                m00_axis_tuser = '0;
            end

        endcase

    end

    // Start detect
    assign sfd_found_0 = phy_rx_valid && (xgmii_rxd[7:0] == RS_START) && (xgmii_rxc[0] == 1'b1);
    assign sfd_found_4 = DATA_WIDTH == 32 ? 1'b0 : phy_rx_valid && (xgmii_rxd[39:32] == RS_START) && (xgmii_rxc[4] == 1'b1);
    assign sfd_found = sfd_found_0 || sfd_found_4; 

    always @(posedge i_clk) // Record sfd loc for next cycle output
    if (i_reset) begin
        sfd_found_loc <= '0;
        sfd_found_del <= '0;
    end else begin
        sfd_found_loc <= {sfd_found_4, sfd_found_0};
        sfd_found_del <= sfd_found;
    end

    // Term detect
    genvar gi;
    generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
        assign term_loc[gi] = phy_rx_valid && xgmii_rxd[gi*8 +: 8] == RS_TERM && xgmii_rxc[gi];
    end endgenerate

    assign term_found = |term_loc;

    // Keep
    assign start_keep = DATA_WIDTH == 32 ? 4'b0000 :
                            sfd_found_loc[0] ? 8'b11111111 : 8'b11110000; // Keep for the first cycle of DATA
    assign start_valid = DATA_WIDTH == 32 ? 1'b0 : sfd_found_0; // If data width is 32, start is all preamble, else if 64, 
                                                                // only valid if start is found in first byte

    generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
        assign term_keep[gi] = (1 << gi) < term_loc ? 1'b1 : 1'b0;
    end endgenerate

    // Masked data
    generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
        assign masked_data[gi*8 +: 8] = m00_axis_tkeep[gi] ? xgmii_rxd[gi*8 +: 8] : 8'h00;
    end endgenerate

    // CRC

    // TODO - delay by 1 cycle!

    // todo doc:
    /*
        // three scenarios
        // term is with crc (easy)
        // term is first in next frame
        // crc is split across two frames

        // options:
            delay everything (bad)
            calc crc across xfers and flag with term

        // this approach is alternative to using length field - 
        //      this gives quicker result for crc but not if length is wrong
    // */

    always @(posedge i_clk)
    if (i_reset) begin
        rx_crc_input_del <= '0;
        rx_crc_input_valid_del <= '0;
        rx_captured_crc <= '0;
    end else begin
        rx_crc_input_del <= m00_axis_tdata;
        rx_crc_input_valid_del <= m00_axis_tkeep & {DATA_NBYTES{phy_rx_valid}};

        if (!term_found) begin
            
        end else begin
            
        end
    end

    logic[DATA_NBYTES-1:0] crc_input_valid;
    always @(*) begin
        if (!term_found) begin
            crc_input_valid = rx_crc_input_valid_del & {DATA_NBYTES{rx_state != IDLE}};
            rx_captured_crc = xgmii_rxd;
        end else begin
            // We need to stop the CRC itself from being input
            case (term_loc) 
                1: crc_input_valid = DATA_WIDTH == 32 ? 4'b0000 : 8'b00001111;
                2: crc_input_valid = DATA_WIDTH == 32 ? 4'b0001 : 8'b00011111;
                4: crc_input_valid = DATA_WIDTH == 32 ? 4'b0011 : 8'b00111111;
                8: crc_input_valid = DATA_WIDTH == 32 ? 4'b0111 : 8'b01111111;
                default: crc_input_valid = DATA_WIDTH == 32 ? 4'b1111 : 8'b11111111;
            endcase

            case (term_loc) 
                1: rx_captured_crc = rx_crc_input_del;
                2: rx_captured_crc = {xgmii_rxd[0+:8], rx_crc_input_del[8+:24]};
                4: rx_captured_crc = {xgmii_rxd[0+:16], rx_crc_input_del[16+:16]};
                8: rx_captured_crc = {xgmii_rxd[0+:24], rx_crc_input_del[24+:8]};
                default: rx_captured_crc = xgmii_rxd;
            endcase
        end
    end


    assign rx_crc_reset = rx_state == IDLE;
    

    //assign crc_input_valid = rx_crc_input_valid_del;// & {DATA_NBYTES{!term_found}};

    slicing_crc #(
        .SLICE_LENGTH(DATA_NBYTES),
        .INITIAL_CRC(32'hFFFFFFFF),
        .INVERT_OUTPUT(1),
        .REGISTER_OUTPUT(0)
    ) u_rx_crc (
        .clk(i_clk),
        .reset(rx_crc_reset),
        .data(rx_crc_input_del),
        .valid(crc_input_valid),
        .crc(rx_calc_crc)
    );

    // assign rx_crc_input = m00_axis_tdata;
    // //assign rx_crc_input_valid = m00_axis_tkeep; // todo this will include crc itself
    // assign rx_crc_reset = rx_state == IDLE;

    // logic [7:0] delayed_crc_input_valid;
    // always @(*) begin
    //     if (!term_found) begin
    //         frame_crc = xgmii_rxd[63:32]; // Assume term is first in next frame for now
    //         rx_crc_input_valid = m00_axis_tvalid ? (m00_axis_tkeep & {8{phy_rx_valid}}) : '0;
    //         delayed_crc_input_valid = rx_crc_input_valid_del & {8{phy_rx_valid}}; // This is required to pause the delay pipeline when data invalid
    //     end else begin
    //         delayed_crc_input_valid = rx_crc_input_valid_del & {8{phy_rx_valid}};
    //         rx_crc_input_valid = m00_axis_tvalid ? (m00_axis_tkeep & {8{phy_rx_valid}}) : '0;

    //         case (term_loc)
    //             8'b00000001: begin
    //                 frame_crc = prev_frame_crc;
    //                 delayed_crc_input_valid = 8'b00001111 & {8{phy_rx_valid}}; // This means the last 4 bytes of the previous frame were the crc
    //             end
    //             8'b00000010: begin
    //                 frame_crc = {xgmii_rxd[7:0], prev_frame_crc[31:8]};
    //                 delayed_crc_input_valid = 8'b00011111 & {8{phy_rx_valid}}; 
    //             end
    //             8'b00000100: begin
    //                 frame_crc = {xgmii_rxd[15:0], prev_frame_crc[31:16]};
    //                 delayed_crc_input_valid = 8'b00111111 & {8{phy_rx_valid}}; 
    //             end
    //             8'b00001000: begin
    //                 frame_crc = {xgmii_rxd[23:0], prev_frame_crc[31:24]};
    //                 delayed_crc_input_valid = 8'b01111111 & {8{phy_rx_valid}}; 
    //             end
    //             8'b00010000: begin
    //                 frame_crc = xgmii_rxd[31:0];
    //                 rx_crc_input_valid = m00_axis_tvalid ? 8'b00000000 : '0;
    //             end
    //             8'b00100000: begin
    //                 frame_crc = xgmii_rxd[39:8];
    //                 rx_crc_input_valid = m00_axis_tvalid ? 8'b00000001 : '0;
    //             end
    //             8'b01000000: begin
    //                 frame_crc = xgmii_rxd[47:16];
    //                 rx_crc_input_valid = m00_axis_tvalid ? 8'b00000011 : '0;
    //             end
    //             8'b10000000: begin
    //                 frame_crc = xgmii_rxd[55:24];
    //                 rx_crc_input_valid = m00_axis_tvalid ? 8'b00000111 : '0;
    //             end
    //             default: begin
    //                 frame_crc = '0;
    //                 rx_crc_input_valid = '0;
    //             end
    //         endcase


    //     end
    // end

    // // todo optimise out with xgmii_del
    // always @(posedge i_clk)
    // if (i_reset) begin
    //     prev_frame_crc <= '0;
    // end else if (phy_rx_valid) begin
    //     prev_frame_crc <= frame_crc;
    // end
    

    // slicing_crc #(
    //     .SLICE_LENGTH(8),
    //     .INITIAL_CRC(32'hFFFFFFFF),
    //     .INVERT_OUTPUT(1),
    //     .REGISTER_OUTPUT(0)
    // ) u_rx_crc (
    //     .clk(i_clk),
    //     .reset(rx_crc_reset),
    //     .data(rx_crc_input),
    //     .valid(rx_crc_input_valid),
    //     .crc(rx_crc)
    // );

    // always @(posedge i_clk)
    // if (i_reset) begin
    //     rx_crc_input_del <= '0;
    //     rx_crc_input_valid_del <= '0;
    // end else if (phy_rx_valid) begin
    //     rx_crc_input_del <= rx_crc_input;
    //     rx_crc_input_valid_del <= rx_crc_input_valid;
    // end

    

    // // todo fix crc checking options:
    // // - delay all by 1
    // // - use frame length to detect when crc
    // // - dual crc solution?
    // // - what is the actual crc latency and why?

    // //assign delayed_crc_input_valid = term_loc[0] ? 8'b00001111 : rx_crc_input_valid_del;

    // slicing_crc #(
    //     .SLICE_LENGTH(8),
    //     .INITIAL_CRC(32'hFFFFFFFF),
    //     .INVERT_OUTPUT(1),
    //     .REGISTER_OUTPUT(0)
    // ) u_rx_crc_del (
    //     .clk(i_clk),
    //     .reset(rx_crc_reset),
    //     .data(rx_crc_input_del),
    //     .valid(delayed_crc_input_valid),
    //     .crc(term_crc)
    // );

    // // Finally set tuser
    // wire [31:0] frame_crc_byteswapped;
    // assign frame_crc_byteswapped = {frame_crc[0+:8], frame_crc[8+:8], frame_crc[16+:8], frame_crc[24+:8]};
    // assign m00_axis_tuser = term_found && term_loc < 8'b00010000  ? term_crc == frame_crc :
    //                         term_found ? rx_crc == frame_crc : 1'b0;

    

endmodule