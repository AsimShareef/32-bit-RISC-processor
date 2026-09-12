`timescale 1ns / 1ps

// Runs programs/booth_mult.asm against a table of signed 16-bit
// (M, R) test vectors and checks R2 against an independently computed
// reference product ($signed multiply, not the DUT's bit-serial algorithm).
module tb_booth;
    reg clk = 0;
    reg rst = 1;
    reg interrupt = 0;
    wire [31:0] pc_out;
    wire halt_out;

    risc_processor #(
        .IMEM_FILE("build/booth_mult.hex"),
        .DMEM_FILE("")
    ) DUT (
        .clk(clk), .rst(rst), .interrupt(interrupt),
        .pc_out(pc_out), .halt_out(halt_out)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer i;
    integer cycles;

    // Signed 16-bit test vectors (M, R).
    localparam NCASES = 10;
    reg signed [15:0] mvals [0:NCASES-1];
    reg signed [15:0] rvals [0:NCASES-1];

    task run_case;
        input signed [15:0] m;
        input signed [15:0] r;
        reg signed [31:0] expected;
        begin
            expected = $signed(m) * $signed(r);

            // Drive reset, pre-load data memory, release reset.
            rst = 1;
            interrupt = 0;
            @(posedge clk);
            DUT.DMEM.mem[0] = {{16{m[15]}}, m};   // Mem[0] = M, sign-extended
            DUT.DMEM.mem[1] = {{16{r[15]}}, r};   // Mem[8] = R, sign-extended
            @(posedge clk);
            rst = 0;

            cycles = 0;
            while (!halt_out && cycles < 5000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end

            if (!halt_out) begin
                $display("FAIL: M=%0d R=%0d never halted", m, r);
                errors = errors + 1;
            end else if (DUT.REGFILE.regs[2] !== expected) begin
                $display("FAIL: M=%0d R=%0d  got R2=%0d (%h) expected=%0d (%h)",
                          m, r, $signed(DUT.REGFILE.regs[2]), DUT.REGFILE.regs[2],
                          expected, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: M=%0d R=%0d -> R2=%0d (%0d cycles)",
                          m, r, $signed(DUT.REGFILE.regs[2]), cycles);
            end
        end
    endtask

    initial begin
        mvals[0]=16'sd0;      rvals[0]=16'sd0;
        mvals[1]=16'sd1;      rvals[1]=16'sd1;
        mvals[2]=16'sd7;      rvals[2]=16'sd6;
        mvals[3]=-16'sd7;     rvals[3]=16'sd6;
        mvals[4]=16'sd7;      rvals[4]=-16'sd6;
        mvals[5]=-16'sd7;     rvals[5]=-16'sd6;
        mvals[6]=16'sd123;    rvals[6]=16'sd456;
        mvals[7]=-16'sd32768; rvals[7]=16'sd1;      // most negative * 1
        mvals[8]=-16'sd32768; rvals[8]=-16'sd32768; // most negative * most negative
        mvals[9]=16'sd32767;  rvals[9]=16'sd32767;  // most positive * most positive

        for (i = 0; i < NCASES; i = i + 1)
            run_case(mvals[i], rvals[i]);

        if (errors == 0) $display("\n*** ALL BOOTH TESTS PASSED (%0d cases) ***", NCASES);
        else              $display("\n*** %0d BOOTH TEST(S) FAILED ***", errors);
        $finish;
    end
endmodule
