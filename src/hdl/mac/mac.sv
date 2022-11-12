

module mac (
    
    input wire i_reset,

    // Tx PHY
    input wire i_txc,
    output logic [63:0] o_txd,
    output logic [7:0] o_txctl,
    input wire i_tx_ready,

    // Tx User AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep, // todo
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
    

    localparam MIN_PACKET_SIZE = 64;
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
    logic [$clog2(MIN_PACKET_SIZE):0] data_counter; 
    logic min_packet_size_reached;
    logic [4:0] ipg_counter;
    logic [63:0] data_del;
    wire [31:0] rx_crc;
    wire [63:0] term_data;
    wire [7:0] rx_crc_input_valid;
    wire  rx_crc_reset;
    

    always @(posedge i_txc)
    if (tx_reset) begin
        tx_state <= IDLE;
        data_counter <= '0;
        ipg_counter <= '0;
        data_del <= '0;
        min_packet_size_reached <= '0;
    end else begin
        tx_state <= tx_next_state;
        data_counter <= (min_packet_size_reached) ? data_counter :
                        ((tx_next_state == DATA || tx_next_state == PADDING)) ? data_counter + 8 : '0;
        ipg_counter <= (tx_state == IPG) ? ipg_counter + 8 : '0;
        data_del <= s00_axis_tdata;

        if ((tx_next_state == DATA || tx_next_state == PADDING) && data_counter >= 63)
            min_packet_size_reached <= 1'b1;
        else 
            min_packet_size_reached <= 1'b0;
    end

    assign s00_axis_tready = i_tx_ready && (tx_state == IDLE || tx_state == DATA);
    assign term_data = {RS_IDLE, RS_IDLE, RS_IDLE, RS_TERM, rx_crc[7:0], rx_crc[15:8], rx_crc[23:16], rx_crc[31:24]};
    assign rx_crc_input_valid = s00_axis_tkeep & {8{(tx_state == DATA || tx_state == PADDING) && i_tx_ready}};
    assign rx_crc_reset = tx_state == IDLE || tx_state == IPG;

    always_comb begin
        
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
                if (!s00_axis_tvalid && i_tx_ready)
                    tx_next_state = IDLE;
                else if (s00_axis_tlast && !min_packet_size_reached)
                    tx_next_state = PADDING;
                else if (s00_axis_tlast)
                    tx_next_state = TERM;
                else
                    tx_next_state = DATA;
                    
                // tx_next_state = (!s00_axis_tvalid && i_tx_ready) ? IDLE :
                //                 (s00_axis_tlast && data_counter < MIN_PACKET_SIZE) ? PADDING :
                //                 (s00_axis_tlast) ? TERM : DATA;
                o_txd = (!s00_axis_tvalid && i_tx_ready) ? ERROR_FRAME : data_del;
                o_txctl = (!s00_axis_tvalid && i_tx_ready) ? '1 : '0;
            end
            PADDING: begin 
                if (!min_packet_size_reached) 
                    tx_next_state = PADDING;
                else 
                    tx_next_state = TERM;
                // tx_next_state =  ? PADDING : TERM;
                o_txd = '0;
                o_txctl = '0;
            end
            TERM: begin
                tx_next_state = IPG;
                o_txd = term_data;
                o_txctl = 8'b11110000;
            end
            IPG: begin
                if (ipg_counter < IPG_SIZE)
                    tx_next_state = IPG;
                else
                    tx_next_state = IDLE;
                // tx_next_state = (ipg_counter < IPG_SIZE) ? IPG : IDLE;
                o_txd = IDLE_FRAME;
                o_txctl = '1;
            end

        endcase

    end

    crc32 #(.INPUT_WIDTH_BYTES(8)) u_rx_crc(
        
        .i_clk(i_rxc),
        .i_data(o_txd),
        .i_valid(rx_crc_input_valid),
        .i_reset(rx_crc_reset),
        .o_crc(rx_crc)
    );

endmodule