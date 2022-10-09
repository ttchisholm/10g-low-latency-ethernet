import eg_frames::*;

module encode_tb();

logic i_reset;
logic i_init_done;

logic i_txc;
wire i_rxc;
logic[63:0] i_txd;
logic[7:0] i_txctl;
logic i_tx_pause;
wire [63:0] o_txd;
wire [1:0] o_tx_header;

int pre_idle_frames = 1000;


initial begin 
    i_txc = '0;
    i_txd = '0;
    i_txctl = '0;
    scrambler_init_done = 0;

    i_reset = 1;
    i_init_done = 0;
    @(negedge i_txc);
    i_reset = 0;
    i_init_done = 1;

end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_txc = ~i_txc; end
assign i_rxc = i_txc;


initial begin

    @(posedge i_init_done);

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


encode_6466b u_dut(.*);



endmodule