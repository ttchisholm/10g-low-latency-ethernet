import eg_frames::*;

module pcs_tb();

    logic i_reset;
    logic i_rxc;
    logic [63:0] i_rxd;
    wire [63:0] o_rxd;
    wire [7:0] o_rxctl;
    wire o_rx_valid;
    logic i_txc;
    logic[63:0] i_txd;
    logic[7:0] i_txctl;
    logic o_tx_ready;
    logic [63:0] o_txd;

    int pre_idle_frames = 100;

    initial begin 
        i_txc = '0;
        i_txd = '0;
        i_txctl = '0;
        
        i_reset = 1;
        @(negedge i_txc);
        i_reset = 0;
    end


//always begin #1.58810509ns txc = ~txc; end
    always begin #2ns i_txc = ~i_txc; end
    assign i_rxc = i_txc;

    pcs #(.SCRAMBLER_BYPASS(0)) u_dut(.*);

    initial begin

        forever begin

            for(int i = 0; i < pre_idle_frames; i++) begin
                @(posedge i_txc);
                i_txd = 64'h0707070707070707;
                i_txctl = 8'b11111111;
            end

            foreach (eg_tx_data[i]) begin
                @(posedge i_txc);
                i_txd = eg_tx_data[i];
                i_txctl = eg_tx_ctl[i];
            end
        end

    end

    assign i_rxd = o_txd;



endmodule