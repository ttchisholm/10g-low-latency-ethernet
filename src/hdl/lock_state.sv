module lock_state(
    input i_clk,
    input i_reset,
    input [1:0] i_header,
    input i_valid,
    
    output o_slip
);

    typedef enum logic[3:0] { LOCK_INIT, RESET_CNT, TEST_SH, 
        VALID_SH, INVALID_SH, GOOD_64, SLIP} lock_state_t;

    lock_state_t state, next_state;
    logic rx_block_lock, test_sh, slip_done;
    logic [15:0] sh_cnt, sh_invalid_cnt;
    wire sh_valid;

    assign sh_valid = (i_header[1] ^ i_header[0]);
    assign o_slip = (state == SLIP);

    always @(posedge i_clk) begin
        if(i_reset) begin
            state <= LOCK_INIT;
        end else if(i_valid) begin
            state <= next_state;

        end
    end

    always_comb begin
        case (state)
            LOCK_INIT: begin
                next_state = RESET_CNT;
            end
            RESET_CNT: begin
                next_state = TEST_SH;
            end
            TEST_SH: begin
               next_state = sh_valid ? VALID_SH : INVALID_SH;
            end
            VALID_SH: begin
                // Minor change here as going back to TEST_SH would miss data
                next_state = sh_cnt == 64 && sh_invalid_cnt == 0 ? GOOD_64 : 
                             sh_cnt == 64 && sh_invalid_cnt != 0 ? RESET_CNT :
                             sh_cnt < 64 && !sh_valid ? INVALID_SH : VALID_SH;
            end
            INVALID_SH: begin
                next_state = sh_cnt == 64 && sh_invalid_cnt < 16 ? RESET_CNT :
                             sh_invalid_cnt == 16 ? SLIP :
                             sh_cnt < 64 && !sh_valid ? INVALID_SH : VALID_SH;
            end
            GOOD_64: begin
                next_state <= RESET_CNT;
            end
            SLIP: begin
                next_state <= RESET_CNT;
            end
            default: begin
                next_state = LOCK_INIT;
            end
            endcase

    end

    always @(posedge i_clk) begin
        if(i_reset) begin
            rx_block_lock <= 1'b0;
            test_sh <= 1'b0;
            sh_cnt <= 0;
            sh_invalid_cnt <= 0;
            slip_done <= 1'b0;
        end else if(i_valid) begin
            case (state)
                LOCK_INIT: begin
                    rx_block_lock <= 1'b0;
                    test_sh <= 1'b0;
                end
                RESET_CNT: begin
                    sh_cnt <= 0;
                    sh_invalid_cnt <= 0;
                    slip_done <= 1'b0;
                end
                TEST_SH: begin
                    test_sh <= 1'b0;
                end
                VALID_SH: begin
                    sh_cnt <= sh_cnt + 1;
                end
                INVALID_SH: begin
                    sh_cnt <= sh_cnt + 1;
                    sh_invalid_cnt <= sh_invalid_cnt + 1;
                end
                GOOD_64: begin
                    rx_block_lock <= 1'b0;
                end
                SLIP: begin
                    rx_block_lock <= 1'b0;
                end
                default: begin
                    rx_block_lock <= 1'b0;
                    test_sh <= 1'b0;
                    sh_cnt <= 0;
                    sh_invalid_cnt <= 0;
                    slip_done <= 1'b0;
                end
            endcase
        end
    end

endmodule