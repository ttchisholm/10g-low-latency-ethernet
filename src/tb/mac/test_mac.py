from asyncore import loop
import enum
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure

import debugpy


class MAC_TB:
    def __init__(self, dut):
        self.dut = dut

        self.data_width = len(self.dut.s00_axis_tdata)
        self.clk_period = round(1 / (10.3125 / self.data_width), 3) # ps precision

        cocotb.start_soon(Clock(dut.i_txc, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.i_rxc, self.clk_period, units="ns").start())

        #if loopback: cocotb.start_soon(self.loopback())

        self.dut.s00_axis_tvalid.value = 0
        self.dut.s00_axis_tdata.value = 0
        self.dut.s00_axis_tkeep.value = 0
        self.dut.s00_axis_tlast.value = 0
        
        
    async def change_reset(self, val):
        self.dut.i_reset.value = val
        for _ in range(2): # wait for reset to propagate to both tx/rx clock domains
            await RisingEdge(self.dut.i_rxc)
            await RisingEdge(self.dut.i_txc)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        await self.change_reset(0)


@cocotb.test()
async def tx_test(dut):
    tb = MAC_TB(dut)

    
    await tb.reset()

    dut.i_tx_ready.value = 1
    dut.s00_axis_tkeep.value = int("0b11111111", 2)
    await RisingEdge(dut.i_txc)

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

        tvc = list(chunker(tv, 8))

        for i, ivalues in enumerate(tvc):

            while tb.dut.s00_axis_tready.value == 0:
                tb.dut.s00_axis_tvalid.value = 0
                timeout += 1
                await RisingEdge(dut.i_txc)
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

            await RisingEdge(dut.i_txc)

        tb.dut.s00_axis_tvalid.value = 0
        tb.dut.s00_axis_tdata.value = 0
        tb.dut.s00_axis_tlast.value = 0

        await RisingEdge(dut.i_txc)

    for _ in range(20):
        await RisingEdge(dut.i_txc)
        
            


            