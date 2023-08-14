`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/13 15:20:23
// Design Name: tb_axi_stream_insert_header
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_axi_stream_insert_header; 

	parameter PERIOD = 10 ; 
	parameter DATA_WD = 32 ; 
	parameter DATA_BYTE_WD = DATA_WD / 8 ; 
	parameter tb_datain_depth = 4;
    
    // axi_stream_insert_header Inputs
    reg   clk                                = 0 ;
    reg   rst_n                              = 0 ;
    reg   valid_in                           = 0 ;
    reg   [DATA_WD-1 : 0]  data_in           = 0 ;
    reg   [DATA_BYTE_WD-1 : 0]  keep_in      = 0 ;
    reg   ready_out                          = 1 ;
    reg   valid_insert                       = 0 ;
    reg   [DATA_WD-1 : 0]	data_insert		 = 0 ;
    reg   [DATA_BYTE_WD-1 : 0]  keep_insert  = 0 ;

    // axi_stream_insert_header Outputs
    wire  ready_in                             	 ;
    wire  valid_out                            	 ;
    wire  [DATA_WD-1 : 0]  data_out            	 ;
    wire  [DATA_BYTE_WD-1 : 0]  keep_out       	 ;
    wire  last_out                             	 ;
    wire  ready_insert                         	 ;
    wire  last_in                              	 ;

initial
begin            
    $dumpfile("tb_axi_stream_insert_header.vcd"); //生成的vcd文件名称
    $dumpvars(0, tb_axi_stream_insert_header);    //tb模块名称
end
    
initial	begin
       forever #(PERIOD/2)  clk = ~clk;
   end
   
initial begin
       #(PERIOD*2) rst_n = 1;
	   #(PERIOD*200)								;
	   $finish										;
end

integer seed									 ;
initial begin	                                 
	seed 	=		2							 ;
end

// 随机产生1拍header数据
initial begin
	forever #(PERIOD)	begin
	    data_insert	=	$random(seed)		;
		keep_insert		=	{$random(seed)}%2?({$random(seed)}%2?4'b0001:4'b0011):({$random(seed)}%2?4'b0111:4'b1111);
	end
end
    
    axi_stream_insert_header #(
    .DATA_WD      (DATA_WD),
    .DATA_BYTE_WD (DATA_BYTE_WD))
    u_axi_stream_insert_header (
    .clk                     (clk),
    .rst                     (!rst_n),
    .s01_axis_tvalid                (valid_in),
    .s01_axis_tdata                 (data_in          [DATA_WD-1 : 0]),
    .s01_axis_tkeep                 (keep_in          [DATA_BYTE_WD-1 : 0]),
    .s01_axis_tlast                 (last_in),
    .m_axis_tready               (ready_out),
    .s00_axis_tvalid            (valid_insert),
    .s00_axis_tdata        	 (data_insert      [DATA_WD-1 : 0]),
    .s00_axis_tkeep             (keep_insert      [DATA_BYTE_WD-1 : 0]),
    
    .s01_axis_tready                (ready_in),
    .m_axis_tvalid               (valid_out),
    .m_axis_tdata                (data_out         [DATA_WD-1 : 0]),
    .m_axis_tkeep                (keep_out         [DATA_BYTE_WD-1 : 0]),
    .m_axis_tlast                (last_out),
    .s00_axis_tready            (ready_insert)
    );
    

// valid_insert信号，随机产生
always @(posedge clk or negedge rst_n)begin
		if(!rst_n)
				valid_insert		<=		0			;	
		else begin
				valid_insert		<=	{$random(seed)}%2 ;
				ready_out		<=	{$random(seed)}%2 ;
		end
end
  
// 计数器cnt
reg 	[3:0]cnt		=	0							;
always @(posedge clk or negedge rst_n)begin
		if(!rst_n)
				cnt				<=		0				;
		else if(cnt == (tb_datain_depth+1)) 
				cnt				<=	0					;
		else if(ready_in && cnt == 0)
				cnt				<=	cnt + 1				;
		else if(ready_in && valid_in)
				cnt				<=	cnt + 1				;

		else 
				cnt 			<=	cnt					;

end

// 产生5拍data_in数据
always @(posedge clk or negedge rst_n)begin
		if(!rst_n)
				data_in			<=	32'h0				;
		else if(ready_in)
			case(cnt)
				0: data_in		<=	$random(seed)		;
				1: data_in		<=	$random(seed)		;				
				2: data_in		<=	$random(seed)		;
				3: data_in		<=	$random(seed)		;
				4: data_in		<=	$random(seed)		;		
				default: 	data_in		<=		0		;
			endcase
		else 
				data_in			<=	data_in				;
end

// valid_in
always @(posedge clk or negedge rst_n)begin
		if(!rst_n)
				valid_in		<=		0				;
		else if(ready_in)
			case(cnt)
				0:valid_in		<=		1				;
				1:valid_in		<=		1				;
				2:valid_in		<=		1				;
				3:valid_in		<=		1				;	
				4:valid_in		<=		1				;	
				default:valid_in	<=		0			;	
			endcase
		else 
				valid_in		<=		valid_in		;
end	

// keep_in:前4拍全为高，最后1拍随机
always @(posedge clk or negedge rst_n)begin
		if(!rst_n)
				keep_in			<=		0				;
		else if(ready_in)
			case(cnt)
				0: keep_in		<=	4'b1111				;
				1: keep_in		<=	4'b1111				;
				2: keep_in		<=	4'b1111				;
				3: keep_in		<=	4'b1111				;
				4: keep_in		<=	{$random(seed)}%2?({$random(seed)}%2?4'b1111:4'b1110):({$random(seed)}%2?4'b1100:4'b1000);
				default: keep_in	<=	4'b0			;
			endcase
		else 
				keep_in			<=	keep_in			;
end

// last_in:最后一拍数据
assign 		last_in	= (cnt == tb_datain_depth) ? 1: 0		;

    
endmodule