`timescale 1ns / 1ps

// Runs programs/hamming_weight.asm against a table of 5-word arrays and
// checks R3 against an independently computed reference popcount sum.
module tb_hamming;
    reg clk = 0;
    reg rst = 1;
    reg interrupt = 0;
    wire [31:0] pc_out;
    wire halt_out;

    risc_processor #(
        .IMEM_FILE("build/hamming_weight.hex"),
        .DMEM_FILE("")
    ) DUT (
        .clk(clk), .rst(rst), .interrupt(interrupt),
        .pc_out(pc_out), .halt_out(halt_out)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer i, w;
    integer cycles;

    function integer popcount_ref;
        input [31:0] v;
        integer k;
        begin
            popcount_ref = 0;
            for (k = 0; k < 32; k = k + 1)
                popcount_ref = popcount_ref + v[k];
        end
    endfunction

    localparam NCASES = 4;
    reg [31:0] arrays [0:NCASES-1][0:4];

    task run_case;
        input [31:0] w0, w1, w2, w3, w4;
        integer expected;
        begin
            expected = popcount_ref(w0) + popcount_ref(w1) + popcount_ref(w2) +
                       popcount_ref(w3) + popcount_ref(w4);

            rst = 1;
            interrupt = 0;
            @(posedge clk);
            // Mem[24],[32],[40],[48],[56] -> word indices 3,4,5,6,7 (8-byte granular).
            DUT.DMEM.mem[3] = w0;
            DUT.DMEM.mem[4] = w1;
            DUT.DMEM.mem[5] = w2;
            DUT.DMEM.mem[6] = w3;
            DUT.DMEM.mem[7] = w4;
            @(posedge clk);
            rst = 0;

            cycles = 0;
            while (!halt_out && cycles < 2000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (!halt_out) begin
                $display("FAIL: never halted");
                errors = errors + 1;
            end else if (DUT.REGFILE.regs[3] !== expected) begin
                $display("FAIL: got R3=%0d expected=%0d (words=%h,%h,%h,%h,%h)",
                          DUT.REGFILE.regs[3], expected, w0, w1, w2, w3, w4);
                errors = errors + 1;
            end else begin
                $display("PASS: R3=%0d (%0d cycles)  words=%h,%h,%h,%h,%h",
                          DUT.REGFILE.regs[3], cycles, w0, w1, w2, w3, w4);
            end
        end
    endtask

    initial begin
        run_case(32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000); // 0
        run_case(32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF); // 160
        run_case(32'h00000001, 32'h00000003, 32'h00000007, 32'h0000000F, 32'h0000001F); // 1+2+3+4+5=15
        run_case(32'hDEADBEEF, 32'hCAFEBABE, 32'h12345678, 32'h9ABCDEF0, 32'h00000000);

        if (errors == 0) $display("\n*** ALL HAMMING TESTS PASSED ***");
        else              $display("\n*** %0d HAMMING TEST(S) FAILED ***", errors);
        $finish;
    end
endmodule
