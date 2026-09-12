`timescale 1ns / 1ps

// Runs programs/sum_5_to_1.asm (5+4+3+2+1=15) to completion and checks
// R1, R2 and Mem[0] against the expected result.
module tb_processor_sum;
    reg clk = 0;
    reg rst = 1;
    reg interrupt = 0;
    wire [31:0] pc_out;
    wire halt_out;

    risc_processor #(
        .IMEM_FILE("build/sum_5_to_1.hex"),
        .DMEM_FILE("")
    ) DUT (
        .clk(clk), .rst(rst), .interrupt(interrupt),
        .pc_out(pc_out), .halt_out(halt_out)
    );

    always #5 clk = ~clk;

    integer cycles = 0;
    initial begin
        $dumpfile("build/tb_processor_sum.vcd");
        $dumpvars(0, tb_processor_sum);

        repeat (3) @(posedge clk);
        rst = 0;

        while (!halt_out && cycles < 2000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (!halt_out) begin
            $display("FAIL: processor never halted (cycles=%0d)", cycles);
            $finish;
        end

        $display("Halted after %0d cycles. PC=%0d", cycles, pc_out);
        $display("R1 = %0d (expect 0)",  DUT.REGFILE.regs[1]);
        $display("R2 = %0d (expect 15)", DUT.REGFILE.regs[2]);
        $display("Mem[0] = %0d (expect 15)", DUT.DMEM.mem[0]);

        if (DUT.REGFILE.regs[1] === 32'd0 &&
            DUT.REGFILE.regs[2] === 32'd15 &&
            DUT.DMEM.mem[0]     === 32'd15)
            $display("\n*** SUM_5_TO_1 TEST PASSED ***");
        else
            $display("\n*** SUM_5_TO_1 TEST FAILED ***");

        $finish;
    end
endmodule
