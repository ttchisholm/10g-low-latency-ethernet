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
    input wire [DATA_NBYTES-1:0] term_loc,

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
    wire sfd_found;
    logic [DATA_NBYTES-1:0] start_keep;
    logic sfd_found_del;
    wire start_valid;

    // Term detect
    wire term_found;
    //wire [DATA_NBYTES-1:0] term_loc;
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
                m00_axis_tkeep = sfd_found_del ? start_keep :
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
    assign sfd_found = phy_rx_valid && (xgmii_rxd[7:0] == RS_START) && (xgmii_rxc[0] == 1'b1);

    always @(posedge i_clk) // Record sfd loc for next cycle output
    if (i_reset) begin
        sfd_found_del <= '0;
    end else begin
        sfd_found_del <= (phy_rx_valid) ? sfd_found : sfd_found_del; 
    end

    // Term detect - now done in PCS for better timing
    // genvar gi;
    // generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
    //     assign term_loc[gi] = phy_rx_valid && xgmii_rxd[gi*8 +: 8] == RS_TERM && xgmii_rxc[gi];
    // end endgenerate

    assign term_found = |term_loc;

    // Keep
    assign start_keep = 4'b0000;
    assign start_valid = 1'b0; // If data width is 32, start is all preamble

    genvar gi;
    generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
        assign term_keep[gi] = (1 << gi) < term_loc ? 1'b1 : 1'b0;
    end endgenerate

    // Masked data
    generate for (gi = 0; gi < DATA_NBYTES; gi++) begin
        assign masked_data[gi*8 +: 8] = m00_axis_tkeep[gi] ? xgmii_rxd[gi*8 +: 8] : 8'h00;
    end endgenerate

    // CRC

    always @(posedge i_clk)
    if (i_reset) begin
        rx_crc_input_del <= '0;
        rx_crc_input_valid_del <= '0;
    end else begin
        rx_crc_input_del <= phy_rx_valid ? m00_axis_tdata : rx_crc_input_del;
        rx_crc_input_valid_del <= phy_rx_valid ? m00_axis_tkeep : rx_crc_input_valid_del;
        
    end

    logic[DATA_NBYTES-1:0] crc_input_valid;
    always @(*) begin
        if (!phy_rx_valid) begin
            crc_input_valid = {DATA_NBYTES{1'b0}};
        end else if (!term_found) begin
            crc_input_valid = rx_crc_input_valid_del;
        end else begin
            // We need to stop the CRC itself from being input
            case (term_loc) 
                1: crc_input_valid = 4'b0000;
                2: crc_input_valid = 4'b0001;
                4: crc_input_valid = 4'b0011;
                8: crc_input_valid = 4'b0111;
                default: crc_input_valid = 4'b1111;
            endcase
        end

        case (term_loc) 
            1: rx_captured_crc = rx_crc_input_del;
            2: rx_captured_crc = {xgmii_rxd[0+:8], rx_crc_input_del[8+:24]};
            4: rx_captured_crc = {xgmii_rxd[0+:16], rx_crc_input_del[16+:16]};
            8: rx_captured_crc = {xgmii_rxd[0+:24], rx_crc_input_del[24+:8]};
            default: rx_captured_crc = xgmii_rxd;
        endcase
    end 

    assign rx_crc_reset = rx_state == IDLE;


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

endmodule