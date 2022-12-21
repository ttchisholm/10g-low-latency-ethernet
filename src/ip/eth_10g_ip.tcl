create_project -in_memory -part xczu49dr-ffvf1760-2-e
set_property target_language Verilog [current_project]
set_property source_mgmt_mode All [current_project]
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -version 1.7 -module_name gtwizard_ultrascale_0
set_property -dict [list CONFIG.TX_REFCLK_FREQUENCY {156.25} CONFIG.TX_USER_DATA_WIDTH {64} CONFIG.TX_BUFFER_MODE {0} CONFIG.TX_OUTCLK_SOURCE {TXPROGDIVCLK} CONFIG.RX_REFCLK_FREQUENCY {156.25} CONFIG.RX_USER_DATA_WIDTH {64} CONFIG.RX_BUFFER_MODE {0} CONFIG.RX_REFCLK_SOURCE {} CONFIG.FREERUN_FREQUENCY {100}] [get_ips gtwizard_ultrascale_0]
generate_target all [get_ips gtwizard_ultrascale_0]
