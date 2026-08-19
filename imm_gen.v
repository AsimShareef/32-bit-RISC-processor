module imm_gen(
    input wire [31:0] instruction,
    input wire immSel,
    output reg [31:0] imm_out
);
    wire [5:0] opcode = instruction[31:26];
    
    always @(*) begin
        if (immSel) begin
            // J-type immediate zero-extend and shift left by 2
            imm_out = {4'd0, instruction[25:0], 2'b00};
        end else begin
            // I-type sign-extend immediate
            imm_out = {{16{instruction[15]}}, instruction[15:0]};
        end
    end
endmodule
