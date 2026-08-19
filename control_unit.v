module control_unit(
    input wire [5:0] opcode,
    input wire [4:0] func,
    output reg [3:0] aluOp,
    output reg [2:0] brOp,
    output reg aluSrc,
    output reg regAluOut,
    output reg rdMem,
    output reg wrMem,
    output reg wrReg,
    output reg mToReg,
    output reg immSel,
    output reg isCmov,
    output reg isPush,
    output reg isPop,
    output reg isCall,
    output reg isRet,
    output reg isHalt,
    output reg pcSrc
);

    always @(*) begin
        // Output defaults - safe start!
        aluOp     = 5'b00000;
        brOp      = 3'b100;
        aluSrc    = 1'b0;
        regAluOut = 1'b0;
        rdMem     = 1'b0;
        wrMem     = 1'b0;
        wrReg     = 1'b0;
        mToReg    = 1'b0;
        immSel    = 1'b0;
        isCmov    = 1'b0;
        isPush    = 1'b0;
        isPop     = 1'b0;
        isCall    = 1'b0;
        isRet     = 1'b0;
        isHalt    = 1'b0;
        pcSrc     = 1'b0;

        case (opcode)
            6'b000000: begin // Register-Register ALU
                aluOp = func[3:0];
                aluSrc = 1'b1;      // Register source
                regAluOut = 1'b1;
                wrReg = 1'b1;
            end

            6'b000001, 6'b000010, 6'b000011, 6'b000100,
            6'b000101, 6'b000110, 6'b000111, 6'b001000,
            6'b001001, 6'b001010, 6'b001011, 6'b001100,
            6'b001101, 6'b001110, 6'b001111: begin // Register-Immediate ALU
                aluOp = opcode[3:0];
                aluSrc = 1'b0;      // Immediate source
                regAluOut = 1'b0;
                wrReg = 1'b1;
            end

            6'b010000: begin // LUI
                aluOp = 4'b1111;
                aluSrc = 1'b0;
                regAluOut = 1'b0;
                wrReg = 1'b1;
            end

            6'b010001: begin // LD (Load)
                aluOp = 4'b0000;    // ADD for address
                aluSrc = 1'b0;
                regAluOut = 1'b0;
                rdMem = 1'b1;
                wrReg = 1'b1;
                mToReg = 1'b1;
            end

            6'b010010: begin // ST (Store)
                aluOp = 4'b0000;
                aluSrc = 1'b0;
                wrMem = 1'b1;
            end

            6'b010011: begin // PUSH
                aluOp = 4'b0000;
                wrMem = 1'b1;
                isPush = 1'b1;
            end

            6'b010100: begin // POP
                aluOp = 4'b0000;
                rdMem = 1'b1;
                wrReg = 1'b1;
                mToReg = 1'b1;
                isPop = 1'b1;
                regAluOut = 1'b0;
            end

            6'b010101: begin // CMOV
                aluOp = 4'b0000;
                aluSrc = 1'b1;
                regAluOut = 1'b1;
                wrReg = 1'b1;
                isCmov = 1'b1;
            end

            6'b100000: begin // BR (Branch)
                brOp = 3'b000;
                immSel = 1'b1;
                pcSrc = 1'b1;
            end
            
            6'b100001: begin // BMI (Branch if Minus)
                brOp = 3'b001;
                immSel = 1'b0;
                pcSrc = 1'b1;
            end
            
            6'b100010: begin // BPL (Branch if Plus)
                brOp = 3'b010;
                immSel = 1'b0;
                pcSrc = 1'b1;
            end
            
            6'b100011: begin // BZ (Branch if Zero)
                brOp = 3'b011;
                immSel = 1'b0;
                pcSrc = 1'b1;
            end
            
            6'b100100: begin // HALT
                isHalt = 1'b1;
            end
            
            6'b100101: begin // NOP
                // No change, keep defaults
            end
            
            6'b100110: begin // CALL
                isCall = 1'b1;
                wrMem = 1'b1;
                pcSrc = 1'b1;
            end
            
            6'b100111: begin // RET
                isRet = 1'b1;
                rdMem = 1'b1;
                pcSrc = 1'b1;
            end
            
            default: begin
                // No change, keep defaults
            end
        endcase

        // Simulation-time debug (remove/comment for final FPGA synthesis)
        $display("[%0t] CTRL - opcode=%b func=%b aluOp=%b wrReg=%b wrMem=%b rdMem=%b",
             $time, opcode, func, aluOp, wrReg, wrMem, rdMem);
    end
endmodule
