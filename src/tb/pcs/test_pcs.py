from asyncore import loop
import asyncio
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep, First
from cocotb.clock import Clock
from cocotb.result import TestFailure
from cocotb.queue import Queue

from pcs_test_vector import PCSTestVector

import debugpy

class PCS_TB:
    def __init__(self, dut, loopback=False):
        self.dut = dut

        # debugpy.listen(5678)
        # debugpy.wait_for_client()
        # debugpy.breakpoint()

        self.data_width = len(self.dut.i_xgmii_tx_data)
        self.data_nbytes = self.data_width // 8
        self.clk_period = round(1 / (10.3125 / self.data_width), 2) # ps precision
        self.gearbox_pause_val = 31 if self.data_width == 32 else 32

        cocotb.start_soon(Clock(dut.i_xver_tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.i_xver_rx_clk, self.clk_period, units="ns").start())

        if loopback: cocotb.start_soon(self.loopback())

        # default to idle frame
        self.dut.i_xgmii_tx_data.value = int(''.join(["07" for _ in range(self.data_nbytes)]), 16) 
        self.dut.i_xgmii_tx_ctl.value = int(''.join(["1" for _ in range(self.data_nbytes)]), 2)
        self.dut.o_xgmii_rx_data.value = int("0x0", 16)

    async def change_reset(self, val):
        self.dut.i_tx_reset.value = val
        self.dut.i_rx_reset.value = val
        
        await RisingEdge(self.dut.i_xver_tx_clk)
        await RisingEdge(self.dut.i_xver_rx_clk)


    async def reset(self):
        await self.change_reset(0)
        await self.change_reset(1)
        self.dut.i_tx_reset.value = 0
        self.dut.i_rx_reset.value = 0

    async def loopback(self, delay=1):
        
        async def capture_outputs(self, q, delay):
            for _ in range(delay): await q.put([0, 0, 0, 0])
            prev_tx_gearbox_seq = 0
            while True:
                await RisingEdge(self.dut.i_xver_tx_clk)
                
                o_xver_tx_data = self.dut.o_xver_tx_data.value
                o_xver_tx_header = self.dut.o_xver_tx_header.value
                xver_tx_data_valid = self.dut.o_xver_tx_gearbox_sequence.value != self.gearbox_pause_val

                xver_tx_header_valid = self.dut.o_xver_tx_gearbox_sequence.value != prev_tx_gearbox_seq and xver_tx_data_valid
                prev_tx_gearbox_seq = self.dut.o_xver_tx_gearbox_sequence.value

                await q.put([o_xver_tx_data, o_xver_tx_header, xver_tx_data_valid, xver_tx_header_valid])

        async def apply_input(self, q):
            while True:
                await RisingEdge(self.dut.i_xver_rx_clk)
                [o_xver_tx_data, o_xver_tx_header, xver_tx_data_valid, xver_tx_header_valid] = await q.get()
                
                self.dut.i_xver_rx_data.value = o_xver_tx_data
                self.dut.i_xver_rx_header.value = o_xver_tx_header
                self.dut.i_xver_rx_data_valid.value = xver_tx_data_valid
                self.dut.i_xver_rx_header_valid.value = xver_tx_header_valid

                

        q = Queue()
        cocotb.start_soon(capture_outputs(self, q, delay))
        cocotb.start_soon(apply_input(self, q))




#
#   Test transmit encoding and scrambling with sample test vector
#
@cocotb.test()
async def encode_scramble_test(dut):
    
    tb = PCS_TB(dut)
    test_vector = PCSTestVector()

    await tb.reset()

    # Wait for one cycle before applying test vector to align the encoder - but 
    #   hold the scrambler data so the initial state lines up with the test vector
    await RisingEdge(tb.dut.i_xver_tx_clk)

    # set up tx output monitor
    # we need to probe internal signals to check data without having to undo the gearing
    async def monitor_tx_scrambled_data():
        frame_index = 0
        timeout_index = 0
        while True:
            await RisingEdge(tb.dut.i_xver_tx_clk)
            timeout_index += 1
            if tb.dut.o_xgmii_tx_ready.value:
                
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
        await RisingEdge(tb.dut.i_xver_tx_clk)
        if tb.dut.o_xgmii_tx_ready.value:
            tb.dut.i_xgmii_tx_data.value = data
            tb.dut.i_xgmii_tx_ctl.value = ctl    

    await tx_monitor

    
#
#   Test tx -> rx chain in loopback with sample test vector
#

@cocotb.test()
async def tx_rx_loopback_test(dut):
    
    tb = PCS_TB(dut, loopback=True)
    test_vector = PCSTestVector()

    await tb.reset()

    # set up tx output monitor
    async def monitor_rx_data():
        start_frame = 1 if tb.data_width == 64 else 2 # wait on first non-idle frame 
        frame_index = start_frame 
        timeout_index = 0 
        while True:
            await RisingEdge(tb.dut.i_xver_rx_clk)
            timeout_index += 1
            if tb.dut.o_xgmii_rx_valid.value:
                
                if frame_index != start_frame: # ensure frames are correct sequentially
                    assert (tb.dut.o_xgmii_rx_ctl.value, tb.dut.o_xgmii_rx_data.value) == \
                            test_vector.eg_xgmii_data[tb.data_width][frame_index], \
                            f'rx frame index {frame_index} incorrect. ' + \
                            f'({tb.dut.o_xgmii_rx_ctl.value},{tb.dut.o_xgmii_rx_data.value.integer:08x}) != ' + \
                            f'({test_vector.eg_xgmii_data[tb.data_width][frame_index][0]:08b}, {test_vector.eg_xgmii_data[tb.data_width][frame_index][1]:08x})'

                if (tb.dut.o_xgmii_rx_ctl.value, tb.dut.o_xgmii_rx_data.value) == \
                    test_vector.eg_xgmii_data[tb.data_width][frame_index]:
                    print(f'Found frame {frame_index}')
                    frame_index += 1
                    timeout_index = 0
                    if(frame_index == len(test_vector.eg_xgmii_data[tb.data_width])):
                        return
                        
            if timeout_index >= 10:
                raise TestFailure('Waiting for rx frame timed out')

    

    # transmit idles to allow gearbox to sync
    for _ in range(200):
        await RisingEdge(tb.dut.i_xver_tx_clk)

    rx_monitor = cocotb.start_soon(monitor_rx_data())

    # tx example frame
    for ctl, data in test_vector.eg_xgmii_data[tb.data_width]: 
        await RisingEdge(tb.dut.i_xver_tx_clk)
        if tb.dut.o_xgmii_tx_ready.value:
            tb.dut.i_xgmii_tx_data.value = data
            tb.dut.i_xgmii_tx_ctl.value = ctl        

    await rx_monitor
