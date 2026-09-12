`timescale 1ns / 1ps

// Instruction ROM, word (4-byte) addressed.
//
// Design note: the original version of this project instantiated Xilinx's
// Block Memory Generator IP (`blk_mem_gen_1`) directly. That IP is a GUI
// wizard product of the Vivado project file, not portable Verilog -- it
// cannot be checked into a repo in a way that lets anyone else open the
// project, and it cannot be simulated with an open-source simulator such
// as Icarus Verilog. This module instead uses the standard vendor-neutral
// "registered read from an array" coding template
// (`dout <= mem[addr]` inside a clocked always block). Every mainstream
// synthesis tool (Vivado, Yosys, ...) recognizes this template and infers
// a real Block RAM primitive from it, so behaviour on real FPGA hardware
// is unchanged while the design becomes both simulatable and tool-agnostic.
module instruction_memory #(
    parameter DEPTH     = 256,          // words
    parameter INIT_FILE = ""            // optional $readmemh file
)(
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] insn
);
    localparam AW = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];

    initial begin
        insn = 32'h0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk) begin
        insn <= mem[addr[AW+1:2]];
    end
endmodule
