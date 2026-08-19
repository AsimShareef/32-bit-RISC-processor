module branch_unit(
    input wire [31:0] rs_data,
    input wire [2:0] brOp,
    output reg branch_taken
);
    always @(*) begin
        case (brOp)
            3'b000: branch_taken = 1'b1;                    // BR - unconditional
            3'b001: branch_taken = rs_data[31];             // BMI - branch if negative
            3'b010: branch_taken = ~rs_data[31];            // BPL - branch if positive
            3'b011: branch_taken = (rs_data == 32'd0);      // BZ - branch if zero
            default: branch_taken = 1'b0;
        endcase
    end
endmodule
