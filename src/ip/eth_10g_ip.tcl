if {[info exists env(ETH10G_FPGA_PART)]} { 
    set FPGA_PART $env(ETH10G_FPGA_PART)
    puts "FPGA_PART = ${FPGA_PART}"
} else {
    puts "Environment variable ETH10G_FPGA_PART not set, generate IP from shell script."
    exit 1
}

if {[info exists env(ETH10G_CHANNEL)]} { 
    set CHANNEL $env(ETH10G_CHANNEL)
    puts "CHANNEL = ${CHANNEL}"
} else {
    puts "Environment variable ETH10G_CHANNEL not set, generate IP from shell script."
    exit 1
}

# IP project setup
create_project -in_memory -part $FPGA_PART
set_property target_language Verilog [current_project]
set_property source_mgmt_mode All [current_project]

# Transceiver - with gearbox
# create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name gtwizard_ultrascale_0 -dir . -force 
# set_property -dict [list CONFIG.CHANNEL_ENABLE ${CHANNEL} CONFIG.TX_MASTER_CHANNEL ${CHANNEL} CONFIG.RX_MASTER_CHANNEL ${CHANNEL} \
#                          CONFIG.TX_REFCLK_FREQUENCY {156.25} CONFIG.TX_DATA_ENCODING {64B66B} CONFIG.TX_USER_DATA_WIDTH {32} \
#                          CONFIG.TX_BUFFER_MODE {0} CONFIG.TX_OUTCLK_SOURCE {TXPROGDIVCLK} CONFIG.RX_REFCLK_FREQUENCY {156.25} \
#                          CONFIG.RX_DATA_DECODING {64B66B} CONFIG.RX_USER_DATA_WIDTH {32} CONFIG.RX_INT_DATA_WIDTH {32} \
#                          CONFIG.RX_BUFFER_MODE {0} CONFIG.RX_REFCLK_SOURCE {} CONFIG.TX_REFCLK_SOURCE {} \
#                          CONFIG.LOCATE_TX_USER_CLOCKING {CORE} CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
#                          CONFIG.TXPROGDIV_FREQ_ENABLE {false} CONFIG.FREERUN_FREQUENCY {100} CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in}] [get_ips gtwizard_ultrascale_0]
# generate_target all [get_ips gtwizard_ultrascale_0]

create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name gtwizard_ultrascale_0 -dir . -force 
set_property -dict [list CONFIG.CHANNEL_ENABLE ${CHANNEL} CONFIG.TX_MASTER_CHANNEL ${CHANNEL} CONFIG.RX_MASTER_CHANNEL ${CHANNEL} \
                         CONFIG.TX_REFCLK_FREQUENCY {156.25} CONFIG.TX_DATA_ENCODING {RAW} CONFIG.TX_USER_DATA_WIDTH {32} \
                         CONFIG.TX_BUFFER_MODE {0} CONFIG.TX_OUTCLK_SOURCE {TXPROGDIVCLK} CONFIG.RX_REFCLK_FREQUENCY {156.25} \
                         CONFIG.RX_DATA_DECODING {RAW} CONFIG.RX_USER_DATA_WIDTH {32} CONFIG.RX_INT_DATA_WIDTH {32} \
                         CONFIG.RX_BUFFER_MODE {0} CONFIG.RX_REFCLK_SOURCE {} CONFIG.TX_REFCLK_SOURCE {} \
                         CONFIG.LOCATE_TX_USER_CLOCKING {CORE} CONFIG.LOCATE_RX_USER_CLOCKING {CORE} \
                         CONFIG.TXPROGDIV_FREQ_ENABLE {false} CONFIG.FREERUN_FREQUENCY {100} CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in}] [get_ips gtwizard_ultrascale_0]
generate_target all [get_ips gtwizard_ultrascale_0]


# Transceiver bringup VIO

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name gtwizard_ultrascale_0_vio_0 -dir . -force
set_property -dict [list CONFIG.C_PROBE_IN7_WIDTH {2} CONFIG.C_PROBE_IN6_WIDTH {2} CONFIG.C_PROBE_IN5_WIDTH {2} CONFIG.C_PROBE_IN4_WIDTH {2} \
                         CONFIG.C_PROBE_IN3_WIDTH {4} CONFIG.C_PROBE_OUT6_INIT_VAL {0x2} CONFIG.C_PROBE_OUT6_WIDTH {3} \
                         CONFIG.C_NUM_PROBE_OUT {7} CONFIG.C_NUM_PROBE_IN {14} \
                         CONFIG.Component_Name {gtwizard_ultrascale_0_vio_0}] [get_ips gtwizard_ultrascale_0_vio_0]
generate_target all [get_ips gtwizard_ultrascale_0_vio_0]


# Example core control VIO

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name eth_core_control_vio -dir . -force
set_property -dict [list CONFIG.C_PROBE_OUT2_INIT_VAL {0xBEEF0000} CONFIG.C_PROBE_OUT1_INIT_VAL {0x100} CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} CONFIG.C_PROBE_OUT2_WIDTH {32} CONFIG.C_PROBE_OUT1_WIDTH {16} CONFIG.C_NUM_PROBE_OUT {3} CONFIG.C_EN_PROBE_IN_ACTIVITY {0} CONFIG.C_NUM_PROBE_IN {0}] [get_ips eth_core_control_vio]
generate_target all [get_ips eth_core_control_vio]

# Packet monitor ILAs

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name example_packet_ila -dir . -force
set_property -dict [list CONFIG.C_DATA_DEPTH {131072} CONFIG.C_NUM_OF_PROBES {7} CONFIG.C_PROBE0_WIDTH {32} CONFIG.C_PROBE1_WIDTH {4} CONFIG.C_PROBE5_WIDTH {16}] [get_ips example_packet_ila]
generate_target all [get_ips example_packet_ila]

exit 0