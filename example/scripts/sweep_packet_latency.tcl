


set packet_lengths {64 128 256 512 1024 2048 4096 8192 16364}

foreach x $packet_lengths {
    
    set x_hex [format %04x $x]
    
    set_property OUTPUT_VALUE $x_hex [get_hw_probes packet_length -of_objects [get_hw_vios -of_objects [get_hw_devices xczu49dr_0] -filter {CELL_NAME=~"u_packet_control_vio"}]]
    commit_hw_vio [get_hw_probes {packet_length} -of_objects [get_hw_vios -of_objects [get_hw_devices xczu49dr_0] -filter {CELL_NAME=~"u_packet_control_vio"}]]
    run_hw_ila [get_hw_ilas -of_objects [get_hw_devices xczu49dr_0] -filter {CELL_NAME=~"tx_packet_ila"}]
    wait_on_hw_ila [get_hw_ilas -of_objects [get_hw_devices xczu49dr_0] -filter {CELL_NAME=~"tx_packet_ila"}]
    display_hw_ila_data [upload_hw_ila_data [get_hw_ilas -of_objects [get_hw_devices xczu49dr_0] -filter {CELL_NAME=~"tx_packet_ila"}]]
    write_hw_ila_data -force -csv_file ./iladata_${x}.csv hw_ila_data_2

}

