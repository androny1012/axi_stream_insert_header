// `timescale 1ns / 1ps
// //////////////////////////////////////////////////////////////////////////////////
// // Company: 
// // Engineer: 
// // 
// // Create Date: 2023/08/23 16:06:27
// // Design Name: 
// // Module Name: shifter
// // Project Name: 
// // Target Devices: 
// // Tool Versions: 
// // Description: 
// // 
// // Dependencies: 
// // 
// // Revision:
// // Revision 0.01 - File Created
// // Additional Comments:
// // 
// //////////////////////////////////////////////////////////////////////////////////


// module shifter #(
//     parameter DATA_WD = 32,
//     parameter DATA_BYTE_WD = DATA_WD / 8
// ) (

//     // The header to be inserted to AXI Stream input
//     input                           s00_axis_tvalid,
//     input   [DATA_WD-1 : 0]         s00_axis_tdata,
//     input   [DATA_BYTE_WD-1 : 0]    s00_axis_tkeep,
//     input                           s00_axis_tlast,
//     output                          s00_axis_tready,

//     // AXI Stream output with header inserted
//     output                          m_axis_tvalid,
//     output  [DATA_WD-1 : 0]         m_axis_tdata,
//     output  [DATA_BYTE_WD-1 : 0]    m_axis_tkeep,
//     output                          m_axis_tlast,
//     input                           m_axis_tready
// );
//     integer idx;

// //  for loop count zero
// //  lut:40 cell:125 Net:164
//     reg [$clog2(DATA_BYTE_WD+1)+2:0]    s00_axis_tkeep_count_zeros;
//     always @* begin
//         s00_axis_tkeep_count_zeros = {DATA_BYTE_WD{1'b0}};  
//         for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
//             s00_axis_tkeep_count_zeros = s00_axis_tkeep_count_zeros + !s00_axis_tkeep[idx];
//         end
//     end
    
//     assign m_axis_tdata  = s00_axis_tdata << (s00_axis_tkeep_count_zeros << 3);
//     assign m_axis_tkeep  = s00_axis_tkeep <<  s00_axis_tkeep_count_zeros;

// //  for loop zero shift
// //  lut:30 cell:122 Net:161
//    reg [DATA_WD-1 : 0]         s00_axis_tdata_shift;
//    reg [DATA_BYTE_WD-1 : 0]    s00_axis_tkeep_shift;
//    always @(*) begin
//        s00_axis_tdata_shift = s00_axis_tdata;  
//        s00_axis_tkeep_shift = s00_axis_tkeep;  
//        for( idx = 0; idx<DATA_BYTE_WD; idx = idx + 1) begin
//            if(!s00_axis_tkeep_shift[DATA_BYTE_WD-1]) begin
//                s00_axis_tdata_shift = s00_axis_tdata_shift << 8;
//                s00_axis_tkeep_shift = s00_axis_tkeep_shift << 1;
//            end
//        end
//    end

//    assign m_axis_tdata  = s00_axis_tdata_shift;
//    assign m_axis_tkeep  = s00_axis_tkeep_shift;

// //  case zero shift
// //  lut:40 cell:123 Net:162
//    reg [DATA_WD-1 : 0]         s00_axis_tdata_shift;
//    reg [DATA_BYTE_WD-1 : 0]    s00_axis_tkeep_shift;
//    always @(*) begin
//        case(s00_axis_tkeep) 
//        4'b1111:begin
//            s00_axis_tdata_shift = s00_axis_tdata;
//            s00_axis_tkeep_shift = s00_axis_tkeep;  
//        end
//        4'b0111:begin
//            s00_axis_tdata_shift = s00_axis_tdata << 8;
//            s00_axis_tkeep_shift = s00_axis_tkeep << 1;          
//        end
//        4'b0011:begin
//            s00_axis_tdata_shift = s00_axis_tdata << 16;
//            s00_axis_tkeep_shift = s00_axis_tkeep << 2;          
//        end
//        4'b0001:begin
//            s00_axis_tdata_shift = s00_axis_tdata << 24;
//            s00_axis_tkeep_shift = s00_axis_tkeep << 3;          
//        end
//        default:begin
//            s00_axis_tdata_shift = s00_axis_tdata;
//            s00_axis_tkeep_shift = s00_axis_tkeep;  
//        end
//        endcase
//    end  
  
//    assign m_axis_tdata  = s00_axis_tdata_shift;
//    assign m_axis_tkeep  = s00_axis_tkeep_shift;
  
//     assign m_axis_tvalid = s00_axis_tvalid;
//     assign m_axis_tlast  = s00_axis_tlast;
//     assign s00_axis_tready = m_axis_tready;
// endmodule
