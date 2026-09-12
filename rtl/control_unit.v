`timescale 1ns / 1ps

// Hardwired (combinational) decode of the opcode/func fields into every
// control signal the datapath needs. See docs/ISA.md for the full opcode
// table and the RTL micro-operation table this file implements.
module control_unit(
    input  wire [5:0] opcode,
    input  wire [3:0] func,

    output reg  [3:0] aluOp,     // function code fed to the ALU
    output reg         aluBSrc,   // 1 = ALU B operand is rt (register), 0 = immediate
    output reg         destIsRd,  // 1 = write-back register is rd, 0 = rt
    output reg         regWrite,  // this instruction writes a GPR
    output reg         memRead,   // this instruction reads data memory (LD/POP/RET)
    output reg         memWrite,  // this instruction writes data memory (ST/PUSH/CALL)
    output reg         memToReg,  // write-back value comes from data memory (LD/POP)
    output reg         isMove,    // rt <= rs
    output reg         isMovSp,   // rt <= SP
    output reg         isCmov,    // rd <= (rs < rt) ? rs : rt
    output reg         isPush,
    output reg         isPop,
    output reg         isCall,    // rs holds the (indirect) call target
    output reg         isRet,
    output reg         isHalt,
    output reg         isBranch,
    output reg  [1:0]  brType,    // 00 BR(uncond) 01 BMI 10 BPL 11 BZ
    output reg          immIs26    // 1 selects the 26-bit immediate (BR only)
);

    // ---- Opcode map (docs/ISA.md, Table 1) -------------------------------
    localparam OP_RTYPE = 6'h00; // func selects ALU op (0-14) or CMOV (15)
    localparam OP_ADDI  = 6'h01, OP_SUBI = 6'h02, OP_ANDI = 6'h03, OP_ORI  = 6'h04,
               OP_XORI  = 6'h05, OP_NORI = 6'h06, OP_SLLI = 6'h07, OP_SRLI = 6'h08,
               OP_SRAI  = 6'h09, OP_SLTI = 6'h0A, OP_SGTI = 6'h0B, OP_LUI  = 6'h0C,
               OP_LD    = 6'h0D, OP_ST   = 6'h0E, OP_MOVE = 6'h0F, OP_MOVSP= 6'h10,
               OP_PUSH  = 6'h11, OP_POP  = 6'h12, OP_BR   = 6'h13, OP_BMI  = 6'h14,
               OP_BPL   = 6'h15, OP_BZ   = 6'h16, OP_CALL = 6'h17, OP_RET  = 6'h18,
               OP_HALT  = 6'h19, OP_NOP  = 6'h1A;

    localparam ALU_ADD = 4'h0;
    localparam FUNC_CMOV = 4'hF; // reserved RR func code: compare-select, not an ALU op

    localparam BR_UNCOND = 2'b00, BR_MI = 2'b01, BR_PL = 2'b10, BR_Z = 2'b11;

    always @(*) begin
        // Safe defaults == NOP behaviour for any unrecognised opcode.
        aluOp    = ALU_ADD;
        aluBSrc  = 1'b0;
        destIsRd = 1'b0;
        regWrite = 1'b0;
        memRead  = 1'b0;
        memWrite = 1'b0;
        memToReg = 1'b0;
        isMove   = 1'b0;
        isMovSp  = 1'b0;
        isCmov   = 1'b0;
        isPush   = 1'b0;
        isPop    = 1'b0;
        isCall   = 1'b0;
        isRet    = 1'b0;
        isHalt   = 1'b0;
        isBranch = 1'b0;
        brType   = BR_UNCOND;
        immIs26  = 1'b0;

        case (opcode)
            OP_RTYPE: begin
                // Register-register ALU ops (Rd <= Rs op Rt) and CMOV share
                // this opcode; func disambiguates. Both write rd.
                if (func == FUNC_CMOV)
                    isCmov = 1'b1;
                else
                    aluOp  = func;
                aluBSrc  = 1'b1;
                destIsRd = 1'b1;
                regWrite = 1'b1;
            end

            OP_ADDI: begin aluOp = 4'h0; regWrite = 1'b1; end
            OP_SUBI: begin aluOp = 4'h1; regWrite = 1'b1; end
            OP_ANDI: begin aluOp = 4'h2; regWrite = 1'b1; end
            OP_ORI : begin aluOp = 4'h3; regWrite = 1'b1; end
            OP_XORI: begin aluOp = 4'h4; regWrite = 1'b1; end
            OP_NORI: begin aluOp = 4'h5; regWrite = 1'b1; end
            OP_SLLI: begin aluOp = 4'h7; regWrite = 1'b1; end
            OP_SRLI: begin aluOp = 4'h8; regWrite = 1'b1; end
            OP_SRAI: begin aluOp = 4'h9; regWrite = 1'b1; end
            OP_SLTI: begin aluOp = 4'hC; regWrite = 1'b1; end
            OP_SGTI: begin aluOp = 4'hD; regWrite = 1'b1; end
            OP_LUI : begin aluOp = 4'hF; regWrite = 1'b1; end

            OP_LD: begin
                aluOp    = ALU_ADD;   // effective address = rs + imm
                regWrite = 1'b1;
                memRead  = 1'b1;
                memToReg = 1'b1;
            end

            OP_ST: begin
                aluOp    = ALU_ADD;   // effective address = rs + imm
                memWrite = 1'b1;
            end

            OP_MOVE:  begin isMove  = 1'b1; regWrite = 1'b1; end
            OP_MOVSP: begin isMovSp = 1'b1; regWrite = 1'b1; end

            OP_PUSH: begin isPush = 1'b1; memWrite = 1'b1; end
            OP_POP : begin isPop  = 1'b1; regWrite = 1'b1; memRead = 1'b1; memToReg = 1'b1; end

            OP_BR : begin isBranch = 1'b1; brType = BR_UNCOND; immIs26 = 1'b1; end
            OP_BMI: begin isBranch = 1'b1; brType = BR_MI; end
            OP_BPL: begin isBranch = 1'b1; brType = BR_PL; end
            OP_BZ : begin isBranch = 1'b1; brType = BR_Z;  end

            OP_CALL: begin isCall = 1'b1; memWrite = 1'b1; end   // target = rs (indirect)
            OP_RET : begin isRet  = 1'b1; memRead  = 1'b1; end   // target = Mem[SP]

            OP_HALT: isHalt = 1'b1;
            OP_NOP : ; // no-op: all defaults already correct

            default: ; // undefined opcode behaves as NOP
        endcase
    end
endmodule
