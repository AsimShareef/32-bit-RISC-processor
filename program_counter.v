module program_counter(
    input wire clk,
    input wire rst,
    input wire halt,
    input wire pc_write,
    input wire [31:0] pc_next,
    output reg [31:0] pc
);
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;
            $display("[%0t] PC reset to 0", $time);
        end else if (!halt && pc_write) begin
            pc <= pc_next;
            $display("[%0t] PC updated to %h", $time, pc_next);
        end
    end
endmodule
