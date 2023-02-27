`default_nettype none
`include "code_defs_pkg.svh"

module tx_mac #(
    parameter DATA_WIDTH = 32,

    localparam DATA_NBYTES = DATA_WIDTH / 8
) (
    
    input wire i_reset,
    input wire i_clk,

    // Tx PHY
    output logic [DATA_WIDTH-1:0] xgmii_txd,
    output logic [DATA_NBYTES-1:0] xgmii_txc,
    input wire phy_tx_ready,

    // Tx User AXIS
    input wire [DATA_WIDTH-1:0] s00_axis_tdata,
    input wire [DATA_NBYTES-1:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast
);

    // Todo:
    //  - comment state
    //  - comment term
    //  - tidy

    // *********** Tx Datapath *********** //
    
    import code_defs_pkg::*;

    localparam MIN_PAYLOAD_SIZE = 46;
    localparam MAX_PAYLOAD_SIZE = 1500; //todo not true
    localparam IPG_SIZE = 12;

    localparam START_FRAME_64 = {MAC_SFD, {6{MAC_PRE}}, RS_START}; // First octet of preamble is replaced by RS_START (46.1.7.1.4)
    localparam START_CTL_64 = 8'b00000001;
    localparam IDLE_FRAME_64 =  {8{RS_IDLE}};
    localparam ERROR_FRAME_64 = {8{RS_ERROR}};

    // Tx states
    typedef enum {IDLE, DATA, PADDING, TERM, IPG} tx_state_t;
    tx_state_t tx_state, tx_next_state;

    // Delayed inputs

   

    // Define how many cycles to buffer input for (to allow for time to send preamble)
    localparam INPUT_PIPELINE_LENGTH = DATA_WIDTH == 64 ? 1 : 2; // Todo should be a way to save a cycle here
    localparam PIPE_END = INPUT_PIPELINE_LENGTH-1;
    localparam START_FRAME_END = DATA_WIDTH == 64 ? 0 : 1;

    // Ideally the struct would be the array - iverilog doesn't seem to support it
     typedef struct packed {
        logic [INPUT_PIPELINE_LENGTH-1:0] [DATA_WIDTH-1:0]  tdata ;
        logic  [INPUT_PIPELINE_LENGTH-1:0] tlast ;
        logic  [INPUT_PIPELINE_LENGTH-1:0] tvalid ;
        logic [INPUT_PIPELINE_LENGTH-1:0] [DATA_NBYTES-1:0] tkeep ;
    } input_pipeline_t ;

    input_pipeline_t input_del; 
    // logic [DATA_WIDTH-1:0] data_del [2];
    // logic tlast_del, tvalid_del;

    // CRC
    wire [31:0] tx_crc, tx_crc_byteswapped;
    wire [DATA_NBYTES-1:0] tx_crc_input_valid;
    wire  tx_crc_reset;
    wire [DATA_WIDTH-1:0] tx_crc_input;

    // Termination
    logic [7:0] tx_data_keep;
    logic [63:0] tx_term_data_0, tx_term_data_1;
    logic [7:0] tx_term_ctl_0, tx_term_ctl_1;

    // Min payload counter
    logic [$clog2(MIN_PAYLOAD_SIZE):0] data_counter, next_data_counter; // Extra bit for overflow
    logic min_packet_size_reached;

    // IPG counter
    logic [4:0] initial_ipg_count;
    logic [4:0] ipg_counter;

    // Start frame counter
    logic start_frame_count;

    genvar gi;
    generate for (gi = 0; gi < INPUT_PIPELINE_LENGTH; gi++) begin

        always @(posedge i_clk)
        if (i_reset) begin
            input_del.tdata[gi] <= {DATA_WIDTH{1'b0}};
            input_del.tlast[gi] <= 1'b0;
            input_del.tvalid[gi] <= 1'b0;
            input_del.tkeep[gi] <= {DATA_NBYTES{1'b0}};
        end else begin

            if (gi == 0) begin
                if (phy_tx_ready) begin
                    input_del.tdata[gi] <= (tx_next_state == PADDING) ? {DATA_WIDTH{1'b0}} : s00_axis_tdata;
                    input_del.tlast[gi] <= s00_axis_tlast;
                    input_del.tvalid[gi] <= s00_axis_tvalid;
                    input_del.tkeep[gi] <= tx_data_keep;
                end
            end else begin
                input_del.tdata[gi] <= input_del.tdata[gi-1];
                input_del.tlast[gi] <= input_del.tlast[gi-1];
                input_del.tvalid[gi] <= input_del.tvalid[gi-1];
                input_del.tkeep[gi] <= input_del.tkeep[gi-1];
            end
        end

    end endgenerate


    always @(posedge i_clk)
    if (i_reset) begin
        tx_state <= IDLE;
        data_counter <= '0;
        ipg_counter <= '0;
        start_frame_count <= '0;
        
    end else begin
        tx_state <= tx_next_state;        
        data_counter <= next_data_counter; 
        ipg_counter <= (tx_state == IPG) ? ipg_counter + DATA_NBYTES : initial_ipg_count;
        start_frame_count <= (tx_state == IDLE && s00_axis_tvalid) ? start_frame_count + 1 : 0;
        
    end

    assign s00_axis_tready = phy_tx_ready && !input_del.tlast[PIPE_END] && (tx_state == IDLE || tx_state == DATA);

    assign tx_crc_input_valid = tx_data_keep & {8{(tx_next_state == DATA || tx_next_state == PADDING) && phy_tx_ready}};
    assign tx_crc_reset = tx_next_state == IDLE;
    assign tx_crc_input = tx_next_state == DATA ? s00_axis_tdata : '0;

    assign tx_data_keep = (tx_state == DATA && min_packet_size_reached) ? s00_axis_tkeep : '1; // todo non 8-octet padding

    always @(*) begin

        if (!phy_tx_ready) begin
            tx_next_state = tx_state;
            xgmii_txd = ERROR_FRAME_64[0 +: DATA_WIDTH];
            xgmii_txc = '1;
            next_data_counter = data_counter;
        end else begin
            case (tx_state)
                IDLE: begin
                    if (s00_axis_tvalid && start_frame_count == START_FRAME_END)
                        tx_next_state = DATA;
                    else 
                        tx_next_state = IDLE;
                    
                    
                    xgmii_txd = (s00_axis_tvalid) ? START_FRAME_64[start_frame_count*DATA_WIDTH +: DATA_WIDTH] : IDLE_FRAME_64[0 +: DATA_WIDTH];
                    xgmii_txc = (s00_axis_tvalid) ? START_CTL_64[start_frame_count*DATA_NBYTES +: DATA_NBYTES] : '1;
                    next_data_counter = 0;
                end
                DATA: begin
                    if (!input_del.tvalid[PIPE_END]) // tvalid must be high throughout frame
                        tx_next_state = IDLE;
                    else if (input_del.tlast[PIPE_END] && !min_packet_size_reached)
                        tx_next_state = PADDING;
                    else if (input_del.tlast[PIPE_END])
                        tx_next_state = TERM;
                    else
                        tx_next_state = DATA;
                        
                    xgmii_txd = (!input_del.tvalid[PIPE_END]) ? ERROR_FRAME_64[0 +: DATA_WIDTH] :               
                                (tx_next_state == TERM)       ? tx_term_data_0 : input_del.tdata[PIPE_END];  
                    xgmii_txc = (!input_del.tvalid[PIPE_END]) ? '1 : 
                                (tx_next_state == TERM)       ? tx_term_ctl_0 : '0;

                    // todo use keep rather than assume all bytes are valid
                    // stop counting when min size reached
                    next_data_counter = (data_counter[$clog2(MIN_PAYLOAD_SIZE)]) ? data_counter : data_counter + DATA_NBYTES; 
                end
                PADDING: begin
                    if (!min_packet_size_reached) 
                        tx_next_state = PADDING;
                    else 
                        tx_next_state = TERM;
                    
                    xgmii_txd = (tx_next_state == TERM) ? tx_term_data_0 : '0;
                    xgmii_txc = (tx_next_state == TERM) ? tx_term_ctl_0 : '0;

                    next_data_counter = data_counter + 8;
                end
                TERM: begin
                    tx_next_state = IPG;
                    xgmii_txd = tx_term_data_1;
                    xgmii_txc = tx_term_ctl_1;
                    next_data_counter = 0;
                end
                IPG: begin
                    if (ipg_counter < IPG_SIZE)
                        tx_next_state = IPG;
                    else
                        tx_next_state = IDLE;

                    xgmii_txd = IDLE_FRAME_64;
                    xgmii_txc = '1;
                    next_data_counter = 0;
                end
                default: begin
                    tx_next_state = IDLE;
                    xgmii_txd = ERROR_FRAME_64;
                    xgmii_txc = '1;
                    next_data_counter = 0;
                end

            endcase
        end

        

    end

    assign min_packet_size_reached = next_data_counter >= MIN_PAYLOAD_SIZE;

    // Construct the final two tx frames depending on number of bytes in last axis frame
    // first term frame is used without reg
    always @(*) begin
        case (input_del.tkeep[PIPE_END])
            8'b11111111: begin
                tx_term_data_0 = input_del.tdata[PIPE_END];
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b01111111: begin
                tx_term_data_0 = {tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][55:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00111111: begin
                tx_term_data_0 = {tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][47:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00011111: begin
                tx_term_data_0 = {tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][39:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00001111: begin
                tx_term_data_0 = {tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][31:0]};
                tx_term_ctl_0 = 8'b00000000;
            end
            8'b00000111: begin
                tx_term_data_0 = {RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][23:0]};
                tx_term_ctl_0 = 8'b10000000;
            end
            8'b00000011: begin
                tx_term_data_0 = {RS_IDLE, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][15:0]};
                tx_term_ctl_0 = 8'b11000000;
            end
            8'b00000001: begin
                tx_term_data_0 = {RS_IDLE, RS_IDLE, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], input_del.tdata[PIPE_END][7:0]};
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
    end else if (tx_next_state == TERM) begin
        case (input_del.tkeep[PIPE_END])
            8'b11111111: begin
                tx_term_data_1 <= {{3{RS_IDLE}}, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24]};
                tx_term_ctl_1 <= 8'b11110000;
                initial_ipg_count <= 3;
            end
            8'b01111111: begin
                tx_term_data_1 <= {{4{RS_IDLE}}, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16]};
                tx_term_ctl_1 <= 8'b11111000;
                initial_ipg_count <= 4;
            end
            8'b00111111: begin
                tx_term_data_1 <= {{5{RS_IDLE}}, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8]};
                tx_term_ctl_1 <= 8'b11111100;
                initial_ipg_count <= 5;
            end
            8'b00011111: begin
                tx_term_data_1 <= {{6{RS_IDLE}}, RS_TERM, tx_crc_byteswapped[7:0]};
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

    slicing_crc #(
        .SLICE_LENGTH(DATA_NBYTES),
        .INITIAL_CRC(32'hFFFFFFFF),
        .INVERT_OUTPUT(1),
        .REGISTER_OUTPUT(1)
    ) u_tx_crc (
        .clk(i_clk),
        .reset(tx_crc_reset),
        .data(tx_crc_input),
        .valid(tx_crc_input_valid),
        .crc(tx_crc)
    );
    
    assign tx_crc_byteswapped = {tx_crc[0+:8], tx_crc[8+:8], tx_crc[16+:8], tx_crc[24+:8]};
endmodule