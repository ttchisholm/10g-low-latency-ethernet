# MIT License

# Copyright (c) 2023 Tom Chisholm

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""
    mac_pcs_bfm.py

    Pyuvm Bus Fuctional Model (BFM) for mac_pcs module.

"""

import logging
import debugpy

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Edge
from cocotb.queue import QueueEmpty, Queue
from cocotb.clock import Clock

from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor)

from pyuvm import utility_classes

class MacPcsBfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.tx_driver_queue = Queue(maxsize=1)
        self.tx_monitor_queue = Queue(maxsize=0)
        self.rx_monitor_queue = Queue(maxsize=0)

        self.tx_axis_source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "s00_axis"), 
                                                self.dut.i_xver_tx_clk, self.dut.i_rx_reset)
        

        self.tx_axis_monitor = AxiStreamMonitor(AxiStreamBus.from_prefix(self.dut, "s00_axis"), 
                                                self.dut.i_xver_tx_clk, self.dut.i_rx_reset)
        

        self.rx_axis_monitor = AxiStreamMonitor(AxiStreamBus.from_prefix(self.dut, "m00_axis"), 
                                                self.dut.i_xver_rx_clk, self.dut.i_tx_reset)
        

    def set_axis_log(self, enable):
        self.tx_axis_source.log.propagate = enable
        self.tx_axis_monitor.log.propagate = enable
        self.rx_axis_monitor.log.propagate = enable
       
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

    async def send_tx_packet(self, packet):
        await self.tx_driver_queue.put(packet)

    async def reset(self):
        self.dut.i_tx_reset.value = 1
        self.dut.i_rx_reset.value = 1
        self.dut.i_xver_rx_clk.value = 0
        self.dut.i_xver_rx_data.value = 0
        self.dut.i_xver_tx_clk.value = 0
        await RisingEdge(self.dut.i_xver_rx_clk)
        await RisingEdge(self.dut.i_xver_tx_clk)
        await FallingEdge(self.dut.i_xver_rx_clk)
        await FallingEdge(self.dut.i_xver_tx_clk)
        self.dut.i_tx_reset.value = 0
        self.dut.i_rx_reset.value = 0
        await RisingEdge(self.dut.i_xver_rx_clk)
        await RisingEdge(self.dut.i_xver_tx_clk)

    async def pause(self, cycles):
        for _ in range(cycles):
            await RisingEdge(self.dut.i_xver_tx_clk)

    async def driver_bfm(self):
        while True:
            packet = await self.tx_driver_queue.get()
            await self.tx_axis_source.send(packet.tobytes())
            await self.tx_axis_source.wait()


    async def tx_monitor_bfm(self):
        while True:
            packet = await self.tx_axis_monitor.recv()
            self.tx_monitor_queue.put_nowait(packet)
    
    async def rx_monitor_bfm(self):
        while True:
            packet = await self.rx_axis_monitor.recv(compact=False)
            packet = self.compact_axis_no_tuser(packet)
            self.rx_monitor_queue.put_nowait(packet)

    async def get_tx_frame(self):
        return await self.tx_monitor_queue.get()

    async def get_rx_frame(self):
        return await self.rx_monitor_queue.get()
            

    async def start_bfm(self):
        self.data_width = len(self.dut.xgmii_tx_data)
        self.data_nbytes = self.data_width // 8
        self.gearbox_pause_val = 32
        self.clk_period = round(1 / (10.3125 / self.data_width), 2) # ps precision
        
        cocotb.start_soon(Clock(self.dut.i_xver_tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(self.dut.i_xver_rx_clk, self.clk_period, units="ns").start())
        

        await self.reset()
        cocotb.start_soon(self.loopback())

        # manual slip for idles - debugging w/out scrambler
        # conseq = 0
        # for i in range(20000):

        #     if self.dut.xgmii_rx_data.value == int('0x07070707', 16) and \
        #         self.dut.u_pcs.genblk3.u_rx_gearbox.o_header.value != 0:
        #         conseq += 1
        #     else:
        #         conseq = 0
             
        #     if conseq > 40:
        #         print('aligned')
        #         break

        #     if i % 87 == 0:
        #         self.dut.u_pcs.rx_gearbox_slip.value = 1
        #     else:
        #         self.dut.u_pcs.rx_gearbox_slip.value = 0
        #     await RisingEdge(self.dut.i_xver_rx_clk)


        cocotb.start_soon(self.driver_bfm())
        cocotb.start_soon(self.tx_monitor_bfm())
        cocotb.start_soon(self.rx_monitor_bfm())


    # A copy of AxiStreamFrame::compact but does not remvove tuser when tkeep = 0
    @staticmethod
    def compact_axis_no_tuser(frame):
        if len(frame.tkeep):
            # remove tkeep=0 bytes
            for k in range(len(frame.tdata)-1, -1, -1):
                if not frame.tkeep[k]:
                    if k < len(frame.tdata):
                        del frame.tdata[k]
                    if k < len(frame.tkeep):
                        del frame.tkeep[k]
                    if k < len(frame.tid):
                        del frame.tid[k]
                    if k < len(frame.tdest):
                        del frame.tdest[k]

        # remove tkeep
        frame.tkeep = None

        # clean up other sideband signals
        # either remove or consolidate if values are identical
        if len(frame.tid) == 0:
            frame.tid = None
        elif all(frame.tid[0] == i for i in frame.tid):
            frame.tid = frame.tid[0]

        if len(frame.tdest) == 0:
            frame.tdest = None
        elif all(frame.tdest[0] == i for i in frame.tdest):
            frame.tdest = frame.tdest[0]

        if len(frame.tuser) == 0:
            frame.tuser = None
        elif all(frame.tuser[0] == i for i in frame.tuser):
            frame.tuser = frame.tuser[0]

        return frame

        



    