`timescale 1ns / 1ps

// "Final Program Demonstration" Project 2: Total Hamming Weight.
// Result register is R3 per the assignment. Regenerate
// programs/hamming_weight.hex (and the .coe for Vivado's IP Catalog) with:
//   python tools/assemble.py programs/hamming_weight.asm --hex programs/hamming_weight.hex --coe programs/hamming_weight.coe
// The TA-supplied data .coe (5 words at byte addresses 24,32,40,48,56 --
// see docs/README) replaces programs/hamming_data.hex for a real demo.
module top_hamming(
    input  wire        clk,
    input  wire        reset,
    input  wire        sw0,
    output wire [15:0] led
);
    top_autonomous #(
        .IMEM_FILE("programs/hamming_weight.hex"),
        .DMEM_FILE("programs/hamming_data.hex"),
        .RESULT_REG(4'd3)
    ) TOP (
        .clk(clk), .reset(reset), .sw0(sw0), .led(led)
    );
endmodule
