module mac (
    
    input wire i_reset,

    // Tx PHY
    input wire i_txc,
    output wire [63:0] o_txd,
    output wire [7:0] o_txctl,
    input wire i_tx_ready,

    // Tx User AXIS
    input wire [63:0] s00_axis_tdata,
    input wire [7:0] s00_axis_tkeep, // todo
    input wire s00_axis_tvalid,
    output wire s00_axis_tready,
    input wire s00_axis_tlast,
    

    // Rx PHY
    input wire i_rxc,
    input wire [63:0] i_rxd,
    input wire [7:0] i_rxctl,
    input wire i_rx_valid,

    // Rx USER
    input wire [63:0] s00_axis_tdata,
    input wire s00_axis_tvalid,
    output wire s00_axis_tready
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

    enum {IDLE, DATA, PADDING, TERM, IPG} tx_state, tx_next_state;
    logic [$clog2(MIN_PACKET_SIZE)-1:0] data_counter;
    logic [4:0] ipg_counter;
    logic [63:0] data_del;
    wire [31:0] rx_crc;
    

    always @(posedge i_txc)
    if (!tx_reset) begin
        tx_state <= IDLE;
        data_counter <= '0;
        ipg_counter <= '0;
        data_del <= '0;
    end else begin
        tx_state <= tx_next_state;
        data_counter <= (tx_state == DATA || tx_state == PADDING) ? data_counter + 8 : '0;
        ipg_counter <= (tx_state == IPG) ? ipg_counter + 8 : '0;
        data_del <= s00_axis_tdata;
    end

    assign s00_axis_tready = i_tx_ready && (tx_state == IDLE || tx_state == DATA);
    
    always_comb begin
        
        case (tx_state)
            IDLE: begin
                tx_next_state = (s00_axis_tvalid && i_tx_ready) ? DATA : IDLE;
                o_txd = (s00_axis_tvalid && i_tx_ready) ? START_FRAME : IDLE_FRAME;
                o_txctl = (s00_axis_tvalid && i_tx_ready) ? 8'b00000001 : '1;
            end
            DATA: begin
                tx_next_state = (!s00_axis_tvalid && i_tx_ready) ? IDLE :
                                (s00_axis_tlast && data_counter < MIN_PACKET_SIZE) ? PADDING :
                                (s00_axis_tlast) ? TERM : DATA;
                o_txd = (!s00_axis_tvalid && i_tx_ready) ? ERROR_FRAME : data_del;
                o_txctl = (!s00_axis_tvalid && i_tx_ready) ? '1 : '0;
            end
            PADDING: begin 
                tx_next_state = (data_counter < MIN_PACKET_SIZE) ? PADDING : TERM;
                o_txd = '0;
                o_txctl = '0;
            end
            TERM: begin
                tx_next_state = IPG;
                o_txd = {RS_IDLE, RS_IDLE, RS_IDLE, RS_TERM, rx_crc[0:+8], rx_crc[8:+8], rx_crc[16:+8], rx_crc[24:+8]};
                o_txctl = 8'b11110000;
            end
            IPG: begin
                tx_next_state = (ipg_counter < IPG_SIZE) ? IPG : IDLE;
                o_txd = IDLE_FRAME;
                o_txctl = '1;
            end

        endcase

    end



endmodule