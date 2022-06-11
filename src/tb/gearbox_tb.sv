module gearbox_tb();


localparam INPUT_WIDTH = 20;
localparam OUTPUT_WIDTH = 16;

logic i_clk;
logic [INPUT_WIDTH-1:0] i_data;
wire [OUTPUT_WIDTH-1:0] o_data;
logic i_reset;
logic i_init_done;

logic i_slip;
wire o_valid;
wire o_pause;


gearbox #(.INPUT_WIDTH(INPUT_WIDTH), .OUTPUT_WIDTH(OUTPUT_WIDTH)) u_gearbox
(.*);

initial begin 
    i_clk = 1'b0;
    i_reset = 1'b1;
    i_init_done = 1'b1;
    i_data = '0;
    i_slip = 1'b0;

    @(negedge i_clk);
    i_reset = 1'b0;

    for(int i = 0; i < 16;) begin
        @(posedge i_clk);
        #1ns i_data = i;
        if(!o_pause) i++;
    end
end


//always begin #1.58810509ns txc = ~txc; end
always begin #2ns i_clk = ~i_clk; end




endmodule