import eg_frames::*;

module encode_tb();

logic i_reset;
logic i_init_done;

logic i_txc;
logic[63:0] i_txd;
logic[7:0] i_txctl;
logic i_tx_pause;
wire [63:0] o_txd;
wire [1:0] o_tx_header;



initial begin 
    i_txc = '0;
    i_txd = '0;
    i_txctl = '0;
    i_tx_pause = '0;
    scrambler_init_done = 0;

    i_reset = 1;
    i_init_done = 0;
    @(negedge i_txc);
    i_reset = 0;
    i_init_done = 1;

    // Sync up scrambler initial state to match eg frames
    @(posedge i_txc);
    #0.1ns scrambler_init_done = 1;
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_txc = ~i_txc; end



logic scrambler_init_done;

initial begin

    @(posedge i_init_done);

    foreach (eg_tx_data[i]) begin
        @(posedge i_txc);
        i_txd = eg_tx_data[i];
        
    end
end

initial begin
    @(posedge i_init_done);

    foreach (eg_tx_ctl[i]) begin
        @(posedge i_txc);
        i_txctl = eg_tx_ctl[i];
        
    end
end


wire [63:0] scrambled_out;

encode_6466b u_dut(.*);

scrambler u_scram(
.i_reset(i_reset),
.i_init_done(scrambler_init_done),
.i_tx_pause(i_tx_pause),
.i_txc(i_txc),
.i_txd(o_txd),
.o_txd(scrambled_out));


endmodule