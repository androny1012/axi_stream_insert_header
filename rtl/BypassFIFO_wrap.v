module BypassFIFO_wrap #(
    parameter DEPTH = 6,
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

    wire [DEPTH:0]      valids; 
    wire [DEPTH:0]      readys;
    wire [DATA_WD-1:0]  data [DEPTH: 0];

    assign valids[0]        = valid_pre_i;
    assign data[0]          = data_pre_i;
    assign ready_pre_o      = readys[0];

    assign valid_post_o     = valids[DEPTH];
    assign data_post_o      = data[DEPTH];
    assign readys[DEPTH]    = ready_post_i;
    
    genvar i;
    generate
        for (i = 1; i < DEPTH+1; i = i + 1) begin
            BypassFIFO #(
                .DATA_WD     (DATA_WD            )
            ) u_buffer_unit(
                .clk         (clk                ),
                .rst_n       (rst_n              ),
                .valid_pre_i (valids[i-1]        ),
                .data_pre_i  (data[i-1]          ),
                .ready_pre_o (readys[DEPTH-i]    ),
                .valid_post_o(valids[i]          ),
                .data_post_o (data[i]            ),
                .ready_post_i(readys[DEPTH+1-i]  )
            );
        end
    endgenerate

endmodule