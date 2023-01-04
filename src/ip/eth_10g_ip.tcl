# Designed to be run in 'gen' subdirectory


# IP project setup
create_project -in_memory -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
set_property source_mgmt_mode All [current_project]

# Transceiver
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name gtwizard_ultrascale_0 -dir . -force
set_property -dict [list CONFIG.CHANNEL_ENABLE {X0Y16 X0Y12} CONFIG.TX_MASTER_CHANNEL {X0Y12} CONFIG.RX_MASTER_CHANNEL {X0Y12} \
                         CONFIG.TX_REFCLK_FREQUENCY {156.25} CONFIG.TX_USER_DATA_WIDTH {64} CONFIG.TX_BUFFER_MODE {0} \
                         CONFIG.TX_OUTCLK_SOURCE {TXPROGDIVCLK} CONFIG.RX_REFCLK_FREQUENCY {156.25} CONFIG.RX_USER_DATA_WIDTH {64} \
                         CONFIG.RX_BUFFER_MODE {0} CONFIG.RX_REFCLK_SOURCE {} CONFIG.FREERUN_FREQUENCY {100} \
                         CONFIG.LOCATE_TX_USER_CLOCKING {CORE} CONFIG.LOCATE_RX_USER_CLOCKING {CORE}] [get_ips gtwizard_ultrascale_0]
generate_target all [get_ips gtwizard_ultrascale_0]


# Transceiver bringup VIO

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name gtwizard_ultrascale_0_vio_0 -dir . -force
set_property -dict [list CONFIG.C_PROBE_IN7_WIDTH {2} CONFIG.C_PROBE_IN6_WIDTH {2} CONFIG.C_PROBE_IN5_WIDTH {2} CONFIG.C_PROBE_IN4_WIDTH {2} \
                         CONFIG.C_PROBE_IN3_WIDTH {4} CONFIG.C_NUM_PROBE_OUT {6} CONFIG.C_NUM_PROBE_IN {14} \
                         CONFIG.Component_Name {gtwizard_ultrascale_0_vio_0}] [get_ips gtwizard_ultrascale_0_vio_0]
generate_target all [get_ips gtwizard_ultrascale_0_vio_0]


# Example core control VIO

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name eth_core_control_vio -dir . -force
set_property -dict [list CONFIG.C_PROBE_OUT2_INIT_VAL {0x00000000DEADBEEF} CONFIG.C_PROBE_OUT1_INIT_VAL {0x100} CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} CONFIG.C_PROBE_OUT2_WIDTH {64} CONFIG.C_PROBE_OUT1_WIDTH {16} CONFIG.C_NUM_PROBE_OUT {3} CONFIG.C_EN_PROBE_IN_ACTIVITY {0} CONFIG.C_NUM_PROBE_IN {0}] [get_ips eth_core_control_vio]
generate_target all [get_ips eth_core_control_vio]

# Packet monitor ILAs

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name example_packet_ila -dir . -force
set_property -dict [list CONFIG.C_DATA_DEPTH {131072} CONFIG.C_NUM_OF_PROBES {5} CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_PROBE1_WIDTH {8}] [get_ips example_packet_ila]
generate_target all [get_ips example_packet_ila]

