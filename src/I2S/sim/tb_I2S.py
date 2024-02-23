# -*- coding: utf-8 -*-
"""
Created on Thu Sep 23 22:16:04 2021

@author: Philip


"""
import numpy as np
import random
import logging

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.queue import Queue
from cocotb.handle import SimHandleBase
from cocotb.result import TestFailure


class I2SDataMonitor:
    """
    """

    def __init__(self, sclk, lrck, sd, data_width=24, sclk_lrck_ratio=64):
        self.values = Queue()
        self._sclk = sclk # serial clock handle
        self._lrck = lrck # Left/right clk/ws handle
        self._sd = sd #serial data handle
        self._data_width = data_width
        self._sclk_lrck_ratio = sclk_lrck_ratio
        self._coro = None

    def start(self):
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self):
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        self._coro.kill()
        self._coro = None

    async def _run(self):
        while True:
            data_sample = dict(left=0, right=0)
            # Wait until falling edge of lrck
            await FallingEdge(self._lrck)
            
            for channel in ['left', 'right']:
                await RisingEdge(self._sclk)
                for _ in range(self._data_width):
                    # Shift in samples
                    await RisingEdge(self._sclk)
                    data_sample[channel] = (data_sample[channel] << 1) | (self._sd.value & 0b1)
                if channel == 'left':
                    await RisingEdge(self._lrck)

            self.values.put_nowait(data_sample)

class I2SRxDataDriver:
    """
    Drives the rx serial data pin with the I2S protocol
    """

    def __init__(self,log, sclk, lrck, sd, data_width=24, mode="random"):
        self._log = log
        self._sclk = sclk # serial clock handle
        self._lrck = lrck # Left/right clk/ws handle
        self._sd = sd #serial data handle
        self._data_width = data_width
        self._coro = None
        self._mode = mode
        
    def start(self):
        """Start Driver"""
        if self._coro is not None:
            raise RuntimeError("Driver already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self):
        """Stop Driver"""
        if self._coro is None:
            raise RuntimeError("Driver never started")
        self._coro.kill()
        self._coro = None

    async def _run(self):
        left_sample = 0
        right_sample = 0 
        while True:
            if self._mode == "random":
                left_sample = random.randint(0, 2**(self._data_width)-1)
                # left_sample = 2**self._data_width-1
                right_sample = random.randint(0, 2**(self._data_width)-1)
                # right_sample = 2**self._data_width-1

            elif self._mode == "ramp":
                left_sample += 1 
                right_sample += 1
            else:
                raise ValueError("Unsupported driver mode! Must be \"random\" or \"ramp\"")
            
            data_sample = dict(left=left_sample, right=right_sample)
            self._log.info("Sending left_sample: %d, right_sample: %d", left_sample, right_sample)
            
            # Wait until falling edge of lrck
            await FallingEdge(self._lrck)
            
            for channel in ['left', 'right']:
                await FallingEdge(self._sclk)
                for _ in range(self._data_width):
                    # Shift out samples
                    self._sd.value = (data_sample[channel] >> (self._data_width - 1)) & 0b1
                    data_sample[channel] = data_sample[channel] << 1 
                    await FallingEdge(self._sclk)
                
                self._sd.value = 0
                if channel == 'left':
                    await RisingEdge(self._lrck)

class I2STxDataDriver:
    """
    Drives the Tx bus input to the I2S module
    """
    def __init__(self,log, clk, data, valid, ready, data_width=24, mode="random"):
        self.values = Queue()
        self._log = log
        self._clk = clk
        self._data = data
        self._valid = valid
        self._ready = ready
        self._data_width = data_width
        self._coro = None
        self._mode = mode
        
    def start(self):
        """Start Driver"""
        if self._coro is not None:
            raise RuntimeError("Driver already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self):
        """Stop Driver"""
        if self._coro is None:
            raise RuntimeError("Driver never started")
        self._coro.kill()
        self._coro = None

    async def _run(self):
        left_sample = 0
        right_sample = 0 
        while True:
            if self._mode == "random":
                left_sample = random.randint(0, 2**(self._data_width)-1)
                #left_sample = 2**self._data_width-1
                right_sample = random.randint(0, 2**(self._data_width)-1)
                # right_sample = 2**self._data_width-1

            elif self._mode == "ramp":
                left_sample += 1 
                right_sample += 1
            else:
                raise ValueError("Unsupported driver mode! Must be \"random\" or \"ramp\"")
            
            data_sample = (left_sample << 24) |  right_sample
            self._log.info("Sending left_sample: %d, right_sample: %d", left_sample, right_sample)
            self._valid.value = 1
            self._data.value = data_sample
            await RisingEdge(self._clk)

            # Transaction happens when ready = 1 and valid = 1
            while self._ready.value.binstr != '1':
                await RisingEdge(self._clk)
 
            # Place sent data onto queue
            tx_sample_dict = dict(left=left_sample, right=right_sample)
            self.values.put_nowait(tx_sample_dict)

class DataValidMonitor:
    """
    """

    def __init__(self, clk, data, valid, ready):
        self.values = Queue()
        self._clk = clk
        self._data = data
        self._valid = valid
        self._ready = ready
        self._coro = None

    def start(self):
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self):
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        self._coro.kill()
        self._coro = None

    async def _run(self):
        self._ready.value = 1
        while True:
            await RisingEdge(self._clk)
            if self._valid.value.binstr == '1':
                left_sample = (self._data.value & (0xFFFFFF << 24)) >> 24    #take left 24 bits
                right_sample = self._data.value & (0xFFFFFF)    #take right 24 bits
                i2s_sample = dict(left=left_sample, right=right_sample)
                self.values.put_nowait(i2s_sample)

class Scoreboard:
    def __init__(self, log, input_mon, output_mon, skip_first_data=False, stop_at_error=False):
        self._log = log
        # self.expected =
        self.errors = 0
        self.input_mon = input_mon
        self.output_mon = output_mon
        self._sae = stop_at_error
        self._coro = None
        self._skip_first_data = skip_first_data

    
    def check(self, dut_val, ref_val, print_info=""):
        if dut_val == ref_val:
            self._log.info("Data match, got: {}, expected {}, {}".format(dut_val, ref_val, print_info))
        else:
            self._log.error("Incorrect data, got: {}, expected {}, {}".format(dut_val, ref_val, print_info))
            self.errors += 1
            if self._sae:
                raise TestFailure("Incorrect data, got: {}, expected {}, {}".format(dut_val, ref_val, print_info))
    
    def start(self):
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Scoreboard already started")
        self._coro = cocotb.start_soon(self._run())

    def stop(self):
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Scoreboard never started")
        self._coro.kill()
        self._coro = None
        self._log.info("Number of errors: %d", self.errors)
    
    async def _run(self):
        # For tx, we need to skip the first data after reset. The LR Ck
        # hasn't transitioned yet, so there is no way to sync the RX monitor to
        # sample the first data
        if self._skip_first_data:
            await self.input_mon.values.get()            
        while True:
            ref_output = await self.input_mon.values.get()
            dut_output = await self.output_mon.values.get()
            self.check(dut_output, ref_output)
        
class TB(object):

    def __init__(self, dut):
        self.dut = dut
        self.log = dut._log
        self.rx_driver_log = logging.getLogger('rx_driver')
        self.rx_driver_log.setLevel(logging.INFO)
        self.rx_scoreboard_log = logging.getLogger('rx_scoreboard')
        self.rx_scoreboard_log.setLevel(logging.INFO)

        self.tx_driver_log = logging.getLogger('tx_driver')
        self.tx_driver_log.setLevel(logging.INFO)
        self.tx_scoreboard_log = logging.getLogger('tx_scoreboard')
        self.tx_scoreboard_log.setLevel(logging.INFO)
        
        self.clk_period = 10
        self.clk_units = "ns"
        
        self.data_width = 24 

        # Receive monitors/drivers/scoreboard
        self.output_rx_mon = DataValidMonitor(
            self.dut.clk,
            self.dut.o_rx_data,
            self.dut.o_rx_data_vld,
            self.dut.i_rx_rdy,
            )
        
        self.input_rx_mon = I2SDataMonitor(
            self.dut.o_i2s_rx_sclk,
            self.dut.o_i2s_rx_lrck,
            self.dut.i_i2s_rx_sd,
            self.data_width, 
            )

        self.input_rx_driver = I2SRxDataDriver(
            self.rx_driver_log,
            self.dut.o_i2s_rx_sclk,
            self.dut.o_i2s_rx_lrck,
            self.dut.i_i2s_rx_sd,
            self.data_width, 
            mode="random",
            )
        
        self.rx_scoreboard = Scoreboard(
            self.rx_scoreboard_log,
            self.input_rx_mon,
            self.output_rx_mon,
            stop_at_error=False,
            )
        
        # Transmit monitors/drivers/scoreboard       
        self.output_tx_mon = I2SDataMonitor(
            self.dut.o_i2s_tx_sclk,
            self.dut.o_i2s_tx_lrck,
            self.dut.o_i2s_tx_sd,
            self.data_width, 
            )

        self.input_tx_driver = I2STxDataDriver(
            self.tx_driver_log,
            self.dut.clk,
            self.dut.i_tx_data,
            self.dut.i_tx_data_vld,
            self.dut.o_tx_rdy,
            self.data_width,
            mode="random",
            )
        
        self.tx_scoreboard = Scoreboard(
            self.tx_scoreboard_log,
            self.input_tx_driver,
            self.output_tx_mon,
            skip_first_data=True,
            stop_at_error=False,
            )

        # start the clock
        cocotb.start_soon(Clock(self.dut.clk, self.clk_period,
                          units=self.clk_units).start())
        
    async def reset(self, n_clks=5):
        self.log.info('reset')
        self.dut.rst.value = 1
        await self.wait_clks(n_clks)
        self.dut.rst.value = 0

    async def wait_clks(self, n_clks=1):
        for _ in range(n_clks):
            await RisingEdge(self.dut.clk)

    def _init_signals(self):
        self.dut.i_i2s_rx_sd.value = 0
        self.dut.i_rx_rdy.value = 1

    async def start_rx(self):
        """Starts monitors, drivers and scoreboard"""
        self._init_signals()
        self.input_rx_driver.start()
        self.input_rx_mon.start()
        await FallingEdge(self.dut.o_i2s_rx_lrck)
        await FallingEdge(self.dut.o_i2s_rx_lrck)
        self.output_rx_mon.start()
        self.rx_scoreboard.start()
        
    def end_rx(self, ):
        """Stops everything"""
        self.input_rx_driver.stop()
        self.input_rx_mon.stop()
        self.output_rx_mon.stop()
        self.rx_scoreboard.stop()
        self.log.info("End of sim")

    async def start_tx(self):
        """Starts monitors, drivers and scoreboard"""
        self._init_signals()
        self.input_tx_driver.start()
        self.output_tx_mon.start()
        self.tx_scoreboard.start()
        
    def end_tx(self, ):
        """Stops everything"""
        self.input_tx_driver.stop()
        self.output_tx_mon.stop()
        self.tx_scoreboard.stop()
        self.log.info("End of sim")
