// Lookup table crc32

module crc32 #(
    parameter [31:0] INITIAL_CRC = 32'hFFFFFFFF,
    parameter INPUT_WIDTH_BYTES = 8
) (
    input i_clk,
    input [INPUT_WIDTH_BYTES*8 -1:0] i_data,
    input [INPUT_WIDTH_BYTES-1 : 0] i_valid,
    input i_reset,

    output [31:0] o_crc
);


    logic [31:0] crc_table [0:255];
    logic [31:0] crc;

    initial begin
        $readmemh("crc32.mem", crc_table);
    end

    initial begin
        crc <= INITIAL_CRC;
    end

    assign o_crc = crc ^ 32'hFFFFFFFF;

    wire [31:0] next_crc;
    always @(posedge i_clk) begin
        if(i_reset) begin
            crc <= INITIAL_CRC;
        end else if(i_valid != '0) begin
            crc <= next_crc;
        end
    end


    genvar gi;
    generate
        wire [31:0] crc_output_stage [INPUT_WIDTH_BYTES + 1];

        assign crc_output_stage[0] = crc;

        for (gi = 0; gi < INPUT_WIDTH_BYTES; gi++) begin
            
            assign crc_output_stage[gi+1] = i_valid[gi] ? (crc_output_stage[gi] >> 8) ^ 
                                            crc_table[crc_output_stage[gi][7:0] ^ i_data[gi*8 +: 8]] : crc_output_stage[gi];
            
        end

        assign next_crc = crc_output_stage[INPUT_WIDTH_BYTES];
    endgenerate

    // (crc >> 8) ^ crc_table[crc[7:0] ^ i_data];


endmodule