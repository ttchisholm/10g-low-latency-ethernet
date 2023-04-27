`timescale 1ns/1ps
`default_nettype none

module lock_state(
    input wire i_clk,
    input wire i_reset,
    input wire [1:0] i_header,
    input wire i_valid,
    
    output wire o_slip
);

    typedef enum logic[3:0] { LOCK_INIT, RESET_CNT, TEST_SH, 
        VALID_SH, INVALID_SH, GOOD_64, SLIP, X='x, Z='z} lock_state_t;

    lock_state_t state, next_state;
    logic rx_block_lock, test_sh, slip_done;
    logic [15:0] sh_cnt, sh_invalid_cnt;
    wire sh_valid;

    assign sh_valid = (i_header[1] ^ i_header[0]);
    assign o_slip = (state == SLIP);

    always @(posedge i_clk) begin
        if(i_reset) begin
            state <= LOCK_INIT;
        end else begin
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
                // Must use if..else here to avoid unknown propagation into enum
                if (!i_valid) begin
                    next_state = TEST_SH;
                end if (sh_valid) begin
                    next_state = VALID_SH;
                end else begin
                    next_state = INVALID_SH;    
                end
            end
            VALID_SH: begin
                // Minor change here as going back to TEST_SH would miss data
                // next_state = sh_cnt == 64 && sh_invalid_cnt == 0 ? GOOD_64 : 
                //              sh_cnt == 64 && sh_invalid_cnt != 0 ? RESET_CNT :
                //              sh_cnt < 64 && !sh_valid ? INVALID_SH : VALID_SH;

                // if (sh_cnt == 15'd10) begin
                //     next_state = SLIP;
                // end else begin
                //     next_state = VALID_SH;
                // end

                if (!i_valid) begin
                    next_state = VALID_SH;
                end if (sh_cnt == 64 && sh_invalid_cnt == 0) begin
                    next_state = GOOD_64;
                end else if (sh_cnt == 64 && sh_invalid_cnt != 0) begin
                    next_state = RESET_CNT;
                end else if (sh_cnt < 64 && !sh_valid) begin
                    next_state = INVALID_SH;
                end else begin
                    next_state = VALID_SH;
                end
            end
            INVALID_SH: begin
                // next_state = sh_cnt == 64 && sh_invalid_cnt < 16 ? RESET_CNT :
                //              sh_invalid_cnt == 16 ? SLIP :
                //              sh_cnt < 64 && !sh_valid ? INVALID_SH : VALID_SH;

                if (!i_valid) begin
                    next_state = INVALID_SH;
                end if (sh_cnt == 64 && sh_invalid_cnt < 16) begin
                    next_state = RESET_CNT; 
                end else if (sh_invalid_cnt == 16) begin
                    next_state = SLIP;
                end else if (sh_cnt < 64 && !sh_valid) begin
                    next_state = INVALID_SH;
                end else begin
                    next_state = VALID_SH;
                end
            end
            GOOD_64: begin
                next_state = RESET_CNT;
            end
            SLIP: begin
                next_state = RESET_CNT;
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
        end else begin
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
                    sh_cnt <= (i_valid) ? sh_cnt + 1 : sh_cnt;
                end
                INVALID_SH: begin
                    sh_cnt <= (i_valid) ? sh_cnt + 1 : sh_cnt;
                    sh_invalid_cnt <= (i_valid) ? sh_invalid_cnt + 1 : sh_invalid_cnt;
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