module test_top(
    
    input wire i_reset,
    input wire i_init_done,   // Rx interface from pcs
    input wire i_rxc,
    input wire i_rxc2, //rxc/2
    input wire [63:0] i_rxd,
    input wire [1:0] i_rx_header,
    input wire i_rx_valid,

    //Rx interface out
    output logic [31:0] o_rxd,
    output logic [3:0] o_rxctl,
    output logic o_rx_valid,
    
    input wire i_txc,
    input wire i_txc2, // txc/2
    input wire[31:0] i_txd,
    input wire[3:0] i_txctl,

    // Input from gearbox
    input wire i_tx_pause, 

    // TX Interface out
    output wire [63:0] o_txd,
    output wire [1:0] o_tx_header);


decode_6466b dec(.*);
encode_6466b enc(.*);


endmodule