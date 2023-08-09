module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8
) (
    input                        clk,
    input                        rst_n,

    // AXI Stream input original data
    input                        valid_in,
    input   [DATA_WD-1 : 0]      data_in,
    input   [DATA_BYTE_WD-1 : 0] keep_in,
    input                        last_in,
    output                       ready_in,

    // The header to be inserted to AXI Stream input
    input                        valid_insert,
    input   [DATA_WD-1 : 0]      header_insert,
    input   [DATA_BYTE_WD-1 : 0] keep_insert,
    output                       ready_insert,

    // AXI Stream output with header inserted
    output                       valid_out,
    output  [DATA_WD-1 : 0]      data_out,
    output  [DATA_BYTE_WD-1 : 0] keep_out,
    output                       last_out,
    input                        ready_out
);

    //status
    parameter WAIT_HEAD = 2'd0;
    parameter WAIT_LAST = 2'd1;
    parameter s2            = 2'd2;
    parameter s3            = 2'd3;

    reg [1:0]  current_state;
    reg [1:0]  next_state;

    //current_state
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            current_state <= WAIT_HEAD;
        else
            current_state <= next_state;
    end

    //next_state
    always @(*) begin
        if(!rst_n)
            next_state = WAIT_HEAD;
        else begin
            case (current_state)
                WAIT_HEAD : next_state = valid_insert ? WAIT_LAST : WAIT_HEAD;
                WAIT_LAST : next_state = last_in      ? WAIT_HEAD : WAIT_LAST;
                default   : next_state = WAIT_HEAD;
            endcase
        end
    end

    assign ready_insert = (current_state == WAIT_HEAD);
    assign ready_in     = (current_state == WAIT_LAST);

    // NOTE: $clog2 was added in 1364-2005, not supported in 1364-1995 or 1364-2001
    reg [$clog2(DATA_BYTE_WD+1)-1:0] keep_insert_count_ones;
    integer idx;

    always @* begin
        keep_insert_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
            keep_insert_count_ones = keep_insert_count_ones + keep_insert[idx];
        end
    end

    reg [$clog2(DATA_BYTE_WD+1)-1:0] keep_in_count_ones;
    integer idx_in;

    always @* begin
        keep_in_count_ones = {DATA_BYTE_WD{1'b0}};  
        for( idx_in = 0; idx_in<DATA_BYTE_WD; idx_in = idx_in + 1) begin
            keep_in_count_ones = keep_in_count_ones + keep_in[idx_in];
        end
    end

    // 0: 1-3需要和data拼接
    // 1: 0和4不用拼接
    reg [$clog2(DATA_BYTE_WD+1)-1:0] insert_type;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            insert_type <= 1'b0;
        else if(valid_insert && ready_insert)
            insert_type <= keep_insert_count_ones;
    end

    reg [DATA_WD-1 : 0]         data_out_r;
    reg [DATA_WD-1 : 0]         data_cut;
    reg [DATA_BYTE_WD-1 : 0]    keep_out_r;
    reg                         valid_out_r;
    reg                         last_out_r;
    reg                         res_out;

    wire [DATA_WD-1:0] insert_mask;
    assign insert_mask = {DATA_WD{1'b1}} >> ((DATA_BYTE_WD - insert_type) << 3);
    // wire [DATA_WD-1:0] insert_out;
    // assign insert_out = (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & data_in) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
    // (DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) 解决移位后位宽问题

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_out_r  <= {DATA_WD{1'b0}};
            keep_out_r  <= {DATA_BYTE_WD{1'b0}};
            valid_out_r <= 1'b0;
            last_out_r  <= 1'b0;
            res_out     <= 1'b0;
        end else if(valid_insert && ready_insert) begin
            if(insert_type == DATA_BYTE_WD) begin
                data_out_r  <= header_insert;
                valid_out_r <= 1'b1;
                keep_out_r  <= {DATA_BYTE_WD{1'b1}};
            end
        end else if(valid_in && ready_in && last_in)begin
            valid_out_r <= 1'b1;
            if(insert_type == 0 || insert_type == DATA_BYTE_WD) begin
                data_out_r  <= data_in;
                keep_out_r  <= {DATA_BYTE_WD{1'b1}};
                last_out_r  <= 1'b1;
            end else begin   
                data_out_r  <= (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & data_in) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
                if((insert_type + keep_in_count_ones) > DATA_BYTE_WD) begin
                    keep_out_r  <= {DATA_BYTE_WD{1'b1}};
                    res_out <= 1'b1;
                end else begin
                    keep_out_r  <= {DATA_BYTE_WD{1'b1}} << ((DATA_BYTE_WD - insert_type) + keep_in_count_ones);
                    last_out_r  <= 1'b1;
                end
            end
        end else if(valid_in && ready_in)begin
            valid_out_r <= 1'b1;
            keep_out_r  <= {DATA_BYTE_WD{1'b1}};
            if(insert_type == 0 || insert_type == DATA_BYTE_WD) begin
                data_out_r  <= data_in;
            end else begin   
                data_out_r  <= (insert_mask & data_cut) << ((DATA_BYTE_WD - insert_type) << 3) | (~insert_mask & data_in) >> ((DATA_BYTE_WD - (DATA_BYTE_WD - insert_type)) << 3);
            end
        end else if(res_out) begin
            valid_out_r <= 1'b1;
            keep_out_r  <= {DATA_BYTE_WD{1'b1}};
            data_out_r  <= data_in;
            last_out_r  <= 1'b1;
            res_out     <= 1'b0;
        end else begin
            // data_out_r <= {DATA_WD{1'b0}};
            valid_out_r <= 1'b0;            
            last_out_r  <= 1'b0;            
        end
    end


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_cut <= {DATA_WD{1'b0}};
        end else if(valid_insert && ready_insert) begin
            data_cut <= header_insert;
        end else if(valid_in && ready_in)begin
            data_cut <= data_in;
        end
    end
    assign data_out  = data_out_r;
    assign valid_out = valid_out_r;
    assign keep_out  = keep_out_r;
    assign last_out  = last_out_r;
endmodule