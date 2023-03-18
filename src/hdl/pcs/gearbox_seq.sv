module gearbox_seq #(
    parameter WIDTH = 6,
    parameter MAX_VAL = 32,
    parameter PAUSE_VAL = 32,
    parameter HALF_STEP = 1
) (
    input wire clk,
    input wire reset,
    output logic [WIDTH-1:0] count,
    output wire pause
);

    logic step;

    always @(posedge clk)
    if (reset) begin
        count <= '0;
    end else begin
        if (step) begin
            count <= count < MAX_VAL ? count + 1 : '0; 
        end
    end

    generate if(HALF_STEP) begin
        always @(posedge clk)
        if (reset) begin
            step <= '0;
        end else begin
            step <= ~step;
        end
    end else begin
        assign step = 1'b1;
    end endgenerate

    assign pause = count == PAUSE_VAL;

endmodule