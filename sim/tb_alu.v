`timescale 1ns / 1ps

// Directed test of every ALU function against an independent Verilog
// reference computation. Run with: sim/run_alu.sh (or see README).
module tb_alu;
    reg  [3:0]  func;
    reg  [31:0] A, B;
    wire [31:0] RES;

    integer errors = 0;
    integer i;

    alu #(.N(32)) DUT (.func(func), .A(A), .B(B), .RES(RES));

    function [31:0] popcount_ref;
        input [31:0] v;
        integer k;
        begin
            popcount_ref = 0;
            for (k = 0; k < 32; k = k + 1)
                popcount_ref = popcount_ref + v[k];
        end
    endfunction

    task check;
        input [127:0] name;
        input [31:0]  expected;
        begin
            if (RES !== expected) begin
                $display("FAIL %0s : func=%h A=%h B=%h RES=%h expected=%h",
                          name, func, A, B, RES, expected);
                errors = errors + 1;
            end else begin
                $display("PASS %0s : func=%h A=%h B=%h RES=%h", name, func, A, B, RES);
            end
        end
    endtask

    initial begin
        // ADD
        func = 4'h0; A = 32'd10; B = 32'd15; #1; check("ADD", 32'd25);
        func = 4'h0; A = 32'hFFFFFFFF; B = 32'd1; #1; check("ADD wrap", 32'h0);
        // SUB
        func = 4'h1; A = 32'd5; B = 32'd8; #1; check("SUB neg", 32'hFFFFFFFD);
        // AND/OR/XOR/NOR
        func = 4'h2; A = 32'hFF00FF00; B = 32'h0F0F0F0F; #1; check("AND", 32'h0F000F00);
        func = 4'h3; A = 32'hFF00FF00; B = 32'h0F0F0F0F; #1; check("OR",  32'hFF0FFF0F);
        func = 4'h4; A = 32'hFF00FF00; B = 32'h0F0F0F0F; #1; check("XOR", 32'hF00FF00F);
        func = 4'h5; A = 32'h0; B = 32'h0; #1; check("NOR of 0,0", 32'hFFFFFFFF);
        // NOT
        func = 4'h6; A = 32'h0000FFFF; B = 32'h0; #1; check("NOT", 32'hFFFF0000);
        // Shifts
        func = 4'h7; A = 32'h1; B = 32'd4; #1; check("SLL", 32'h10);
        func = 4'h8; A = 32'h80000000; B = 32'd4; #1; check("SRL", 32'h08000000);
        func = 4'h9; A = 32'h80000000; B = 32'd4; #1; check("SRA", 32'hF8000000);
        // INC/DEC
        func = 4'hA; A = 32'd41; B = 32'h0; #1; check("INC", 32'd42);
        func = 4'hB; A = 32'd42; B = 32'h0; #1; check("DEC", 32'd41);
        // SLT/SGT (signed)
        func = 4'hC; A = -32'sd5; B = 32'sd3; #1; check("SLT true",  32'd1);
        func = 4'hC; A = 32'sd3;  B = -32'sd5; #1; check("SLT false", 32'd0);
        func = 4'hD; A = 32'sd9;  B = 32'sd2;  #1; check("SGT true",  32'd1);
        func = 4'hD; A = 32'sd2;  B = 32'sd9;  #1; check("SGT false", 32'd0);
        // HAM
        func = 4'hE; A = 32'hFFFFFFFF; B = 32'h0; #1; check("HAM all ones", 32'd32);
        func = 4'hE; A = 32'h00000000; B = 32'h0; #1; check("HAM zero", 32'd0);
        func = 4'hE; A = 32'h0F0F0F0F; B = 32'h0; #1; check("HAM mixed", 32'd16);
        // LUI
        func = 4'hF; A = 32'h0; B = 32'h0000BEEF; #1; check("LUI", 32'hBEEF0000);

        // Randomized cross-check of ADD/SUB/AND/OR/XOR against $signed math
        for (i = 0; i < 200; i = i + 1) begin
            A = $random; B = $random;
            func = 4'h0; #1; check("rand ADD", A + B);
            func = 4'h1; #1; check("rand SUB", A - B);
            func = 4'h2; #1; check("rand AND", A & B);
            func = 4'h3; #1; check("rand OR",  A | B);
            func = 4'h4; #1; check("rand XOR", A ^ B);
            func = 4'hE; #1; check("rand HAM", popcount_ref(A));
        end

        if (errors == 0) $display("\n*** ALL ALU TESTS PASSED ***");
        else              $display("\n*** %0d ALU TEST(S) FAILED ***", errors);
        $finish;
    end
endmodule
