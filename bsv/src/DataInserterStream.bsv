import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import BRAMFIFO::*;

import Connectable :: *;
import GetPut :: *;

import BusConversion :: *;
import SemiFifo :: *;
import AxiStreamTypes :: *;
import Axi4LiteTypes :: *;
import Axi4Types :: *;
import Ehr::*;
import Ports :: *;

typedef 1 HEAD_FIFO_DEPTH;
typedef 1 DATAIN_FIFO_DEPTH;
typedef 1 DATAOUT_FIFO_DEPTH;

function UInt#(8) shitfCnt(Bit#(4) din);
    // 计算长度码 len
    UInt#(8) len = 0;
    for(UInt#(4) i=0; i<4; i=i+1)
       if(din[i] == 1)
          len = len + 1;
    
    return len;
endfunction

function Tuple2#(Bit#(32), Bit#(4)) rmZero(Bit#(32) data,Bit#(4) keep);

    for(UInt#(3) i=0; i<4; i=i+1)
        if(keep[3] == 0) begin
            data = data << 8;
            keep = keep << 1;
        end
    
    return tuple2( data,keep );
endfunction


interface DataInserterIFC#(numeric type keepWidth, numeric type usrWidth);
    (* prefix = "s00_axis" *) interface RawAxiStreamSlave #(keepWidth, usrWidth) headStreamIn ;
    (* prefix = "s01_axis" *) interface RawAxiStreamSlave #(keepWidth, usrWidth) dataStreamIn ;
    (* prefix = "m_axis" *)   interface RawAxiStreamMaster#(keepWidth, usrWidth) dataStreamOut;
endinterface

(* synthesize *)
module mkDataInserterStream(DataInserterIFC#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH));
    Integer headFifoDepth    = valueOf(HEAD_FIFO_DEPTH);
    Integer dataInFifoDepth  = valueOf(DATAIN_FIFO_DEPTH);
    Integer dataOutFifoDepth = valueOf(DATAOUT_FIFO_DEPTH);

    // FIFOF#(AxiStream32) headFifo <- mkSizedFIFOF(headFifoDepth+1);
    // FIFOF#(AxiStream32) dataInFifo <- mkSizedFIFOF(dataInFifoDepth+1);
    FIFOF#(AxiStream32) dataOutFifo <- mkSizedFIFOF(dataOutFifoDepth+1);

    FIFOF#(AxiStream32) headFifo <- mkSizedBypassFIFOF(headFifoDepth);
    FIFOF#(AxiStream32) dataInFifo <- mkSizedBypassFIFOF(dataInFifoDepth);
    // FIFOF#(AxiStream32) dataOutFifo <- mkSizedBypassFIFOF(dataOutFifoDepth);

    let rawAxiSlaveHead  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(headFifo));
    let rawAxiSlaveData  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(dataInFifo));
    let rawAxiMasterData <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(dataOutFifo));
    
    Reg#(Bool)                      headSendReg    <- mkReg(True);
    Reg#(Bit#(AXIS_TDATA_WIDTH))    resDataReg     <- mkReg(0);
    Reg#(Bit#(AXIS_TKEEP_WIDTH))    resKeepReg     <- mkReg(0);
    Reg#(Bool)                      tailValidReg   <- mkReg(False);

    rule getHead;
        if (headSendReg) begin
            if (headFifo.notEmpty) begin
                let rxHead = headFifo.first;
                headFifo.deq();

                let headData = rxHead.tData;
                let headKeep = rxHead.tKeep;
                let headKeepCnt = shitfCnt(headKeep);

                if (headKeep[3] == 1'b1) begin
                    let streamOut = AxiStream32{     
                        tData: headData,
                        tKeep: headKeep,
                        tLast: False
                    };
                    dataOutFifo.enq( streamOut );
                    resDataReg <= 32'b0;
                    resKeepReg <= 4'b0;
                    
                    headSendReg <= False;
                end 
                else if (dataInFifo.notEmpty) begin
                    let rxData = dataInFifo.first;
                    dataInFifo.deq;

                    let dataData = rxData.tData;
                    let dataKeep = rxData.tKeep;
                    let dataKeepCnt = shitfCnt(dataKeep);
                    let dataLast = rxData.tLast;
                    if (dataLast) begin
                        if ((dataKeepCnt + headKeepCnt) > 4) begin
                            dataLast = False;
                            tailValidReg <= True;
                        end
                    end

                    let streamOut = AxiStream32{     
                        tData: truncate({headData,dataData} >> (headKeepCnt<<3)),
                        tKeep: truncate({headKeep,dataKeep} >>  headKeepCnt),
                        tLast: dataLast
                    };
                    dataOutFifo.enq(streamOut);

                    resDataReg <= dataData;
                    resKeepReg <= dataKeep & headKeep;

                    headSendReg <= dataLast;
                end
                else begin
                    resDataReg <= headData;
                    resKeepReg <= headKeep;
                    headSendReg <= False;
                end 
            end
        end else begin
            if (tailValidReg) begin
                let streamOut = AxiStream32{
                    tData: resDataReg,
                    tKeep: resKeepReg,
                    tLast: True
                };

                dataOutFifo.enq(streamOut);
                headSendReg <= True;
                tailValidReg <= False;
            end
            else if (dataInFifo.notEmpty) begin
                let rxData = dataInFifo.first;
                dataInFifo.deq;   

                let dataData = rxData.tData;
                let dataKeep = rxData.tKeep;
                let dataKeepCnt = shitfCnt(dataKeep);
                let headKeepCnt = shitfCnt(resKeepReg);
                
                let dataLast = rxData.tLast;
                if (dataLast) begin
                    if ((dataKeepCnt + headKeepCnt) > 4) begin
                        dataLast = False;
                        tailValidReg <= True;
                    end
                end

                let streamOut = AxiStream32{     
                    tData: truncate({resDataReg,dataData} >> (headKeepCnt<<3)),
                    tKeep: truncate({resKeepReg,dataKeep} >>  headKeepCnt),
                    tLast: dataLast
                };
                dataOutFifo.enq(streamOut);

                resDataReg <= dataData;
                resKeepReg <= dataKeep & resKeepReg;
                
                headSendReg <= dataLast; 
            end
        end

    endrule

    interface headStreamIn  = rawAxiSlaveHead ;
    interface dataStreamIn  = rawAxiSlaveData ;
    interface dataStreamOut = rawAxiMasterData;

endmodule