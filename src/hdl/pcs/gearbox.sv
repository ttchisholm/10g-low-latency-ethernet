`default_nettype none

// Todo comment doc operation from spreadsheet

module tx_gearbox #(
    localparam DATA_WIDTH = 32,
    localparam HEADER_WIDTH = 2,
    localparam SEQUENCE_WIDTH = 6
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_data,
    input wire [HEADER_WIDTH-1:0] i_header,
    input wire [SEQUENCE_WIDTH-1:0] i_gearbox_seq, 
    input wire i_pause,
    output wire [DATA_WIDTH-1:0] o_data
);

    localparam BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH;

    // Re-use the gearbox sequnce counter method as used in gty
    wire load_header, frame_word;
    logic [2*DATA_WIDTH + HEADER_WIDTH -1:0] obuf;

    assign load_header = i_gearbox_seq[0]; // Load header on even cycles
    assign frame_word = !i_gearbox_seq[0]; // Load bottom word on even cycles (with header), top on odd
    assign o_data = obuf[0 +: DATA_WIDTH];

    wire [SEQUENCE_WIDTH:0] header_idx;
    wire [SEQUENCE_WIDTH:0] data_idx;

    assign header_idx = i_gearbox_seq; // Location to load H0
    assign data_idx = load_header ? i_gearbox_seq + 2 : i_gearbox_seq + 1; // Location to load D0 or D32

    // Need to assign single bits as iverilog does not support variable width assignments
    genvar gi;
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin
        always @(posedge i_clk)
        if (i_reset) begin
            obuf[gi] <= 1'b0;
        end else begin

            if (gi < DATA_WIDTH) begin
                obuf[gi] <= obuf[gi+DATA_WIDTH];
            end

            if (!i_pause) begin
                if (load_header) begin
                    if (gi >= header_idx && gi < header_idx + 2) begin
                        obuf[gi] <= i_header[gi-header_idx];
                    end
                end 

                if (gi >= data_idx && gi < data_idx + DATA_WIDTH) begin
                    obuf[gi] <= frame_word ? i_data[gi-data_idx] : i_data[gi-data_idx];
                end
            end
            
        end

    end endgenerate


endmodule

module rx_gearbox #(
    localparam DATA_WIDTH = 32,
    localparam HEADER_WIDTH = 2,
    localparam SEQUENCE_WIDTH = 6
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_data,
    
    input wire i_slip,
    
    output wire [DATA_WIDTH-1:0] o_data,
    output wire [HEADER_WIDTH-1:0] o_header,
    output logic o_data_valid,
    output logic o_header_valid
);

    localparam BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH;



    // Create the sequence counter - 0 to 32
    logic [SEQUENCE_WIDTH:0] gearbox_seq;

    logic [1:0] half_slip;
    wire tick_out;

    always @(posedge i_clk)
    if (i_reset) begin
        gearbox_seq <= '0;
        half_slip <= '0;
    end else begin
        if (!i_slip) begin
            gearbox_seq <= gearbox_seq < 32 ? gearbox_seq + 1 : '0; 
        end

        if (i_slip) begin
            half_slip <= half_slip + 1;
        end
    end

    assign tick_out = half_slip[1];

    // Re-use the gearbox sequnce counter method as used in gty - this time counting every clock
    logic [BUF_SIZE:0] obuf, next_obuf; // Extra bit at top of buffer to allow for single bit slip
    wire frame_word;
    logic [6:0] data_idxs[33]; // For each counter value, the start buffer index to load the data 
    


    // TODO - buf construction out



    
    assign frame_word = gearbox_seq[0];
    assign o_header = tick_out ? obuf[2:1] : obuf[1:0];
    assign o_data = tick_out ? (!frame_word ? obuf[34:3] : obuf[66:35]) :
                               (!frame_word ? obuf[33:2] : obuf[65:34]);

    logic [6:0] data_idx;
        
    assign data_idx = data_idxs[gearbox_seq];// + tick_out; // Allow for slipping every bit

    // Need to assign single bits as iverilog does not support variable width assignments
    genvar gi;
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin

        always_comb begin

            next_obuf[gi] = obuf[gi];

            if (gearbox_seq[0] == 0) begin
                if (gearbox_seq != 0 && gi >= data_idx) begin
                    next_obuf[gi] = i_data[gi - data_idx];
                end else if (gi < DATA_WIDTH - gearbox_seq) begin
                    next_obuf[gi] = i_data[gi + gearbox_seq];
                end
            
            end else begin
                if (gi >= data_idx && gi < data_idx + 32) begin
                    next_obuf[gi] = i_data[gi - data_idx];
                end
            end
        end
            

        
    end endgenerate

    always @(*) begin
        next_obuf[66] = next_obuf[0];
    end

    always @(posedge i_clk)
    if (i_reset) begin
        obuf <= 1'b0;
        o_data_valid <= '0;
        o_header_valid <= '0;
    end else begin
        obuf <= next_obuf;
        o_data_valid <= gearbox_seq != 32;
        o_header_valid <= !gearbox_seq[0];
    end


    // Ridiculous but clearest way to sequence loading of data as modelled
    initial begin
       data_idxs[0] = 00;
       data_idxs[1] = 32;
       data_idxs[2] = 64;
       data_idxs[3] = 30;
       data_idxs[4] = 62;
       data_idxs[5] = 28;
       data_idxs[6] = 60;
       data_idxs[7] = 26;
       data_idxs[8] = 58;
       data_idxs[9] = 24;
       data_idxs[10] = 56;
       data_idxs[11] = 22;
       data_idxs[12] = 54;
       data_idxs[13] = 20;
       data_idxs[14] = 52;
       data_idxs[15] = 18;
       data_idxs[16] = 50;
       data_idxs[17] = 16;
       data_idxs[18] = 48;
       data_idxs[19] = 14;
       data_idxs[20] = 46;
       data_idxs[21] = 12;
       data_idxs[22] = 44;
       data_idxs[23] = 10;
       data_idxs[24] = 42;
       data_idxs[25] = 8;
       data_idxs[26] = 40;
       data_idxs[27] = 6;
       data_idxs[28] = 38;
       data_idxs[29] = 4;
       data_idxs[30] = 36;
       data_idxs[31] = 2;
       data_idxs[32] = 34;
    end

endmodule