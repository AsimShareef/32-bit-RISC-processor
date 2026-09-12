`timescale 1ns / 1ps

// Data RAM. Byte-addressed on the port, but the ISA requires every
// load/store address to be a multiple of 8 (docs/ISA.md), so only
// addr[AW+2:3] is actually decoded -- an 8-byte-granular word memory,
// same "registered read from an array" BRAM-inference template as
// instruction_memory.v (see the note there for why this replaced the
// original Xilinx blk_mem_gen_2 IP instantiation).
module data_memory #(
    parameter DEPTH     = 256,          // 8-byte words
    parameter INIT_FILE = ""            // optional $readmemh file
)(
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);
    localparam AW = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];

    initial begin
        rdata = 32'h0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        if (we)
            mem[addr[AW+2:3]] <= wdata;
        rdata <= mem[addr[AW+2:3]];
    end
endmodule
