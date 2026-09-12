`timescale 1ns / 1ps

// Sign-extends the instruction's immediate field.
// imm26 = 1 selects the 26-bit field used only by BR (unconditional,
// PC-relative, wide enough to reach anywhere in program memory).
// imm26 = 0 selects the 16-bit field used by every other I-type
// instruction (ADDI.. SGTI, LD/ST offsets, BMI/BPL/BZ offsets).
module imm_gen(
    input  wire [31:0] instruction,
    input  wire        imm26,
    output wire [31:0] imm_out
);
    assign imm_out = imm26
        ? {{6{instruction[25]}}, instruction[25:0]}
        : {{16{instruction[15]}}, instruction[15:0]};
endmodule
