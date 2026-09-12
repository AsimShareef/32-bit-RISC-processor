`timescale 1ns / 1ps

// 32-bit ALU covering the 15 arithmetic/logic/shift functions required by
// the ISA (docs/ISA.md, Table 2). CMOV is a compare-and-select handled
// directly in risc_processor.v (it needs both operands unchanged as
// candidate results, which does not fit an ALU with a single RES output),
// and LUI is folded in here as func 4'hF since it only ever needs bits
// B[15:0] shifted into the upper half of the result.
module alu #(
    parameter N = 32
)(
    input  wire [3:0]   func,
    input  wire [N-1:0] A,
    input  wire [N-1:0] B,
    output reg  [N-1:0] RES
);
    localparam ALU_ADD = 4'h0, ALU_SUB = 4'h1, ALU_AND = 4'h2, ALU_OR  = 4'h3,
               ALU_XOR = 4'h4, ALU_NOR = 4'h5, ALU_NOT = 4'h6, ALU_SLL = 4'h7,
               ALU_SRL = 4'h8, ALU_SRA = 4'h9, ALU_INC = 4'hA, ALU_DEC = 4'hB,
               ALU_SLT = 4'hC, ALU_SGT = 4'hD, ALU_HAM = 4'hE, ALU_LUI = 4'hF;

    // Hamming weight (population count) of A.
    function [N-1:0] popcount;
        input [N-1:0] val;
        integer i;
        begin
            popcount = {N{1'b0}};
            for (i = 0; i < N; i = i + 1)
                popcount = popcount + val[i];
        end
    endfunction

    always @(*) begin
        case (func)
            ALU_ADD: RES = A + B;
            ALU_SUB: RES = A - B;
            ALU_AND: RES = A & B;
            ALU_OR : RES = A | B;
            ALU_XOR: RES = A ^ B;
            ALU_NOR: RES = ~(A | B);
            ALU_NOT: RES = ~A;
            ALU_SLL: RES = A << B[4:0];
            ALU_SRL: RES = A >> B[4:0];
            ALU_SRA: RES = $signed(A) >>> B[4:0];
            ALU_INC: RES = A + {{(N-1){1'b0}}, 1'b1};
            ALU_DEC: RES = A - {{(N-1){1'b0}}, 1'b1};
            ALU_SLT: RES = ($signed(A) < $signed(B)) ? {{(N-1){1'b0}}, 1'b1} : {N{1'b0}};
            ALU_SGT: RES = ($signed(A) > $signed(B)) ? {{(N-1){1'b0}}, 1'b1} : {N{1'b0}};
            ALU_HAM: RES = popcount(A);
            ALU_LUI: RES = {B[15:0], 16'h0000};
            default: RES = {N{1'b0}};
        endcase
    end
endmodule
