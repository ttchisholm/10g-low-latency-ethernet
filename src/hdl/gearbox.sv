module gearbox #(
    parameter INPUT_WIDTH = 4,
    parameter OUTPUT_WIDTH = 8
) (
    input wire i_reset, 
    input wire i_init_done,
    input wire i_clk,
    input wire [INPUT_WIDTH-1:0] i_data,
    input wire i_slip,
    output logic [OUTPUT_WIDTH-1:0] o_data,
    output wire o_pause,
    output wire o_valid
);

    function int gcd(int a, int b);
        return (b == 0 ? a : gcd(b, a % b));
    endfunction

    localparam GCD = gcd(INPUT_WIDTH, OUTPUT_WIDTH);

    logic [INPUT_WIDTH-1:0] input_delayed;
    logic [2*INPUT_WIDTH - 1:0] output_buf;
    logic [6:0] count, count_index; //todo calc count width

    generate
        if(INPUT_WIDTH < OUTPUT_WIDTH) begin
            assign o_pause = 1'b0;

            always @(posedge i_clk) begin
                if(i_reset || !i_init_done) begin
                    input_delayed <= '0;
                    count <= '0; // Todo for debugging - set to (-2)
                    output_buf <= '0;
                end else begin
                    if (!o_valid) begin
                        count <= '0;
                    end else if(!i_slip) begin
                        count <= count + 1;
                    end

                    input_delayed <= i_data;
                    output_buf <= {i_data, input_delayed};
                end

            end

            assign o_valid = count != INPUT_WIDTH / GCD;
            assign o_data = o_valid ? output_buf[(count * GCD) +: OUTPUT_WIDTH] : '0;

        end else if (INPUT_WIDTH > OUTPUT_WIDTH) begin
            assign o_valid = 1'b1;

            always @(posedge i_clk) begin
                if(i_reset || !i_init_done) begin
                    input_delayed <= '0;
                    count <= '0;
                    output_buf <= '0;
                end else begin
                    if (o_pause) begin
                        count <= '0;
                    end else begin
                        count <= count + 1;
                        input_delayed <= i_data;
                        output_buf <= {i_data, input_delayed};
                    end
                end

            end

            assign o_pause = count == (INPUT_WIDTH / GCD) - 1;
            assign count_index =  count; 
            assign o_data = output_buf[INPUT_WIDTH - (count_index*GCD) +: OUTPUT_WIDTH];

        end else begin // INPUT_WIDTH == OUTPUT_WIDTH
            assign o_pause = 1'b0;
            assign o_valid = 1'b1;
            assign o_data = i_data;
        end


    endgenerate


endmodule
