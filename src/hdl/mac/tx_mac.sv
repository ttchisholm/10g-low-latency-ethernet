`timescale 1ns/1ps
`default_nettype none
`include "code_defs_pkg.svh"

module tx_mac #(
    localparam DATA_WIDTH = 32,
    localparam DATA_NBYTES = DATA_WIDTH / 8
) (
    
    input wire reset,
    input wire clk,

    // Tx PHY
    output logic [DATA_WIDTH-1:0] xgmii_tx_data,
    output logic [DATA_NBYTES-1:0] xgmii_tx_ctl,
    input wire phy_tx_ready,

    // Tx User AXIS
    input wire [DATA_WIDTH-1:0] s00_axis_tdata,
    input wire [DATA_NBYTES-1:0] s00_axis_tkeep,
    input wire s00_axis_tvalid,
    output logic s00_axis_tready,
    input wire s00_axis_tlast
);

    import code_defs_pkg::*;


    /****  Local Definitions ****/
    localparam MIN_FRAME_SIZE = 60; //Excluding CRC
    localparam IPG_SIZE = 12;
    localparam N_TERM_FRAMES = 4;
    localparam IPG_COUNTER_WIDTH = 5;

    localparam START_FRAME_64 = {MAC_SFD, {6{MAC_PRE}}, RS_START}; // First octet of preamble is replaced by RS_START (46.1.7.1.4)
    localparam START_CTL_64 = 8'b00000001;
    localparam IDLE_FRAME_64 =  {8{RS_IDLE}};
    localparam ERROR_FRAME_64 = {8{RS_ERROR}};

    /****  Data Pipeline Definitions ****/
    // Define how many cycles to buffer input for (to allow for time to send preamble)
    localparam INPUT_PIPELINE_LENGTH = 64 / DATA_WIDTH; // Todo should be a way to save a cycle here
    localparam PIPE_END = INPUT_PIPELINE_LENGTH-1;

    // Ideally the struct would be the array - iverilog doesn't seem to support it
     typedef struct packed {
        logic [INPUT_PIPELINE_LENGTH-1:0] [DATA_WIDTH-1:0]  tdata ;
        logic  [INPUT_PIPELINE_LENGTH-1:0] tlast ;
        logic  [INPUT_PIPELINE_LENGTH-1:0] tvalid ;
        logic [INPUT_PIPELINE_LENGTH-1:0] [DATA_NBYTES-1:0] tkeep ;
        logic [INPUT_PIPELINE_LENGTH-1:0] [$clog2(MIN_FRAME_SIZE):0] data_counter;
        
    } input_pipeline_t ;

    input_pipeline_t input_del; 
    logic phy_tx_ready_del;

    // Pipeline debugging
    // verilator lint_off UNUSED
    wire [DATA_WIDTH-1:0] dbg_data_last, dbg_data_first;
    wire dbg_last_last;
    wire dbg_valid_last;
    wire [DATA_NBYTES-1:0] dbg_keep_last, dbg_keep_first;
    wire [$clog2(MIN_FRAME_SIZE):0] dbg_count_last;
    // verilator lint_on UNUSED

    assign dbg_data_last = input_del.tdata[PIPE_END];
    assign dbg_last_last = input_del.tlast[PIPE_END];
    assign dbg_valid_last = input_del.tvalid[PIPE_END];
    assign dbg_keep_last = input_del.tkeep[PIPE_END];
    assign dbg_count_last = input_del.data_counter[PIPE_END];
    assign dbg_keep_first = input_del.tkeep[0];
    assign dbg_data_first = input_del.tdata[0];

    /****  State definitions ****/
    typedef enum {IDLE, PREAMBLE, DATA, PADDING, TERM, IPG} tx_state_t;
    tx_state_t tx_state, tx_next_state;

    /****  Other definitions ****/
    // Min payload counter
    logic [$clog2(MIN_FRAME_SIZE):0] data_counter, next_data_counter; // Extra bit for overflow
    logic min_packet_size_reached;

    // IPG counter
    logic [IPG_COUNTER_WIDTH-1:0] initial_ipg_count;
    logic [IPG_COUNTER_WIDTH-1:0] ipg_counter;

    // CRC
    wire [31:0] tx_crc, tx_crc_byteswapped;
    wire [DATA_NBYTES-1:0] tx_crc_input_valid;
    wire tx_crc_reset;
    wire [DATA_WIDTH-1:0] tx_crc_input;
    logic [DATA_NBYTES-1:0] tx_data_keep, tx_pad_keep, tx_term_keep;

    // Termination
    logic seen_last;
    logic [1:0] term_counter, term_rest_idx;
    logic [1:0][63:0] tx_next_term_data_64;
    logic [1:0][7:0] tx_next_term_ctl_64;
    logic [DATA_WIDTH-1:0] tx_term_data_first; // Term frame to output when term detected
    logic [DATA_NBYTES-1:0] tx_term_ctl_first;
    logic [N_TERM_FRAMES-2:0] [DATA_WIDTH-1:0] tx_term_data_rest; // The next 3 term frames after term detected
    logic [N_TERM_FRAMES-2:0] [DATA_NBYTES-1:0] tx_term_ctl_rest;
    
    

    /****  Data Pipeline Implementation ****/
    genvar gi;
    generate for (gi = 0; gi < INPUT_PIPELINE_LENGTH; gi++) begin
        if (gi == 0) begin // Pipeline start
        always @(posedge clk)
        if (reset) begin
            input_del.tdata[gi] <= {DATA_WIDTH{1'b0}};
            input_del.tlast[gi] <= 1'b0;
            input_del.tvalid[gi] <= 1'b0;
            input_del.tkeep[gi] <= {DATA_NBYTES{1'b0}};
            input_del.data_counter[gi] <= '0;
        end else begin
                if (phy_tx_ready) begin
                    input_del.tdata[gi] <= s00_axis_tready ? s00_axis_tdata : 32'b0; // If phy_tx_ready but !s00_axis_tready, we're padding
                    input_del.tlast[gi] <= s00_axis_tlast;
                    input_del.tvalid[gi] <= s00_axis_tvalid;
                    input_del.tkeep[gi] <= input_del.data_counter[0] < MIN_FRAME_SIZE ? 4'b1111 : 
                                           (tx_next_state == DATA) ? tx_data_keep : 4'b0000;
                    input_del.data_counter[gi] <= tx_next_state == IDLE ? '0 :
                                                  (input_del.data_counter[gi] >= MIN_FRAME_SIZE) ? input_del.data_counter[gi] : 
                                                   input_del.data_counter[gi] + DATA_NBYTES;
                end
            end
        end else begin // Move the pipeline along
            always @(posedge clk)
            if (reset) begin
                input_del.tdata[gi] <= {DATA_WIDTH{1'b0}};
                input_del.tlast[gi] <= 1'b0;
                input_del.tvalid[gi] <= 1'b0;
                input_del.tkeep[gi] <= {DATA_NBYTES{1'b0}};
                input_del.data_counter[gi] <= '0;
            end else begin
                if (phy_tx_ready) begin
                    input_del.tdata[gi] <= input_del.tdata[gi-1];
                    input_del.tlast[gi] <= input_del.tlast[gi-1];
                    input_del.tvalid[gi] <= input_del.tvalid[gi-1];
                    input_del.tkeep[gi] <= input_del.tkeep[gi-1];
                    input_del.data_counter[gi] <= input_del.data_counter[gi-1];
                end
            end
        end
    end endgenerate


    /**** Sequential State Implementation ****/
    always @(posedge clk)
    if (reset) begin
        tx_state <= IDLE;
        data_counter <= '0;
        ipg_counter <= '0;
        term_counter <= '0;
        phy_tx_ready_del <= '0;
        seen_last <= '0;
        
    end else begin
        tx_state <= tx_next_state;        
        data_counter <= next_data_counter; 
        ipg_counter <= (tx_state == IPG)  ? ipg_counter + IPG_COUNTER_WIDTH'(DATA_NBYTES) : 
                                            initial_ipg_count;
        term_counter <= (!phy_tx_ready) ? term_counter : 
                        (tx_next_state == TERM) ? term_counter + 1 : 0;
        phy_tx_ready_del <= phy_tx_ready;
        seen_last <= (tx_next_state == IDLE) ? '0 :
                     (!seen_last) ? s00_axis_tlast && s00_axis_tvalid && s00_axis_tready : seen_last;
    end

    
    /**** Next State Implementation ****/

    // Assign the index to the term data array - cast widths for verilator
    assign term_rest_idx = 2'(32'(term_counter)-1); // -1 as first term frame seperate variable

    always @(*) begin

        if (!phy_tx_ready) begin
            tx_next_state = tx_state;
            xgmii_tx_data = ERROR_FRAME_64[0 +: DATA_WIDTH];
            xgmii_tx_ctl = '1;
            next_data_counter = data_counter;
        end else begin
            case (tx_state)
                IDLE: begin
                    tx_next_state = bit'(s00_axis_tvalid) ? PREAMBLE :
                                    IDLE;
                    xgmii_tx_data = tx_next_state == IDLE ? IDLE_FRAME_64[0+:DATA_WIDTH] :
                                                            START_FRAME_64[0+:DATA_WIDTH];
                    xgmii_tx_ctl = tx_next_state == IDLE ? '1 :
                                                            START_CTL_64[0+:DATA_NBYTES];
                    next_data_counter = 0;
                end
                PREAMBLE: begin // Only used in 32-bit mode
                    tx_next_state = bit'(!s00_axis_tvalid) ? IDLE :
                                                            DATA;
                    xgmii_tx_data = START_FRAME_64[32+:32];
                    xgmii_tx_ctl = START_CTL_64[4+:4];
                    next_data_counter = 0;
                end
                DATA: begin
                    // tvalid must be high throughout frame
                    tx_next_state = bit'(!input_del.tvalid[PIPE_END])                           ? IDLE :                    
                                    bit'(input_del.tlast[PIPE_END] && !min_packet_size_reached) ? PADDING :
                                    bit'(input_del.tlast[PIPE_END])                             ? TERM :
                                                                                                  DATA;


                    xgmii_tx_data = !input_del.tvalid[PIPE_END] ? ERROR_FRAME_64[0 +: DATA_WIDTH] : 
                                    input_del.tlast[PIPE_END]   ? tx_term_data_first :
                                                                  input_del.tdata[PIPE_END];
                    
                    xgmii_tx_ctl = !input_del.tvalid[PIPE_END] ? '1 : 
                                    input_del.tlast[PIPE_END]  ? tx_term_ctl_first :
                                                                 '0;

                    // stop counting when min size reached
                    next_data_counter = (data_counter >= MIN_FRAME_SIZE) ? data_counter : data_counter + DATA_NBYTES; 
                end
                PADDING: begin
                    tx_next_state = bit'(!min_packet_size_reached) ? PADDING : TERM;
                    xgmii_tx_data = !min_packet_size_reached ? '0 : tx_term_data_first;
                    xgmii_tx_ctl = !min_packet_size_reached ? '0 : tx_term_ctl_first; 
                    next_data_counter = data_counter + DATA_NBYTES;
                end
                TERM: begin
                    // 1 TERM cycle for 64-bit, 2 for 32-bit
                    tx_next_state = bit'(term_counter == 3) ? IPG : TERM;
                    xgmii_tx_data = tx_term_data_rest[term_rest_idx]; 
                    xgmii_tx_ctl = tx_term_ctl_rest[term_rest_idx];
                    next_data_counter = 0;
                end
                IPG: begin
                    tx_next_state = bit'(ipg_counter < IPG_SIZE) ? IPG : IDLE;
                    xgmii_tx_data = IDLE_FRAME_64[0+:DATA_WIDTH];
                    xgmii_tx_ctl = '1;
                    next_data_counter = 0;
                end
                default: begin
                    tx_next_state = IDLE;
                    xgmii_tx_data = ERROR_FRAME_64[0 +: DATA_WIDTH];
                    xgmii_tx_ctl = '1;
                    next_data_counter = 0;
                end

            endcase
        end
    end

    assign min_packet_size_reached = next_data_counter >= MIN_FRAME_SIZE;
    assign s00_axis_tready = phy_tx_ready && !seen_last && (tx_state == IDLE || tx_state == PREAMBLE  || tx_state == DATA);
    assign tx_data_keep = {DATA_NBYTES{phy_tx_ready}} & (s00_axis_tkeep & {DATA_NBYTES{s00_axis_tvalid}});
    assign tx_pad_keep = data_counter < MIN_FRAME_SIZE ? 4'b1111 : 4'b0000;
    assign tx_term_keep = (tx_state == PADDING) ? tx_pad_keep : input_del.tkeep[PIPE_END];


    /**** Termination Data ****/
    // Construct the final 2/4 tx frames depending on number of bytes in last axis frame
    wire [DATA_WIDTH-1:0] term_data;
    assign term_data = (tx_state == PADDING) ? '0 : input_del.tdata[PIPE_END];
    

    always @(*) begin
        case (tx_term_keep)
        4'b1111: begin
            tx_next_term_data_64[0] = {tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], term_data[31:0]};
            tx_next_term_ctl_64[0] = 8'b00000000;
            tx_next_term_data_64[1] = {{7{RS_IDLE}}, RS_TERM};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 7;
        end
        4'b0111: begin
            tx_next_term_data_64[0] = {RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], term_data[23:0]};
            tx_next_term_ctl_64[0] = 8'b10000000;
            tx_next_term_data_64[1] = {{8{RS_IDLE}}};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 8;
        end
        4'b0011: begin
            tx_next_term_data_64[0] = {RS_IDLE, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], term_data[15:0]};
            tx_next_term_ctl_64[0] = 8'b11000000;
            tx_next_term_data_64[1] = {{8{RS_IDLE}}};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 9;
        end
        4'b0001: begin
            tx_next_term_data_64[0] = {RS_IDLE, RS_IDLE, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24], term_data[7:0]};
            tx_next_term_ctl_64[0] = 8'b11100000;
            tx_next_term_data_64[1] = {{8{RS_IDLE}}};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 10;
        end
        4'b0000: begin
            tx_next_term_data_64[0] = {RS_IDLE, RS_IDLE, RS_IDLE, RS_TERM, tx_crc_byteswapped[7:0], tx_crc_byteswapped[15:8], tx_crc_byteswapped[23:16], tx_crc_byteswapped[31:24]};
            tx_next_term_ctl_64[0] = 8'b11110000;
            tx_next_term_data_64[1] = {{8{RS_IDLE}}};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 11;
        end
        default: begin
            tx_next_term_data_64[0] = {8{RS_ERROR}};
            tx_next_term_ctl_64[0] = 8'b11111111;
            tx_next_term_data_64[1] = {8{RS_ERROR}};
            tx_next_term_ctl_64[1] = 8'b11111111;
            initial_ipg_count = 0;
        end
        endcase
    end


    // Use the first frame immedietly (contains last bytes of data and maybe crc)
    assign tx_term_data_first = tx_next_term_data_64[0][0+:32];
    assign tx_term_ctl_first = tx_next_term_ctl_64[0][0+:4];

    // Assign term cycles 1-3 (cycle 0 assigned above)
    for (gi = 1; gi < N_TERM_FRAMES; gi++) begin
            // Save the following frames for the next cycle(s)
            always @(posedge clk)
            if (reset) begin
            tx_term_data_rest[gi-1] <= {DATA_WIDTH{1'b0}};
            tx_term_ctl_rest[gi-1] <= {DATA_NBYTES{1'b0}};
            end else if (tx_state != TERM && tx_next_state == TERM) begin
            tx_term_data_rest[gi-1] <= tx_next_term_data_64[gi / 2][(gi % 2) * DATA_WIDTH +: DATA_WIDTH];
            tx_term_ctl_rest[gi-1] <= tx_next_term_ctl_64[gi / 2][(gi % 2) * DATA_NBYTES +: DATA_NBYTES];
        end
    end

    /**** CRC Implementation ****/

    assign tx_crc_reset = reset || (tx_state == IDLE);
    assign tx_crc_input = (tx_next_state == PADDING) ? 32'b0 : input_del.tdata[0];
    assign tx_crc_input_valid = {DATA_NBYTES{phy_tx_ready_del}} & input_del.tkeep[0];

    slicing_crc #(
        .SLICE_LENGTH(DATA_NBYTES),
        .INITIAL_CRC(32'hFFFFFFFF),
        .INVERT_OUTPUT(1),
        .REGISTER_OUTPUT(1)
    ) u_tx_crc (
        .clk(clk),
        .reset(tx_crc_reset),
        .data(tx_crc_input),
        .valid(tx_crc_input_valid),
        .crc(tx_crc)
    );
    
    assign tx_crc_byteswapped = {tx_crc[0+:8], tx_crc[8+:8], tx_crc[16+:8], tx_crc[24+:8]};

endmodule
