// import FIFO::*;
// import FIFOF::*;
// import SpecialFIFOs::*;
// import BRAMFIFO::*;

// import Connectable :: *;
// import GetPut :: *;

// import BusConversion :: *;
// import SemiFifo :: *;
// import AxiStreamTypes :: *;
// import Axi4LiteTypes :: *;
// import Axi4Types :: *;
// import Ehr::*;
// import Ports :: *;

// typedef 1 HEAD_FIFO_DEPTH;
// typedef 1 DATAIN_FIFO_DEPTH;
// typedef 1 DATAOUT_FIFO_DEPTH;

// function UInt#(4) shitfCnt(Bit#(4) din);
//     // 计算长度码 len
//     UInt#(4) len = 0;
//     for(UInt#(4) i=0; i<4; i=i+1)
//        if(din[i] == 1)
//           len = len + 1;
    
//     return len;
//  endfunction

// interface DataInserterIFC#(numeric type keepWidth, numeric type usrWidth);
//     (* prefix = "s00_axis" *) interface RawAxiStreamSlave #(keepWidth, usrWidth) headStreamIn ;
//     (* prefix = "s01_axis" *) interface RawAxiStreamSlave #(keepWidth, usrWidth) dataStreamIn ;
//     (* prefix = "m_axis" *)   interface RawAxiStreamMaster#(keepWidth, usrWidth) dataStreamOut;
// endinterface

// (* synthesize *)
// module mkDataInserterStream(DataInserterIFC#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH));
//     Integer headFifoDepth    = valueOf(HEAD_FIFO_DEPTH);
//     Integer dataInFifoDepth  = valueOf(DATAIN_FIFO_DEPTH);
//     Integer dataOutFifoDepth = valueOf(DATAOUT_FIFO_DEPTH);

//     // FIFOF#(AxiStream32) headFifo <- mkSizedFIFOF(headFifoDepth);
//     // FIFOF#(AxiStream32) dataInFifo <- mkSizedFIFOF(dataInFifoDepth);
//     // FIFOF#(AxiStream32) dataOutFifo <- mkSizedFIFOF(dataOutFifoDepth);

//     FIFOF#(AxiStream32) headFifo <- mkSizedBypassFIFOF(headFifoDepth);
//     FIFOF#(AxiStream32) dataInFifo <- mkSizedBypassFIFOF(dataInFifoDepth);
//     FIFOF#(AxiStream32) dataOutFifo <- mkSizedBypassFIFOF(dataOutFifoDepth);

//     let rawAxiSlaveHead  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(headFifo));
//     let rawAxiSlaveData  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(dataInFifo));
//     let rawAxiMasterData <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(dataOutFifo));
    
//     Ehr#(2, Bool) headSendReg <- mkEhr(True);
//     // Ehr#(2, Bool) headSendReg <- mkEhr(True);

//     // Ehr#(3, Bit#(TMul#(AXIS_TDATA_WIDTH, 2))) concatDataReg     <- mkEhr(0);
//     // Ehr#(3, Bit#(TMul#(AXIS_TKEEP_WIDTH, 2))) concatKeepReg     <- mkEhr(0);
//     Reg#(Bit#(AXIS_TDATA_WIDTH)) resDataReg     <- mkReg(0);
//     Reg#(Bit#(AXIS_TKEEP_WIDTH)) resKeepReg     <- mkReg(0);
//     Reg#(Bit#(AXIS_TDATA_WIDTH)) dataDataReg    <- mkReg(0);
//     Reg#(Bit#(AXIS_TKEEP_WIDTH)) dataKeepReg    <- mkReg(0);
//     // Ehr#(2, Bit#(AXIS_TDATA_WIDTH)) resDataReg     <- mkEhr(0);
//     // Ehr#(2, Bit#(AXIS_TKEEP_WIDTH)) resKeepReg     <- mkEhr(0);
//     // Ehr#(2, Bit#(AXIS_TDATA_WIDTH)) dataDataReg    <- mkEhr(0);
//     // Ehr#(2, Bit#(AXIS_TKEEP_WIDTH)) dataKeepReg    <- mkEhr(0);

//     // Reg#(Bit#(TMul#(AXIS_TDATA_WIDTH, 2))) concatDataReg <- mkReg(0);
//     // Reg#(Bit#(TMul#(AXIS_TKEEP_WIDTH, 2))) concatKeepReg <- mkReg(0);

//     Reg#(Bool) tlastReg <- mkReg(False);
//     // Ehr#(2, Bool) tlastReg <- mkEhr(False);

//     Reg#(UInt#(4)) shitfCntReg <- mkReg(0);
//     // Ehr#(2, UInt#(4)) shitfCntReg <- mkEhr(0);
    
//     rule getHead if (headSendReg[0] == True);
//         let rxHead = headFifo.first;
//         headFifo.deq();

//         resDataReg  <= rxHead.tData;
//         resKeepReg  <= rxHead.tKeep;
//         shitfCntReg <= shitfCnt(rxHead.tKeep);

//         headSendReg[0] <= False;
//     endrule

//     rule getDataIn if (headSendReg[1] == False && dataKeepReg[3] == 1'b0);
//         let rxData = dataInFifo.first;
//         dataInFifo.deq();

//         dataDataReg <= rxData.tData;
//         dataKeepReg <= rxData.tKeep;
//         tlastReg    <= rxData.tLast;

//     endrule

//     rule putDataOut if (resKeepReg[3] == 1'b1 || dataKeepReg[3] == 1'b1);

//         Bool tail_valid;
//         Bit#(AXIS_TDATA_WIDTH) dataOut;
//         Bit#(AXIS_TKEEP_WIDTH) keepOut;
//         if(resKeepReg[3] == 1'b1) begin
//             resDataReg <= dataDataReg;
//             resKeepReg <= dataKeepReg;
//             // dataDataReg <= 32'b0;
//             // dataKeepReg <=  4'b0;
//             tail_valid = tlastReg;
//             dataOut = resDataReg;
//             keepOut = resKeepReg;
//         // end
//         // end else if(resKeepReg[0] == 1'b1) begin

//         //     resDataReg[1] <= dataDataReg[1];
//         //     resKeepReg[1] <= dataKeepReg[1] & resKeepReg[1];
//         //     dataDataReg[1] <= 32'b0;
//         //     dataKeepReg[1] <=  4'b0;
//         //     let headCnt = shitfCnt(resKeepReg[1]);
//         //     let tailCnt = shitfCnt(dataKeepReg[1]);
//         //     tail_valid = tlastReg[1] && ((headCnt + tailCnt) <= 4);
//         //     dataOut = truncate({resDataReg[1],dataDataReg[1]} >> 24);
//         //     keepOut = truncate({resKeepReg[1],dataKeepReg[1]} >> 3);

//         end else begin
//             resDataReg <= 32'b0;
//             resKeepReg <=  4'b0;
//             dataDataReg <= 32'b0;
//             dataKeepReg <=  4'b0;
//             tail_valid = True;
//             dataOut = resDataReg << 8;
//             keepOut = resKeepReg << 1;
//         end

//         let streamOut = AxiStream32{     
//             tData: dataOut,
//             tKeep: keepOut,
//             tLast: tail_valid ? tlastReg : False
//         };

//         if(tlastReg == True && tail_valid == True) begin
//             tlastReg <= False;
//             headSendReg[1] <= True;
//         end
//         dataOutFifo.enq( streamOut );

//     endrule

//     interface headStreamIn  = rawAxiSlaveHead ;
//     interface dataStreamIn  = rawAxiSlaveData ;
//     interface dataStreamOut = rawAxiMasterData;

// endmodule