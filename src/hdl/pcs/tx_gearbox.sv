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
