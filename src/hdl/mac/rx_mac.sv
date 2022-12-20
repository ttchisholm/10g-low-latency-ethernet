`default_nettype none

module rx_mac (
    
    input wire i_reset,
    input wire i_clk,

     // Rx PHY
    input wire [63:0] xgmii_rxd,
    input wire [7:0] xgmii_rxc,
    input wire phy_rx_valid,

    // Rx AXIS
    output logic [63:0] m00_axis_tdata,
    output logic [7:0] m00_axis_tkeep,
    output logic m00_axis_tvalid,
    output logic m00_axis_tlast,
    output logic m00_axis_tuser
);

    // *********** Rx Datapath *********** //

    import encoder_pkg::*;


    // Rx states
    typedef enum {IDLE, PREAMBLE, DATA, TERM} rx_state_t;
    rx_state_t rx_state, rx_next_state;

    // Start detect
    wire sfd_found, sfd_found_0, sfd_found_4;
    logic [1:0] sfd_found_loc;
    logic [7:0] start_keep;

    // Term detect
    wire term_found;
    wire [7:0] term_loc;
    wire [7:0] term_keep;

    // Masked data out
    wire [63:0] masked_data;

    // CRC
    logic [31:0] rx_crc, rx_crc_del, term_crc, frame_crc, prev_frame_crc;
    logic [7:0] rx_crc_input_valid, rx_crc_input_valid_del;
    wire  rx_crc_reset;
    logic [63:0] rx_crc_input, rx_crc_input_del;



    // State
    always @(posedge i_clk)
    if (i_reset) begin
        rx_state <= IDLE;
    
    end else begin
        rx_state <= rx_next_state;
    end

    always @(*) begin
        case (rx_state)
            IDLE: begin
                if (sfd_found)
                    rx_next_state = DATA;
                else
                    rx_next_state = IDLE;
                
                m00_axis_tdata = '0;
                m00_axis_tvalid = '0;
                m00_axis_tkeep = '0;
                m00_axis_tlast = '0;
            end
            DATA: begin
                if (term_found)
                    rx_next_state = IDLE;
                else
                    rx_next_state = DATA;
                
                m00_axis_tdata = masked_data;
                m00_axis_tvalid = phy_rx_valid;
                m00_axis_tkeep = |sfd_found_loc ? start_keep :
                                  term_found    ? term_keep  :
                                                8'b11111111; 
                m00_axis_tlast = term_found;
            end

        endcase

    end

    // Start detect
    assign sfd_found_0 = (xgmii_rxd[7:0] == RS_START) && (xgmii_rxc[0] == 1'b1);
    assign sfd_found_4 = (xgmii_rxd[39:32] == RS_START) && (xgmii_rxc[4] == 1'b1);
    assign sfd_found = sfd_found_0 || sfd_found_4; 

    always @(posedge i_clk) // Record sfd loc for next cycle output
    if (i_reset) begin
        sfd_found_loc <= '0;
    end else begin
        sfd_found_loc <= {sfd_found_4, sfd_found_0};
    end

    // Term detect
    genvar gi;
    generate for (gi = 0; gi < 8; gi++) begin
        assign term_loc[gi] = xgmii_rxd[gi*8 +: 8] == RS_TERM && xgmii_rxc[gi];
    end endgenerate

    assign term_found = |term_loc;

    // Keep
    assign start_keep = sfd_found_loc[0] ? 8'b11111111 : 8'b11110000; // Keep for the first cycle of DATA

    generate for (gi = 0; gi < 8; gi++) begin
        assign term_keep[gi] = (1 << gi) < term_loc ? 1'b1 : 1'b0;
    end endgenerate

    // Masked data
    generate for (gi = 0; gi < 8; gi++) begin
        assign masked_data[gi*8 +: 8] = m00_axis_tkeep[gi] ? xgmii_rxd[gi*8 +: 8] : 8'h00;
    end endgenerate

    // CRC

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
    */

    assign rx_crc_input = m00_axis_tdata;
    //assign rx_crc_input_valid = m00_axis_tkeep; // todo this will include crc itself
    assign rx_crc_reset = rx_state == IDLE;

    logic [7:0] delayed_crc_input_valid;
    always @(*) begin
        if (!term_found) begin
            frame_crc = xgmii_rxd[63:32]; // Assume term is first in next frame for now
            rx_crc_input_valid = m00_axis_tkeep & {8{phy_rx_valid}};
            delayed_crc_input_valid = rx_crc_input_valid_del;
        end else begin
            delayed_crc_input_valid = rx_crc_input_valid_del;
            rx_crc_input_valid = m00_axis_tkeep & {8{phy_rx_valid}};

            case (term_loc)
                8'b00000001: begin
                    frame_crc = prev_frame_crc;
                    delayed_crc_input_valid = 8'b00001111; // This means the last 4 bytes of the previous frame were the crc
                end
                8'b00000010: begin
                    frame_crc = {xgmii_rxd[7:0], prev_frame_crc[31:8]};
                    delayed_crc_input_valid = 8'b00011111; 
                end
                8'b00000100: begin
                    frame_crc = {xgmii_rxd[15:0], prev_frame_crc[31:16]};
                    delayed_crc_input_valid = 8'b00111111; 
                end
                8'b00001000: begin
                    frame_crc = {xgmii_rxd[23:0], prev_frame_crc[31:24]};
                    delayed_crc_input_valid = 8'b01111111; 
                end
                8'b00010000: begin
                    frame_crc = xgmii_rxd[31:0];
                    rx_crc_input_valid = 8'b00000000;
                end
                8'b00100000: begin
                    frame_crc = xgmii_rxd[39:8];
                    rx_crc_input_valid = 8'b00000001;
                end
                8'b01000000: begin
                    frame_crc = xgmii_rxd[47:16];
                    rx_crc_input_valid = 8'b00000011;
                end
                8'b10000000: begin
                    frame_crc = xgmii_rxd[55:24];
                    rx_crc_input_valid = 8'b00000111;
                end
            endcase


        end
    end

    // todo optimise out with xgmii_del
    always @(posedge i_clk)
    if (i_reset) begin
        prev_frame_crc <= '0;
    end else begin
        prev_frame_crc <= frame_crc;
    end
    

                       
    

    crc32 #(.INPUT_WIDTH_BYTES(8),
        .REGISTER_OUTPUT(0)) u_rx_crc(
        
        .i_clk(i_clk),
        .i_data(rx_crc_input),
        .i_valid(rx_crc_input_valid),
        .i_reset(rx_crc_reset),
        .o_crc(rx_crc)
    );

    always @(posedge i_clk)
    if (i_reset) begin
        rx_crc_input_del <= '0;
        rx_crc_input_valid_del <= '0;
    end else begin
        rx_crc_input_del <= rx_crc_input;
        rx_crc_input_valid_del <= rx_crc_input_valid;
    end

    

    // todo fix crc checking options:
    // - delay all by 1
    // - use frame length to detect when crc
    // - dual crc solution?
    // - what is the actual crc latency and why?

    //assign delayed_crc_input_valid = term_loc[0] ? 8'b00001111 : rx_crc_input_valid_del;

    crc32 #(
        .INPUT_WIDTH_BYTES(8),
        .REGISTER_OUTPUT(0)
    ) u_rx_crc_del(
        
        .i_clk(i_clk),
        .i_data(rx_crc_input_del),
        .i_valid(delayed_crc_input_valid),
        .i_reset(rx_crc_reset),
        .o_crc(term_crc)
    );

    // Finally set tuser
    wire [31:0] frame_crc_byteswapped;
    assign frame_crc_byteswapped = {frame_crc[0+:8], frame_crc[8+:8], frame_crc[16+:8], frame_crc[24+:8]};
    assign m00_axis_tuser = term_found && term_loc < 8'b00000100  ? term_crc == frame_crc :
                            term_found ? rx_crc == frame_crc : 1'b0;

    

endmodule