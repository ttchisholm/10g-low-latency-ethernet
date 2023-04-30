import pytest
import os

from cocotb_test.simulator import run

@pytest.mark.parametrize(
    "parameters", [
        {"REGISTER_OUTPUT": "0"},  
        ])
def test_rx_gearbox(parameters):

    sim_build = "./sim_build/rx_gearbox"
    os.makedirs(sim_build, exist_ok=True)

    run(
        verilog_sources=['../../hdl/pcs/rx_gearbox.sv'],
        toplevel="rx_gearbox",

        module="test_rx_gearbox",
        simulator="icarus",
        verilog_compile_args=["-g2012"],
        includes=["../hdl", "../../", "../../../"],
        parameters=parameters,
        extra_env=parameters,
        sim_build=sim_build
    )

@pytest.mark.parametrize(
    "parameters", [
        {"REGISTER_OUTPUT": "0"},  
        ])
def test_tx_gearbox(parameters):

    sim_build = "./sim_build/tx_gearbox"
    os.makedirs(sim_build, exist_ok=True)

    run(
        verilog_sources=['../../hdl/pcs/tx_gearbox.sv'],
        toplevel="tx_gearbox",

        module="test_tx_gearbox",
        simulator="icarus",
        verilog_compile_args=["-g2012"],
        includes=["../hdl", "../../", "../../../"],
        parameters=parameters,
        extra_env=parameters,
        sim_build=sim_build
    )