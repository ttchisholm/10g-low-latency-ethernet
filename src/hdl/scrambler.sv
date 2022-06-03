module scrambler (
    input wire i_reset,
    input wire i_init_done,
    input wire i_tx_pause,

    input wire i_txc2,
    input wire [63:0] i_txd,

    output wire [63:0] o_txd

);

    logic[63:0] delayed_txd;
    wire [127:0] scrambler_data, scrambler_data_rev; // We need two transfers to calculate output, +1 latency :( todo
    //wire [63:0] scrambled_out;

    always @(posedge i_txc2) begin
        if (i_reset || !i_init_done) begin
            delayed_txd <= '1;
        end
        else if (!i_tx_pause) begin
            delayed_txd <= o_txd;
        end
    end

    // Data here is reversed wrt. polynomial index
    assign scrambler_data = {{o_txd}, {delayed_txd}};
    
    //
    
    genvar gi;
    // generate
    //     for(gi = 0; gi < 128; gi++)  begin
    //         assign scrambler_data_rev[gi] = scrambler_data[127-gi];
    //     end
    // endgenerate;

    // Parallel scrambler
    // Polynomial is 1 + x^39 + x^58, easier to write as inverse 1 + x^19 + x^58
    //  and say S0 is first transmitted bit (lsb)
    // S58 = D58 + S19 + S0
    // S65 = D65 + S26 + S7
    // ...
    // S128 = D128 + S89 + S70

    
    generate;
        for (gi = 0; gi < 64; gi++) begin
            assign o_txd[gi] = scrambler_data[6+gi] ^ scrambler_data[25+gi] ^ i_txd[gi];
        end
    endgenerate



    // Test 1 bit lfsr

    logic [63:0] out_1bit;
    logic [57:0] lfsr;

    initial begin
        lfsr = '1;

        @(posedge i_init_done);
        
        forever begin
            @(posedge i_txc2);
            #0.1ns

            for(int i = 0; i < 64; i++) begin
                out_1bit[i] = i_txd[i] ^ lfsr[0] ^ lfsr[19];
                lfsr = {out_1bit[i], lfsr[57:1]};
            end
        end

    end

    
endmodule