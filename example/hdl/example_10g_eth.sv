module example_10g_eth (

    input wire init_clk,

    // Differential reference clock inputs
    input  wire mgtrefclk0_x0y3_p,
    input  wire mgtrefclk0_x0y3_n,

    // Serial data ports for transceiver channel 0
    input  wire ch0_gtyrxn_in,
    input  wire ch0_gtyrxp_in,
    output wire ch0_gtytxn_out,
    output wire ch0_gtytxp_out
);

    wire packet_gen_reset;
    logic [1:0] reset_cdc;
    wire core_reset;

    // Packet gen
    wire [15:0] packet_length;
    logic [15:0] packet_length_cnt;
    logic [31:0] packet_vio_data;

    // Tx AXIS
    wire s00_axis_aclk;
    wire [31:0] s00_axis_tdata;
    wire [3:0] s00_axis_tkeep;
    wire s00_axis_tvalid;
    wire s00_axis_tready;
    wire s00_axis_tlast;

    // Rx AXIS
    wire m00_axis_aclk;
    wire [31:0] m00_axis_tdata;
    wire [3:0] m00_axis_tkeep;
    wire m00_axis_tvalid;
    wire m00_axis_tlast;
    wire m00_axis_tuser;

    // Resets
    wire mac_pcs_rx_reset, mac_pcs_tx_reset;

    // Performance meas
    wire [15:0] perf_latency;
    wire perf_complete;
    wire perf_tx_start, perf_rx_stop;

    always @(posedge s00_axis_aclk)
    if (packet_gen_reset) begin
        packet_length_cnt <= '0;
    end else if (s00_axis_tready) begin
        packet_length_cnt <= (packet_length_cnt == packet_length) ? '0 : packet_length_cnt + 1;
    end

    assign s00_axis_tdata = {packet_vio_data[31:16], packet_length_cnt}; // Set lower 16 bits to packet index counter 
    assign s00_axis_tkeep = '1;
    assign s00_axis_tlast = packet_length_cnt == packet_length;
    assign s00_axis_tvalid = !packet_gen_reset;

    // Packet Gen VIO
    eth_core_control_vio u_packet_control_vio (
        .clk(s00_axis_aclk),                // input wire clk
        .probe_out0(packet_gen_reset),  // output wire [0 : 0] probe_out0
        .probe_out1(packet_length),  // output wire [15 : 0] probe_out1
        .probe_out2(packet_vio_data)  // output wire [63 : 0] probe_out2
    );

    eth_core_control_vio u_core_reset_vio (
        .clk(init_clk),                // input wire clk
        .probe_out0(core_reset),  // output wire [0 : 0] probe_out0
        .probe_out1(),  // output wire [15 : 0] probe_out1
        .probe_out2()  // output wire [63 : 0] probe_out2
    );

    // Data monitor ILAs
    example_packet_ila tx_packet_ila (
        .clk(s00_axis_aclk), // input wire clk
        .probe0(s00_axis_tdata), // input wire [63:0]  probe0  
        .probe1(s00_axis_tkeep), // input wire [7:0]  probe1 
        .probe2(s00_axis_tready), // input wire [0:0]  probe2 
        .probe3(s00_axis_tvalid), // input wire [0:0]  probe3 
        .probe4(s00_axis_tlast), // input wire [0:0]  probe4
        .probe5(perf_latency),
        .probe6(perf_complete)
    );

    example_packet_ila rx_packet_ila (
        .clk(m00_axis_aclk), // input wire clk
        .probe0(m00_axis_tdata), // input wire [63:0]  probe0  
        .probe1(m00_axis_tkeep), // input wire [7:0]  probe1 
        .probe2(m00_axis_tuser), // input wire [0:0]  probe2 
        .probe3(m00_axis_tvalid), // input wire [0:0]  probe3 
        .probe4(m00_axis_tlast), // input wire [0:0]  probe4
        .probe5(16'h0),
        .probe6(perf_rx_stop)
    );


    assign perf_tx_start = s00_axis_tvalid && s00_axis_tready && s00_axis_tdata[15:0] == 16'b0;
    assign perf_rx_stop = m00_axis_tvalid && m00_axis_tdata[15:0] == 16'b0;

    eth_perf u_eth_perf (
    
        .tx_reset(mac_pcs_tx_reset),
        .tx_clk(s00_axis_aclk),
        .tx_start(perf_tx_start),
        .latency(perf_latency),
        .test_complete(perf_complete),

        .rx_reset(mac_pcs_rx_reset),
        .rx_clk(m00_axis_aclk),
        .rx_stop(perf_rx_stop)
    );

    // Eth Core
    eth_10g #(
        .SCRAMBLER_BYPASS(0),
        .EXTERNAL_GEARBOX(0),
        .INIT_CLK_FREQ(100.0)
    ) u_eth_10g (
        .reset(core_reset),
        .init_clk(init_clk),
        .mgtrefclk0_x0y3_p(mgtrefclk0_x0y3_p),
        .mgtrefclk0_x0y3_n(mgtrefclk0_x0y3_n),
        .s00_axis_aclk(s00_axis_aclk),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tkeep(s00_axis_tkeep),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast),
        .m00_axis_aclk(m00_axis_aclk),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tkeep(m00_axis_tkeep),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tuser(m00_axis_tuser),
        .ch0_gtyrxn_in(ch0_gtyrxn_in),
        .ch0_gtyrxp_in(ch0_gtyrxp_in),
        .ch0_gtytxn_out(ch0_gtytxn_out),
        .ch0_gtytxp_out(ch0_gtytxp_out),
        .mac_pcs_tx_reset(mac_pcs_tx_reset),
        .mac_pcs_rx_reset(mac_pcs_rx_reset)
    );


endmodule