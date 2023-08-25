import FIFOF :: *;
import Connectable :: *;
import GetPut :: *;

import BusConversion :: *;
import SemiFifo :: *;
import AxiStreamTypes :: *;
import Axi4LiteTypes :: *;
import Axi4Types :: *;

import Ports :: *;

typedef 1 HEAD_FIFO_DEPTH;
typedef 1 DATAIN_FIFO_DEPTH;
typedef 1 DATAOUT_FIFO_DEPTH;

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

    FIFOF#(AxiStream32) headFifo <- mkSizedFIFOF(headFifoDepth);
    FIFOF#(AxiStream32) dataInFifo <- mkSizedFIFOF(dataInFifoDepth);
    FIFOF#(AxiStream32) dataOutFifo <- mkSizedFIFOF(dataInFifoDepth);

    // Wire#(Maybe#(AxiStream32)) rxHeadStream <- mkBypassWire;
    // Wire#(Maybe#(AxiStream32)) rxDataStream <- mkBypassWire;

    rule getHead;
        let rxHead = headFifo.first;
        headFifo.deq();
        if(rxHead.tKeep == 4'b1111) begin
            dataOutFifo.enq(rxHead);
        end

    endrule

    let rawAxiSlaveHead  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(headFifo));
    let rawAxiSlaveData  <- mkPipeInToRawAxiStreamSlave(convertFifoToPipeIn(dataInFifo));
    let rawAxiMasterData <- mkPipeOutToRawAxiStreamMaster(convertFifoToPipeOut(dataOutFifo));

    interface headStreamIn  = rawAxiSlaveHead ;
    interface dataStreamIn  = rawAxiSlaveData ;
    interface dataStreamOut = rawAxiMasterData;

    // interface RawAxiStreamSlave headStreamIn;
    //     method Bool tReady = True;
    //     method Action tValid(
    //         Bool valid, 
    //         Bit#(AXIS_TDATA_WIDTH) tData, 
    //         Bit#(AXIS_TKEEP_WIDTH) tKeep, 
    //         Bool tLast, 
    //         Bit#(AXIS_TUSER_WIDTH) tUser
    //     );
    //         if (valid) begin
    //         rxHeadStream <= tagged Valid AxiStream32 {
    //                 tData: tData,
    //                 tKeep: tKeep,
    //                 tLast: tLast,
    //                 tUser: tUser
    //             };
    //         end
    //         else begin
    //             rxHeadStream <= tagged Invalid;
    //         end
    //     endmethod
    // endinterface

    // interface RawAxiStreamSlave dataStreamIn;
    //     method Bool tReady = True;
    //     method Action tValid(
    //         Bool valid, 
    //         Bit#(AXIS_TDATA_WIDTH) tData, 
    //         Bit#(AXIS_TKEEP_WIDTH) tKeep, 
    //         Bool tLast, 
    //         Bit#(AXIS_TUSER_WIDTH) tUser
    //     );
    //         if (valid) begin
    //         rxDataStream <= tagged Valid AxiStream32 {
    //                 tData: tData,
    //                 tKeep: tKeep,
    //                 tLast: tLast,
    //                 tUser: tUser
    //             };
    //         end
    //         else begin
    //             rxDataStream <= tagged Invalid;
    //         end
    //     endmethod
    // endinterface
endmodule