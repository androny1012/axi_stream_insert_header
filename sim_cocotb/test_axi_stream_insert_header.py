#!/usr/bin/env python

import itertools
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink

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


async def run_test(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)
    byte_lanes = tb.source[0].byte_lanes # 位宽字节数
    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    package_num = 4
    for __ in range(package_num):
        for _ in range(1):
            length = 1  # HEAD个数
            head_data = bytearray(random_int_list(0,255,length * byte_lanes))
            head_frame = AxiStreamFrame(tdata = head_data, tkeep = [1,1,1,1])
            await tb.source[0].send(head_frame)

        for _ in range(1):
            # length = random.randint(8, 16) # 数据个数
            length = 2 # 数据个数
            body_data = bytearray(random_int_list(0,255,length * byte_lanes))
            body_frame = AxiStreamFrame(tdata = body_data, tkeep = [1,1,1,1])
            await tb.source[1].send(body_frame)

        out_frame = AxiStreamFrame(head_data + body_data)
        rx_frame = await tb.sink.recv()
        assert rx_frame.tdata == out_frame.tdata


    assert tb.sink.empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

def cycle_pause():
    # return itertools.cycle([1, 1, 1, 0])
    return itertools.cycle(random_int_list(0,1,100))

factory = TestFactory(run_test)
# factory.add_option("idle_inserter", [None, cycle_pause])
# factory.add_option("backpressure_inserter", [None, cycle_pause])
factory.generate_tests()


