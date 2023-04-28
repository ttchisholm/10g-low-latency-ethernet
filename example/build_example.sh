# !/bin/sh

# Ensure IP is built using src/ip/gen_eth_10g_ip and part matches below.

export ETH10G_FPGA_PART=xczu49dr-ffvf1760-2-e

mkdir -p build
cd build
vivado -mode tcl -source ../example_10g_eth_build.tcl -notrace