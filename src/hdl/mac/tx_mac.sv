`default_nettype none

module tx_mac (
    
    input wire i_reset,
    input wire i_clk,

    // Tx PHY
    output logic [63:0] xgmii_txd,
    output logic [7:0] xgmii_txc,
    input wire phy_tx_ready,

    // Tx User AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast
);

    // Todo:
    //  - comment state
    //  - comment term
    //  - tidy

    // *********** Tx Datapath *********** //

    import encoder_pkg::*;

    localparam MIN_PAYLOAD_SIZE = 46;
    localparam IPG_SIZE = 12;

    localparam START_FRAME = {MAC_SFD, {6{MAC_PRE}}, RS_START}; // First octet of preamble is replaced by RS_START (46.1.7.1.4)
    localparam IDLE_FRAME =  {8{RS_IDLE}};
    localparam ERROR_FRAME = {8{RS_ERROR}};

    // Tx states
    typedef enum {IDLE, DATA, PADDING, TERM, IPG} tx_state_t;
    tx_state_t tx_state, tx_next_state;

    // Delayed inputs
    logic [63:0] data_del;
    logic tlast_del, tvalid_del;

    // CRC
    wire [31:0] tx_crc;
    wire [7:0] tx_crc_input_valid;
    wire  tx_crc_reset;
    wire [63:0] tx_crc_input;

    // Termination
    logic [7:0] tx_data_keep;
    logic [63:0] tx_term_data_0, tx_term_data_1;
    logic [7:0] tx_term_ctl_0, tx_term_ctl_1;

    // Min payload counter
    logic [$clog2(MIN_PAYLOAD_SIZE):0] data_counter; 
    logic min_packet_size_reached;

    // IPG counter
    logic [4:0] initial_ipg_count;
    logic [4:0] ipg_counter;

  

    always @(posedge i_clk)
    if (i_reset) begin
        tx_state <= IDLE;
        data_del <= '0;
        tlast_del <= '0;
        tvalid_del <= '0;
        data_counter <= '0;
        ipg_counter <= '0;
        min_packet_size_reached <= '0;
        
    end else begin
        tx_state <= tx_next_state;

        data_del <= s00_axis_tdata;
        tlast_del <= s00_axis_tlast;
        tvalid_del <= s00_axis_tvalid;

        data_counter <= (min_packet_size_reached) ? data_counter :
                        ((tx_next_state == DATA || tx_next_state == PADDING)) ? data_counter + 8 : '0;
        ipg_counter <= (tx_state == IPG) ? ipg_counter + 8 : initial_ipg_count;

        if ((tx_next_state == DATA || tx_next_state == PADDING) && data_counter >= MIN_PAYLOAD_SIZE)
            min_packet_size_reached <= 1'b1;
        else 
            min_packet_size_reached <= 1'b0;
    end

    assign s00_axis_tready = phy_tx_ready && !tlast_del && (tx_state == IDLE || tx_state == DATA);

    assign tx_crc_input_valid = tx_data_keep & {8{(tx_next_state == DATA || tx_next_state == PADDING) && phy_tx_ready}};
    assign tx_crc_reset = tx_next_state == IDLE;
    assign tx_crc_input = tx_next_state == DATA ? s00_axis_tdata : '0;

    assign tx_data_keep = (tx_state == DATA && min_packet_size_reached) ? s00_axis_tkeep : '1; // todo non 8-octet padding

    always @(*) begin
        case (tx_state)
            IDLE: begin
                if (s00_axis_tvalid && phy_tx_ready)
                    tx_next_state = DATA;
                else 
                    tx_next_state = IDLE;
                
                
                xgmii_txd = (s00_axis_tvalid && phy_tx_ready) ? START_FRAME : IDLE_FRAME;
                xgmii_txc = (s00_axis_tvalid && phy_tx_ready) ? 8'b00000001 : '1;
            end
            DATA: begin
                if (!tvalid_del && phy_tx_ready) // tvalid must be high throughout frame
                    tx_next_state = IDLE;
                else if (tlast_del && !min_packet_size_reached)
                    tx_next_state = PADDING;
                else if (tlast_del)
                    tx_next_state = TERM;
                else
                    tx_next_state = DATA;
                    
                xgmii_txd = (!tvalid_del && phy_tx_ready) ? ERROR_FRAME :               
                            (tx_next_state == TERM)       ? tx_term_data_0 : data_del;  
                xgmii_txc = (!tvalid_del && phy_tx_ready) ? '1 : 
                            (tx_next_state == TERM)       ? tx_term_ctl_0 : '0;
            end
            PADDING: begin
                if (!min_packet_size_reached) 
                    tx_next_state = PADDING;
                else 
                    tx_next_state = TERM;
                
                xgmii_txd = (tx_next_state == TERM) ? tx_term_data_0 : '0;
                xgmii_txc = (tx_next_state == TERM) ? tx_term_ctl_0 : '0;
            end
            TERM: begin
                tx_next_state = IPG;
                xgmii_txd = tx_term_data_1;
                xgmii_txc = tx_term_ctl_1;
            end
            IPG: begin
                if (ipg_counter < IPG_SIZE)
                    tx_next_state = IPG;
                else
                    tx_next_state = IDLE;

                xgmii_txd = IDLE_FRAME;
                xgmii_txc = '1;
            end

        endcase

    end

    // Construct the final two tx frames depending on number of bytes in last axis frame
    // first term frame is used without reg
    always @(*) begin
        case (tx_data_keep)
            8'b11111111: begin
                tx_term_data_0 = data_del;
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b01111111: begin
                tx_term_data_0 = {tx_crc[31:24], data_del[55:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00111111: begin
                tx_term_data_0 = {tx_crc[23:16], tx_crc[31:24], data_del[47:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00011111: begin
                tx_term_data_0 = {tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[39:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00001111: begin
                tx_term_data_0 = {tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[31:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00000111: begin
                tx_term_data_0 = {RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[23:0]};
                tx_term_ctl_0 = 8'b10000000;
            end
            8'b00000011: begin
                tx_term_data_0 = {RS_IDLE, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[15:0]};
                tx_term_ctl_0 = 8'b11000000;
            end
            8'b00000001: begin
                tx_term_data_0 = {RS_IDLE, RS_IDLE, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[7:0]};
                tx_term_ctl_0 = 8'b11100000;
            end
            default: begin
                tx_term_data_0 = {8{RS_ERROR}};
                tx_term_ctl_0 = 8'b11111111;
            end
        endcase
    end

    always @(posedge i_clk)
    if (i_reset) begin
        tx_term_data_1 <= '0;
        tx_term_ctl_1 <= '0;
        initial_ipg_count <= '0;
    end else if (tlast_del) begin
        case (tx_data_keep)
            8'b11111111: begin
                tx_term_data_1 <= {{3{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24]};
                tx_term_ctl_1 <= 8'b11110000;
                initial_ipg_count <= 3;
            end
            8'b01111111: begin
                tx_term_data_1 <= {{4{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16]};
                tx_term_ctl_1 <= 8'b11111000;
                initial_ipg_count <= 4;
            end
            8'b00111111: begin
                tx_term_data_1 <= {{5{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8]};
                tx_term_ctl_1 <= 8'b11111100;
                initial_ipg_count <= 5;
            end
            8'b00011111: begin
                tx_term_data_1 <= {{6{RS_IDLE}}, RS_TERM, tx_crc[7:0]};
                tx_term_ctl_1 <= 8'b11111110;
                initial_ipg_count <= 6;
            end
            8'b00001111: begin
                tx_term_data_1 <= {{7{RS_IDLE}}, RS_TERM};
                tx_term_ctl_1 <= 8'b11111111;
                initial_ipg_count <= 7;
            end
            8'b00000111: begin
                tx_term_data_1 <= {{8{RS_IDLE}}};
                tx_term_ctl_1 <= 8'b11111111;
                initial_ipg_count <= 8;
            end
            8'b00000011: begin
                tx_term_data_1 <= {{8{RS_IDLE}}};
                tx_term_ctl_1 <= 8'b11111111;
                initial_ipg_count <= 9;
            end
            8'b00000001: begin
                tx_term_data_1 <= {{8{RS_IDLE}}};
                tx_term_ctl_1 <= 8'b11111111;
                initial_ipg_count <= 10;
            end
            default: begin
                tx_term_data_1 <= {8{RS_ERROR}};
                tx_term_ctl_1 <= 8'b11111111;
                initial_ipg_count <= 0;
            end
        endcase
    end

    crc32 #(.INPUT_WIDTH_BYTES(8)) u_tx_crc(
        
        .i_clk(i_clk),
        .i_data(tx_crc_input),
        .i_valid(tx_crc_input_valid),
        .i_reset(tx_crc_reset),
        .o_crc(tx_crc)
    );

endmodule