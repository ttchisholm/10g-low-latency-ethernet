import cocotb
from cocotb.triggers import Timer, RisingEdge, Edge, NextTimeStep
from cocotb.clock import Clock

class PCS_TB:
    def __init__(self, dut):
        self.dut = dut

        self.data_width = len(self.dut.i_txd)
        self.clk_period = round(1 / (10.3125 / self.data_width), 3) # ps precision

        cocotb.start_soon(Clock(dut.i_txc, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.i_rxc, self.clk_period, units="ns").start())

        self.dut.i_txd.value = int("0x0707070707070707", 16)
        self.dut.i_txctl.value = int("0b11111111", 2) 
        self.dut.i_rxd.value = int("0", 16)


    async def change_reset(self, val):
        self.dut.i_reset.value = val
        for _ in range(2):
            await RisingEdge(self.dut.i_txc)
            await RisingEdge(self.dut.i_rxc)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        await self.change_reset(0)


        
            
    
@cocotb.test()
async def encode_test(dut):

    eg_tx_data = [
        #int("0x0707070707070707", 16),
        int("0xd5555555555555fb", 16),
        int("0x8b0e380577200008", 16),
        int("0x0045000800000000", 16),
        int("0x061b0000661c2800", 16),
        int("0x00004d590000d79e", 16),
        int("0x0000eb4a2839d168", 16),
        int("0x12500c7a00007730", 16),
        int("0x000000008462d21e", 16),
        int("0x79f7eb9300000000", 16),
        int("0x07070707070707fd", 16),
        int("0x0707070707070707", 16)
    ]

    eg_tx_ctl = [
        #int("0b11111111", 2),
        int("0b00000001", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b00000000", 2),
        int("0b11111111", 2),
        int("0b11111111", 2),
    ]


    tb = PCS_TB(dut)

    async def loopback():
        while True:
            await Edge(tb.dut.o_txd)
            tb.dut.i_rxd.value = tb.dut.o_txd.value
    
    cocotb.start_soon(loopback())

    await tb.reset()

    #await RisingEdge(tb.dut.i_txc)

    

    
    
    for _ in range(10):
        for d, ctl in zip(eg_tx_data, eg_tx_ctl):
            await RisingEdge(tb.dut.i_txc)
            tb.dut.i_txd.value = d
            tb.dut.i_txctl.value = ctl

    for _ in range(200):
        await RisingEdge(tb.dut.i_txc)

    # for _ in range(10):
    #     for d, ctl in zip(eg_tx_data, eg_tx_ctl):
    #         await RisingEdge(tb.dut.i_txc)
    #         tb.dut.i_txd.value = d
    #         tb.dut.i_txctl.value = ctl



    

    