# Timing
create_clock -name init_clk -period 10 [get_ports i_init_clk]
create_clock -name mgtrefclk0_x0y3 -period 6.4 [get_ports i_mgtrefclk0_x0y3_p]

set_clock_groups -async -group [get_clocks init_clk] -group [get_clocks -include_generated_clocks mgtrefclk0_x0y3]

# Pins
set_property PACKAGE_PIN G12 [get_ports i_init_clk]
set_property IOSTANDARD LVCMOS18 [get_ports i_init_clk]

set_property PACKAGE_PIN P34 [get_ports i_mgtrefclk0_x0y3_p]

