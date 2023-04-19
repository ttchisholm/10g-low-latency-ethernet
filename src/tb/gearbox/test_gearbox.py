from asyncore import loop
import asyncio
import enum
import cocotb
import numpy as np
from gearbox_model import RxGearboxModel

from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock
from cocotb.result import TestFailure

import debugpy


class RxGearboxTb:
    def __init__(self, dut):
        self.dut = dut
    
        self.clk_period = round(1 / (10.3125 / 32), 2) # ps precision
        cocotb.start_soon(Clock(dut.i_clk, self.clk_period, units="ns").start())
        self.dut.i_reset.value = 1
        self.dut.i_slip.value = 0
        self.dut.i_data.value = 0

        
    async def reset(self):
        self.dut.i_reset.value = 0
        await RisingEdge(self.dut.i_clk)
        self.dut.i_reset.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_reset.value = 0
        
        



@cocotb.test()
async def rx_gearbox_test_no_slip(dut):

    # debugpy.listen(5678)
    # debugpy.wait_for_client()
    # debugpy.breakpoint()
    

    tb = RxGearboxTb(dut)
   
    await tb.reset()

    # Generate random data
    gen_idata = [np.random.randint(0,2,32) for _ in range(100)]

    # Create ref model
    model = RxGearboxModel()


    tb.dut.i_data.value=0
    

    # Load first set of data into dut as output delayed by one cycle
    # for i in range(len(gen_idata[0])):
    #     tb.dut.i_data[i].value = int(gen_idata[0][i])

    # await RisingEdge(tb.dut.i_clk)

    for id in gen_idata:
        for i in range(len(id)):
            tb.dut.i_data[i].value = int(id[i])

        await FallingEdge(tb.dut.i_clk)
        
        dut_odata = str(tb.dut.o_data.value)[::-1]
        dut_oheader = str(tb.dut.o_header.value)[::-1]
        dut_odata_valid = str(tb.dut.o_data_valid.value)
        dut_oheader_valid = str(tb.dut.o_header_valid.value)
        dut_obuf = str(tb.dut.next_obuf.value)[::-1]

        await RisingEdge(tb.dut.i_clk)

        ret = model.next(id)

        model_odata = ''.join([str(x) for x in ret['data']])
        model_oheader = ''.join([str(x) for x in ret['header']])
        model_odata_valid = str(int(ret['data_valid']))
        model_oheader_valid = str(int(ret['header_valid']))
        model_obuf = ''.join([str(x) for x in ret['obuf']])

        
        all_eq = model_odata == dut_odata and \
                    model_oheader == dut_oheader and \
                    model_odata_valid == dut_odata_valid and \
                    model_oheader_valid == dut_oheader_valid

        if not all_eq:
            print('dut data:    ', dut_odata_valid, dut_odata)
            print('model data:  ', model_odata_valid, model_odata)
            print('dut header:  ', dut_oheader_valid, dut_oheader)
            print('model header:', model_oheader_valid, model_oheader)
            print('dut buf:  ',  dut_obuf)
            print('model buf:',  model_obuf)
            print('dut cycle: ', tb.dut.gearbox_seq.value)
            print('model cycle: ', ret['cycle'])
            print('input data:  ', str(tb.dut.i_data.value)[::-1])
            assert all_eq


        

        

        
        

  