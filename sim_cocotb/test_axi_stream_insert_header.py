#!/usr/bin/env python

import itertools
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
import numpy as np

if cocotb.simulator.is_running():
    from ref_model import genInsertHeaderData

def random_int_list(start, stop, length):
    start, stop = (int(start), int(stop)) if start <= stop else (int(stop), int(start))
    length = int(abs(length)) if length else 0
    random_list = []
    for i in range(length):
        random_list.append(random.randint(start, stop))
    return random_list

class TB(object):
    def __init__(self, dut):
        self.dut = dut

        ports = 2

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.source = [AxiStreamSource(AxiStreamBus.from_prefix(dut, f"s{k:02d}_axis"), dut.clk, dut.rst) for k in range(ports)]
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk, dut.rst)

    def set_idle_generator(self, generator=None):
        if generator:
            for source in self.source:
                source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

@cocotb.test(timeout_time=20000, timeout_unit="ns")
async def run_incr_test(dut, idle_inserter=None, backpressure_inserter=None):
    random.seed(7)
    
    tb = TB(dut)
    byte_lanes = tb.source[0].byte_lanes # 位宽字节数
    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)
    random.seed(0)
    # package_num = 16
    # for __ in range(package_num):
    for j in range(12,16):
        for i in range(4):
            # random.seed(7)
            # length = random.randint(2,16)
            # head_bytenum = random.randint(1, (length-1) if byte_lanes > (length-1) else byte_lanes) # head byte数随机
            length = j
            head_bytenum = i + 1
            head_data, head_tkeep, body_data, body_tkeep, ref_byte = genInsertHeaderData(byte_lanes, length, head_bytenum)
            head_byte = bytearray(head_data)
            head_frame = AxiStreamFrame(tdata = head_byte, tkeep = head_tkeep)
            await tb.source[0].send(head_frame)

            body_byte = bytearray(body_data)
            body_frame = AxiStreamFrame(tdata = body_byte, tkeep = body_tkeep)
            await tb.source[1].send(body_frame)

            out_frame = AxiStreamFrame(ref_byte) 
            rx_frame = await tb.sink.recv()
            assert rx_frame.tdata == out_frame.tdata


    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=20000, timeout_unit="ns")
async def run_random_test(dut, idle_inserter=None, backpressure_inserter=None):
    random.seed(7)

    tb = TB(dut)
    byte_lanes = tb.source[0].byte_lanes # 位宽字节数
    await tb.reset()
    # random.seed(7)
    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)
    package_num = 64
    for __ in range(package_num):
        
        length = random.randint(2,32)
        head_bytenum = random.randint(1, (length-1) if byte_lanes > (length-1) else byte_lanes) # head byte数随机
        head_data, head_tkeep, body_data, body_tkeep, ref_byte = genInsertHeaderData(byte_lanes, length, head_bytenum)
        head_byte = bytearray(head_data)
        head_frame = AxiStreamFrame(tdata = head_byte, tkeep = head_tkeep)
        await tb.source[0].send(head_frame)

        body_byte = bytearray(body_data)
        body_frame = AxiStreamFrame(tdata = body_byte, tkeep = body_tkeep)
        await tb.source[1].send(body_frame)

        out_frame = AxiStreamFrame(ref_byte) 
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == out_frame.tdata

    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

def cycle_pause():
    # return itertools.cycle([1, 1, 1, 0])
    return itertools.cycle(random_int_list(0,1,100))


# 自增测试,遍历所有head和data的长度组合情况
factory = TestFactory(run_incr_test)
factory.add_option("idle_inserter", [None, cycle_pause])
factory.add_option("backpressure_inserter", [None, cycle_pause])
factory.generate_tests()

# 随机测试
factory = TestFactory(run_random_test)
factory.add_option("idle_inserter", [None, cycle_pause])
factory.add_option("backpressure_inserter", [None, cycle_pause])
factory.generate_tests()
