# !/bin/sh

export ETH10G_FPGA_PART=xczu49dr-ffvf1760-2-e
export ETH10G_CHANNEL=X0Y12

mkdir -p gen
cd gen
vivado -mode tcl -source ../eth_10g_ip.tcl