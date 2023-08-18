module BypassFIFO #(
    parameter DATA_WD = 32
) (
    input                       clk,
    input                       rst_n,

    input                       valid_pre_i,    //from pre-stage
    input   [DATA_WD-1:0]       data_pre_i,     //from pre-stage
    output                      ready_pre_o,    //to pre-stage

    output                      valid_post_o,   //to post-stage
    output  [DATA_WD-1:0]       data_post_o,    //to post-stage
    input                       ready_post_i    //from post-stage
);

    reg                     valid_buf; 
    reg     [DATA_WD-1:0]   data_buf;  //暂存后级not ready时的数据
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_buf <= 1'b0;
        end else if(ready_post_i) begin //如果后级ready,buf中的数据一定是空
            valid_buf <= 1'b0;
        end else if(ready_pre_o && !ready_post_i) begin
            valid_buf <= valid_pre_i;            
        end 
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_buf  <= 'b0;
        end else if(ready_pre_o && !ready_post_i) begin
            data_buf  <= data_pre_i;                
        end 
    end

    assign ready_pre_o  = !valid_buf; // 只要buf中的数为空，就可以enq
    assign valid_post_o = valid_buf ? valid_buf: valid_pre_i; // 只要寄存器或buf中有数就可以deq
    assign data_post_o  = valid_buf ? data_buf : data_pre_i;
endmodule