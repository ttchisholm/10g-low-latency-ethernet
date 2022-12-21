module serdes (

    input wire i_reset,

    // PCS
    output wire pcs_rxc,
    output wire [63:0] pcs_rxd,
    output wire pcs_txc,
    input wire [63:0] pcs_txd,

    // Serial
    input wire gty_rxp,
    input wire gty_rxn,
    output wire gty_txp,
    output wire gty_txn,
    
    // Ref
    input wire mgt_refclk_p,
    input wire mgt_refclk_n
);

    // Todo
    /*
        // reset order - gty then buffbypass ug578 pg 142

        Inputs:
                // input wire [0 : 0] gtwiz_userclk_tx_reset_in                 - high until srcclk stable
                // input wire [0 : 0] gtwiz_userclk_rx_reset_in                 - high until srcclk stable
                // input wire [0 : 0] gtwiz_buffbypass_tx_reset_in              - release after usrclk stable. sync to txusrclk2 "This signal should be released as soon as TXUSRCLK2 is stable, and before the transmitter datapath reset sequence completes for all channels."
                // input wire [0 : 0] gtwiz_buffbypass_tx_start_user_in         - high pulse to start reset. sync to txusrclk2 - shouldn't be needed if working on reset
                // input wire [0 : 0] gtwiz_buffbypass_rx_reset_in              - release after usrclk stable. sync to rxusrclk2 
                // input wire [0 : 0] gtwiz_buffbypass_rx_start_user_in         - high pulse to start reset. sync to rxusrclk2 - shouldn't be needed if working on reset
                // input wire [0 : 0] gtwiz_reset_clk_freerun_in                - free runnning clk for reset f < usrclk (100M?). Use for reset block
                // input wire [0 : 0] gtwiz_reset_all_in                        - high pulse (clk_freerun_in) to reset. Async
                // input wire [0 : 0] gtwiz_reset_tx_pll_and_datapath_in        - as above
                // input wire [0 : 0] gtwiz_reset_tx_datapath_in                - as above
                // input wire [0 : 0] gtwiz_reset_rx_pll_and_datapath_in        - as above
                // input wire [0 : 0] gtwiz_reset_rx_datapath_in                - as above
                // input wire [63 : 0] gtwiz_userdata_tx_in                     - -> pcs_txd
                // input wire [0 : 0] gtrefclk00_in                             - -> mgt_refclk (after ibuf)
                // input wire [0 : 0] gtyrxn_in                                 - -> gty_rxn
                // input wire [0 : 0] gtyrxp_in                                 - -> gty_rxp

    Outputs:
                // output wire [0 : 0] gtwiz_userclk_tx_srcclk_out              - txoutclk (unconnected)
                // output wire [0 : 0] gtwiz_userclk_tx_usrclk_out              - txusrclk (unconnected)
                // output wire [0 : 0] gtwiz_userclk_tx_usrclk2_out             - txusrclk2 -> pcs_txc
                // output wire [0 : 0] gtwiz_userclk_tx_active_out              - clks ready -> ILA
                // output wire [0 : 0] gtwiz_userclk_rx_srcclk_out              
                // output wire [0 : 0] gtwiz_userclk_rx_usrclk_out
                // output wire [0 : 0] gtwiz_userclk_rx_usrclk2_out
                // output wire [0 : 0] gtwiz_userclk_rx_active_out
                // output wire [0 : 0] gtwiz_buffbypass_tx_done_out            - -> ILA
                // output wire [0 : 0] gtwiz_buffbypass_tx_error_out           - -> ILA
                // output wire [0 : 0] gtwiz_buffbypass_rx_done_out            - -> ILA
                // output wire [0 : 0] gtwiz_buffbypass_rx_error_out           - -> ILA
                // output wire [0 : 0] gtwiz_reset_rx_cdr_stable_out            - Reserved
                // output wire [0 : 0] gtwiz_reset_tx_done_out                  - prim reset done. txusrclk2
                // output wire [0 : 0] gtwiz_reset_rx_done_out                  - prim reset done. rxusrclk2 
                // output wire [63 : 0] gtwiz_userdata_rx_out                   - -> pcs_rxd
                // output wire [0 : 0] qpll0outclk_out                          - Unconnected (or to other quad)
                // output wire [0 : 0] qpll0outrefclk_out                       - Unconnected (or to other quad)
                // output wire [0 : 0] gtpowergood_out
                // output wire [0 : 0] gtytxn_out                               - -> gty_rxn
                // output wire [0 : 0] gtytxp_out                               - -> gty_rxp
                // output wire [0 : 0] rxpmaresetdone_out                       - -> ILA (or to other quad)
                // output wire [0 : 0] txpmaresetdone_out                       - -> ILA (or to other quad)
                // output wire [0 : 0] txprgdivresetdone_out                    - -> ILA (or to other quad)
    */

    // Use gtwizard_ultrascale_0_example_wrapper.v

    // Use clk buf from example design (example_top)

    // Use buffbypass reset from example design (example_top)



    gtwizard_ultrascale_0 your_instance_name (
  .gtwiz_userclk_tx_reset_in(gtwiz_userclk_tx_reset_in),                    // input wire [0 : 0] gtwiz_userclk_tx_reset_in
  .gtwiz_userclk_tx_srcclk_out(gtwiz_userclk_tx_srcclk_out),                // output wire [0 : 0] gtwiz_userclk_tx_srcclk_out
  .gtwiz_userclk_tx_usrclk_out(gtwiz_userclk_tx_usrclk_out),                // output wire [0 : 0] gtwiz_userclk_tx_usrclk_out
  .gtwiz_userclk_tx_usrclk2_out(gtwiz_userclk_tx_usrclk2_out),              // output wire [0 : 0] gtwiz_userclk_tx_usrclk2_out
  .gtwiz_userclk_tx_active_out(gtwiz_userclk_tx_active_out),                // output wire [0 : 0] gtwiz_userclk_tx_active_out
  .gtwiz_userclk_rx_reset_in(gtwiz_userclk_rx_reset_in),                    // input wire [0 : 0] gtwiz_userclk_rx_reset_in
  .gtwiz_userclk_rx_srcclk_out(gtwiz_userclk_rx_srcclk_out),                // output wire [0 : 0] gtwiz_userclk_rx_srcclk_out
  .gtwiz_userclk_rx_usrclk_out(gtwiz_userclk_rx_usrclk_out),                // output wire [0 : 0] gtwiz_userclk_rx_usrclk_out
  .gtwiz_userclk_rx_usrclk2_out(gtwiz_userclk_rx_usrclk2_out),              // output wire [0 : 0] gtwiz_userclk_rx_usrclk2_out
  .gtwiz_userclk_rx_active_out(gtwiz_userclk_rx_active_out),                // output wire [0 : 0] gtwiz_userclk_rx_active_out
  .gtwiz_buffbypass_tx_reset_in(gtwiz_buffbypass_tx_reset_in),              // input wire [0 : 0] gtwiz_buffbypass_tx_reset_in
  .gtwiz_buffbypass_tx_start_user_in(gtwiz_buffbypass_tx_start_user_in),    // input wire [0 : 0] gtwiz_buffbypass_tx_start_user_in
  .gtwiz_buffbypass_tx_done_out(gtwiz_buffbypass_tx_done_out),              // output wire [0 : 0] gtwiz_buffbypass_tx_done_out
  .gtwiz_buffbypass_tx_error_out(gtwiz_buffbypass_tx_error_out),            // output wire [0 : 0] gtwiz_buffbypass_tx_error_out
  .gtwiz_buffbypass_rx_reset_in(gtwiz_buffbypass_rx_reset_in),              // input wire [0 : 0] gtwiz_buffbypass_rx_reset_in
  .gtwiz_buffbypass_rx_start_user_in(gtwiz_buffbypass_rx_start_user_in),    // input wire [0 : 0] gtwiz_buffbypass_rx_start_user_in
  .gtwiz_buffbypass_rx_done_out(gtwiz_buffbypass_rx_done_out),              // output wire [0 : 0] gtwiz_buffbypass_rx_done_out
  .gtwiz_buffbypass_rx_error_out(gtwiz_buffbypass_rx_error_out),            // output wire [0 : 0] gtwiz_buffbypass_rx_error_out
  .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),                  // input wire [0 : 0] gtwiz_reset_clk_freerun_in
  .gtwiz_reset_all_in(gtwiz_reset_all_in),                                  // input wire [0 : 0] gtwiz_reset_all_in
  .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),  // input wire [0 : 0] gtwiz_reset_tx_pll_and_datapath_in
  .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),                  // input wire [0 : 0] gtwiz_reset_tx_datapath_in
  .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),  // input wire [0 : 0] gtwiz_reset_rx_pll_and_datapath_in
  .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),                  // input wire [0 : 0] gtwiz_reset_rx_datapath_in
  .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),            // output wire [0 : 0] gtwiz_reset_rx_cdr_stable_out
  .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),                        // output wire [0 : 0] gtwiz_reset_tx_done_out
  .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),                        // output wire [0 : 0] gtwiz_reset_rx_done_out
  .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),                              // input wire [63 : 0] gtwiz_userdata_tx_in
  .gtwiz_userdata_rx_out(gtwiz_userdata_rx_out),                            // output wire [63 : 0] gtwiz_userdata_rx_out
  .gtrefclk00_in(gtrefclk00_in),                                            // input wire [0 : 0] gtrefclk00_in
  .qpll0outclk_out(qpll0outclk_out),                                        // output wire [0 : 0] qpll0outclk_out
  .qpll0outrefclk_out(qpll0outrefclk_out),                                  // output wire [0 : 0] qpll0outrefclk_out
  .gtyrxn_in(gtyrxn_in),                                                    // input wire [0 : 0] gtyrxn_in
  .gtyrxp_in(gtyrxp_in),                                                    // input wire [0 : 0] gtyrxp_in
  .gtpowergood_out(gtpowergood_out),                                        // output wire [0 : 0] gtpowergood_out
  .gtytxn_out(gtytxn_out),                                                  // output wire [0 : 0] gtytxn_out
  .gtytxp_out(gtytxp_out),                                                  // output wire [0 : 0] gtytxp_out
  .rxpmaresetdone_out(rxpmaresetdone_out),                                  // output wire [0 : 0] rxpmaresetdone_out
  .txpmaresetdone_out(txpmaresetdone_out),                                  // output wire [0 : 0] txpmaresetdone_out
  .txprgdivresetdone_out(txprgdivresetdone_out)                            // output wire [0 : 0] txprgdivresetdone_out
);


endmodule