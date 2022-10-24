// Lookup table crc32

module crc32 #(
    parameter [31:0] INITIAL_CRC = 32'hFFFFFFFF
) (
    input i_clk,
    input [7:0] i_data,
    input i_valid,
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

    // assign o_crc = {crc[ 7: 0], 
    //                 crc[15: 8],
    //                 crc[23:16],
    //                 crc[31:24]} ^ 32'hFFFFFFFF;
    assign o_crc = crc ^ 32'hFFFFFFFF;

    always @(posedge i_clk) begin
        if(i_reset) begin
            crc <= INITIAL_CRC;
        end else if(i_valid) begin
            crc <= (crc >> 8) ^ crc_table[crc[7:0] ^ i_data];
        end
    end


endmodule