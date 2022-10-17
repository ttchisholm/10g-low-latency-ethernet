module descrambler (
    input wire i_reset,
    input wire i_init_done,
    input wire i_rx_valid,

    input wire i_rxc,
    input wire [63:0] i_rxd,

    output wire [63:0] o_rxd

);

    logic[63:0] delayed_rxd;
    wire [127:0] scrambler_data;

    always @(posedge i_rxc) begin
        if (i_reset || !i_init_done) begin
            delayed_rxd <= '1;
        end
        else if (i_rx_valid) begin
            delayed_rxd <= i_rxd;
        end
    end

    // Data here is reversed wrt. polynomial index
    assign scrambler_data = {{i_rxd}, {delayed_rxd}};
    
    //
    
    // Parallel scrambler
    // Polynomial is 1 + x^39 + x^58, easier to write as inverse 1 + x^19 + x^58
    //  and say S0 is first transmitted bit (lsb)
    // S58 = D58 + S19 + S0
    // S65 = D65 + S26 + S7
    // ...
    // S128 = D128 + S89 + S70

    genvar gi;
    generate;
        for (gi = 0; gi < 64; gi++) begin
            assign o_rxd[gi] = scrambler_data[6+gi] ^ scrambler_data[25+gi] ^ i_rxd[gi];
        end
    endgenerate
    
endmodule