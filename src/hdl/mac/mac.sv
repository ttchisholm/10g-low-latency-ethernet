

module mac (
    
    input wire i_reset,

    // Tx PHY
    input wire i_txc,
    output logic [63:0] o_txd,
    output logic [7:0] o_txctl,
    input wire i_tx_ready,

    // Tx User AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast,
    

    // Rx PHY
    input wire i_rxc,
    input wire [63:0] i_rxd,
    input wire [7:0] i_rxctl,
    input wire i_rx_valid,

    // Rx USER
    output logic [63:0] m00_axis_tdata,
    output logic [7:0] m00_axis_tkeep, // todo
    output logic m00_axis_tvalid,
    input wire m00_axis_tready,
    output logic m00_axis_tlast
);

    import encoder_pkg::*;
    

    localparam MIN_PAYLOAD_SIZE = 46;
    localparam IPG_SIZE = 12;

    // ************* RESET ************* //
    logic [1:0] rx_reset_sync, tx_reset_sync;
    wire rx_reset, tx_reset;

    always @(posedge i_rxc) begin
        rx_reset_sync <= {rx_reset_sync[0], i_reset};
    end
    assign rx_reset = rx_reset_sync[1];

    always @(posedge i_txc) begin
        tx_reset_sync <= {tx_reset_sync[0], i_reset};
    end
    assign tx_reset = tx_reset_sync[1];

    // *********** Tx Datapath *********** //
    // State flow:
    /*
    
        On first valid, send start/preamble/SFD, put data into crc calc
        Send data delayed after start/preamble/SFD
        On last, either pad if frame too small, or/then append crc
        If valid is low before tlast, cancel frame
        todo - tkeep
    */

    localparam START_FRAME = 64'hd5555555555555fb; // First octet of preamble is replaced by SFD (46.1.7.1.4)
    localparam IDLE_FRAME =  64'h0707070707070707;
    localparam ERROR_FRAME = 64'hfefefefefefefefe;

    typedef enum {IDLE, DATA, PADDING, TERM, IPG} tx_state_t;
    tx_state_t tx_state, tx_next_state;
    logic [$clog2(MIN_PAYLOAD_SIZE):0] data_counter; 
    logic min_packet_size_reached;
    logic [4:0] ipg_counter;
    logic [63:0] data_del;
    logic tlast_del, tvalid_del;
    wire [31:0] tx_crc;
    wire [63:0] term_data;
    wire [7:0] tx_crc_input_valid;
    wire  tx_crc_reset;
    wire [63:0] tx_crc_input;

    logic [7:0] tx_data_keep;
    logic [63:0] tx_term_data_0, tx_term_data_1;
    logic [7:0] tx_term_ctl_0, tx_term_ctl_1;
    logic [4:0] initial_ipg_count;
    

    always @(posedge i_txc)
    if (tx_reset) begin
        tx_state <= IDLE;
        data_counter <= '0;
        ipg_counter <= '0;
        data_del <= '0;
        min_packet_size_reached <= '0;
        tlast_del <= '0;
        tvalid_del <= '0;
    end else begin
        tx_state <= tx_next_state;
        data_counter <= (min_packet_size_reached) ? data_counter :
                        ((tx_next_state == DATA || tx_next_state == PADDING)) ? data_counter + 8 : '0;
        ipg_counter <= (tx_state == IPG) ? ipg_counter + 8 : initial_ipg_count;
        data_del <= s00_axis_tdata;
        tlast_del <= s00_axis_tlast;
        tvalid_del <= s00_axis_tvalid;

        if ((tx_next_state == DATA || tx_next_state == PADDING) && data_counter >= MIN_PAYLOAD_SIZE)
            min_packet_size_reached <= 1'b1;
        else 
            min_packet_size_reached <= 1'b0;
    end

    assign s00_axis_tready = i_tx_ready && !tlast_del && (tx_state == IDLE || tx_state == DATA);

    assign tx_crc_input_valid = tx_data_keep & {8{(tx_next_state == DATA || tx_next_state == PADDING) && i_tx_ready}};
    assign tx_crc_reset = tx_next_state == IDLE;
    assign tx_crc_input = tx_next_state == DATA ? s00_axis_tdata : '0;
    assign tx_data_keep = (tx_state == DATA && min_packet_size_reached) ? s00_axis_tkeep : '1; // todo non 8-octet padding

    always @(*) begin
        
        case (tx_state)
            IDLE: begin
                if (s00_axis_tvalid && i_tx_ready)
                    tx_next_state = DATA;
                else 
                    tx_next_state = IDLE;
                
                
                o_txd = (s00_axis_tvalid && i_tx_ready) ? START_FRAME : IDLE_FRAME;
                o_txctl = (s00_axis_tvalid && i_tx_ready) ? 8'b00000001 : '1;
            end
            DATA: begin
                if (!tvalid_del && i_tx_ready)
                    tx_next_state = IDLE;
                else if (tlast_del && !min_packet_size_reached)
                    tx_next_state = PADDING;
                else if (tlast_del)
                    tx_next_state = TERM;
                else
                    tx_next_state = DATA;
                    
                o_txd = (!tvalid_del && i_tx_ready) ? ERROR_FRAME : 
                        (tx_next_state == TERM)     ? tx_term_data_0 : data_del;
                o_txctl = (!tvalid_del && i_tx_ready) ? '1 : 
                          (tx_next_state == TERM)     ? tx_term_ctl_0 : '0;
            end
            PADDING: begin
                if (!min_packet_size_reached) 
                    tx_next_state = PADDING;
                else 
                    tx_next_state = TERM;
                
                o_txd = (tx_next_state == TERM) ? tx_term_data_0 : '0;
                o_txctl = (tx_next_state == TERM) ? tx_term_ctl_0 : '0;
            end
            TERM: begin
                tx_next_state = IPG;
                o_txd = tx_term_data_1;
                o_txctl = tx_term_ctl_1;
            end
            IPG: begin
                if (ipg_counter < IPG_SIZE)
                    tx_next_state = IPG;
                else
                    tx_next_state = IDLE;

                o_txd = IDLE_FRAME;
                o_txctl = '1;
            end

        endcase

    end

    // Construct the final two tx frames depending on number of bytes in last axis frame
    always @(*) begin
        case (tx_data_keep)
            8'b11111111: begin
                tx_term_data_0 = data_del;
                tx_term_data_1 = {{3{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24]};
                tx_term_ctl_0 = 8'b00000000;
                tx_term_ctl_1 = 8'b11110000;
                initial_ipg_count = 3;
            end
            8'b01111111: begin
                tx_term_data_0 = {tx_crc[31:24], data_del[55:0]};
                tx_term_data_1 = {{4{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16]};
                tx_term_ctl_0 = 8'b00000000;
                tx_term_ctl_1 = 8'b11111000;
                initial_ipg_count = 4;
            end
            8'b00111111: begin
                tx_term_data_0 = {tx_crc[23:16], tx_crc[31:24], data_del[47:0]};
                tx_term_data_1 = {{5{RS_IDLE}}, RS_TERM, tx_crc[7:0], tx_crc[15:8]};
                tx_term_ctl_0 = 8'b00000000;
                tx_term_ctl_1 = 8'b11111100;
                initial_ipg_count = 5;
            end
            8'b00011111: begin
                tx_term_data_0 = {tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[39:0]};
                tx_term_data_1 = {{6{RS_IDLE}}, RS_TERM, tx_crc[7:0]};
                tx_term_ctl_0 = 8'b00000000;
                tx_term_ctl_1 = 8'b11111110;
                initial_ipg_count = 6;
            end
            8'b00001111: begin
                tx_term_data_0 = {tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[31:0]};
                tx_term_data_1 = {{7{RS_IDLE}}, RS_TERM};
                tx_term_ctl_0 = 8'b00000000;
                tx_term_ctl_1 = 8'b11111111;
                initial_ipg_count = 7;
            end
            8'b00000111: begin
                tx_term_data_0 = {RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[23:0]};
                tx_term_data_1 = {{8{RS_IDLE}}};
                tx_term_ctl_0 = 8'b10000000;
                tx_term_ctl_1 = 8'b11111111;
                initial_ipg_count = 8;
            end
            8'b00000011: begin
                tx_term_data_0 = {RS_IDLE, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[15:0]};
                tx_term_data_1 = {{8{RS_IDLE}}};
                tx_term_ctl_0 = 8'b11000000;
                tx_term_ctl_1 = 8'b11111111;
                initial_ipg_count = 9;
            end
            8'b00000001: begin
                tx_term_data_0 = {RS_IDLE, RS_IDLE, RS_TERM, tx_crc[7:0], tx_crc[15:8], tx_crc[23:16], tx_crc[31:24], data_del[7:0]};
                tx_term_data_1 = {{8{RS_IDLE}}};
                tx_term_ctl_0 = 8'b11100000;
                tx_term_ctl_1 = 8'b11111111;
                initial_ipg_count = 10;
            end
            default: begin
                tx_term_data_0 = {8{RS_ERROR}};
                tx_term_data_1 = {8{RS_ERROR}};
                initial_ipg_count = 0;
            end
        endcase

    end

    crc32 #(.INPUT_WIDTH_BYTES(8)) u_tx_crc(
        
        .i_clk(i_rxc),
        .i_data(tx_crc_input),
        .i_valid(tx_crc_input_valid),
        .i_reset(tx_crc_reset),
        .o_crc(tx_crc)
    );

endmodule