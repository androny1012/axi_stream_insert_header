`resetall
`timescale 1ns / 1ps
`default_nettype none

module DataInserterStream #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8
) (
    input                           clk,
    input                           rst,

    // The header to be inserted to AXI Stream input
    input                           s00_axis_tvalid,
    input   [DATA_WD-1 : 0]         s00_axis_tdata,
    input   [DATA_BYTE_WD-1 : 0]    s00_axis_tkeep,
    output                          s00_axis_tready,

    // AXI Stream input original data
    input                           s01_axis_tvalid,
    input   [DATA_WD-1 : 0]         s01_axis_tdata,
    input   [DATA_BYTE_WD-1 : 0]    s01_axis_tkeep,
    input                           s01_axis_tlast,
    output                          s01_axis_tready,

    // AXI Stream output with header inserted
    output                          m_axis_tvalid,
    output  [DATA_WD-1 : 0]         m_axis_tdata,
    output  [DATA_BYTE_WD-1 : 0]    m_axis_tkeep,
    output                          m_axis_tlast,
    input                           m_axis_tready
);

    reg                         header_valid_reg;
    reg [DATA_WD-1 : 0]         header_data_reg ;
    reg [DATA_BYTE_WD-1 : 0]    header_keep_reg ;

    reg                         data_valid_reg;
    reg [DATA_WD-1 : 0]         data_data_reg ;
    reg [DATA_BYTE_WD-1 : 0]    data_keep_reg ;
    reg                         data_last_reg;

    reg                         res_valid_reg;
    reg [DATA_WD-1 : 0]         res_data_reg ;
    reg [DATA_BYTE_WD-1 : 0]    res_keep_reg ;
    reg [DATA_WD-1 : 0]         res_data_shift;
    reg [DATA_BYTE_WD-1 : 0]    res_keep_shift;

    reg [2*DATA_WD-1 : 0]       concat_data;
    reg [2*DATA_BYTE_WD-1 : 0]  concat_keep;
    reg [2*DATA_WD-1 : 0]       concat_data_shift;
    reg [2*DATA_BYTE_WD-1 : 0]  concat_keep_shift;

    integer idx;
    
    reg send_header;
    reg last_sv;
    reg tlast_gen;
    reg tail_valid;

    // 记录本次传输是否已经发过header，为1是还没发，防止重复发header
    always @(posedge clk) begin
        if(rst) begin
            send_header <= 1'b1;
        end else if(m_axis_tvalid && m_axis_tready) begin
            send_header <= m_axis_tlast;
        end
    end

    // 记录收到输入tlast 和输出tlast的时间，在此期间，不要再发buffer中的一个数据
    always @(posedge clk) begin
        if(rst) begin
            last_sv <= 1'b0;
        end else if(s01_axis_tvalid && s01_axis_tready && s01_axis_tlast) begin
            last_sv <= 1'b1;
        end else if(  m_axis_tvalid &&   m_axis_tready &&   m_axis_tlast) begin
            last_sv <= 1'b0;
        end
    end

    // header用过了为什么不能清空，因为一次传输没结束，header进来也没用，还可以用于记录已经收到head的状态
    always @(posedge clk) begin
        if(rst) begin
            header_valid_reg <= 1'b0;
            header_data_reg  <= 'b0;
            header_keep_reg  <= 'b0;
        end else if(s00_axis_tready) begin
            header_valid_reg <= s00_axis_tvalid;
            header_data_reg  <= s00_axis_tdata;
            header_keep_reg  <= s00_axis_tkeep;
        end else if(m_axis_tready && m_axis_tvalid && m_axis_tlast) begin
            header_valid_reg <= 1'b0;
        end
    end

    // 要保证清空的逻辑是已经用过了buffer中的数据
    // 握手必须清空buffer吗？如果发的header是1111呢？ 先不考虑这个情况？
    // 清空buffer的条件应该是data reg送入了 res buffer中
    // 而res buffer取data reg的条件就是 输出握手，前提是送出去的不是全1
    always @(posedge clk) begin
        if(rst) begin
            data_valid_reg <= 1'b0;
            data_data_reg  <= 'b0;
            data_keep_reg  <= 'b0;
            data_last_reg  <= 1'b0;
        end else if(s01_axis_tready) begin
            data_valid_reg <= s01_axis_tvalid;
            data_data_reg  <= s01_axis_tdata;
            data_keep_reg  <= s01_axis_tkeep;
            data_last_reg  <= s01_axis_tlast;
        end else if(m_axis_tready && m_axis_tvalid) begin
            // 只在传输本次数据时清空buffer,防止清掉提前进来的数据
            if(!last_sv)
                data_valid_reg <= 1'b0;
        end 
    end

    always @(*) begin
        if(rst) begin
            concat_data = 'b0;
            concat_keep = 'b0;
        end else begin
            concat_data = 'b0;
            concat_keep = 'b0;
            if(header_valid_reg && send_header) begin // 发过header后就不要再送入输出端口
                concat_data[2*DATA_WD-1      : DATA_WD]      = header_data_reg;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = header_keep_reg;
            end
            if(res_valid_reg) begin                  // 只要有res的数据就可以拼接到最高位
                concat_data[2*DATA_WD-1      : DATA_WD]      = res_data_shift;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = res_keep_shift;            
            end
            if(data_valid_reg && ((header_valid_reg && send_header) | !send_header) && !tail_valid) begin // 可以和head同时concat，但不能是下一次传输的数据
                concat_data[DATA_WD-1      : 0]              = data_data_reg;
                concat_keep[DATA_BYTE_WD-1 : 0]              = data_keep_reg;
            end
        end
    end

    always @(*) begin
        concat_data_shift = concat_data;  
        concat_keep_shift = concat_keep;  
        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
            if(!concat_keep_shift[2*DATA_BYTE_WD-1]) begin
                concat_data_shift = concat_data_shift << 8;
                concat_keep_shift = concat_keep_shift << 1;
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            res_valid_reg <= 1'b0;
            res_data_reg  <= 'b0;
            res_keep_reg  <= 'b0;
        end else if(m_axis_tvalid && m_axis_tready) begin
            res_valid_reg <= concat_keep_shift[DATA_BYTE_WD-1];
            res_data_reg  <= concat_data_shift[DATA_WD-1      : 0];
            res_keep_reg  <= concat_keep_shift[DATA_BYTE_WD-1 : 0];
        end
    end

    always @(*) begin
        res_data_shift = res_data_reg;  
        res_keep_shift = res_keep_reg;  
        for( idx = 0; idx<DATA_BYTE_WD-1; idx = idx + 1) begin
            if(!res_keep_shift[0]) begin
                res_data_shift = res_data_shift >> 8;
                res_keep_shift = res_keep_shift >> 1;
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            tail_valid <= 1'b0;
        end else if(last_sv && m_axis_tready && header_valid_reg) begin // 收到了 head 且收到了最后一个data，且将要输出最后一拍的一部分数据，如果还有剩，就是小尾巴
            tail_valid <= concat_keep_shift[DATA_BYTE_WD-1];
        end else if(m_axis_tready && m_axis_tlast) begin
            tail_valid <= 1'b0;
        end
    end  

    always @(*) begin
        if(rst) begin
            tlast_gen = 1'b0;
        end else if(last_sv && m_axis_tready && header_valid_reg) begin // 收到了 head 且收到了最后一个data，在输出数据的时候判断buffer中是否还有剩余的数据，无则就是最后一拍
            tlast_gen = !concat_keep_shift[DATA_BYTE_WD-1];
        end else if(tail_valid && m_axis_tready) begin
            tlast_gen = !concat_keep_shift[DATA_BYTE_WD-1];
        end else begin
            tlast_gen = 1'b0;
        end
    end

    // header : buffer 为空 或者 本次传输结束
    assign s00_axis_tready  = !header_valid_reg | (m_axis_tready && m_axis_tlast);

    // data   : buffer 为空 或者 传输了一个本次传输的数据 !last_sv 是防止下次传输的数据被送入
    // assign s01_axis_tready  = !data_valid_reg   | (m_axis_tready && m_axis_tlast); 
    assign s01_axis_tready  = !data_valid_reg   | (m_axis_tready && m_axis_tlast) | (m_axis_tready && m_axis_tvalid && !last_sv) ;
    // data_valid_reg 中有数据并不代表一定会输出，可能输出的是head?可能是下次传输提前进buffer的数据，不能输出

    assign m_axis_tdata  = concat_data_shift[2*DATA_WD-1      :      DATA_WD];
    assign m_axis_tvalid = concat_keep_shift[  DATA_BYTE_WD                 ] | m_axis_tlast;
    assign m_axis_tkeep  = concat_keep_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD];
    assign m_axis_tlast  = tlast_gen;
endmodule

`resetall