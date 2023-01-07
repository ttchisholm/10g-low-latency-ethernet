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


// =====================================================================================================================
// This file contains functions available for example design HDL generation as required
// =====================================================================================================================

// Function to populate a bit mapping of enabled transceiver common blocks to transceiver quads
function [47:0] f_pop_cm_en (
  input integer in_null
);
begin : main_f_pop_cm_en
  integer i;
  reg [47:0] tmp;
  for (i = 0; i < 192; i = i + 4) begin
    if ((P_CHANNEL_ENABLE[i]   ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+1] ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+2] ==  1'b1) ||
        (P_CHANNEL_ENABLE[i+3] ==  1'b1))
      tmp[i/4] = 1'b1;
    else
      tmp[i/4] = 1'b0;
  end
  f_pop_cm_en = tmp;
end
endfunction

// Function to calculate a pointer to a master channel's packed index
function integer f_calc_pk_mc_idx (
  input integer idx_mc
);
begin : main_f_calc_pk_mc_idx
  integer i, j;
  integer tmp;
  j = 0;
  for (i = 0; i < 192; i = i + 1) begin
    if (P_CHANNEL_ENABLE[i] == 1'b1) begin
      if (i == idx_mc)
        tmp = j;
      else
        j = j + 1;
    end
  end
  f_calc_pk_mc_idx = tmp;
end
endfunction

// Function to calculate the upper bound of a transceiver common-related signal within a packed vector, for a given
// signal width and unpacked common index
function integer f_ub_cm (
  input integer width,
  input integer index
);
begin : main_f_ub_cm
  integer i, j;
  j = 0;
  for (i = 0; i <= index; i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1)
      j = j + 1;
  end
  f_ub_cm = (width * j) - 1;
end
endfunction

// Function to calculate the lower bound of a transceiver common-related signal within a packed vector, for a given
// signal width and unpacked common index
function integer f_lb_cm (
  input integer width,
  input integer index
);
begin : main_f_lb_cm
  integer i, j;
  j = 0;
  for (i = 0; i < index; i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1)
      j = j + 1;
  end
  f_lb_cm = (width * j);
end
endfunction

// Function to calculate the packed vector index of a transceiver common, provided the packed vector index of the
// associated transceiver channel
function integer f_idx_cm (
  input integer index
);
begin : main_f_idx_cm
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin
    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (P_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+2] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+1] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i]   == 1'b1)
        j = j + 1;
    end

    if (j >= (index + 1)) begin
      flag   = 1;
      result = k;
    end
  end
  f_idx_cm = result - 1;
end
endfunction

// Function to calculate the packed vector index of the upper bound transceiver channel which is associated with the
// provided transceiver common packed vector index
function integer f_idx_ch_ub (
  input integer index
);
begin : main_f_idx_ch_ub
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin

    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (P_CHANNEL_ENABLE[i]   == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+1] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+2] == 1'b1)
        j = j + 1;
      if (P_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
      if (k == index + 1) begin
        flag   = 1;
        result = j;
      end
    end

  end
  f_idx_ch_ub = result - 1;
end
endfunction

// Function to calculate the packed vector index of the lower bound transceiver channel which is associated with the
// provided transceiver common packed vector index
function integer f_idx_ch_lb (
  input integer index
);
begin : main_f_idx_ch_lb
  integer i, j, k, flag, result;
  j    = 0;
  k    = 0;
  flag = 0;
  for (i = 0; (i < 192) && (flag == 0); i = i + 4) begin

    if (P_CHANNEL_ENABLE[i]   == 1'b1 ||
        P_CHANNEL_ENABLE[i+1] == 1'b1 ||
        P_CHANNEL_ENABLE[i+2] == 1'b1 ||
        P_CHANNEL_ENABLE[i+3] == 1'b1) begin
      k = k + 1;
      if (k == index + 1) begin
        flag   = 1;
        result = j + 1;
      end
      else begin
        if (P_CHANNEL_ENABLE[i]   == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+1] == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+2] == 1'b1)
          j = j + 1;
        if (P_CHANNEL_ENABLE[i+3] == 1'b1)
          j = j + 1;
      end
    end

  end
  f_idx_ch_lb = result - 1;
end
endfunction
