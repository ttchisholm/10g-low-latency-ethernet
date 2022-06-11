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

    // Sync up scrambler initial state to match eg frames
    @(posedge i_txc);
    #0.1ns scrambler_init_done = 1;
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_txc = ~i_txc; end
assign i_rxc = i_txc;



logic scrambler_init_done;

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



wire [63:0] scrambled_out, descrambled_out, gearbox_out;

wire [65:0] rx_gearbox_out;
wire rx_gearbox_valid;
wire gearbox_slip;


encode_6466b u_dut(.*);

scrambler u_scram(
.i_reset(i_reset),
.i_init_done(scrambler_init_done),
.i_tx_pause(i_tx_pause),
.i_txc(i_txc),
.i_txd(o_txd),
.o_txd(scrambled_out));

descrambler u_descram(
.i_reset(i_reset),
.i_init_done(scrambler_init_done),
.i_tx_pause(i_tx_pause),
.i_txc(i_txc),
.i_txd(scrambled_out),
.o_txd(descrambled_out));

gearbox #(.INPUT_WIDTH(66),
        .OUTPUT_WIDTH(64)) 
    u_tx_gearbox(
    
    .i_reset(i_reset),
    .i_init_done(scrambler_init_done),

    .i_clk(i_txc),
    .i_data({o_tx_header, scrambled_out}),
    .i_slip(1'b0),
    .o_data(gearbox_out),
    .o_pause(i_tx_pause),
    .o_valid()
);

gearbox #(.INPUT_WIDTH(64),
        .OUTPUT_WIDTH(66)) 
        u_rx_gearbox(
    .i_reset(i_reset),
    .i_init_done(scrambler_init_done),

    .i_clk(i_rxc),
    .i_data(gearbox_out),
    .o_data(rx_gearbox_out),
    .o_valid(rx_gearbox_valid),
    .i_slip(gearbox_slip)
);

lock_state u_lock_state(
    .i_clk(i_rxc),
    .i_reset(i_reset),
    .i_header(rx_gearbox_out[65:64]),
    .i_valid(rx_gearbox_valid),
    
    .o_slip(gearbox_slip)
);



endmodule