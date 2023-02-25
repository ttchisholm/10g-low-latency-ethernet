module scrambler #(
    parameter DATA_WIDTH = 32
) (
    input wire i_reset,
    input wire i_init_done,
    input wire i_tx_pause,

    input wire i_txc,
    input wire [DATA_WIDTH-1:0] i_txd,

    output wire [DATA_WIDTH-1:0] o_txd

);

    logic[127:0] scrambler_data;
    logic [127:0] next_scrambler_data;

    always @(posedge i_txc) begin
        if (i_reset || !i_init_done) begin
            scrambler_data <= '1;
        end
        else if (!i_tx_pause) begin
            scrambler_data <= next_scrambler_data;
        end
    end

    // Data here is reversed wrt. polynomial index
    assign next_scrambler_data = {{o_txd}, {scrambler_data[DATA_WIDTH +: 128 - DATA_WIDTH]}};

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
            assign o_txd[gi] = next_scrambler_data[(64-DATA_WIDTH) + 6+gi] ^ next_scrambler_data[(64-DATA_WIDTH) + 25+gi] ^ i_txd[gi];
        end
    endgenerate
    
endmodule