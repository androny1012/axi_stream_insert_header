`resetall
`timescale 1ns / 1ps
`default_nettype none

module DataInserter #(
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

    reg [DATA_WD-1 : 0]                 m_axis_tdata_r;
    reg [DATA_BYTE_WD-1 : 0]            m_axis_tkeep_r;
    reg                                 m_axis_tvalid_r;
    reg                                 m_axis_tlast_r;

    reg                                 send_header; // 用这个信号和状态机有什么区别
    
    // buffer 在一次数据没传完，拆一半时用到
    reg [DATA_WD-1 : 0]                 data_buffer;
    reg                                 data_valid;
    reg [DATA_WD-1 : 0]                 header_buffer;
    reg [$clog2(DATA_BYTE_WD+1)-1:0]    header_buffer_cnt;
    reg                                 header_buffer_valid;

    wire                                header_valid;
    wire [$clog2(DATA_BYTE_WD+1)-1:0]   header_cnt;
    wire [DATA_WD-1 : 0]                header_data;

    reg [$clog2(DATA_BYTE_WD+1)-1:0]    s00_axis_tkeep_count_ones;
    reg [$clog2(DATA_BYTE_WD+1)-1:0]    s01_axis_tkeep_count_ones;
    integer idx;

    always @* begin
        s00_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        s01_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
            s00_axis_tkeep_count_ones = s00_axis_tkeep_count_ones + s00_axis_tkeep[idx];
            s01_axis_tkeep_count_ones = s01_axis_tkeep_count_ones + s01_axis_tkeep[idx];
        end
    end

    // wire [$clog2(DATA_BYTE_WD+1)-1:0] s00_axis_tkeep_count_ones;
    // wire [$clog2(DATA_BYTE_WD+1)-1:0] s01_axis_tkeep_count_ones;

    // function [$clog2(DATA_BYTE_WD+1)-1:0] ones_counter;
    //     integer idx;
    //     input [DATA_BYTE_WD-1:0] s_axis_tkeep;
    //     for( idx = 0; idx < DATA_BYTE_WD; idx = idx + 1) begin
    //         ones_counter = ones_counter + s_axis_tkeep[idx];
    //     end
    // endfunction

    // assign s00_axis_tkeep_count_ones = ones_counter(s00_axis_tkeep);
    // assign s01_axis_tkeep_count_ones = ones_counter(s01_axis_tkeep);

    assign header_data  = header_buffer_valid ? header_buffer       : s00_axis_tdata;
    assign header_cnt   = header_buffer_valid ? header_buffer_cnt   : s00_axis_tkeep_count_ones;
    assign header_valid = header_buffer_valid ? header_buffer_valid : s00_axis_tvalid;
    
    // 和状态机有什么区别
    always @(posedge clk) begin
        if(rst) begin
            send_header <= 1'b1;
        end else if(m_axis_tvalid && m_axis_tready) begin  // something else?
            if(send_header && m_axis_tlast) begin
                send_header <= send_header;
            end else if(send_header || m_axis_tlast) begin
                send_header <= !send_header;
            end
        end
    end

    // 后级反压，需要发header，buffer中为空
    assign s00_axis_tready = m_axis_tready &&   send_header && !header_buffer_valid;
    assign s01_axis_tready = m_axis_tready && (!send_header || ((header_cnt < DATA_BYTE_WD) && header_valid && send_header));

    // 应该在每次传输header记录下来，并在单次传输过程中保持
    always @(posedge clk) begin
        if(rst) begin
            header_buffer_cnt <=  'b0;
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            header_buffer_cnt <= s00_axis_tkeep_count_ones;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            header_buffer <= {DATA_WD{1'b0}};
            header_buffer_valid <= 1'b0;
        end else if(m_axis_tvalid && m_axis_tready && (header_buffer_valid || m_axis_tlast)) begin  // something else?
            header_buffer_valid <= 1'b0;
        end else if(s00_axis_tready) begin
            header_buffer       <= s00_axis_tdata;
            header_buffer_valid <= s00_axis_tvalid;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            data_buffer <= {DATA_WD{1'b0}};
            data_valid  <= 1'b0;
        // end else if(m_axis_tvalid && m_axis_tready && !header_valid && data_valid) begin  // something else?
        //     data_valid  <= 1'b0;
        end else if(s01_axis_tready) begin
            data_buffer <= s01_axis_tdata;
            data_valid  <= s01_axis_tvalid;
        end
    end

    //前后拼接可能留下的小尾巴
    reg [DATA_WD-1 : 0]                 tail_data ;
    reg [DATA_BYTE_WD-1 : 0]            tail_keep ;
    reg                                 tail_valid;
    always @(posedge clk) begin
        if(rst) begin
            tail_data  <=  'b0;
            tail_keep  <=  'b0;
            tail_valid <= 1'b0;
        end else if(m_axis_tready && tail_valid) begin
            tail_data  <=  'b0;
            tail_keep  <=  'b0;
            tail_valid <= 1'b0;            
        end else if(s01_axis_tready && s01_axis_tlast && ((s01_axis_tkeep_count_ones + header_cnt) > DATA_BYTE_WD) && (header_cnt != DATA_BYTE_WD)) begin
            tail_data  <= s01_axis_tdata;
            tail_keep  <= s01_axis_tkeep;
            tail_valid <= 1'b1;
        end
    end

    always @(*) begin
        m_axis_tdata_r  = {DATA_WD{1'b0}};
        m_axis_tkeep_r  = {DATA_BYTE_WD{1'b0}};
        m_axis_tvalid_r = 1'b0;
        m_axis_tlast_r  = 1'b0;
        if(rst) begin
            m_axis_tdata_r  = {DATA_WD{1'b0}};
            m_axis_tkeep_r  = {DATA_BYTE_WD{1'b0}};
            m_axis_tvalid_r = 1'b0;
            m_axis_tlast_r  = 1'b0;
        end else if(tail_valid) begin
            m_axis_tdata_r  = tail_data << ((DATA_BYTE_WD - header_buffer_cnt) << 3);
            m_axis_tkeep_r  = tail_keep << (DATA_BYTE_WD - header_buffer_cnt);
            m_axis_tvalid_r = 1'b1;
            m_axis_tlast_r  = 1'b1;
        end else if(send_header) begin
            if(s00_axis_tkeep_count_ones == DATA_BYTE_WD) begin
                m_axis_tdata_r  = header_data;
                m_axis_tkeep_r  = s00_axis_tkeep;
                m_axis_tvalid_r = s00_axis_tvalid;
                m_axis_tlast_r  = 1'b0;
            end else if(s01_axis_tlast && ((s00_axis_tkeep_count_ones + s01_axis_tkeep_count_ones) <= DATA_BYTE_WD)) begin
                m_axis_tdata_r  = {header_data, s01_axis_tdata} >> ((DATA_BYTE_WD - (DATA_BYTE_WD - s00_axis_tkeep_count_ones)) << 3);
                m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}} << (DATA_BYTE_WD - (s01_axis_tkeep_count_ones + s00_axis_tkeep_count_ones));
                m_axis_tvalid_r = header_valid && s01_axis_tvalid;
                m_axis_tlast_r  = 1'b1;
            end else begin
                m_axis_tdata_r  = {header_data, s01_axis_tdata} >> ((DATA_BYTE_WD - (DATA_BYTE_WD - s00_axis_tkeep_count_ones)) << 3);
                m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}};
                m_axis_tvalid_r = header_valid && s01_axis_tvalid;
                m_axis_tlast_r  = 1'b0;
            end
        end else begin
            m_axis_tvalid_r = s01_axis_tvalid;
            if(header_buffer_cnt == DATA_BYTE_WD) begin
                m_axis_tdata_r  = s01_axis_tdata;
                m_axis_tkeep_r  = s01_axis_tkeep;   
                m_axis_tlast_r  = s01_axis_tlast;
            end else if(s01_axis_tready) begin 
                m_axis_tdata_r  = {data_buffer, s01_axis_tdata} >> ((DATA_BYTE_WD - (DATA_BYTE_WD - header_buffer_cnt)) << 3);
                if(s01_axis_tlast && ((header_buffer_cnt + s01_axis_tkeep_count_ones) <= DATA_BYTE_WD)) begin
                    m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}} << (DATA_BYTE_WD - (s01_axis_tkeep_count_ones + header_buffer_cnt));
                    m_axis_tlast_r  = 1'b1;
                end else begin
                    m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}};
                    m_axis_tlast_r  = 1'b0;
                end
            end
        end
    end

    assign m_axis_tdata  = m_axis_tdata_r;
    assign m_axis_tvalid = m_axis_tvalid_r;
    assign m_axis_tkeep  = m_axis_tkeep_r;
    assign m_axis_tlast  = m_axis_tlast_r;

endmodule

`resetall