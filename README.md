# 10G Low Latency Ethernet

[![cocotb-test](https://github.com/ttchisholm/10g-low-latency-ethernet/actions/workflows/cocotb-test.yaml/badge.svg?branch=master)](https://github.com/ttchisholm/10g-low-latency-ethernet/actions/workflows/cocotb-test.yaml)

## Overview

For more information, refer to my blog series for this project - [Designing a Low Latency 10G Ethernet Core - Part 1 (Introduction)](https://ttchisholm.github.io/ethernet/2023/05/01/designing-10g-eth-1.html)

This repository contains:
- A low latency 10G Ethernet MAC/PCS, written in SystemVerilog and tested with pyuvm/cocotb
- An integrated low latency 10G Ethernet core, with MAC/PCS and GTY wrapper/IP for Xilinx UltraScale+
- An example design containing packet latency measurement in loopback

Repository structure:

```
.github/        # GitHub workflow
example/        # Example design
src/            # Ethernet core source
    hdl/            # HDL source
    ip/             # IP generation
    lib/            # Submodules
    tb/             # Testbenches
```

## Example Design

**Building the example design:**

1. Clone the slicing_crc submodule

```console
git submodule update --init --recursive
```

2. Generate GTY IP. Set the FPGA part and GTY channel in *src/ip/gen_eth_10g_ip.sh* and run

```console
cd src/ip  
./gen_eth_10g_ip.sh
```

3. Modify the constraints file *example/constraints/example_10g_eth.xdc* with appropriate pin assignments. The design requires a 100MHz clock input for initialisation and a low-jitter 156.25MHz clock for the transceivers

4. Build the example design. Set the FPGA part again in *example/build_example.sh*

```console
cd example
./build_example.sh
Vivado> all
```
**Running the example design:**

1. Program the device in Vivado Hardware Manager
2. Add the VIOs
3. De-assert *core_reset* in *hw_vio1 (u_core_reset_vio)*
4. De-assert *packet_gen_reset* in *hw_vio3 (u_packet_control_vio)*
5. Capture on *hw_ila_2 (tx_packet_ila)* to observe latency