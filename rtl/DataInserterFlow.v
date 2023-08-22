`resetall
`timescale 1ns / 1ps
`default_nettype none

module DataInserterFlow #(
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

    // 放一个同时可以存两组data的buffer
    // sendhead状态先把head放进buffer,如果同一时刻有data则插在后面
    // 下一周期，判断buffer_keep中是否有4个1,有就将数据左移出去，没有就不valid，同时，keep中少于等于4个1，data是可以送进来拼的
    // 需要保证buffer_keep是没有前置零的，这样判断四个1只需要用门即可

    reg send_header;
    always @(posedge clk) begin
        if(rst) begin
            send_header <= 1'b1;
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            send_header <= 1'b0;
        end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
            send_header <= 1'b1;
        end
    end

    integer idx;

    // reg [$clog2(DATA_BYTE_WD+1)-1:0]    s00_axis_tkeep_count_zeros;
    // reg [$clog2(DATA_BYTE_WD+1)-1:0]    s00_axis_tkeep_count_zeros_reg;
    
    // //需要优化
    // always @* begin
    //     s00_axis_tkeep_count_zeros = {DATA_BYTE_WD{1'b0}};  
    //     for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
    //         s00_axis_tkeep_count_zeros = s00_axis_tkeep_count_zeros + !s00_axis_tkeep[idx];
    //     end
    // end

    // always @(posedge clk) begin
    //     if(rst) begin
    //         s00_axis_tkeep_count_zeros_reg <= 'b0;
    //     end else if(send_header) begin 
    //         s00_axis_tkeep_count_zeros_reg <= s00_axis_tkeep_count_zeros;
    //     end
    // end
    // wire [$clog2(DATA_BYTE_WD+1)+2:0] header_count_zeros;
    // assign header_count_zeros = {3'b0, send_header ? s00_axis_tkeep_count_zeros : s00_axis_tkeep_count_zeros_reg};

    reg [2*DATA_WD-1 : 0]       data_concat;
    reg [2*DATA_BYTE_WD-1 : 0]  keep_concat;
    reg [2*DATA_WD-1 : 0]       data_concat_shift;
    reg [2*DATA_BYTE_WD-1 : 0]  keep_concat_shift;

    reg [DATA_WD-1 : 0]         data_buffer_reg;
    reg [DATA_BYTE_WD-1 : 0]    keep_buffer_reg;

    reg [DATA_WD-1 : 0]         res_data_reg;
    reg [DATA_BYTE_WD-1 : 0]    res_keep_reg;
    reg [DATA_WD-1 : 0]         res_data_reg_shift;
    reg [DATA_BYTE_WD-1 : 0]    res_keep_reg_shift;

    reg [1:0]                   tail_valid_reg;
    

    always @(*) begin
        if(rst) begin
            data_concat = {2*DATA_WD{1'b0}};
            keep_concat = {2*DATA_BYTE_WD{1'b0}};
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            if(s01_axis_tvalid && s01_axis_tready) begin
                data_concat = {s00_axis_tdata,s01_axis_tdata};//<< (header_count_zeros << 3); // 保证header进入时没有前置零
                keep_concat = {s00_axis_tkeep,s01_axis_tkeep};//<<  header_count_zeros      ; // 保证header进入时没有前置零
            end else begin
                data_concat = {s00_axis_tdata,{DATA_WD{1'b0}}}     ;// << (header_count_zeros << 3); // 保证header进入时没有前置零
                keep_concat = {s00_axis_tkeep,{DATA_BYTE_WD{1'b0}}};// <<  header_count_zeros      ; // 保证header进入时没有前置零
            end
        end else if(s01_axis_tvalid && s01_axis_tready) begin
            // 拼接方式在收到header的时候已经知道了,需要记录下来在每次传输都用到
            if(!(|res_keep_reg_shift)) begin
                data_concat = {s01_axis_tdata,{DATA_WD{1'b0}}}      ;//<< (header_count_zeros << 3); // 保证header进入时没有前置零
                keep_concat = {s01_axis_tkeep,{DATA_BYTE_WD{1'b0}}} ;//<<  header_count_zeros      ; // 保证header进入时没有前置零
            end else begin
                data_concat = {res_data_reg_shift,s01_axis_tdata} ;//<< (header_count_zeros << 3);
                keep_concat = {res_keep_reg_shift,s01_axis_tkeep} ;//<<  header_count_zeros      ;
            end
        end else begin
            data_concat = {res_data_reg_shift,{DATA_WD{1'b0}}}      ;//<< (header_count_zeros << 3);
            keep_concat = {res_keep_reg_shift,{DATA_BYTE_WD{1'b0}}} ;//<<  header_count_zeros;
        end
    end


    always @* begin
        data_concat_shift = data_concat;  
        keep_concat_shift = keep_concat;  
        for( idx = 0; idx<DATA_BYTE_WD-1; idx = idx + 1) begin
            if(!keep_concat_shift[2*DATA_BYTE_WD - 1]) begin
                data_concat_shift = data_concat_shift << 8; 
                keep_concat_shift = keep_concat_shift << 1; 
            end
        end
    end

    //每次拼接
    always @(posedge clk) begin
        if(rst) begin
            res_data_reg <= 'b0;
            res_keep_reg <= 'b0;
        end else if(m_axis_tready) begin //保持前置零的状态方便拼接
            if(tail_valid_reg[1]) begin
                res_data_reg <= 'b0;
                res_keep_reg <= 'b0;                
            end else if(&keep_concat_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] | s01_axis_tlast) begin
                res_data_reg <= data_concat_shift[DATA_WD - 1 : 0]      ;//>> (header_count_zeros << 3);
                res_keep_reg <= keep_concat_shift[DATA_BYTE_WD - 1 : 0] ;//>>  header_count_zeros      ;
            end else begin
                res_data_reg <= data_concat_shift[2*DATA_WD-1      : DATA_WD]     ;// >> (header_count_zeros << 3);
                res_keep_reg <= keep_concat_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD];// >>  header_count_zeros      ;    
            end        
        end
    end

    always @* begin
        res_data_reg_shift = res_data_reg;  
        res_keep_reg_shift = res_keep_reg;  
        for( idx = 0; idx<DATA_BYTE_WD-1; idx = idx + 1) begin
            if(!res_keep_reg_shift[0]) begin
                res_data_reg_shift = res_data_reg_shift >> 8; 
                res_keep_reg_shift = res_keep_reg_shift >> 1; 
            end
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            data_buffer_reg <= 'b0;
            keep_buffer_reg <= 'b0;
        end else if(m_axis_tready) begin
            data_buffer_reg <= data_concat_shift[2*DATA_WD-1      : DATA_WD];
            keep_buffer_reg <= keep_concat_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD];
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            tail_valid_reg <= 2'b00;
        end else if(s01_axis_tready && s01_axis_tvalid && s01_axis_tlast) begin //保持前置零的状态方便拼接
            if(keep_concat_shift[DATA_BYTE_WD-1])
                tail_valid_reg <= 2'b10;
            else
                tail_valid_reg <= 2'b01;
        end else if(m_axis_tready && m_axis_tvalid && (|tail_valid_reg)) begin
            tail_valid_reg <= tail_valid_reg >> 1'b1;
        end
    end

    // assign s00_axis_tready = !(|res_keep_reg_shift) || (m_axis_tready && m_axis_tvalid);
    assign s00_axis_tready = !(|res_keep_reg_shift) && m_axis_tready;
    // assign s00_axis_tready = !(m_axis_tvalid) || (m_axis_tready);
    // assign s01_axis_tready = (s00_axis_tready && s00_axis_tvalid) | (m_axis_tready && !send_header);
    assign s01_axis_tready = (s00_axis_tready && s00_axis_tvalid) | (m_axis_tready && !send_header);
    
    assign m_axis_tdata  =  data_buffer_reg;
    assign m_axis_tvalid =  keep_buffer_reg[0] | tail_valid_reg[0]; // 前4bit全为1
    assign m_axis_tkeep  =  keep_buffer_reg ; 
    assign m_axis_tlast  =  tail_valid_reg[0];

endmodule

`resetall