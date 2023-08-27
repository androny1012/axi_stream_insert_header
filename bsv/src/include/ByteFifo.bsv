import Ehr::*;
import Vector::*;

interface ByteFifo;
    method Bool notFull;
    method Action enq(Bit#(32) x);
    method Bool notEmpty;
    method Action deq;
    method Bit#(32) first;
    method Action clear;
endinterface

module ByteFifo(ByteFifo);
    // n is size of fifo
    // t is data type of fifo
    Vector#(8, Reg#(Bit#(8)))       data         <- replicateM(mkRegU());
    Ehr#(2, Bit#(TLog#(8)))         enqP         <- mkEhr(0);
    Ehr#(2, Bit#(TLog#(8)))         deqP         <- mkEhr(0);
    Ehr#(2, Bool)                   notEmptyP    <- mkEhr(False);
    Ehr#(2, Bool)                   notFullP     <- mkEhr(True);
    Ehr#(2, Bool)                   req_deq      <- mkEhr(False);
    Ehr#(2, Maybe#(Bit#(8)))        req_enq      <- mkEhr(tagged Invalid);
    Bit#(TLog#(8))                  size         = fromInteger(valueOf(n)-1);

    (*no_implicit_conditions, fire_when_enabled*) // 保证每个周期都fire
    rule canonicalize;
        // enq and deq
        if ((notFullP[0] && isValid(req_enq[1])) && (notEmptyP[0] && req_deq[1])) begin
            notEmptyP[0] <= True;
            notFullP[0] <= True;
            data[enqP[0]] <= fromMaybe(?, req_enq[1]);

            let nextEnqP = enqP[0] + 1;
            if (nextEnqP > size) begin
                nextEnqP = 0;
            end

            let nextDeqP = deqP[0] + 1;
            if (nextDeqP > size) begin
                nextDeqP = 0;
            end

            enqP[0] <= nextEnqP;
            deqP[0] <= nextDeqP;
        // deq only
        end else if (notEmptyP[0] && req_deq[1]) begin
            let nextDeqP = deqP[0] + 1;
            if (nextDeqP > size) begin
                nextDeqP = 0;
            end

            if (nextDeqP == enqP[0]) begin
                notEmptyP[0] <= False;
            end
            notFullP[0] <= True;
            deqP[0] <= nextDeqP;
        // enq only
        end else if (notFullP[0] && isValid(req_enq[1])) begin
            let nextEnqP = enqP[0] + 1;
            if (nextEnqP > size) begin
                nextEnqP = 0;
            end

            if (nextEnqP == deqP[0]) begin
                notFullP[0] <= False;
            end
            notEmptyP[0] <= True;
            data[enqP[0]] <= fromMaybe(?, req_enq[1]);
            enqP[0] <= nextEnqP;
        end
        req_enq[1] <= tagged Invalid;
        req_deq[1] <= False;
    endrule

    method Bool notFull();
        return notFullP[0];
    endmethod

    method Action enq (t x) if (notFullP[0]);
        req_enq[0] <= tagged Valid (x);
    endmethod

    method Bool notEmpty();
        return notEmptyP[0];
    endmethod

    method Action deq() if (notEmptyP[0]);
        req_deq[0] <= True;
    endmethod

    method t first() if (notEmptyP[0]);
        return data[deqP[0]];
    endmethod

    method Action clear();
        enqP[1] <= 0;
        deqP[1] <= 0;
        notEmptyP[1] <= False;
        notFullP[1] <= True;
    endmethod

endmodule