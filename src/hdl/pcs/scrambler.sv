`timescale 1ns/1ps
`default_nettype none

module scrambler #(
    parameter DESCRAMBLE = 0, 

    localparam int DATA_WIDTH = 32
) (
    input wire clk,
    input wire reset,
    input wire init_done,
    input wire pause,
    input wire [DATA_WIDTH-1:0] idata,
    output wire [DATA_WIDTH-1:0] odata
);

    // verilator lint_off UNUSED
    logic[127:0] scrambler_data;
    // verilator lint_on UNUSED

    logic [127:0] next_scrambler_data;
    logic [95:0] next_scrambler_data_split;

    always @(posedge clk) begin
        if (reset || !init_done) begin
            scrambler_data <= '1;
        end
        else if (!pause) begin
            scrambler_data <= next_scrambler_data;
        end
    end

    // Data here is reversed wrt. polynomial index
    // We need to split the scrambler data to avoid circular comb (verilator)
    // Shift the scrambler data down by DATA_WIDTH
    assign next_scrambler_data_split = {scrambler_data[DATA_WIDTH +: 128 - DATA_WIDTH]};

    // If descrambling, shift in input data, else scrambler output
    assign next_scrambler_data = DESCRAMBLE ? {idata, next_scrambler_data_split} : 
                                              {odata, next_scrambler_data_split};

    // Parallel scrambler
    // Polynomial is 1 + x^39 + x^58, easier to write as inverse 1 + x^19 + x^58
    //  and say S0 is first transmitted bit (lsb)
    // S58 = D58 + S19 + S0
    // ...
    // S64 = D64 + S25 + S6
    // S65 = D65 + S26 + S7
    // ...
    // S127 = D127 + S88 + S69

    // For 32-bit mode, as we only shift the scrambler data by 32 each time, need to offset index with (64-DATA_WIDTH)

    genvar gi;
    generate;
        for (gi = 0; gi < DATA_WIDTH; gi++) begin
            assign odata[gi] = next_scrambler_data_split[(64-DATA_WIDTH) + 6+gi] ^ next_scrambler_data_split[(64-DATA_WIDTH) + 25+gi] ^ idata[gi];
        end
    endgenerate
    
endmodule
