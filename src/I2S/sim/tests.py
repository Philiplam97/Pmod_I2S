# -*- coding: utf-8 -*-
"""
Created on Thu Sep 23 22:46:54 2021

@author: Philip

test for LFSR.
"""

import numpy as np
from tb_I2S import TB 

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.queue import Queue
from cocotb.handle import SimHandleBase

@cocotb.test(skip=False)
async def test_I2S_rx(dut):
    """Test receive """
    tb = TB(dut)
    await tb.reset()
    await tb.start_rx()
    for _ in range(50):
        await RisingEdge(dut.o_i2s_tx_lrck)
    tb.end_rx()
    
@cocotb.test(skip=False)
async def test_I2S_tx(dut):
    """Test transmit """
    tb = TB(dut)
    await tb.reset()
    await tb.start_tx()
    for _ in range(50):
        await RisingEdge(dut.o_i2s_tx_lrck)
    tb.end_tx()
