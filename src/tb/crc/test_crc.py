from asyncore import loop
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure


class CRC_TB:
    def __init__(self, dut, loopback=False):
        self.dut = dut

        self.data_width = len(self.dut.i_data)
        self.clk_period = round(1 / (10.3125 / self.data_width), 2) # ps precision

        cocotb.start_soon(Clock(dut.i_clk, self.clk_period, units="ns").start())

        self.dut.i_data.value = 0
        self.dut.i_valid.value = 0
        


    async def change_reset(self, val):
        self.dut.i_reset.value = val
        for _ in range(2): # wait for reset to propagate to both tx/rx clock domains
            await RisingEdge(self.dut.i_clk)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        await self.change_reset(0)


#
#   Test ...
#
@cocotb.test()
async def crc_test(dut):
    
    tb = CRC_TB(dut)
    test_vector = [     
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
    ]

    assert (tb.data_width % 8 == 0)
    input_width_bytes = tb.data_width // 8

    # concatonate the test vector to match the input width
    # https://stackoverflow.com/questions/434287/how-to-iterate-over-a-list-in-chunks
    def chunker(seq, size):
        return (seq[pos:pos + size] for pos in range(0, len(seq), size))


    await tb.reset()
    await FallingEdge(tb.dut.i_clk)

    for ivalues in chunker(test_vector, input_width_bytes):

        ivalue = 0
        ivalid = 0
        for i, v in enumerate(ivalues):
            ivalue = ivalue | (v <<  (i * 8))
            ivalid = ivalid | (1 << i)

        print(f"ivalue: {ivalue:16x} ")
        print(f"ivalid: {ivalid:16b} ")

        tb.dut.i_data.value = ivalue
        tb.dut.i_valid.value = ivalid
        await FallingEdge(tb.dut.i_clk)

    assert tb.dut.o_crc.value.integer == int("0x1b8831b3", 16)
   

