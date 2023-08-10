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


    // assign m_axis_tdata    = s01_axis_tdata;
    // assign m_axis_tvalid   = s01_axis_tvalid;
    // assign m_axis_tkeep    = s01_axis_tkeep;
    // assign m_axis_tlast    = s01_axis_tlast;
    // assign s01_axis_tready = m_axis_tready;

    //status
    parameter WAIT_HEAD = 2'd0;
    parameter WAIT_LAST = 2'd1;
    parameter s2            = 2'd2;
    parameter s3            = 2'd3;

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
                WAIT_HEAD : next_state = s00_axis_tvalid            ? WAIT_LAST : WAIT_HEAD;
                WAIT_LAST : next_state = m_axis_tlast                ? WAIT_HEAD : WAIT_LAST;
                default   : next_state = WAIT_HEAD;
            endcase
        end
    end

    assign s00_axis_tready = (current_state == WAIT_HEAD);
    assign s01_axis_tready     = (current_state == WAIT_LAST);

    // NOTE: $clog2 was added in 1364-2005, not supported in 1364-1995 or 1364-2001
    reg [$clog2(DATA_BYTE_WD+1)-1:0] s00_axis_tkeep_count_ones;
    integer idx;

    always @* begin
        s00_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
            s00_axis_tkeep_count_ones = s00_axis_tkeep_count_ones + s00_axis_tkeep[idx];
        end
    end

    reg [$clog2(DATA_BYTE_WD+1)-1:0] s01_axis_tkeep_count_ones;
    integer idx_in;

    always @* begin
        s01_axis_tkeep_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx_in = 0; idx_in<DATA_BYTE_WD; idx_in = idx_in + 1) begin
            s01_axis_tkeep_count_ones = s01_axis_tkeep_count_ones + s01_axis_tkeep[idx_in];
        end
    end

    // 0: 1-3需要和data拼接
    // 1: 0和4不用拼接
    reg [$clog2(DATA_BYTE_WD+1)-1:0] insert_type;
    always @(posedge clk) begin
        if(rst)
            insert_type <= 1'b0;
        else if(s00_axis_tvalid && s00_axis_tready)
            insert_type <= s00_axis_tkeep_count_ones;
    end

    reg [DATA_WD-1 : 0]         m_axis_tdata_r;
    reg [DATA_WD-1 : 0]         data_cut;
    reg [DATA_BYTE_WD-1 : 0]    m_axis_tkeep_r;
    reg                         m_axis_tvalid_r;
    reg                         m_axis_tlast_r;
    reg                         res_out;
    reg [DATA_BYTE_WD-1 : 0]    m_axis_tkeep_last;

    wire [DATA_WD-1:0] insert_mask;
    assign insert_mask = {DATA_WD{1'b1}} >> ((DATA_BYTE_WD - insert_type) << 3);
    // wire [DATA_WD-1:0] insert_out;
    // assign insert_out = (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & s01_axis_tdata) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
    // (DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) 解决移位后位宽问题

    always @(posedge clk) begin
        if(rst) begin
            m_axis_tdata_r    <= {DATA_WD{1'b0}};
            m_axis_tkeep_r    <= {DATA_BYTE_WD{1'b0}};
            m_axis_tvalid_r   <= 1'b0;
            m_axis_tlast_r    <= 1'b0;
            res_out           <= 1'b0;
            m_axis_tkeep_last <= {DATA_BYTE_WD{1'b0}};
        end else if(res_out) begin
            m_axis_tvalid_r <= 1'b1;
            m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}} << m_axis_tkeep_last;
            m_axis_tdata_r  <= data_cut << ((DATA_BYTE_WD - (DATA_BYTE_WD - m_axis_tkeep_last)) << 3);
            m_axis_tlast_r  <= 1'b1;
            res_out         <= 1'b0;
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            if(s00_axis_tkeep_count_ones == DATA_BYTE_WD) begin
                m_axis_tdata_r  <= s00_axis_tdata;
                m_axis_tvalid_r <= 1'b1;
                m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}};
            end
            m_axis_tlast_r  <= 1'b0;
        end else if(s01_axis_tvalid && s01_axis_tready && s01_axis_tlast)begin
            m_axis_tvalid_r <= 1'b1;
            if(insert_type == 0 || insert_type == DATA_BYTE_WD) begin
                m_axis_tdata_r  <= s01_axis_tdata;
                m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}};
                m_axis_tlast_r  <= 1'b1;
            end else begin   
                m_axis_tdata_r  <= (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & s01_axis_tdata) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
                if((insert_type + s01_axis_tkeep_count_ones) > DATA_BYTE_WD) begin
                    m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}};
                    res_out <= 1'b1;
                    m_axis_tkeep_last <= DATA_BYTE_WD - (insert_type + s01_axis_tkeep_count_ones - DATA_BYTE_WD);
                end else begin
                    m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}} << ((DATA_BYTE_WD - insert_type) + s01_axis_tkeep_count_ones);
                    m_axis_tlast_r  <= 1'b1;
                end
            end
        end else if(s01_axis_tvalid && s01_axis_tready)begin
            m_axis_tvalid_r <= 1'b1;
            m_axis_tkeep_r  <= {DATA_BYTE_WD{1'b1}};
            if(insert_type == 0 || insert_type == DATA_BYTE_WD) begin
                m_axis_tdata_r  <= s01_axis_tdata;
            end else begin   
                m_axis_tdata_r  <= (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & s01_axis_tdata) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
            end
        end else begin
            // m_axis_tdata_r <= {DATA_WD{1'b0}};
            m_axis_tvalid_r <= 1'b0;            
            m_axis_tlast_r  <= 1'b0;            
        end
    end


    always @(posedge clk) begin
        if(rst) begin
            data_cut <= {DATA_WD{1'b0}};
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            data_cut <= s00_axis_tdata;
        end else if(s01_axis_tvalid && s01_axis_tready)begin
            data_cut <= s01_axis_tdata;
        end
    end
    
    assign m_axis_tdata  = m_axis_tdata_r;
    assign m_axis_tvalid = m_axis_tvalid_r;
    assign m_axis_tkeep  = m_axis_tkeep_r;
    assign m_axis_tlast  = m_axis_tlast_r;
    // assign m_axis_tlast  = m_axis_tlast_r;
endmodule

`resetall