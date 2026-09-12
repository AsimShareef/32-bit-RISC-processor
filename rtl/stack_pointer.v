`timescale 1ns / 1ps

// The ISA requires every load/store address to be a multiple of 8
// (docs/ISA.md), so the stack -- which PUSH/POP/CALL/RET address through
// the same data memory -- must grow and shrink in 8-byte steps too.
module stack_pointer #(
    parameter [31:0] SP_INIT = 32'h000007F8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        push_or_call,   // SP <= SP - 8
    input  wire        pop_or_ret,     // SP <= SP + 8
    output reg  [31:0] sp
);
    always @(posedge clk) begin
        if (rst)                  sp <= SP_INIT;
        else if (push_or_call)    sp <= sp - 32'd8;
        else if (pop_or_ret)      sp <= sp + 32'd8;
    end
endmodule
