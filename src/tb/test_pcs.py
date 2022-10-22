import cocotb
from cocotb.triggers import Timer, RisingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure

from pcs_test_vector import PCSTestVector

class PCS_TB:
    def __init__(self, dut):
        self.dut = dut

        self.data_width = len(self.dut.i_txd)
        self.clk_period = round(1 / (10.3125 / self.data_width), 3) # ps precision

        cocotb.start_soon(Clock(dut.i_txc, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.i_rxc, self.clk_period, units="ns").start())

        # default to idle frame
        self.dut.i_txd.value = int("0x0707070707070707", 16) 
        self.dut.i_txctl.value = int("0b11111111", 2) 
        self.dut.i_rxd.value = int("0x0", 16)


    async def change_reset(self, val):
        self.dut.i_reset.value = val
        for _ in range(2): # wait for reset to propagate to both tx/rx clock domains
            await RisingEdge(self.dut.i_txc)
            await RisingEdge(self.dut.i_rxc)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        await self.change_reset(0)

# todo loopback in class

#     async def loopback():
#         while True:
#             await Edge(tb.dut.o_txd)
#             tb.dut.i_rxd.value = tb.dut.o_txd.value

        


@cocotb.test()
async def encode_scramble_test(dut):
    
    tb = PCS_TB(dut)
    test_vector = PCSTestVector()

    await tb.reset()

    # set up tx output monitor
    # we need to probe internal signals to check data without having to undo the gearing
    async def monitor_tx_scrambled_data():
        frame_index = 0
        timeout_index = 0
        while True:
            await RisingEdge(tb.dut.i_txc)
            timeout_index += 1
            if tb.dut.o_tx_ready.value:
                
                if frame_index != 0: # ensure frames are correct sequentially
                    assert (tb.dut.tx_header.value, tb.dut.tx_scrambled_data.value) == \
                            test_vector.eg_scrambled_data[frame_index], \
                            f'tx frame index {frame_index} incorrect. ' + \
                            f'({tb.dut.tx_header.value},{tb.dut.tx_scrambled_data.value.integer:08x}) != ' + \
                            f'({test_vector.eg_scrambled_data[frame_index][0]:02b}, {test_vector.eg_scrambled_data[frame_index][1]:08x})'

                if (tb.dut.tx_header.value, tb.dut.tx_scrambled_data.value) == \
                    test_vector.eg_scrambled_data[frame_index]:
                    print(f'Found frame {frame_index}')
                    frame_index += 1
                    timeout_index = 0
                    if(frame_index == len(test_vector.eg_scrambled_data)):
                        return
                        
            if timeout_index >= 5:
                raise TestFailure('Waiting for eg tx frame timed out')

    cocotb.start_soon(monitor_tx_scrambled_data())

    # tx example frame
    for ctl, data in test_vector.eg_xgmii_data[1:]: # skip first idle frame as this 
                                                    # throws scrambler off wrt example data
        await RisingEdge(tb.dut.i_txc)
        if tb.dut.o_tx_ready.value:
            tb.dut.i_txd.value = data
            tb.dut.i_txctl.value = ctl        

    
