module gearbox_seq #(
    parameter WIDTH = 6,
    parameter MAX_VAL = 32,
    parameter PAUSE_VAL = 32
) (
    input wire clk,
    input wire reset,
    output logic [WIDTH-1:0] count,
    output wire pause
);

    always @(posedge clk)
    if (reset) begin
        count <= '0;
    end else begin
        count <= count < MAX_VAL ? count + 1 : '0; 
    end

    assign pause = count == PAUSE_VAL;

endmodule