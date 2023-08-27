/*

Copyright (c) 2013-2023 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream FIFO
 */
module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8
) (
    input                        clk,
    input                        rst,

    // The header to be inserted to AXI Stream input
    input                        s00_axis_tvalid,
    input   [DATA_WD-1 : 0]      s00_axis_tdata,
    input   [DATA_BYTE_WD-1 : 0] s00_axis_tkeep,
    output                       s00_axis_tready,

    // AXI Stream input original data
    input                        s01_axis_tvalid,
    input   [DATA_WD-1 : 0]      s01_axis_tdata,
    input   [DATA_BYTE_WD-1 : 0] s01_axis_tkeep,
    input                        s01_axis_tlast,
    output                       s01_axis_tready,

    // AXI Stream output with header inserted
    output                       m_axis_tvalid,
    output  [DATA_WD-1 : 0]      m_axis_tdata,
    output  [DATA_BYTE_WD-1 : 0] m_axis_tkeep,
    output                       m_axis_tlast,
    input                        m_axis_tready
);

    mkDataInserterStream u_mkDataInserterStream(
        clk,
        !rst,
        s00_axis_tvalid,
        s00_axis_tdata,
        s00_axis_tkeep,
        1'b1,
        s00_axis_tready,
        
        s01_axis_tvalid,
        s01_axis_tdata,
        s01_axis_tkeep,
        s01_axis_tlast,
        s01_axis_tready,

        m_axis_tvalid,
        m_axis_tdata,
        m_axis_tkeep,
        m_axis_tlast,
        m_axis_tready);

endmodule

`resetall