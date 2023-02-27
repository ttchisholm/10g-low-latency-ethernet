from asyncore import loop
import asyncio
import enum
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure

import debugpy


class MAC_TB:
    def __init__(self, dut, loopback=False):
        self.dut = dut

        self.data_width = len(self.dut.xgmii_tx_data)
        self.data_nbytes = self.data_width // 8
        self.clk_period = round(1 / (10.3125 / self.data_width), 2) # ps precision

        cocotb.start_soon(Clock(dut.tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.rx_clk, self.clk_period, units="ns").start())

        if loopback:  
            cocotb.start_soon(self.loopback('xgmii_tx_data', 'xgmii_rx_data'))
            cocotb.start_soon(self.loopback('xgmii_tx_ctl', 'xgmii_rx_ctl'))

        

        self.dut.s00_axis_tvalid.value = 0
        self.dut.s00_axis_tdata.value = 0
        self.dut.s00_axis_tkeep.value = 0
        self.dut.s00_axis_tlast.value = 0
        
        
    async def change_reset(self, val):
        self.dut.tx_reset.value = val
        self.dut.rx_reset.value = val
        
        await RisingEdge(self.dut.tx_clk)
        await RisingEdge(self.dut.rx_clk)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        self.dut.tx_reset.value = 0
        self.dut.rx_reset.value = 0

    async def loopback(self, output, input):
        while True:
            await Edge(getattr(self.dut, output))
            getattr(self.dut, input).value = getattr(self.dut, output).value



@cocotb.test()
async def tx_test(dut):
    tb = MAC_TB(dut, True)

    dut.phy_tx_ready.value = 1
    
    await tb.reset()

    dut.s00_axis_tkeep.value = int(2**tb.data_nbytes - 1)
    await RisingEdge(dut.tx_clk)

    test_vectors = [
        [   
            int("0x00", 16), int("0x10", 16), int("0xA4", 16), int("0x7B", 16), int("0xEA", 16), int("0x80", 16), 
            int("0x00", 16), int("0x12", 16), int("0x34", 16), int("0x56", 16), int("0x78", 16), int("0x90", 16), 
            int("0x08", 16), int("0x00", 16), int("0x45", 16), int("0x00", 16), int("0x00", 16), int("0x2E", 16), 
            int("0xB3", 16), int("0xFE", 16), int("0x00", 16), int("0x00", 16), int("0x80", 16), int("0x11", 16), 
            int("0x05", 16), int("0x40", 16), int("0xC0", 16), int("0xA8", 16), int("0x00", 16), int("0x2C", 16), 
            int("0xC0", 16), int("0xA8", 16), int("0x00", 16), int("0x04", 16), int("0x04", 16), int("0x00", 16), 
            int("0x04", 16), int("0x00", 16), int("0x00", 16), int("0x1A", 16), int("0x2D", 16), int("0xE8", 16), 
            int("0x00", 16), int("0x01", 16), int("0x02", 16), int("0x03", 16), int("0x04", 16), int("0x05", 16), 
            int("0x06", 16), int("0x07", 16), int("0x08", 16), int("0x09", 16), int("0x0A", 16), int("0x0B", 16), 
            int("0x0C", 16), int("0x0D", 16), int("0x0E", 16), int("0x0F", 16), int("0x10", 16), int("0x11", 16)
        ],
        [   int("0x08", 16),  int("0x00", 16),  int("0x20", 16),  int("0x77", 16), int("0x05", 16), int("0x38", 16), int("0x0e", 16), int("0x8b", 16),
            int("0x00", 16),  int("0x00", 16),  int("0x00", 16),  int("0x00", 16), int("0x08", 16), int("0x00", 16), int("0x45", 16), int("0x00", 16),
            int("0x00", 16),  int("0x28", 16),  int("0x1c", 16),  int("0x66", 16), int("0x00", 16), int("0x00", 16), int("0x1b", 16), int("0x06", 16),
            int("0x9e", 16),  int("0xd7", 16),  int("0x00", 16),  int("0x00", 16), int("0x59", 16), int("0x4d", 16), int("0x00", 16), int("0x00", 16),
            int("0x68", 16),  int("0xd1", 16),  int("0x39", 16),  int("0x28", 16), int("0x4a", 16), int("0xeb", 16), int("0x00", 16), int("0x00", 16),
            int("0x30", 16),  int("0x77", 16),  int("0x00", 16),  int("0x00", 16), int("0x7a", 16), int("0x0c", 16), int("0x50", 16), int("0x12", 16),
            int("0x1e", 16),  int("0xd2", 16),  int("0x62", 16),  int("0x84", 16), int("0x00", 16), int("0x00", 16), int("0x00", 16), int("0x00", 16),
            int("0x00", 16),  int("0x00", 16),  int("0x00", 16),  int("0x00", 16)
        ],
        [   int("0x08", 16),  int("0xdd", 16),  int("0x20", 16),  int("0x77", 16), int("0x05", 16), int("0x38", 16), int("0x0e", 16), int("0x8b", 16),
            int("0xd3", 16),  int("0xd4", 16),  int("0xd5", 16),  int("0xd6", 16), int("0x08", 16), int("0xdd", 16), int("0x45", 16), int("0xdd", 16),
            int("0xdd", 16),  int("0x28", 16),  int("0x1c", 16),  int("0x66", 16), int("0xd8", 16), int("0xda", 16), int("0x1b", 16), int("0x06", 16),
            int("0x9e", 16),  int("0xd7", 16),  int("0x08", 16),  int("0xdd", 16),  int("0x20", 16),  int("0x77", 16), int("0x05", 16), int("0x38", 16), int("0x0e", 16), int("0x8b", 16),
            int("0xd3", 16),  int("0xd4", 16),  int("0xd5", 16),  int("0xd6", 16), int("0x08", 16), int("0xdd", 16), int("0x45", 16), int("0xdd", 16),
            int("0xdd", 16),  int("0x28", 16),  int("0x1c", 16),  int("0x66", 16), int("0xd8", 16), int("0xda", 16), int("0x1b", 16), int("0x06", 16),
            int("0x9e", 16),  int("0xd7", 16),  int("0xd8", 16)
        ]
    ]

    # concatonate the test vector to match the input width
    # https://stackoverflow.com/questions/434287/how-to-iterate-over-a-list-in-chunks
    def chunker(seq, size):
        return (seq[pos:pos + size] for pos in range(0, len(seq), size))

    # debugpy.listen(5678)
    # debugpy.wait_for_client()
    # debugpy.breakpoint()

    for tv in test_vectors:

        timeout = 0

        tvc = list(chunker(tv, tb.data_nbytes))

        for i, ivalues in enumerate(tvc):

            while tb.dut.s00_axis_tready.value == 0:
                tb.dut.s00_axis_tvalid.value = 0
                timeout += 1
                await RisingEdge(dut.tx_clk)
                assert timeout < 20, 'Waiting for tx ready timed out'

            ivalue = 0
            ivalid = 0
            for k, v in enumerate(ivalues):
                ivalue = ivalue | (v <<  (k * 8))
                ivalid = ivalid | (1 << k)
            
            tb.dut.s00_axis_tdata.value = ivalue
            tb.dut.s00_axis_tkeep.value = ivalid
            tb.dut.s00_axis_tvalid.value = 1
            tb.dut.s00_axis_tlast.value = int(i == len(tvc) - 1)

            await RisingEdge(dut.tx_clk)

        tb.dut.s00_axis_tvalid.value = 0
        tb.dut.s00_axis_tdata.value = 0
        tb.dut.s00_axis_tlast.value = 0

        await RisingEdge(dut.tx_clk)

    for _ in range(20):
        await RisingEdge(dut.tx_clk)
        
# @cocotb.test()
# async def rx_test(dut):
#     tb = MAC_TB(dut)

#     eg_xgmii_data = [
#             (int("0b11111111", 2), int("0x0707070707070707", 16)),
#             (int("0b11111111", 2), int("0x0707070707070707", 16)),
#             (int("0b11111111", 2), int("0x0707070707070707", 16)),
#             (int("0b00000001", 2), int("0xd5555555555555fb", 16)),
#             (int("0b00000000", 2), int("0x8b0e380577200008", 16)),
#             (int("0b00000000", 2), int("0x0045000800000000", 16)),
#             (int("0b00000000", 2), int("0x061b0000661c2800", 16)),
#             (int("0b00000000", 2), int("0x00004d590000d79e", 16)),
#             (int("0b00000000", 2), int("0x0000eb4a2839d168", 16)),
#             (int("0b00000000", 2), int("0x12500c7a00007730", 16)),
#             (int("0b00000000", 2), int("0x000000008462d21e", 16)),
#             (int("0b00000000", 2), int("0x79f7eb9300000000", 16)),
#             (int("0b11111111", 2), int("0x07070707070707fd", 16)),
#             (int("0b11111111", 2), int("0x0707070707070707", 16))
#         ]

    

#     tb.dut.xgmii_rx_data.value = 0
#     tb.dut.xgmii_rx_ctl.value = 0
#     tb.dut.phy_rx_valid.value = 1
#     tb.dut.m00_axis_tready.value = 1

#     await tb.reset()

#     for (ctl, data) in eg_xgmii_data:
#         tb.dut.xgmii_rx_data.value = data
#         tb.dut.xgmii_rx_ctl.value = ctl

#         await RisingEdge(dut.rx_clk)


