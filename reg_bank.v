module regfile16x32 (
    input  wire             clk,
    input  wire             rst,
    input  wire             we,
    input  wire [3:0]       waddr,
    input  wire [3:0]       raddr1,
    input  wire [3:0]       raddr2,
    input  wire signed [31:0] wdata,
    output wire signed [31:0] rdata1,
    output wire signed [31:0] rdata2
);

    reg signed [31:0] regs[0:15];

    always @(posedge clk) begin
        if (rst) begin
            regs[0]  <= 32'd0;
            regs[1]  <= 32'd0;
            regs[2]  <= 32'd0;
            regs[3]  <= 32'd0;
            regs[4]  <= 32'd0;
            regs[5]  <= 32'h00000000;
            regs[6]  <= 32'h00000000;
            regs[7]  <= 32'h00000000;
            regs[8]  <= 32'h00000000;
            regs[9]  <= 32'h00000000;
            regs[10] <= 32'h00000000;
            regs[11] <= 32'h00000000;
            regs[12] <= 32'h00000000;
            regs[13] <= 32'h00000000;
            regs[14] <= 32'h00000000;
            regs[15] <= 32'h00000000;
        end else begin
            if (we && (waddr != 4'd0)) begin
                regs[waddr] <= wdata;
                $display("[%0t] Reg[%0d] <= %h", $time, waddr, wdata);
            end
            // Keep R0 zero always.
            regs[0] <= 32'd0;
        end
    end

    // Enforce R0 output is always zero (for strict RISC convention).
    assign rdata1 = (raddr1 == 4'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 4'd0) ? 32'd0 : regs[raddr2];

endmodule
