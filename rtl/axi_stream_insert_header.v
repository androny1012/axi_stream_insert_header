`resetall
`timescale 1ns / 1ps
`default_nettype none

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

    wire                        valid_in;
    wire [DATA_WD-1 : 0]        data_in;
    wire [DATA_BYTE_WD-1 : 0]   keep_in;
    wire                        last_in;
    wire                        ready_in;

    BypassFIFO_wrap#(
        .DEPTH       (0                                             ),  // 0 or 1 
        .DATA_WD     (DATA_WD + DATA_BYTE_WD + 1                    )
    ) u_buffer(
        .clk         (clk                                           ),
        .rst_n       (!rst                                          ),
        .valid_pre_i (s01_axis_tvalid                               ),
        .data_pre_i  ({s01_axis_tdata,s01_axis_tkeep,s01_axis_tlast}),
        .ready_pre_o (s01_axis_tready                               ),
        .valid_post_o(valid_in                                      ),
        .data_post_o ({data_in,keep_in,last_in}                     ),
        .ready_post_i(ready_in                                      )
    );

    DataInserterStream #(
        .DATA_WD        (DATA_WD        ),
        .DATA_BYTE_WD   (DATA_BYTE_WD   )
    ) u_DI(
        .clk            (clk            ),
        .rst            (rst            ),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tdata (s00_axis_tdata ),
        .s00_axis_tkeep (s00_axis_tkeep ),
        .s00_axis_tready(s00_axis_tready),
        .s01_axis_tvalid(valid_in       ),
        .s01_axis_tdata (data_in        ),
        .s01_axis_tkeep (keep_in        ),
        .s01_axis_tlast (last_in        ),
        .s01_axis_tready(ready_in       ),
        .m_axis_tvalid  (m_axis_tvalid  ),
        .m_axis_tdata   (m_axis_tdata   ),
        .m_axis_tkeep   (m_axis_tkeep   ),
        .m_axis_tlast   (m_axis_tlast   ),
        .m_axis_tready  (m_axis_tready  )
    );

endmodule

`resetall