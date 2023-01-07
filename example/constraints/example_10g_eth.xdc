# Timing
create_clock -name init_clk -period 10 [get_ports init_clk]
create_clock -name mgtrefclk0_x0y3 -period 6.4 [get_ports mgtrefclk0_x0y3_p]
create_clock -name mgtrefclk0_x0y4 -period 6.4 [get_ports mgtrefclk0_x0y4_p]

set_clock_groups -async -group [get_clocks init_clk] -group [get_clocks -include_generated_clocks mgtrefclk0_x0y3] \
    -group [get_clocks -include_generated_clocks mgtrefclk0_x0y4]

# Pins

# todo pin

