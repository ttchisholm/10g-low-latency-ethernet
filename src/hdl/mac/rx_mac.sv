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
    input wire m00_axis_tready,
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


    // // CRC
    // wire [31:0] rx_crc;
    // wire [7:0] rx_crc_input_valid;
    // wire  rx_crc_reset;
    // wire [63:0] rx_crc_input;


  

    always @(posedge i_clk)
    if (i_reset) begin
        rx_state <= IDLE;
    
    end else begin
        rx_state <= rx_next_state;
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
                m00_axis_tuser = '0;
            end
            DATA: begin
                if (term_found)
                    rx_next_state = IDLE;
                else
                    rx_next_state = DATA;
                
                m00_axis_tdata = masked_data;
                m00_axis_tvalid = 1'b1;
                m00_axis_tkeep = |sfd_found_loc ? start_keep :
                                  term_found    ? term_keep  :
                                                8'b11111111; 
                m00_axis_tlast = term_found;
                m00_axis_tuser = 1'b0; // todo crc
            end

        endcase

    end

    generate for (gi = 0; gi < 8; gi++) begin
        assign masked_data[gi*8 +: 8] = m00_axis_tkeep[gi] ? xgmii_rxd[gi*8 +: 8] : 8'h00;
    end endgenerate

    

    // crc32 #(.INPUT_WIDTH_BYTES(8)) u_tx_crc(
        
    //     .i_clk(i_clk),
    //     .i_data(tx_crc_input),
    //     .i_valid(tx_crc_input_valid),
    //     .i_reset(tx_crc_reset),
    //     .o_crc(tx_crc)
    // );

endmodule