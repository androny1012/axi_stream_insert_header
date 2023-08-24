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
    // 记录本次传输是否已经发过header，为1是还没发，防止重复发header
    reg send_header;
    always @(posedge clk) begin
        if(rst) begin
            send_header <= 1'b1;
        end else if(m_axis_tvalid && m_axis_tready) begin
            send_header <= m_axis_tlast;
        end
    end

    // 记录收到tlast 和发出tlast的时机
    reg last_sv;
    always @(posedge clk) begin
        if(rst) begin
            last_sv <= 1'b0;
        end else if(s01_axis_tvalid && s01_axis_tready && s01_axis_tlast) begin
            last_sv <= 1'b1;
        end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
            last_sv <= 1'b0;
        end
    end

    // header用过了为什么不能清空，因为一次传输没结束，header进来也没用
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
            if(header_valid_reg && send_header) begin
                concat_data[2*DATA_WD-1      : DATA_WD]      = header_data_reg;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = header_keep_reg;
            end
            if(res_valid_reg) begin
                concat_data[2*DATA_WD-1      : DATA_WD]      = res_data_shift;
                concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = res_keep_shift;            
            end
            if(data_valid_reg && ((header_valid_reg && send_header) | !send_header) && !m_axis_tlast_reg) begin
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
    reg tail_valid;
    always @(posedge clk) begin
        if(rst) begin
            m_axis_tlast_reg <= 1'b0;
        end else if(last_sv && m_axis_tready && header_valid_reg) begin
            m_axis_tlast_reg <= concat_keep_shift[DATA_BYTE_WD-1];
        end else if(m_axis_tready && m_axis_tlast) begin
            m_axis_tlast_reg <= 1'b0;
        end
    end  

    always @(*) begin
        if(rst) begin
            tail_valid = 1'b0;
        end else if(last_sv && m_axis_tready && header_valid_reg) begin
            tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
        end else if(m_axis_tlast_reg && m_axis_tready) begin
            tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
        end else begin
            tail_valid = 1'b0;
        end
    end

    // header : buffer 为空 或者 本次传输结束
    assign s00_axis_tready  = !header_valid_reg | (m_axis_tready && m_axis_tlast);

    // data   : buffer 为空 或者 传输了一个本次传输的数据 !last_sv 是防止下次传输的数据被送入
    assign s01_axis_tready  = !data_valid_reg   | ((!last_sv | m_axis_tlast) && (m_axis_tready && m_axis_tvalid));

    assign m_axis_tdata  = concat_data_shift[2*DATA_WD-1      :      DATA_WD];
    assign m_axis_tvalid = concat_keep_shift[  DATA_BYTE_WD                 ] | m_axis_tlast;
    assign m_axis_tkeep  = concat_keep_shift[2*DATA_BYTE_WD-1 : DATA_BYTE_WD];
    assign m_axis_tlast  = tail_valid;
endmodule

`resetall


    // reg                         tail_valid;

    // reg                         out_tlast;

    // integer idx;

    // //收到header 
    // always @(posedge clk) begin
    //     if(rst) begin
    //         out_tlast <= 1'b1;
    //     end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
    //         out_tlast <= 1'b1;
    //     end else if(s00_axis_tvalid && s00_axis_tready) begin
    //         out_tlast <= 1'b0;
    //     end
    // end

    // // header 的空满？
    // reg send_header;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         send_header <= 1'b1;
    //     end else if(m_axis_tvalid && m_axis_tready) begin
    //         send_header <= m_axis_tlast;
    //     end
    // end

    // // 在收到header后才将data中的数用于拼接，否则无效
    // reg recv_header;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         recv_header <= 1'b0;
    //     end else if(s00_axis_tvalid && s00_axis_tready) begin
    //         recv_header <= 1'b1;
    //     end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
    //         recv_header <= 1'b0;
    //     end
    // end

    // reg send_data;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         send_data <= 1'b0;
    //     end else if(s00_axis_tvalid && s00_axis_tready) begin
    //         send_data <= !s00_axis_tkeep[DATA_BYTE_WD-1];
    //     end else if(m_axis_tvalid && m_axis_tready) begin
    //         send_data <= 1'b1;
    //     end
    // end

    // // 在收到header后才将data中的数用于拼接，否则无效
    // reg last_wait;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         last_wait <= 1'b0;
    //     end else if(s01_axis_tvalid && s01_axis_tready && s01_axis_tlast) begin
    //         last_wait <= 1'b1;
    //     end else if(m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
    //         last_wait <= 1'b0;
    //     end
    // end

    // always @(posedge clk) begin
    //     if(rst) begin
    //         header_valid_reg <= 1'b0;
    //         header_data_reg  <= 'b0;
    //         header_keep_reg  <= 'b0;
    //     end else if(s00_axis_tready) begin
    //         header_valid_reg <= s00_axis_tvalid;
    //         header_data_reg  <= s00_axis_tdata;
    //         header_keep_reg  <= s00_axis_tkeep;
    //     end else if(m_axis_tready && m_axis_tvalid && m_axis_tlast) begin
    //         header_valid_reg <= 1'b0;
    //     end
    // end



    // always @(posedge clk) begin
    //     if(rst) begin
    //         data_valid_reg <= 1'b0;
    //         data_data_reg  <= 'b0;
    //         data_keep_reg  <= 'b0;
    //         data_last_reg  <= 1'b0;
    //     end else if(s01_axis_tready) begin
    //         data_valid_reg <= s01_axis_tvalid;
    //         data_data_reg  <= s01_axis_tdata;
    //         data_keep_reg  <= s01_axis_tkeep;
    //         data_last_reg  <= s01_axis_tlast;
    //     end else if(m_axis_tready && m_axis_tvalid) begin
    //         data_valid_reg <= 1'b0;
    //         data_data_reg  <= 'b0;
    //         data_keep_reg  <= 'b0;
    //         data_last_reg  <= 1'b0;
    //     end 
    // end

    // always @(*) begin
    //     if(rst) begin
    //         concat_data = 'b0;
    //         concat_keep = 'b0;
    //     end else begin
    //         concat_data = 'b0;
    //         concat_keep = 'b0;
    //         if(header_valid_reg && send_header) begin
    //             concat_data[2*DATA_WD-1      : DATA_WD]      = header_data_reg;
    //             concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = header_keep_reg;
    //         end
    //         if(res_valid_reg) begin
    //             concat_data[2*DATA_WD-1      : DATA_WD]      = res_data_shift;
    //             concat_keep[2*DATA_BYTE_WD-1 : DATA_BYTE_WD] = res_keep_shift;            
    //         end
    //         if(data_valid_reg && recv_header && !last_wait) begin
    //             concat_data[DATA_WD-1      : 0]              = data_data_reg;
    //             concat_keep[DATA_BYTE_WD-1 : 0]              = data_keep_reg;
    //         end
    //     end
    // end

    // always @(*) begin
    //     concat_data_shift = concat_data;  
    //     concat_keep_shift = concat_keep;  
    //     for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
    //         if(!concat_keep_shift[2*DATA_BYTE_WD-1]) begin
    //             concat_data_shift = concat_data_shift << 8;
    //             concat_keep_shift = concat_keep_shift << 1;
    //         end
    //     end
    // end

    // always @(posedge clk) begin
    //     if(rst) begin
    //         res_valid_reg <= 1'b0;
    //         res_data_reg  <= 'b0;
    //         res_keep_reg  <= 'b0;
    //     end else if(m_axis_tvalid && m_axis_tready) begin
    //         res_valid_reg <= concat_keep_shift[DATA_BYTE_WD-1];
    //         res_data_reg  <= concat_data_shift[DATA_WD-1      : 0];
    //         res_keep_reg  <= concat_keep_shift[DATA_BYTE_WD-1 : 0];
    //     end
    // end

    // always @(*) begin
    //     res_data_shift = res_data_reg;  
    //     res_keep_shift = res_keep_reg;  
    //     for( idx = 0; idx<DATA_BYTE_WD-1; idx = idx + 1) begin
    //         if(!res_keep_shift[0]) begin
    //             res_data_shift = res_data_shift >> 8;
    //             res_keep_shift = res_keep_shift >> 1;
    //         end
    //     end
    // end

    // reg m_axis_tlast_reg;
    // always @(posedge clk) begin
    //     if(rst) begin
    //         m_axis_tlast_reg <= 1'b0;
    //     end else if(last_wait) begin
    //         m_axis_tlast_reg <= concat_keep_shift[DATA_BYTE_WD-1];
    //     end else if(m_axis_tready) begin
    //         m_axis_tlast_reg <= 1'b0;
    //     end
    // end  

    // always @(*) begin
    //     if(rst) begin
    //         tail_valid = 1'b0;
    //     end else if(last_wait) begin
    //         tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
    //     end else if(m_axis_tlast_reg) begin
    //         tail_valid = !concat_keep_shift[DATA_BYTE_WD-1];
    //     end else begin
    //         tail_valid = 1'b0;
    //     end
    // end

    // assign s00_axis_tready  = !header_valid_reg | (m_axis_tready && m_axis_tvalid && m_axis_tlast);
    
    // // 等待本次传输结束，才能接收下一次的数据
    // // assign s01_axis_tready  = !data_valid_reg   | (send_data && m_axis_tready && m_axis_tvalid && (!(|last_wait) || m_axis_tlast) );
    // assign s01_axis_tready  = !data_valid_reg   ;

    // // buffer中没数， header_valid_reg为空,或者
    // // assign s00_axis_tready  = m_axis_tready;
    // // assign s00_axis_tready  = !header_valid_reg | (m_axis_tready && m_axis_tvalid && m_axis_tlast && !header_valid_reg);
    // // assign s00_axis_tready  = !header_valid_reg | (m_axis_tready);
    // // assign s00_axis_tready  = (!header_valid_reg && !concat_keep_shift[DATA_BYTE_WD-1]) | m_axis_tready;
    
    // // assign s01_axis_tready  = !data_valid_reg   | (m_axis_tready && m_axis_tvalid);
    // // assign s01_axis_tready  = !data_valid_reg   | (!out_tlast && m_axis_tready && ((header_valid_reg && !header_keep_reg[DATA_BYTE_WD-1]) | !header_valid_reg));