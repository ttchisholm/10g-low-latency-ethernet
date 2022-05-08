package encoder_pkg;
     //********** Code Definitions **********//

    typedef enum logic [1:0] {
        SYNC_DATA = 2'b10,
        SYNC_CTL = 2'b01
    } sync_t;

    // Block Type
    typedef enum logic [7:0] {
        BT_IDLE = 8'h1e,
        BT_O4   = 8'h2d,
        BT_S4   = 8'h33,
        BT_O0S4 = 8'h66,
        BT_O0O4 = 8'h55,
        BT_S0   = 8'h78,
        BT_O0   = 8'h4b,
        BT_T0   = 8'h87,
        BT_T1   = 8'h99,
        BT_T2   = 8'haa,
        BT_T3   = 8'hb4,
        BT_T4   = 8'hcc,
        BT_T5   = 8'hd2,
        BT_T6   = 8'he1,
        BT_T7   = 8'hff
    } block_type_t;

    // Control Codes
    typedef enum logic [6:0] {
        CC_IDLE = 7'b00,
        CC_LPI = 7'h06,
        CC_ERROR = 7'h1e,
        CC_RES0 = 7'h2d,
        CC_RES1 = 7'h33,
        CC_RES2 = 7'h4b,
        CC_RES3 = 7'h55,
        CC_RES4 = 7'h66,
        CC_RES5 = 7'h78
    } control_code_t;

    // O-Codes
    typedef enum logic [3:0] {
        OC_SEQ = 4'h0,
        OC_SIG = 4'hf
    } o_code_t;

    // RS Codes
    typedef enum logic [7:0] {
        RS_IDLE = 8'h07,
        RS_LPI = 8'h06,
        RS_START = 8'hfb,
        RS_TERM = 8'hfd,
        RS_ERROR = 8'hfe,
        RS_OSEQ = 8'h9c,
        RS_RES0 = 8'h1c,
        RS_RES1 = 8'h3c,
        RS_RES2 = 8'h7c,
        RS_RES3 = 8'hbc,
        RS_RES4 = 8'hdc,
        RS_RES5 = 8'hf7,
        RS_OSIG = 8'h5c
    } rs_code_t;


endpackage