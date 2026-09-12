`timescale 1ns / 1ps

// Board-level wrapper for the "Final Integration - Autonomous Program
// Execution" addendum: a single reset button starts the processor, it
// runs at full clock speed until HALT, and the selected result register
// is shown on the 16 LEDs (sw[0] picks which half).
//
// This module is deliberately generic (IMEM_FILE/DMEM_FILE/RESULT_REG are
// parameters) so the same wrapper serves both "Final Program
// Demonstration" projects -- see top_booth.v and top_hamming.v, which are
// just this module with those three parameters pinned down, matching the
// addendum's "two separate projects, two separate .bit files" requirement.
module top_autonomous #(
    parameter IMEM_FILE   = "",
    parameter DMEM_FILE   = "",
    parameter [3:0] RESULT_REG = 4'd2
)(
    input  wire        clk,      // E3,  100 MHz
    input  wire        reset,    // BTNC, active-high
    input  wire        sw0,      // J15,  0 = lower 16 bits, 1 = upper 16 bits
    output wire [15:0] led
);

    wire [31:0] pc_out;
    wire        halt_out;
    wire [31:0] result;

    risc_processor #(
        .IMEM_FILE(IMEM_FILE),
        .DMEM_FILE(DMEM_FILE)
    ) CPU (
        .clk(clk),
        .rst(reset),
        .interrupt(1'b0),
        .dbg_raddr(RESULT_REG),
        .dbg_rdata(result),
        .pc_out(pc_out),
        .halt_out(halt_out)
    );

    assign led = sw0 ? result[31:16] : result[15:0];

endmodule
