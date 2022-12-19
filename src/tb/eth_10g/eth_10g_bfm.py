import logging

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Edge
from cocotb.queue import QueueEmpty, Queue
from cocotb.clock import Clock

from pyuvm import utility_classes

from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor)

import debugpy

class Eth10gBfm(metaclass=utility_classes.Singleton):
    def __init__(self):
        self.dut = cocotb.top
        self.tx_driver_queue = Queue(maxsize=1)
        self.tx_monitor_queue = Queue(maxsize=0)
        # self.rx_mon_queue = Queue(maxsize=0)

        self.tx_axis_source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "s00_axis"), 
                                                self.dut.i_xver_txc, self.dut.i_reset)
        self.tx_axis_source.log.propagate = True

        self.tx_axis_monitor = AxiStreamMonitor(AxiStreamBus.from_prefix(self.dut, "s00_axis"), 
                                                self.dut.i_xver_txc, self.dut.i_reset)

       
    async def loopback(self):
        while True:
            await Edge(self.dut.o_xver_txd)
            self.dut.i_xver_rxd.value = self.dut.o_xver_txd.value

    async def send_tx_packet(self, packet):
        await self.tx_driver_queue.put(packet)

    async def reset(self):
        self.dut.i_reset.value = 1
        # self.dut.s00_axis_tdata.value = 0
        # self.dut.s00_axis_tkeep.value = 0
        # self.dut.s00_axis_tvalid.value = 0
        # self.dut.s00_axis_tlast.value = 0
        self.dut.m00_axis_tready.value = 0
        self.dut.i_xver_rxc.value = 0
        self.dut.i_xver_rxd.value = 0
        self.dut.i_xver_txc.value = 0
        await RisingEdge(self.dut.i_xver_rxc)
        await RisingEdge(self.dut.i_xver_txc)
        await FallingEdge(self.dut.i_xver_rxc)
        await FallingEdge(self.dut.i_xver_txc)
        self.dut.i_reset.value = 0
        await RisingEdge(self.dut.i_xver_rxc)
        await RisingEdge(self.dut.i_xver_txc)

    async def pause(self, cycles):
        for _ in range(cycles):
            await RisingEdge(self.dut.i_xver_txc)

    async def driver_bfm(self):
        while True:
            packet = await self.tx_driver_queue.get()
            await self.tx_axis_source.send(packet.tostring())
            await self.tx_axis_source.wait()


    async def tx_monitor_bfm(self):
        while True:
            packet = await self.tx_axis_monitor.recv()
            self.tx_monitor_queue.put_nowait(packet)

    async def get_tx_frame(self):
        return await self.tx_monitor_queue.get()
            

    async def start_bfm(self):
        self.clk_period = round(1 / (10.3125 / 64), 3) # ps precision

        cocotb.start_soon(Clock(self.dut.i_xver_txc, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(self.dut.i_xver_rxc, self.clk_period, units="ns").start())
        cocotb.start_soon(self.loopback())

        await self.reset()
        cocotb.start_soon(self.driver_bfm())
        cocotb.start_soon(self.tx_monitor_bfm())

        



    