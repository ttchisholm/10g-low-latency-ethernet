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

"""test_mac_pcs.py

    Pyuvm testbench for mac_pcs module.

    This testbench implements a single test with random packets, tested in loopback.
    Received packets are checked for correctness and for CRC match flag (TUSER) set.

"""

import random
import debugpy
import yaml
import pytest
import numpy as np
import os
import glob
from shutil import copyfile

from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.queue import QueueEmpty, Queue
from cocotb.clock import Clock
from cocotb_test.simulator import run

from pyuvm import *
import pyuvm

from mac_pcs_bfm import MacPcsBfm

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

    def __init__(self, name, length):
        super().__init__(name)
        self.length = length

    async def body(self):
        for i in range(self.length):
            seq_item = EthTxSeqItem(f'p{i}', np.random.randint(16, 256, 1))
            await self.start_item(seq_item)
            await self.finish_item(seq_item)

class EthTxAllSeq(uvm_sequence):
    async def body(self):
        self.config = ConfigDB().get(None, "", 'run_config')
        seqr = ConfigDB().get(None, "", "SEQR")
        random = EthTxSeqRandom("random", self.config['tx_seq_length'])
        await random.start(seqr)

class TxDriver(uvm_driver):
    def build_phase(self):
        self.config = ConfigDB().get(self, "", 'run_config')
        self.ap = uvm_analysis_port('ap', self)

    def start_of_simulation_phase(self):
        self.bfm = MacPcsBfm()

    async def launch_tb(self):
        await self.bfm.start_bfm()
        await self.bfm.pause(self.config['startup_pause'])

    async def run_phase(self):
        await self.launch_tb()
        while True:
            seq_item = await self.seq_item_port.get_next_item()
            await self.bfm.send_tx_packet(seq_item.packet)
            self.seq_item_port.item_done()

class Monitor(uvm_component):
    def __init__(self, name, parent, method_name):
        super().__init__(name, parent)
        self.method_name = method_name

    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)
        self.bfm = MacPcsBfm()
        self.get_method = getattr(self.bfm, self.method_name)

    async def run_phase(self):
        while True:
            datum = await self.get_method()
            self.logger.debug(f"MONITORED {datum}")
            self.ap.write(datum)

class Scoreboard(uvm_component):
    def build_phase(self):
        self.tx_frame_fifo = uvm_tlm_analysis_fifo("tx_frame_fifo", self)
        self.rx_frame_fifo = uvm_tlm_analysis_fifo("rx_frame_fifo", self)
        self.tx_frame_port = uvm_get_port("tx_frame_port", self)
        self.rx_frame_port = uvm_get_port("rx_frame_port", self)
        self.tx_frame_export = self.tx_frame_fifo.analysis_export
        self.rx_frame_export = self.rx_frame_fifo.analysis_export

    def connect_phase(self):
        self.tx_frame_port.connect(self.tx_frame_fifo.get_export)
        self.rx_frame_port.connect(self.rx_frame_fifo.get_export)

    def check_phase(self):

        had_frame = False

        while self.rx_frame_port.can_get():
            _, rx_frame = self.rx_frame_port.try_get()
            tx_success, tx_frame = self.tx_frame_port.try_get()
            
            had_frame = True

            if not tx_success:
                self.logger.critical(f'tx_frame {tx_frame} error')
                assert tx_success
            else:

                if len(tx_frame.tdata) < 64:
                    data_eq = rx_frame.tdata[0:len(tx_frame.tdata)] == tx_frame.tdata and \
                                all([x == 0 for x in rx_frame.tdata[len(tx_frame.tdata):-4]])
                else:
                    data_eq = rx_frame.tdata[:-4] == tx_frame.tdata

                try:
                    iter(rx_frame.tuser)
                    rx_crc_valid = rx_frame.tuser[-1] == 1
                except TypeError:
                    rx_crc_valid = False    
                    

                if not data_eq:
                    self.logger.critical(f"FAILED (Data Not Equal): {rx_frame}, {tx_frame}")
                    for i, (tx,rx) in enumerate(zip(tx_frame.tdata, rx_frame.tdata)):
                        if tx != rx:
                            print(f'Index {i}, tx = 0x{tx:02x}, rx = 0x{rx:02x}')

                elif not rx_crc_valid:
                    self.logger.critical(f"FAILED (CRC Valid Flag Not Set): {rx_frame}, {tx_frame}")
                else:
                    self.logger.info(f"PASSED: {rx_frame}, {tx_frame}")

                assert data_eq and rx_crc_valid

        if not had_frame: self.logger.critical(f"Didn't recieve any frames")
        assert had_frame



class EthEnv(uvm_env):
    def build_phase(self):
        self.config = ConfigDB().get(self, "", 'run_config')
        
        self.seqr = uvm_sequencer('seqr', self)
        ConfigDB().set(None, '*', 'SEQR', self.seqr)
        
        self.bfm = MacPcsBfm()
        self.bfm.set_axis_log(self.config['print_axis'])
        
        self.driver = TxDriver.create('driver', self)
        self.tx_mon = Monitor("tx_mon", self, "get_tx_frame")
        self.rx_mon = Monitor("rx_mon", self, "get_rx_frame")
        self.scoreboard = Scoreboard("scoreboard", self)
        
    def connect_phase(self):
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        self.tx_mon.ap.connect(self.scoreboard.tx_frame_export)
        self.rx_mon.ap.connect(self.scoreboard.rx_frame_export)


class MacPcsTest(uvm_test):
    def build_phase(self):

        with open('mac_pcs_config.yaml', 'r') as f:
            self.config = yaml.safe_load(f)
        
        ConfigDB().set(None, '*', 'run_config', self.config)

        np.random.seed(self.config['seed'])

        if self.config['debug']:
            debugpy.listen(5678)
            debugpy.wait_for_client()
            debugpy.breakpoint()

        self.env = EthEnv("env", self)

    def end_of_elaboration_phase(self):
        self.test_random = EthTxAllSeq.create("test_random")

    async def run_phase(self):
        self.raise_objection()
        await self.test_random.start()
        self.drop_objection()



@cocotb.test()
async def run_MacPcsTest(pytestconfig):
    # 
    await uvm_root().run_test(MacPcsTest)

@pytest.mark.parametrize(
    "parameters,config", [
        ({"EXTERNAL_GEARBOX": "0", "SCRAMBLER_BYPASS": "0"}, {"loopback_bit_slip": 0}),
        ({"EXTERNAL_GEARBOX": "0", "SCRAMBLER_BYPASS": "0"}, {"loopback_bit_slip": 1}),
        ({"EXTERNAL_GEARBOX": "0", "SCRAMBLER_BYPASS": "0"}, {"loopback_bit_slip": 2}),
        ({"EXTERNAL_GEARBOX": "0", "SCRAMBLER_BYPASS": "0"}, {"loopback_bit_slip": 3}),
        ({"EXTERNAL_GEARBOX": "1", "SCRAMBLER_BYPASS": "0"}, {"loopback_bit_slip": 0}),
        ])
def test_mac_pcs(parameters, config):

    test_variables = {**parameters,  **config}

    sim_build = "./sim_build/" + ",".join((f"{key}={str(value)}" for key, value in test_variables.items()))

    os.makedirs(sim_build, exist_ok=True)

    with open('mac_pcs_config.yaml', 'r') as f:
        base_config = yaml.safe_load(f)

    base_config.update(config)

    with open(os.path.join(sim_build, "mac_pcs_config.yaml"), 'w') as f:
        yaml.dump(base_config, f)

    copyfile("../../lib/slicing_crc/hdl/crc_tables.mem", os.path.join(sim_build, "crc_tables.mem"))

    source_tree = [
        glob.glob('../../hdl/mac_pcs.sv'),
        glob.glob('../../hdl/mac/*.sv'),
        glob.glob('../../hdl/pcs/*.sv'),
        glob.glob('../../lib/slicing_crc/hdl/*.sv')
    ]

    sources = [item for sublist in source_tree for item in sublist]

    run(
        verilog_sources=sources,
        toplevel="mac_pcs",

        module="test_mac_pcs",
        simulator="icarus",
        verilog_compile_args=["-g2012"],
        includes=["../../hdl/include/"],
        parameters=parameters,
        extra_env=parameters,
        sim_build=sim_build
    )