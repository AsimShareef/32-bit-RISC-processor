`timescale 1ns / 1ps

// "Final Program Demonstration" Project 1: Booth's multiplication.
// Result register is R2 per the assignment. Regenerate
// programs/booth_mult.hex (and the .coe for Vivado's IP Catalog) with:
//   python tools/assemble.py programs/booth_mult.asm --hex programs/booth_mult.hex --coe programs/booth_mult.coe
// The TA-supplied data .coe (M at byte address 0, R at byte address 8,
// both sign-extended 32-bit words -- see docs/README) replaces
// programs/booth_data.hex for a real demo.
module top_booth(
    input  wire        clk,
    input  wire        reset,
    input  wire        sw0,
    output wire [15:0] led
);
    top_autonomous #(
        .IMEM_FILE("programs/booth_mult.hex"),
        .DMEM_FILE("programs/booth_data.hex"),
        .RESULT_REG(4'd2)
    ) TOP (
        .clk(clk), .reset(reset), .sw0(sw0), .led(led)
    );
endmodule
