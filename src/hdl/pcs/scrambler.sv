module scrambler (
    input wire i_reset,
    input wire i_init_done,
    input wire i_tx_pause,

    input wire i_txc,
    input wire [63:0] i_txd,

    output wire [63:0] o_txd

);

    logic[63:0] delayed_txd;
    wire [127:0] scrambler_data;

    always @(posedge i_txc) begin
        if (i_reset || !i_init_done) begin
            delayed_txd <= '1;
        end
        else if (!i_tx_pause) begin
            delayed_txd <= o_txd;
        end
    end

    // Data here is reversed wrt. polynomial index
    assign scrambler_data = {{o_txd}, {delayed_txd}};

    // Parallel scrambler
    // Polynomial is 1 + x^39 + x^58, easier to write as inverse 1 + x^19 + x^58
    //  and say S0 is first transmitted bit (lsb)
    // S58 = D58 + S19 + S0
    // ...
    // S64 = D64 + S25 + S6
    // S65 = D65 + S26 + S7
    // ...
    // S127 = D127 + S88 + S69

    genvar gi;
    generate;
        for (gi = 0; gi < 64; gi++) begin
            assign o_txd[gi] = scrambler_data[6+gi] ^ scrambler_data[25+gi] ^ i_txd[gi];
        end
    endgenerate
    
endmodule