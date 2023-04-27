`timescale 1ns/1ps
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
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_frame_word
);

    localparam BUF_SIZE = 2*DATA_WIDTH + HEADER_WIDTH;

    // Re-use the gearbox sequnce counter method as used in gty
    wire load_header;
    logic [2*DATA_WIDTH + HEADER_WIDTH -1:0] obuf, next_obuf, shifted_obuf;

    assign load_header = !i_gearbox_seq[0]; // Load header on even cycles
    assign o_frame_word =  i_gearbox_seq[0]; // Load bottom word on even cycles (with header), top on odd
    assign o_data = next_obuf[0 +: DATA_WIDTH];

    wire [SEQUENCE_WIDTH-1:0] header_idx;
    wire [SEQUENCE_WIDTH-1:0] data_idx;

    assign header_idx = i_gearbox_seq; // Location to load H0
    assign data_idx = load_header ? i_gearbox_seq + 2 : i_gearbox_seq + 1; // Location to load D0 or D32

    assign shifted_obuf = {{DATA_WIDTH{1'b0}}, obuf[DATA_WIDTH +: BUF_SIZE-DATA_WIDTH]};

    // Need to assign single bits as iverilog does not support variable width assignments
    generate for (genvar gi = 0; gi < BUF_SIZE; gi++) begin

        // Next bit can come from three sources:
        //      1. New data (header and data word or just data word)
        //      2. Data previously in the buffer shifted down
        //      3. Existing data at that index
        //  The data source depends on the bit in the buffer and current 
        //  sequence value (which informs header_idx and data_idx).
        
        always @(*) begin

            next_obuf[gi] = obuf[gi]; // Source 3

            if (gi < DATA_WIDTH) begin // Source 2
                next_obuf[gi] = shifted_obuf[gi];
            end

            if (!i_pause) begin // Source 1
                if (load_header) begin
                    if (gi >= header_idx && gi < header_idx + 2) begin
                        next_obuf[gi] = i_header[gi-header_idx];
                    end
                end 

                if (gi >= data_idx && gi < data_idx + DATA_WIDTH) begin
                    next_obuf[gi] = o_frame_word ? i_data[gi-data_idx] : i_data[gi-data_idx];
                end
            end
            
        end

    end endgenerate

    always @(posedge i_clk)
    if (i_reset) begin
        obuf <= '0;
    end else begin
        obuf <= next_obuf;
    end


endmodule
