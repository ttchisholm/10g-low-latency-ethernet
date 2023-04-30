# Vivado build script

if {[info exists env(ETH10G_FPGA_PART)]} { 
    set fpga_part $env(ETH10G_FPGA_PART)
    puts "fpga_part = ${fpga_part}"
} else {
    puts "Environment variable ETH10G_FPGA_PART not set, generate IP from shell script."
    exit 1
}

global output_dir
global src_dir
global build_dir
global ip_dir
global flatten_hierarchy

set project_name example_10g_eth
set output_dir ../build/out
set src_dir ../

set build_dir ../build
set ip_dir ../../src/ip/gen
set core_src_dir ../../src
set core_src_include_dir ../../src/hdl/include
set lib_src_dir ../../src/lib

set flatten_hierarchy none
set directive PerformanceOptimized
set fanout_limit 512
set use_retiming 1

proc init {} {
    
    set_part $::fpga_part
    set_property target_language Verilog [current_project]

    set_property source_mgmt_mode All [current_project]
}

proc add_sources {} {

    read_verilog [glob $::src_dir/hdl/*.sv] -sv
    read_verilog [glob $::core_src_dir/hdl/*.sv] -sv
    read_verilog [glob $::core_src_dir/hdl/**/*.sv] -sv
    read_verilog [glob $::core_src_dir/hdl/**/*.v]
    read_verilog [glob $::lib_src_dir/**/**/*.sv]

    read_ip [glob $::ip_dir/**/*.xci]

    read_xdc [glob $::src_dir/constraints/*.xdc]
}

proc gen_ip {} {

    # Out-Of-Context synthesis for IPs
    foreach ip [get_ips] {
      set ip_filename [get_property IP_FILE $ip]
      set ip_dcp [file rootname $ip_filename]
      append ip_dcp ".dcp"
      set ip_xml [file rootname $ip_filename]
      append ip_xml ".xml"
     
      if {([file exists $ip_dcp] == 0) || [expr {[file mtime $ip_filename ] > [file mtime $ip_dcp ]}]} {
     
        # re-generate the IP
        generate_target all -force $ip 
        set_property generate_synth_checkpoint true [get_files $ip_filename]
        synth_ip -force $ip 
      }
    }
}

proc synth {} {
    
    if { $::use_retiming == 1 } {
        synth_design -top $::project_name -flatten_hierarchy $::flatten_hierarchy -directive $::directive \
            -include_dirs $::core_src_include_dir -retiming
    } else {
        synth_design -top $::project_name -flatten_hierarchy $::flatten_hierarchy -directive $::directive \
            -include_dirs $::core_src_include_dir
    }

    
    write_checkpoint -force $::output_dir/post_synth.dcp
    report_timing_summary -file $::output_dir/post_synth_timing_summary.rpt
    report_utilization -file $::output_dir/post_synth_util.rpt
}

proc impl {} {

    # ensure debug hub connected to free running clock
    connect_debug_port dbg_hub/clk [get_nets i_init_clk]

    opt_design -hier_fanout_limit $::fanout_limit
    # opt_design
    place_design
    report_clock_utilization -file $::output_dir/clock_util.rpt

    #get timing violations and run optimizations if needed
    if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
        puts "Found setup timing violations => running physical optimization"
        phys_opt_design
    }
    write_checkpoint -force $::output_dir/post_place.dcp
    report_utilization -file $::output_dir/post_place_util.rpt
    report_timing_summary -file $::output_dir/post_place_timing_summary.rpt

    #Route design and generate bitstream
    route_design -directive Explore

    # Re-run phys_opt if timing violations found
    if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
        puts "Found setup timing violations => running physical optimization"
        if { $::use_retiming == 1 } {
            phys_opt_design -directive AddRetime
        } else {
            phys_opt_design
        }
        
    }


    write_checkpoint -force $::output_dir/post_route.dcp
    report_route_status -file $::output_dir/post_route_status.rpt
    report_timing_summary -file $::output_dir/post_route_timing_summary.rpt
    report_power -file $::output_dir/post_route_power.rpt
    report_drc -file $::output_dir/post_imp_drc.rpt
}

proc output {} {
    write_verilog -force $::output_dir/cpu_impl_netlist.v -mode timesim -sdf_anno true
    write_debug_probes -force $::output_dir/$::project_name.ltx
    
    write_bitstream -force $::output_dir/$::project_name
    write_bitstream -bin_file -force $::output_dir/$::project_name
}

proc all {} {
    init
    add_sources
    gen_ip
    synth
    impl
    output
}

proc start_synth {} {
    init
    add_sources
    gen_ip
    synth
}

proc impl_out {} {
    impl
    output
}

puts "Build options: "
puts "  'all'         : Full build"
puts "  'start_synth' : Initialise, add sources and run synthesis"
puts "  'impl_out'    : Run implementation and bitstream generation"
