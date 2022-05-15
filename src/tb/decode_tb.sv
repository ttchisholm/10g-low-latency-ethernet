import eg_frames::*;

module decode_tb();

    logic i_reset;
    logic i_init_done;   // Rx interface from pcs
    logic i_rxc;
    logic i_rxc2; //rxc/2
    logic [63:0] i_rxd;
    logic [1:0] i_rx_header;
    logic i_rx_valid;

    //Rx interface out
    wire [31:0] o_rxd;
    wire [3:0] o_rxctl;
    wire o_rx_valid;


initial begin 
    i_rxc = '0;
    i_rxc2 = '0;
    i_rxd = '0;
    i_rx_header = '0;

    i_reset = 1;
    i_init_done = 0;
    @(posedge i_rxc2);
    @(negedge i_rxc);
    i_reset = 0;
    i_init_done = 1;
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_rxc = ~i_rxc; end
initial begin
    #2ns
    forever begin #4ns i_rxc2 = ~i_rxc2; end
end


initial begin

    @(posedge i_init_done);

    foreach (eg_rx_data[i]) begin
        @(negedge i_rxc2);
        i_rxd = eg_rx_data[i];
        
    end
    @(negedge i_rxc2);
    i_rxd = 64'h000000000000001e;
end

initial begin
    @(posedge i_init_done);

    foreach (eg_rx_header[i]) begin
        @(negedge i_rxc2);
        i_rx_header = eg_rx_header[i];
    end
    @(negedge i_rxc2);
    i_rx_header = '1;

end

decode_6466b u_dut(.*);


endmodule