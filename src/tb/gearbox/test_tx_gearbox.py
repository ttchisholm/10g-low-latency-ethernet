from asyncore import loop
import asyncio
import enum
import cocotb
import numpy as np
from gearbox_model import TxGearboxModel

from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, NextTimeStep
from cocotb.clock import Clock

import debugpy

class TxGearboxTb:
    def __init__(self, dut):
        self.dut = dut
    
        self.clk_period = round(1 / (10.3125 / 32), 2) # ps precision
        cocotb.start_soon(Clock(dut.i_clk, self.clk_period, units="ns").start())
        self.dut.i_reset.value = 1
        self.dut.i_data.value = 0
        self.dut.i_header.value = 0

        
    async def reset(self):
        self.dut.i_reset.value = 0
        await RisingEdge(self.dut.i_clk)
        self.dut.i_reset.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_reset.value = 0
        


@cocotb.test()
async def tx_gearbox_test(dut):

    # debugpy.listen(5678)
    # debugpy.wait_for_client()
    # debugpy.breakpoint()
    

    tb = TxGearboxTb(dut)
   
    await tb.reset()

    # Generate random data
    np.random.seed(0)
    gen_idata = [np.random.randint(0,2,64) for _ in range(200)]
    gen_iheader = [np.random.randint(0,2,2) for _ in range(200)]

    # gen_iheader = [[f'{y:02d}-H0{x}' for x in range(2)] for y in range(20)]
    # gen_idata = [[f'{y:02d}-D{x:02d}' for x in range(64)] for y in range(20)]

    # Create ref model
    model = TxGearboxModel('str')


    async def run_cycle(iheader, idata):
        
        for i in range(len(iheader)):
            tb.dut.i_header[i].value = int(iheader[i])

        for i in range(len(idata)):
            tb.dut.i_data[i].value = int(idata[i])

        tb.dut.i_gearbox_seq.value = model.get_count()
        tb.dut.i_pause.value = model.get_pause()

        await FallingEdge(tb.dut.i_clk) # Give the sim a tick to update the comb outputs
        
        dut_odata = str(tb.dut.o_data.value)[::-1]
        dut_obuf = str(tb.dut.next_obuf.value)[::-1]

        await RisingEdge(tb.dut.i_clk)

        ret = model.next(iheader, idata)

        model_odata = ''.join([str(x) for x in ret['data']])
        model_obuf = ''.join([str(x) for x in ret['obuf']])

        all_eq = model_odata == dut_odata

        if not all_eq:
            print('OK' if all_eq else 'FAIL')
            print('seq: ', int(tb.dut.i_gearbox_seq.value))
            print('pause: ', tb.dut.i_pause.value)
            print('dut data:    ', dut_odata)
            print('model data:  ', model_odata)
            print('input data:  ', str(tb.dut.i_data.value)[::-1])
            print('input header:  ', str(tb.dut.i_header.value)[::-1])
        
        assert all_eq

        return ret



    tb.dut.i_data.value = 0

    for ih, id in zip(gen_iheader, gen_idata):
        for _ in range(2):

            idata = id[32:] if model.get_frame_word() else id[:32]
            
            ret = await run_cycle(ih, idata)

            if (ret['pause']): # do another cycle with same data
                ret = await run_cycle(ih, idata)

   
        

  