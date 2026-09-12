`timescale 1ns / 1ps

// 16 x 32-bit general-purpose register file, two read ports / one write
// port, per the assignment spec. R0 is hardwired to zero (writes to it
// are dropped, reads always return 0) -- the strict RISC convention.
// A third, purely observational read port (raddr3/rdata3) is provided
// for board-level debug/result display (see fpga/top_autonomous.v) --
// it never feeds the datapath, so it cannot affect processor behaviour.
module regfile16x32 (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    we,
    input  wire [3:0]              waddr,
    input  wire [3:0]              raddr1,
    input  wire [3:0]              raddr2,
    input  wire [3:0]              raddr3,
    input  wire signed [31:0]      wdata,
    output wire signed [31:0]      rdata1,
    output wire signed [31:0]      rdata2,
    output wire signed [31:0]      rdata3
);

    reg signed [31:0] regs [0:15];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && (waddr != 4'd0)) begin
            regs[waddr] <= wdata;
        end
    end

    assign rdata1 = (raddr1 == 4'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 4'd0) ? 32'd0 : regs[raddr2];
    assign rdata3 = (raddr3 == 4'd0) ? 32'd0 : regs[raddr3];

endmodule
