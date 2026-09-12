`timescale 1ns / 1ps

// A plain, single-style (synchronous reset) PC register. pc_write is
// asserted by the FSM in risc_processor.v exactly once per instruction,
// on whichever cycle that instruction's next-PC value has finally settled
// (immediately after EXECUTE for most instructions, after MEMORY for
// LD/POP/RET, since RET's target only becomes valid once the stack read
// completes).
module program_counter(
    input  wire        clk,
    input  wire        rst,
    input  wire        pc_write,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk) begin
        if (rst)             pc <= 32'd0;
        else if (pc_write)   pc <= pc_next;
    end
endmodule
