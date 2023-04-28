// MIT License

// Copyright (c) 2023 Tom Chisholm

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/*
*   Package: code_defs_pkg
*
*   Description: Collection of definitions for 10G Ethernet
*
*/

`ifndef CODE_DEFS_PACKAGE
`define CODE_DEFS_PACKAGE

package code_defs_pkg;

    typedef enum logic [1:0]
        { SYNC_DATA = 2'b10
        , SYNC_CTL = 2'b01
        } sync_t;

    // Block Type
    typedef enum logic [7:0]
        { BT_IDLE = 8'h1e
        , BT_O4   = 8'h2d
        , BT_S4   = 8'h33
        , BT_O0S4 = 8'h66
        , BT_O0O4 = 8'h55
        , BT_S0   = 8'h78
        , BT_O0   = 8'h4b
        , BT_T0   = 8'h87
        , BT_T1   = 8'h99
        , BT_T2   = 8'haa
        , BT_T3   = 8'hb4
        , BT_T4   = 8'hcc
        , BT_T5   = 8'hd2
        , BT_T6   = 8'he1
        , BT_T7   = 8'hff
        } block_type_t;

    // Control Codes
    typedef enum logic [6:0]
        { CC_IDLE = 7'b00
        , CC_LPI = 7'h06
        , CC_ERROR = 7'h1e
        , CC_RES0 = 7'h2d
        , CC_RES1 = 7'h33
        , CC_RES2 = 7'h4b
        , CC_RES3 = 7'h55
        , CC_RES4 = 7'h66
        , CC_RES5 = 7'h78
        } control_code_t;

    // O-Codes
    typedef enum logic [3:0]
        { OC_SEQ = 4'h0
        , OC_SIG = 4'hf
        } o_code_t;

    // RS Codes
    typedef enum logic [7:0]
        { RS_IDLE = 8'h07
        , RS_LPI = 8'h06
        , RS_START = 8'hfb
        , RS_TERM = 8'hfd
        , RS_ERROR = 8'hfe
        , RS_OSEQ = 8'h9c
        , RS_RES0 = 8'h1c
        , RS_RES1 = 8'h3c
        , RS_RES2 = 8'h7c
        , RS_RES3 = 8'hbc
        , RS_RES4 = 8'hdc
        , RS_RES5 = 8'hf7
        , RS_OSIG = 8'h5c
        } rs_code_t;

    // MAC Codes
    typedef enum logic [7:0]
        { MAC_PRE = 8'h55
        , MAC_SFD = 8'hd5
        } mac_code_t;

    // todo can we use enum types?
    function automatic logic [7:0] control_to_rs_code(logic [6:0] icode);
        case (icode)
            CC_IDLE:    return RS_IDLE;
            CC_LPI:     return RS_LPI;
            CC_ERROR:   return RS_ERROR;
            CC_RES0:    return RS_RES0;
            CC_RES1:    return RS_RES1;
            CC_RES2:    return RS_RES2;
            CC_RES3:    return RS_RES3;
            CC_RES4:    return RS_RES4;
            CC_RES5:    return RS_RES5;
            default: begin
                return RS_IDLE;
            end
        endcase
    endfunction

    function automatic logic [3:0] rs_to_cc_ocode (input logic [7:0] rs_code);
        return rs_code == RS_OSEQ ? OC_SEQ : OC_SIG;
    endfunction

    function automatic logic [7:0] cc_to_rs_ocode (input logic [3:0] cc_ocode);
        return cc_ocode == OC_SEQ ? RS_OSEQ : RS_OSIG;
    endfunction

endpackage

`endif
