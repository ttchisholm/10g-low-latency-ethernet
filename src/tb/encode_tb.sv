import eg_frames::*;

module encode_tb();


logic txc;
logic txc2;
logic[31:0] txd;
logic[3:0] txctl;
wire tx_pause;
wire [65:0] data;


initial begin 
    txc = '0;
    txc2 = '0;
    txd = '0;
    txctl = '0;
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns txc = ~txc; end
always begin #4ns txc2 = ~txc2; end

initial begin

    foreach (eg_tx_data[i]) begin
        txd = eg_tx_data[i];
        @(posedge txc);
    end
end

initial begin
    foreach (eg_tx_ctl[i]) begin
        txctl = eg_tx_ctl[i];
        @(posedge txc);
    end
end

encode_6466b u_dut(.*);


endmodule