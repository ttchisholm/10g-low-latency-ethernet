//------------------------------------------------------------------------------
//  (c) Copyright 2013-2018 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------


`timescale 1ps/1ps

// =====================================================================================================================
// This example design wrapper module instantiates the core and any helper blocks which the user chose to exclude from
// the core, connects them as appropriate, and maps enabled ports
// =====================================================================================================================

module gtwizard_ultrascale_0_example_wrapper #(
  parameter bit EXTERNAL_GEARBOX = 1
) (
  input  wire [0:0] gtyrxn_in
 ,input  wire [0:0] gtyrxp_in
 ,output wire [0:0] gtytxn_out
 ,output wire [0:0] gtytxp_out
 ,input  wire [0:0] gtwiz_userclk_tx_reset_in
 ,output wire [0:0] gtwiz_userclk_tx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_tx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_tx_active_out
 ,input  wire [0:0] gtwiz_userclk_rx_reset_in
 ,output wire [0:0] gtwiz_userclk_rx_srcclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk_out
 ,output wire [0:0] gtwiz_userclk_rx_usrclk2_out
 ,output wire [0:0] gtwiz_userclk_rx_active_out
 ,input  wire [0:0] gtwiz_buffbypass_tx_reset_in
 ,input  wire [0:0] gtwiz_buffbypass_tx_start_user_in
 ,output wire [0:0] gtwiz_buffbypass_tx_done_out
 ,output wire [0:0] gtwiz_buffbypass_tx_error_out
 ,input  wire [0:0] gtwiz_buffbypass_rx_reset_in
 ,input  wire [0:0] gtwiz_buffbypass_rx_start_user_in
 ,output wire [0:0] gtwiz_buffbypass_rx_done_out
 ,output wire [0:0] gtwiz_buffbypass_rx_error_out
 ,input  wire [0:0] gtwiz_reset_clk_freerun_in
 ,input  wire [0:0] gtwiz_reset_all_in
 ,input  wire [0:0] gtwiz_reset_tx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_tx_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_pll_and_datapath_in
 ,input  wire [0:0] gtwiz_reset_rx_datapath_in
 ,output wire [0:0] gtwiz_reset_rx_cdr_stable_out
 ,output wire [0:0] gtwiz_reset_tx_done_out
 ,output wire [0:0] gtwiz_reset_rx_done_out
 ,input  wire [31:0] gtwiz_userdata_tx_in
 ,output wire [31:0] gtwiz_userdata_rx_out
 ,input  wire [0:0] gtrefclk00_in
 ,output wire [0:0] qpll0outclk_out
 ,output wire [0:0] qpll0outrefclk_out
 ,input  wire [2:0] loopback_in
 ,input  wire [0:0] rxgearboxslip_in
 ,input  wire [5:0] txheader_in
 ,input  wire [6:0] txsequence_in
 ,output wire [0:0] gtpowergood_out
 ,output wire [1:0] rxdatavalid_out
 ,output wire [5:0] rxheader_out
 ,output wire [1:0] rxheadervalid_out
 ,output wire [0:0] rxpmaresetdone_out
 ,output wire [1:0] rxstartofseq_out
 ,output wire [0:0] txpmaresetdone_out
 ,output wire [0:0] txprgdivresetdone_out
);


  // ===================================================================================================================
  // PARAMETERS AND FUNCTIONS
  // ===================================================================================================================

  // Declare and initialize local parameters and functions used for HDL generation
  localparam [191:0] P_CHANNEL_ENABLE = 192'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000;
  // `include "gtwizard_ultrascale_0_example_wrapper_functions.v"
  // localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(12);
  // localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(12);


  // ===================================================================================================================
  // HELPER BLOCKS
  // ===================================================================================================================

  // Any helper blocks which the user chose to exclude from the core will appear below. In addition, some signal
  // assignments related to optionally-enabled ports may appear below.
  wire [0:0] gtpowergood_int;

  // Required assignment to expose the GTPOWERGOOD port per user request
  assign gtpowergood_out = gtpowergood_int;

  // ===================================================================================================================
  // CORE INSTANCE
  // ===================================================================================================================

  // Instantiate the core, mapping its enabled ports to example design ports and helper blocks as appropriate

  generate if (EXTERNAL_GEARBOX) begin
      gtwizard_ultrascale_0 gtwizard_ultrascale_0_inst (
      .gtyrxn_in                               (gtyrxn_in)
      ,.gtyrxp_in                               (gtyrxp_in)
      ,.gtytxn_out                              (gtytxn_out)
      ,.gtytxp_out                              (gtytxp_out)
      ,.gtwiz_userclk_tx_reset_in               (gtwiz_userclk_tx_reset_in)
      ,.gtwiz_userclk_tx_srcclk_out             (gtwiz_userclk_tx_srcclk_out)
      ,.gtwiz_userclk_tx_usrclk_out             (gtwiz_userclk_tx_usrclk_out)
      ,.gtwiz_userclk_tx_usrclk2_out            (gtwiz_userclk_tx_usrclk2_out)
      ,.gtwiz_userclk_tx_active_out             (gtwiz_userclk_tx_active_out)
      ,.gtwiz_userclk_rx_reset_in               (gtwiz_userclk_rx_reset_in)
      ,.gtwiz_userclk_rx_srcclk_out             (gtwiz_userclk_rx_srcclk_out)
      ,.gtwiz_userclk_rx_usrclk_out             (gtwiz_userclk_rx_usrclk_out)
      ,.gtwiz_userclk_rx_usrclk2_out            (gtwiz_userclk_rx_usrclk2_out)
      ,.gtwiz_userclk_rx_active_out             (gtwiz_userclk_rx_active_out)
      ,.gtwiz_buffbypass_tx_reset_in            (gtwiz_buffbypass_tx_reset_in)
      ,.gtwiz_buffbypass_tx_start_user_in       (gtwiz_buffbypass_tx_start_user_in)
      ,.gtwiz_buffbypass_tx_done_out            (gtwiz_buffbypass_tx_done_out)
      ,.gtwiz_buffbypass_tx_error_out           (gtwiz_buffbypass_tx_error_out)
      ,.gtwiz_buffbypass_rx_reset_in            (gtwiz_buffbypass_rx_reset_in)
      ,.gtwiz_buffbypass_rx_start_user_in       (gtwiz_buffbypass_rx_start_user_in)
      ,.gtwiz_buffbypass_rx_done_out            (gtwiz_buffbypass_rx_done_out)
      ,.gtwiz_buffbypass_rx_error_out           (gtwiz_buffbypass_rx_error_out)
      ,.gtwiz_reset_clk_freerun_in              (gtwiz_reset_clk_freerun_in)
      ,.gtwiz_reset_all_in                      (gtwiz_reset_all_in)
      ,.gtwiz_reset_tx_pll_and_datapath_in      (gtwiz_reset_tx_pll_and_datapath_in)
      ,.gtwiz_reset_tx_datapath_in              (gtwiz_reset_tx_datapath_in)
      ,.gtwiz_reset_rx_pll_and_datapath_in      (gtwiz_reset_rx_pll_and_datapath_in)
      ,.gtwiz_reset_rx_datapath_in              (gtwiz_reset_rx_datapath_in)
      ,.gtwiz_reset_rx_cdr_stable_out           (gtwiz_reset_rx_cdr_stable_out)
      ,.gtwiz_reset_tx_done_out                 (gtwiz_reset_tx_done_out)
      ,.gtwiz_reset_rx_done_out                 (gtwiz_reset_rx_done_out)
      ,.gtwiz_userdata_tx_in                    (gtwiz_userdata_tx_in)
      ,.gtwiz_userdata_rx_out                   (gtwiz_userdata_rx_out)
      ,.gtrefclk00_in                           (gtrefclk00_in)
      ,.qpll0outclk_out                         (qpll0outclk_out)
      ,.qpll0outrefclk_out                      (qpll0outrefclk_out)
      ,.rxgearboxslip_in                        (rxgearboxslip_in)
      ,.txheader_in                             (txheader_in)
      ,.txsequence_in                           (txsequence_in)
      ,.gtpowergood_out                         (gtpowergood_int)
      ,.rxdatavalid_out                         (rxdatavalid_out)
      ,.rxheader_out                            (rxheader_out)
      ,.rxheadervalid_out                       (rxheadervalid_out)
      ,.rxpmaresetdone_out                      (rxpmaresetdone_out)
      ,.rxstartofseq_out                        (rxstartofseq_out)
      ,.txpmaresetdone_out                      (txpmaresetdone_out)
      ,.txprgdivresetdone_out                   (txprgdivresetdone_out)
      ,.loopback_in                             (loopback_in)
    );
  end else begin
    gtwizard_ultrascale_0 gtwizard_ultrascale_0_inst (
      .gtyrxn_in                               (gtyrxn_in)
      ,.gtyrxp_in                               (gtyrxp_in)
      ,.gtytxn_out                              (gtytxn_out)
      ,.gtytxp_out                              (gtytxp_out)
      ,.gtwiz_userclk_tx_reset_in               (gtwiz_userclk_tx_reset_in)
      ,.gtwiz_userclk_tx_srcclk_out             (gtwiz_userclk_tx_srcclk_out)
      ,.gtwiz_userclk_tx_usrclk_out             (gtwiz_userclk_tx_usrclk_out)
      ,.gtwiz_userclk_tx_usrclk2_out            (gtwiz_userclk_tx_usrclk2_out)
      ,.gtwiz_userclk_tx_active_out             (gtwiz_userclk_tx_active_out)
      ,.gtwiz_userclk_rx_reset_in               (gtwiz_userclk_rx_reset_in)
      ,.gtwiz_userclk_rx_srcclk_out             (gtwiz_userclk_rx_srcclk_out)
      ,.gtwiz_userclk_rx_usrclk_out             (gtwiz_userclk_rx_usrclk_out)
      ,.gtwiz_userclk_rx_usrclk2_out            (gtwiz_userclk_rx_usrclk2_out)
      ,.gtwiz_userclk_rx_active_out             (gtwiz_userclk_rx_active_out)
      ,.gtwiz_buffbypass_tx_reset_in            (gtwiz_buffbypass_tx_reset_in)
      ,.gtwiz_buffbypass_tx_start_user_in       (gtwiz_buffbypass_tx_start_user_in)
      ,.gtwiz_buffbypass_tx_done_out            (gtwiz_buffbypass_tx_done_out)
      ,.gtwiz_buffbypass_tx_error_out           (gtwiz_buffbypass_tx_error_out)
      ,.gtwiz_buffbypass_rx_reset_in            (gtwiz_buffbypass_rx_reset_in)
      ,.gtwiz_buffbypass_rx_start_user_in       (gtwiz_buffbypass_rx_start_user_in)
      ,.gtwiz_buffbypass_rx_done_out            (gtwiz_buffbypass_rx_done_out)
      ,.gtwiz_buffbypass_rx_error_out           (gtwiz_buffbypass_rx_error_out)
      ,.gtwiz_reset_clk_freerun_in              (gtwiz_reset_clk_freerun_in)
      ,.gtwiz_reset_all_in                      (gtwiz_reset_all_in)
      ,.gtwiz_reset_tx_pll_and_datapath_in      (gtwiz_reset_tx_pll_and_datapath_in)
      ,.gtwiz_reset_tx_datapath_in              (gtwiz_reset_tx_datapath_in)
      ,.gtwiz_reset_rx_pll_and_datapath_in      (gtwiz_reset_rx_pll_and_datapath_in)
      ,.gtwiz_reset_rx_datapath_in              (gtwiz_reset_rx_datapath_in)
      ,.gtwiz_reset_rx_cdr_stable_out           (gtwiz_reset_rx_cdr_stable_out)
      ,.gtwiz_reset_tx_done_out                 (gtwiz_reset_tx_done_out)
      ,.gtwiz_reset_rx_done_out                 (gtwiz_reset_rx_done_out)
      ,.gtwiz_userdata_tx_in                    (gtwiz_userdata_tx_in)
      ,.gtwiz_userdata_rx_out                   (gtwiz_userdata_rx_out)
      ,.gtrefclk00_in                           (gtrefclk00_in)
      ,.qpll0outclk_out                         (qpll0outclk_out)
      ,.qpll0outrefclk_out                      (qpll0outrefclk_out)
      ,.gtpowergood_out                         (gtpowergood_int)
      ,.rxpmaresetdone_out                      (rxpmaresetdone_out)
      ,.txpmaresetdone_out                      (txpmaresetdone_out)
      ,.txprgdivresetdone_out                   (txprgdivresetdone_out)
      ,.loopback_in                             (loopback_in)
    );

    assign rxdatavalid_out = gtwiz_reset_tx_done_out ? 1'b1 : 1'b0;
    assign rxheader_out = 2'b0;
    assign rxheadervalid_out = 1'b0;
    assign rxstartofseq_out = 2'b0;

  end endgenerate


endmodule
