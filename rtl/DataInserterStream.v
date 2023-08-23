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

    reg                         tail_valid;

    reg                         out_tlast;

    integer idx;

    //收到header 
    always @(posedge clk) begin
        if(rst) begin
            out_tlast <= 1'b1;
        end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
            out_tlast <= 1'b1;
        end else if(s00_axis_tvalid && s00_axis_tready) begin
            out_tlast <= 1'b0;
        end
    end

    reg send_header;
    always @(posedge clk) begin
        if(rst) begin
            send_header <= 1'b0;
        end else if(m_axis_tvalid && m_axis_tready) begin
            if(header_valid_reg && m_axis_tlast)
                send_header <= 1'b0;
            else if(header_valid_reg || m_axis_tlast)
                send_header <= !send_header;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            header_valid_reg <= 1'b0;
            header_data_reg  <= 'b0;
            header_keep_reg  <= 'b0;
        end else if(s00_axis_tready && s00_axis_tvalid) begin
            header_valid_reg <= 1'b1;
            header_data_reg  <= s00_axis_tdata;
            header_keep_reg  <= s00_axis_tkeep;
        end else if(m_axis_tready && m_axis_tvalid && !send_header) begin
            header_valid_reg <= 1'b0;
            header_data_reg  <= 'b0;
            header_keep_reg  <= 'b0;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            data_valid_reg <= 1'b0;
            data_data_reg  <= 'b0;
            data_keep_reg  <= 'b0;
            data_last_reg  <= 1'b0;
        end else if(s01_axis_tready && s01_axis_tvalid) begin
            data_valid_reg <= 1'b1;
            data_data_reg  <= s01_axis_tdata;
            data_keep_reg  <= s01_axis_tkeep;
            data_last_reg  <= s01_axis_tlast;
        end else if(m_axis_tready && m_axis_tvalid) begin
            data_valid_reg <= 1'b0;
            data_data_reg  <= 'b0;
            data_keep_reg  <= 'b0;
            data_last_reg  <= 1'b0;
        end
    end

    always @(*) begin
        if(rst) begin
            concat_data = 'b0;
            concat_keep = 'b0;
        end else begin
            concat_data = 'b0;
            concat_keep = 'b0;
            // if(header_valid_reg && !out_tlast) begin
            if(header_valid_reg && !send_header) begin
                concat_data[2*DATA_WD-1      : DATA_WD]      = header_data_reg;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = header_keep_reg;
            end
            if(res_valid_reg) begin
                concat_data[2*DATA_WD-1      : DATA_WD]      = res_data_shift;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = res_keep_shift;            
            end
            if(data_valid_reg && !out_tlast) begin
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

    reg m_axis_tlast_reg;
    always @(posedge clk) begin
        if(rst) begin
            m_axis_tlast_reg <= 1'b0;
        end else if(data_valid_reg && data_last_reg) begin
            m_axis_tlast_reg <= concat_keep_shift[DATA_BYTE_WD-1];
        end else if(m_axis_tready) begin
            m_axis_tlast_reg <= 1'b0;
        end
    end  

    always @(*) begin
        if(rst) begin
            tail_valid = 1'b0;
        end else if(data_valid_reg && data_last_reg && !out_tlast) begin
            tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
        end else if(m_axis_tlast_reg) begin
            tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
        end else begin
            tail_valid = 1'b0;
        end
    end

    // buffer中没数， header_valid_reg为空,或者
    // assign s00_axis_tready  = m_axis_tready;
    // assign s00_axis_tready  = !header_valid_reg | (m_axis_tready && m_axis_tvalid && m_axis_tlast && !header_valid_reg);
    assign s00_axis_tready  = !header_valid_reg | (m_axis_tready);
    // assign s00_axis_tready  = (!header_valid_reg && !concat_keep_shift[DATA_BYTE_WD-1]) | m_axis_tready;
    
    assign s01_axis_tready  = !data_valid_reg   | (m_axis_tready && m_axis_tvalid);
    // assign s01_axis_tready  = !data_valid_reg   | (!out_tlast && m_axis_tready && ((header_valid_reg && !header_keep_reg[DATA_BYTE_WD-1]) | !header_valid_reg));

    assign m_axis_tdata  = concat_data_shift[2*DATA_WD-1      :      DATA_WD];
    assign m_axis_tvalid = concat_keep_shift[  DATA_BYTE_WD                 ] | m_axis_tlast;
    assign m_axis_tkeep  = concat_keep_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD];
    assign m_axis_tlast  = tail_valid;
endmodule

`resetall