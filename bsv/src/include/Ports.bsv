import SemiFifo :: *;
import AxiStreamTypes :: *;

typedef 8 BYTE_WIDTH;
typedef Bit#(BYTE_WIDTH) Byte;

typedef 32 AXIS_TDATA_WIDTH;
typedef TDiv#(AXIS_TDATA_WIDTH, BYTE_WIDTH) AXIS_TKEEP_WIDTH;
typedef 0 AXIS_TUSER_WIDTH;

typedef AxiStream#(AXIS_TKEEP_WIDTH, AXIS_TUSER_WIDTH) AxiStream32;