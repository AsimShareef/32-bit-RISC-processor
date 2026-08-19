`timescale 1ns / 1ps

module risc_processor(
    input  wire        clk,
    input  wire        rst,
    input  wire        interrupt,
    output wire [31:0] pc_out,
    output wire        halt_out
);

    // IMEM wire and latched instruction register
    wire [31:0] imem_insn;         // direct BRAM output (synchronous inside BRAM)
    reg  [31:0] inst_reg;          // latched instruction (used by decode/execute)

    // decode fields MUST come from inst_reg (latched)
    wire [5:0]  opcode = inst_reg[31:26];
    wire [4:0]  rs     = inst_reg[25:21];
    wire [4:0]  rt     = inst_reg[20:16];
    wire [4:0]  rd     = inst_reg[15:11];
    wire [15:0] imm16  = inst_reg[15:0];
    wire [25:0] imm26  = inst_reg[25:0];
    wire [4:0]  func   = inst_reg[4:0];

    // control, regs, ALU etc (same as yours)
    wire [3:0]  aluOp;
    wire [2:0]  brOp;
    wire        aluSrc, regAluOut, rdMem, wrMem, wrReg;
    wire        mToReg, immSel, isCmov, isPush, isPop;
    wire        isCall, isRet, isHalt, pcSrc;

    wire [31:0] pc, pc_plus_4, pc_next, pc_branch;
    wire [31:0] imm_extended;
    wire [31:0] rs_data, rt_data, reg_write_data;
    wire [31:0] alu_in_a, alu_in_b, alu_result;
    wire [31:0] mem_read_data;
    wire        branch_taken;
    wire [31:0] sp_addr;
    wire        sp_update;

    assign pc_plus_4 = pc + 4;
    assign pc_branch = pc_plus_4 + imm_extended;
    assign pc_next   = (isRet) ? mem_read_data :
                       (isCall) ? imm_extended :
                       (pcSrc && branch_taken) ? pc_branch : pc_plus_4;

    // Program counter module - unchanged, produces 'pc' on its output
    program_counter PC(
        .clk(clk),
        .rst(rst),
        .halt(isHalt),
        .pc_write(1'b1),
        .pc_next(pc_next),
        .pc(pc)
    );

    // ---------------------------------------------------------
    // KEY FIX: present pc_next to IMEM so memory reads next insn
    // in parallel with the current instruction's execution.
    // Also latch IMEM synchronous output into inst_reg.
    // ---------------------------------------------------------
    // pipeline register that goes to IMEM address input
    reg [31:0] pc_for_imem;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_for_imem <= 32'd0;
        end else begin
            // present next PC to IMEM immediately (prefetch)
            pc_for_imem <= pc_next;
        end
    end

    // IMEM: use pc_for_imem as the address
    instruction_memory IMEM(
        .clk(clk),
        .addr(pc_for_imem),
        .insn(imem_insn)
    );

    // Latch IMEM output (imem_insn) into inst_reg - one-cycle sync latency
    // This register holds the instruction to be decoded/executed this cycle.
    always @(posedge clk or posedge rst) begin
        if (rst) inst_reg <= 32'd0;
        else      inst_reg <= imem_insn;
    end

    // Remaining modules use inst_reg (as declared earlier)
    control_unit CTRL(
        .opcode(opcode),
        .func(func),
        .aluOp(aluOp),
        .brOp(brOp),
        .aluSrc(aluSrc),
        .regAluOut(regAluOut),
        .rdMem(rdMem),
        .wrMem(wrMem),
        .wrReg(wrReg),
        .mToReg(mToReg),
        .immSel(immSel),
        .isCmov(isCmov),
        .isPush(isPush),
        .isPop(isPop),
        .isCall(isCall),
        .isRet(isRet),
        .isHalt(isHalt),
        .pcSrc(pcSrc)
    );

    imm_gen IMM_GEN(
        .instruction(inst_reg),
        .immSel(immSel),
        .imm_out(imm_extended)
    );

    wire [3:0] reg_write_addr = regAluOut ? rd[3:0] : rt[3:0];

    regfile16x32 REGFILE(
        .clk(clk),
        .rst(rst),
        .we(wrReg && (!isCmov || (isCmov && rt_data != 0))),
        .waddr(reg_write_addr),
        .raddr1(rs[3:0]),
        .raddr2(rt[3:0]),
        .wdata(reg_write_data),
        .rdata1(rs_data),
        .rdata2(rt_data)
    );

    assign alu_in_a = rs_data;
    assign alu_in_b = aluSrc ? rt_data : imm_extended;

    ALU #(.N(32)) ALU_UNIT(
        .func(aluOp),
        .A(alu_in_a),
        .B(alu_in_b),
        .RES(alu_result)
    );

    // data address selection (stack ops may alter address)
    wire [31:0] data_addr = (isPush || isCall) ? (sp_addr - 4) :
                            (isPop || isRet) ? sp_addr :
                            alu_result;

    data_memory DMEM(
        .clk(clk),
        .we(wrMem),
        .re(rdMem),
        .addr(data_addr),
        .wdata(isPush ? rs_data : (isCall ? pc_plus_4 : rt_data)),
        .rdata(mem_read_data)
    );

    stack_pointer SP(
        .clk(clk),
        .rst(rst),
        .isPush(isPush),
        .isPop(isPop),
        .isCall(isCall),
        .isRet(isRet),
        .sp_addr(sp_addr),
        .sp_update(sp_update)
    );

    branch_unit BR_UNIT(
        .rs_data(rs_data),
        .brOp(brOp),
        .branch_taken(branch_taken)
    );

    assign reg_write_data = mToReg ? mem_read_data : alu_result;

    assign pc_out   = pc;
    assign halt_out = isHalt;

endmodule
