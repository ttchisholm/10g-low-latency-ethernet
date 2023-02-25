from asyncore import loop
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure

from pcs_test_vector import PCSTestVector

import debugpy

class PCS_TB:
    def __init__(self, dut, loopback=False):
        self.dut = dut

        # debugpy.listen(5678)
        # debugpy.wait_for_client()
        # debugpy.breakpoint()

        self.data_width = len(self.dut.xgmii_tx_data)
        self.data_nbytes = self.data_width // 8
        self.clk_period = round(1 / (10.3125 / self.data_width), 2) # ps precision

        cocotb.start_soon(Clock(dut.xver_tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.xver_rx_clk, self.clk_period, units="ns").start())

        if loopback: cocotb.start_soon(self.loopback())

        # default to idle frame
        self.dut.xgmii_tx_data.value = int(''.join(["07" for _ in range(self.data_nbytes)]), 16) 
        self.dut.xgmii_tx_ctl.value = int(''.join(["1" for _ in range(self.data_nbytes)]), 2)
        self.dut.xgmii_rx_data.value = int("0x0", 16)


    # async def reset(self):
    #     self.dut.tx_reset.value = 1
    #     self.dut.rx_reset.value = 1
    #     self.dut.xver_rx_clk.value = 0
    #     self.dut.xver_rx_data.value = 0
    #     self.dut.xver_tx_clk.value = 0
    #     await RisingEdge(self.dut.xver_rx_clk)
    #     await RisingEdge(self.dut.xver_tx_clk)
    #     await FallingEdge(self.dut.xver_rx_clk)
    #     await FallingEdge(self.dut.xver_tx_clk)
    #     self.dut.tx_reset.value = 0
    #     self.dut.rx_reset.value = 0
    #     await RisingEdge(self.dut.xver_rx_clk)
    #     await RisingEdge(self.dut.xver_tx_clk)

    async def change_reset(self, val):
        self.dut.tx_reset.value = val
        self.dut.rx_reset.value = val
        
        await RisingEdge(self.dut.xver_tx_clk)
        await RisingEdge(self.dut.xver_rx_clk)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        self.dut.tx_reset.value = 0
        self.dut.rx_reset.value = 0

    async def loopback(self):
        while True:
            await Edge(self.dut.xgmii_tx_data)
            self.dut.xgmii_rx_data.value = self.dut.xgmii_tx_data.value

#
#   Test transmit encoding and scrambling with sample test vector
#
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
            await RisingEdge(tb.dut.xver_tx_clk)
            timeout_index += 1
            if tb.dut.xgmii_tx_ready.value:
                
                if frame_index != 0: # ensure frames are correct sequentially
                    assert (tb.dut.tx_header.value, tb.dut.tx_scrambled_data.value) == \
                            test_vector.eg_scrambled_data[tb.data_width][frame_index], \
                            f'tx frame index {frame_index} incorrect. ' + \
                            f'({tb.dut.tx_header.value},{tb.dut.tx_scrambled_data.value.integer:08x}) != ' + \
                            f'({test_vector.eg_scrambled_data[tb.data_width][frame_index][0]:02b}, {test_vector.eg_scrambled_data[tb.data_width][frame_index][1]:08x})'

                if (tb.dut.tx_header.value, tb.dut.tx_scrambled_data.value) == \
                    test_vector.eg_scrambled_data[tb.data_width][frame_index]:
                    print(f'Found frame {frame_index}')
                    frame_index += 1
                    timeout_index = 0
                    if(frame_index == len(test_vector.eg_scrambled_data[tb.data_width])):
                        return
                        
            if timeout_index >= 10:
                raise TestFailure('Waiting for eg tx frame timed out')

    tx_monitor = cocotb.start_soon(monitor_tx_scrambled_data())

    # tx example frame
    for ctl, data in test_vector.eg_xgmii_data[tb.data_width][1:]: # skip first idle frame as this 
                                                    # throws scrambler off wrt example data
        await RisingEdge(tb.dut.xver_tx_clk)
        if tb.dut.xgmii_tx_ready.value:
            tb.dut.xgmii_tx_data.value = data
            tb.dut.xgmii_tx_ctl.value = ctl    

    await tx_monitor

    
#
#   Test tx -> rx chain in loopback with sample test vector
#

# @cocotb.test()
# async def tx_rx_loopback_test(dut):
    
#     tb = PCS_TB(dut, loopback=True)
#     test_vector = PCSTestVector()

#     await tb.reset()

#     # set up tx output monitor
#     async def monitor_rx_data():
#         start_frame = 1 # wait on first non-idle frame 
#         frame_index = start_frame 
#         timeout_index = 0 
#         while True:
#             await RisingEdge(tb.dut.xver_rx_clk)
#             timeout_index += 1
#             if tb.dut.o_rx_valid.value:
                
#                 if frame_index != start_frame: # ensure frames are correct sequentially
#                     assert (tb.dut.o_rxctl.value, tb.dut.o_rxd.value) == \
#                             test_vector.eg_xgmii_data[frame_index], \
#                             f'rx frame index {frame_index} incorrect. ' + \
#                             f'({tb.dut.o_rxctl.value},{tb.dut.o_rxd.value.integer:08x}) != ' + \
#                             f'({test_vector.eg_xgmii_data[frame_index][0]:08b}, {test_vector.eg_xgmii_data[frame_index][1]:08x})'

#                 if (tb.dut.o_rxctl.value, tb.dut.o_rxd.value) == \
#                     test_vector.eg_xgmii_data[frame_index]:
#                     print(f'Found frame {frame_index}')
#                     frame_index += 1
#                     timeout_index = 0
#                     if(frame_index == len(test_vector.eg_xgmii_data)):
#                         return
                        
#             if timeout_index >= 10:
#                 raise TestFailure('Waiting for rx frame timed out')

    

#     # transmit idles to allow gearbox to sync
#     for _ in range(200):
#         await RisingEdge(tb.dut.xver_tx_clk)

#     rx_monitor = cocotb.start_soon(monitor_rx_data())

#     # tx example frame
#     for ctl, data in test_vector.eg_xgmii_data: 
#         await RisingEdge(tb.dut.xver_tx_clk)
#         if tb.dut.xgmii_tx_ready.value:
#             tb.dut.xgmii_tx_data.value = data
#             tb.dut.xgmii_tx_ctl.value = ctl        

#     await rx_monitor
