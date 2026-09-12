`timescale 1ns / 1ps

// Runs programs/isa_selftest.asm to completion and checks that R9 (the
// on-chip fail counter) is zero.
module tb_isa_selftest;
    reg clk = 0;
    reg rst = 1;
    reg interrupt = 0;
    wire [31:0] pc_out;
    wire halt_out;

    risc_processor #(
        .IMEM_FILE("build/isa_selftest.hex"),
        .DMEM_FILE("")
    ) DUT (
        .clk(clk), .rst(rst), .interrupt(interrupt),
        .pc_out(pc_out), .halt_out(halt_out)
    );

    always #5 clk = ~clk;

    integer cycles = 0;
    initial begin
        repeat (3) @(posedge clk);
        rst = 0;

        while (!halt_out && cycles < 20000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!halt_out) begin
            $display("FAIL: self-test never halted (cycles=%0d, pc=%0d)", cycles, pc_out);
            $finish;
        end

        $display("Halted after %0d cycles.", cycles);
        $display("R9 (fail count) = %0d", DUT.REGFILE.regs[9]);
        $display("Mem[0]          = %0d", DUT.DMEM.mem[0]);

        if (DUT.REGFILE.regs[9] === 32'd0)
            $display("\n*** ISA SELF-TEST: ALL CHECKS PASSED ***");
        else
            $display("\n*** ISA SELF-TEST: %0d CHECK(S) FAILED ***", DUT.REGFILE.regs[9]);

        $finish;
    end
endmodule
