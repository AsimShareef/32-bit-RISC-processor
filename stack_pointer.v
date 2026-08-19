module stack_pointer(
    input wire clk,
    input wire rst,
    input wire isPush,
    input wire isPop,
    input wire isCall,
    input wire isRet,
    output reg [31:0] sp_addr,
    output reg sp_update
);
    reg [31:0] sp;
    
    always @(posedge clk) begin
        if (rst) begin
            sp <= 32'h000003FC;  // Initialize stack pointer
        end else begin
            if (isPush || isCall) begin
                sp <= sp - 4;
            end else if (isPop || isRet) begin
                sp <= sp + 4;
            end
        end
    end
    
    always @(*) begin
        sp_addr = sp;
        sp_update = isPush | isPop | isCall | isRet;
    end
endmodule
