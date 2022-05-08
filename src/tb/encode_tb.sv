import eg_frames::*;

module encode_tb();

logic i_reset;
logic i_init_done;

logic i_txc;
logic i_txc2;
logic[31:0] i_txd;
logic[3:0] i_txctl;
wire i_tx_pause;
wire [63:0] o_txd;
wire [1:0] o_tx_header;

logic i_rxc;
logic i_rxc2; //rxc/2
logic [65:0] i_rxd;
logic i_rx_valid;
wire [31:0] o_rxd;
wire [3:0] o_rxctl;
wire o_rx_valid;


initial begin 
    i_txc = '0;
    i_txc2 = '0;
    i_txd = '0;
    i_txctl = '0;

    i_reset = 1;
    i_init_done = 0;
    @(negedge i_txc);
    i_reset = 0;
    i_init_done = 1;
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_txc = ~i_txc; end
always begin #4ns i_txc2 = ~i_txc2; end

initial begin

    @(posedge i_init_done);

    foreach (eg_tx_data[i]) begin
        @(negedge i_txc);
        i_txd = eg_tx_data[i];
        
    end
end

initial begin
    @(posedge i_init_done);

    foreach (eg_tx_ctl[i]) begin
        @(negedge i_txc);
        i_txctl = eg_tx_ctl[i];
        
    end
end

encode_6466b u_dut(.*);


endmodule