module iverilog_dump();
initial begin
    $dumpfile("axi_stream_insert_header.fst");
    $dumpvars(0, axi_stream_insert_header);
end
endmodule
