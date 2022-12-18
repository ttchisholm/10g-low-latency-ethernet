import random

import numpy as np

from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.queue import QueueEmpty, Queue
from cocotb.clock import Clock

from pyuvm import *
import pyuvm

from eth_10g_bfm import Eth10gBfm

import debugpy

class EthTxSeqItem(uvm_sequence_item):
    def __init__(self, name, packet_size):
        super().__init__(name)
        self.packet_size = packet_size
        self.packet = np.random.randint(0, 255, packet_size, dtype=np.uint8)

    def __eq__(self, other):
        return self.packet == other.packet

    def __str__(self):
        return f'{self.get_name()} : Size = {len(self.packet)}, Data = {self.packet}'

class EthTxSeqRandom(uvm_sequence):

    async def body(self):
        for i in range(10):
            seq_item = EthTxSeqItem(f'p{i}', np.random.randint(64, 256, 1))
            await self.start_item(seq_item)
            await self.finish_item(seq_item)

class TestAllSeq(uvm_sequence):

    async def body(self):
        seqr = ConfigDB().get(None, "", "SEQR")
        random = EthTxSeqRandom("random")
        await random.start(seqr)

class TxDriver(uvm_driver):
    def build_phase(self):
        self.ap = uvm_analysis_port('ap', self)

    def start_of_simulation_phase(self):
        self.bfm = Eth10gBfm()

    async def launch_tb(self):
        await self.bfm.start_bfm()
        await self.bfm.pause(20)

    async def run_phase(self):
        await self.launch_tb()
        while True:
            seq_item = await self.seq_item_port.get_next_item()
            await self.bfm.send_tx_packet(seq_item.packet)
            self.seq_item_port.item_done()

class EthEnv(uvm_env):
    def build_phase(self):
        self.seqr = uvm_sequencer('seqr', self)
        ConfigDB().set(None, '*', 'SEQR', self.seqr)
        self.driver = TxDriver.create('driver', self)
        
    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)


class Eth10gTest(uvm_test):
    def build_phase(self):
        self.env = EthEnv("env", self)

    def end_of_elaboration_phase(self):
        self.test_random = TestAllSeq.create("test_random")

    async def run_phase(self):
        self.raise_objection()
        await self.test_random.start()
        self.drop_objection()

@cocotb.test()
async def test_run_Eth10gTest(_):
    # debugpy.listen(5678)
    # debugpy.wait_for_client()
    # debugpy.breakpoint()
    await uvm_root().run_test(Eth10gTest)
