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

    //status
    parameter WAIT_HEAD = 2'd0;
    parameter WAIT_LAST = 2'd1;

    reg [1:0]  current_state;
    reg [1:0]  next_state;

    //current_state
    always @(posedge clk) begin
        if(rst)
            current_state <= WAIT_HEAD;
        else
            current_state <= next_state;
    end

    //next_state
    always @(*) begin
        if(rst)
            next_state = WAIT_HEAD;
        else begin
            case (current_state)
                WAIT_HEAD : next_state = s00_axis_tvalid && s00_axis_tready ? WAIT_LAST : WAIT_HEAD;
                WAIT_LAST : next_state = m_axis_tlast && m_axis_tready      ? WAIT_HEAD : WAIT_LAST;
                default   : next_state = WAIT_HEAD;
            endcase
        end
    end

    assign s00_axis_tready     = (current_state == WAIT_HEAD) && m_axis_tready;
    assign s01_axis_tready     = (current_state == WAIT_LAST) && m_axis_tready;

    reg [DATA_WD-1 : 0]         m_axis_tdata_r;
    reg [DATA_BYTE_WD-1 : 0]    m_axis_tkeep_r;
    reg                         m_axis_tvalid_r;
    reg                         m_axis_tlast_r;

    reg [$clog2(DATA_BYTE_WD+1)-1:0] s00_axis_tkeep_count_ones;
    reg [$clog2(DATA_BYTE_WD+1)-1:0] s01_axis_tkeep_count_ones;
    integer idx;

    always @* begin
        s00_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        s01_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
            s00_axis_tkeep_count_ones = s00_axis_tkeep_count_ones + s00_axis_tkeep[idx];
            s01_axis_tkeep_count_ones = s01_axis_tkeep_count_ones + s01_axis_tkeep[idx];
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
        end else if(res_out) begin
            m_axis_tdata_r  = data_buffer << ((DATA_BYTE_WD - header_cnt_buffer) << 3);
            m_axis_tvalid_r = 1'b1;
            m_axis_tkeep_r  = tkeep_res   << (DATA_BYTE_WD - header_cnt_buffer);
            m_axis_tlast_r  = 1'b1;
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            if(s00_axis_tkeep_count_ones == DATA_BYTE_WD) begin
                m_axis_tdata_r  = s00_axis_tdata;
                m_axis_tvalid_r = 1'b1;
                m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}};   
                m_axis_tlast_r  = 1'b0;
            end
        end else if(s01_axis_tready) begin
            m_axis_tvalid_r = s01_axis_tvalid;
            if(header_cnt_buffer == DATA_BYTE_WD) begin
                m_axis_tdata_r  = s01_axis_tdata;
                m_axis_tkeep_r  = s01_axis_tkeep;   
                m_axis_tlast_r  = s01_axis_tlast;
            end else begin
                    if(s01_axis_tlast && ((s01_axis_tkeep_count_ones + header_cnt_buffer) <= DATA_BYTE_WD)) begin
                        m_axis_tdata_r  = {data_buffer, s01_axis_tdata} >> ((DATA_BYTE_WD - (DATA_BYTE_WD - header_cnt_buffer)) << 3);
                        m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}} << (DATA_BYTE_WD - (s01_axis_tkeep_count_ones + header_cnt_buffer));
                        m_axis_tlast_r  = 1'b1;
                    end else begin
                        m_axis_tdata_r  = {data_buffer, s01_axis_tdata} >> ((DATA_BYTE_WD - (DATA_BYTE_WD - header_cnt_buffer)) << 3);
                        m_axis_tkeep_r  = {DATA_BYTE_WD{1'b1}};
                        m_axis_tlast_r  = 1'b0;
                    end
                end
        end
    end

    reg                                 res_out;
    reg [DATA_WD-1 : 0]                 data_buffer;
    reg [$clog2(DATA_BYTE_WD+1)-1:0]    header_cnt_buffer;
    reg [DATA_BYTE_WD-1 : 0]            tkeep_res;
    always @(posedge clk) begin
        if(rst) begin
            data_buffer       <= {DATA_WD{1'b0}};
            header_cnt_buffer <= 'b0;
            res_out <= 1'b0;
        end else if(res_out && m_axis_tready)begin
            res_out <= 1'b0;
        end else if(s00_axis_tvalid && s00_axis_tready)begin
            // if(s00_axis_tkeep_count_ones < DATA_BYTE_WD) begin
                data_buffer       <= s00_axis_tdata;
                header_cnt_buffer <= s00_axis_tkeep_count_ones;
            // end
            res_out <= 1'b0;
        end else if(s01_axis_tvalid && s01_axis_tready)begin
            if(header_cnt_buffer < DATA_BYTE_WD) begin
                data_buffer       <= s01_axis_tdata;
                if(s01_axis_tlast && ((s01_axis_tkeep_count_ones + header_cnt_buffer) > DATA_BYTE_WD)) begin
                    res_out <= 1'b1;
                    tkeep_res <= s01_axis_tkeep;
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