# !/bin/sh

# Ensure IP is built using src/ip/gen_eth_10g_ip and part matches below.

# Default build parameters
export FPGA_PART=xczu49dr-ffvf1760-2-e
export SCRAMBLER_BYPASS=0
export EXTERNAL_GEARBOX=0
export TX_XVER_BUFFER=0
export INIT_CLK_FREQ=100.0

# get arguments k=v
build_config=""
for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)

   KEY_LENGTH=${#KEY}
   VALUE="${ARGUMENT:$KEY_LENGTH+1}"

   export "$KEY"="$VALUE"

   build_config="${build_config}-${KEY}_${VALUE}"
done

mkdir -p build$build_config
cd build$build_config
vivado -mode tcl -source ../example_10g_eth_build.tcl -notrace