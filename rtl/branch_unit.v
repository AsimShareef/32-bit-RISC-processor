`timescale 1ns / 1ps

// Evaluates the taken/not-taken condition for the four branch instructions.
// BR is unconditional (brType 00) and ignores rs_data entirely.
module branch_unit(
    input  wire [31:0] rs_data,
    input  wire [1:0]  brType,
    output reg          branch_taken
);
    localparam BR_UNCOND = 2'b00, BR_MI = 2'b01, BR_PL = 2'b10, BR_Z = 2'b11;

    always @(*) begin
        case (brType)
            BR_UNCOND: branch_taken = 1'b1;
            BR_MI:     branch_taken = rs_data[31];                       // rs < 0
            BR_PL:     branch_taken = (~rs_data[31]) && (rs_data != 0);  // rs > 0 (strict)
            BR_Z:      branch_taken = (rs_data == 32'd0);                // rs == 0
            default:   branch_taken = 1'b0;
        endcase
    end
endmodule
