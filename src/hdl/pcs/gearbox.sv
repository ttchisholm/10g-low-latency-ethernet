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
    wire load_header;
    logic [2*DATA_WIDTH + HEADER_WIDTH -1:0] obuf;
    logic prev_seq;

    always @(posedge i_clk)
    if (i_reset) begin
        prev_seq <= 1'b0;
    end else begin
        prev_seq <= i_gearbox_seq;
    end

    genvar gi;
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin
        always @(posedge i_clk)
        if (i_reset) begin
            obuf[gi] <= 1'b0;
        end else begin

            int stagger_index = ((i_gearbox_seq + 1) >> 1) << 1; // For odd sequence values, need to ceil to even

            // Need to assign single bits as iverilog does not support variable width assignments
            if (gi < stagger_index) begin // obuf[0 +: count]
                obuf[gi] <= obuf[DATA_WIDTH + gi]; // Shift buffer down by DATA_WIDTH

            end else begin // need to assign obuf [count : end]
                
                if (!i_pause) begin
                    if (load_header) begin // Load header first frame word
                        if (gi < i_gearbox_seq + HEADER_WIDTH) begin
                            obuf[gi] <= i_header[gi - i_gearbox_seq];
                        end else if (gi < i_gearbox_seq + HEADER_WIDTH + DATA_WIDTH) begin
                            obuf[gi] <= i_data[gi - i_gearbox_seq - HEADER_WIDTH];
                        end else begin
                            obuf[gi] <= obuf[gi]; // Explictly stated for clarity
                        end
                    end else begin // Load second frame word
                        if (gi < (stagger_index) + DATA_WIDTH) begin
                            obuf[gi] <= i_data[gi - (stagger_index)];
                        end else begin
                            obuf[gi] <= obuf[gi]; // Explictly stated for clarity
                        end
                    end 
                end else begin
                    obuf[gi] <= obuf[gi]; // Explictly stated for clarity
                end
                
            end 
            
            // // Above is equivilent to:
            // obuf[0 +: i_gearbox_seq] <= obuf[DATA_WIDTH +: i_gearbox_seq];

            // if (!i_pause) begin
            //     if (load_header) begin
            //         obuf[i_gearbox_seq +: (DATA_WIDTH + HEADER_WIDTH)] <= {i_header, i_data};
            //     end else begin 
            //         obuf[i_gearbox_seq +: DATA_WIDTH] <= i_data;
            //     end
            // end
            
        end

    end endgenerate

    

    assign load_header = !i_gearbox_seq[0];
    assign o_data = obuf[0 +: DATA_WIDTH];

endmodule

module rx_gearbox #(
    localparam DATA_WIDTH = 32,
    localparam HEADER_WIDTH = 2,
    localparam SEQUENCE_WIDTH = 6
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_data,
    input wire [SEQUENCE_WIDTH-1:0] i_gearbox_seq, 
    input wire i_pause,
    
    output wire [DATA_WIDTH-1:0] o_data,
    output wire [HEADER_WIDTH-1:0] o_header,
    output wire o_data_valid,
    output wire o_header_valid
);

    localparam BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH;
    // Re-use the gearbox sequnce counter method as used in gty - this time counting every clock
    logic [BUF_SIZE-1:0] obuf;
    wire frame_word; // Output data from first or second word of frame

    assign o_header_valid = !i_pause && i_gearbox_seq[0];
    assign o_data_valid = !i_pause;
    assign frame_word = !i_gearbox_seq[0]; // Output first word of frame with header

    // Need to assign single bits as iverilog does not support variable width assignments
    genvar gi;
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin
        always @(posedge i_clk)
        if (i_reset) begin
            obuf[gi] <= 1'b0;
        end else begin

            if (frame_word) begin // When outputting 2nd word in frame, load first word + header

                if (gi < DATA_WIDTH - i_gearbox_seq) begin //obuf [0 : 32-count]
                    obuf[gi] <= i_data[gi + i_gearbox_seq];
                end else if (gi < BUF_SIZE - i_gearbox_seq) begin // obuf[32-count : 66-count]
                    obuf[gi] <= obuf[gi];
                end else begin // obuf[66-count : end]
                    obuf[gi] <= i_data[gi - (BUF_SIZE - i_gearbox_seq)];
                end

            end else begin
                if (gi < DATA_WIDTH-(i_gearbox_seq+1)) begin // obuf[0 : 32-(count+1)]
                    obuf[gi] <= obuf[gi];

                end else if (gi < 2*DATA_WIDTH - (i_gearbox_seq+1)) begin // obuf[32-(count+1) +: 64-(count+1)]
                    obuf[gi] <= i_data[gi - (DATA_WIDTH - (i_gearbox_seq+1))];
                
                end else begin // obuf[64-(count+1) : end]
                    obuf[gi] <= obuf[gi];
                end
            end
        end

    end endgenerate

    // always @(posedge i_clk)
    // if (i_reset) begin
    //     obuf <= '0;
    // end else begin
        
    //     if (frame_word) begin // When outputting 2nd word in frame, load first word + header
    //         obuf[0 +: DATA_WIDTH-i_gearbox_seq] = i_data[i_gearbox_seq +: DATA_WIDTH-i_gearbox_seq];
    //         obuf[BUF_SIZE-i_gearbox_seq +: i_gearbox_seq] = idata[0 +: i_gearbox_seq];
    //     end else begin 
    //         obuf[DATA_WIDTH-(i_gearbox_seq+1) +: DATA_WIDTH] = idata;
    //     end
    // end

    assign o_header = obuf[0 +: HEADER_WIDTH];
    assign o_data = frame_word ? obuf[HEADER_WIDTH+DATA_WIDTH +: DATA_WIDTH] : obuf[0 +: DATA_WIDTH];


endmodule