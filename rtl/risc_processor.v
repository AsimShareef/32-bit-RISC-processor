`timescale 1ns / 1ps

// Top-level 32-bit multicycle RISC processor.
//
// Control is a small behavioural FSM (FETCH -> EXECUTE -> [MEMORY] ->
// FETCH, with a HALT state that waits for an interrupt or reset), as
// required by the lab spec's "Implementing the control path using
// behavioural FSM design" step. Instruction and data memory both use a
// registered (one-cycle-latency) read, matching how the BRAM they infer
// on real hardware behaves -- see rtl/instruction_memory.v and
// rtl/data_memory.v for why that shape was chosen instead of the
// combinational-read register array the assignment explicitly forbids.
//
// FSM states:
//   S_FETCH  - pc is already the address of the instruction to fetch
//              (set on the way INTO this state); imem's internal address
//              register samples it now, so the instruction word is valid
//              one cycle later.
//   S_EXECUTE- imem_insn now holds the instruction. Registers are read,
//              the ALU/branch/compare logic runs, and (for instructions
//              that need no data-memory read) results are written back
//              and pc/SP advance on the way out of this state.
//   S_MEMORY - entered only for LD / POP / RET, which issued a data-memory
//              read address during EXECUTE; that read's registered result
//              is valid now, so write-back and PC update (RET's target is
//              the loaded word) happen on the way out of this state.
//   S_HALT   - entered on a HALT instruction. pc is frozen. Deasserting
//              is either a reset, or a pulse on `interrupt` (per the main
//              assignment: "HALT waits for an interrupt on input pin
//              INT"), which resumes at the instruction after HALT.
module risc_processor #(
    parameter IMEM_FILE = "",   // $readmemh file for instruction ROM (optional)
    parameter DMEM_FILE = ""    // $readmemh file for data RAM (optional)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        interrupt,
    input  wire [3:0]  dbg_raddr,   // observational register read (board LED display)
    output wire [31:0] dbg_rdata,
    output wire [31:0] pc_out,
    output wire         halt_out
);

    localparam S_FETCH = 2'd0, S_EXECUTE = 2'd1, S_MEMORY = 2'd2, S_HALT = 2'd3;
    reg [1:0] state;

    // ---------------------------------------------------------------
    // Program counter + instruction fetch
    // ---------------------------------------------------------------
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire        pc_write;

    program_counter PC (
        .clk(clk), .rst(rst),
        .pc_write(pc_write),
        .pc_next(pc_next),
        .pc(pc)
    );

    wire [31:0] imem_insn;
    instruction_memory #(.DEPTH(256), .INIT_FILE(IMEM_FILE)) IMEM (
        .clk(clk), .addr(pc), .insn(imem_insn)
    );

    // Decode fields (valid while state is EXECUTE/MEMORY/HALT; imem_insn
    // is still the previous instruction while state==FETCH, but nothing
    // acts on the decode outputs during FETCH, so that is harmless).
    wire [31:0] ir     = imem_insn;
    wire [5:0]  opcode = ir[31:26];
    wire [4:0]  rs     = ir[25:21];
    wire [4:0]  rt     = ir[20:16];
    wire [4:0]  rd     = ir[15:11];
    wire [3:0]  func   = ir[3:0];

    // ---------------------------------------------------------------
    // Control
    // ---------------------------------------------------------------
    wire [3:0] aluOp;
    wire       aluBSrc, destIsRd, regWrite, memRead, memWrite, memToReg;
    wire       isMove, isMovSp, isCmov, isPush, isPop, isCall, isRet, isHalt;
    wire       isBranch, immIs26;
    wire [1:0] brType;

    control_unit CTRL (
        .opcode(opcode), .func(func),
        .aluOp(aluOp), .aluBSrc(aluBSrc), .destIsRd(destIsRd),
        .regWrite(regWrite), .memRead(memRead), .memWrite(memWrite), .memToReg(memToReg),
        .isMove(isMove), .isMovSp(isMovSp), .isCmov(isCmov),
        .isPush(isPush), .isPop(isPop), .isCall(isCall), .isRet(isRet), .isHalt(isHalt),
        .isBranch(isBranch), .brType(brType), .immIs26(immIs26)
    );

    wire [31:0] imm_extended;
    imm_gen IMM_GEN (.instruction(ir), .imm26(immIs26), .imm_out(imm_extended));

    // ---------------------------------------------------------------
    // Register file + ALU
    // ---------------------------------------------------------------
    wire [31:0] rs_data, rt_data;
    wire [31:0] reg_write_data;
    wire [3:0]  reg_write_addr = destIsRd ? rd[3:0] : rt[3:0];

    regfile16x32 REGFILE (
        .clk(clk), .rst(rst),
        .we(regfile_we),
        .waddr(reg_write_addr),
        .raddr1(rs[3:0]), .raddr2(rt[3:0]), .raddr3(dbg_raddr),
        .wdata(reg_write_data),
        .rdata1(rs_data), .rdata2(rt_data), .rdata3(dbg_rdata)
    );

    wire [31:0] alu_in_b = aluBSrc ? rt_data : imm_extended;
    wire [31:0] alu_result;
    alu #(.N(32)) ALU_UNIT (.func(aluOp), .A(rs_data), .B(alu_in_b), .RES(alu_result));

    wire [31:0] cmov_result = ($signed(rs_data) < $signed(rt_data)) ? rs_data : rt_data;

    // ---------------------------------------------------------------
    // Branch resolution
    // ---------------------------------------------------------------
    wire branch_taken;
    branch_unit BR_UNIT (.rs_data(rs_data), .brType(brType), .branch_taken(branch_taken));

    wire [31:0] pc_plus4  = pc + 32'd4;
    wire [31:0] pc_branch = pc_plus4 + imm_extended;

    // ---------------------------------------------------------------
    // Data memory + stack pointer
    // ---------------------------------------------------------------
    wire [31:0] sp;
    wire sp_touch = (isPush || isPop || isCall || isRet) && (state == S_EXECUTE);

    stack_pointer SP_UNIT (
        .clk(clk), .rst(rst),
        .push_or_call(sp_touch && (isPush || isCall)),
        .pop_or_ret(sp_touch && (isPop || isRet)),
        .sp(sp)
    );

    wire [31:0] data_addr =
        (isPush || isCall) ? (sp - 32'd8) :
        (isPop  || isRet ) ?  sp          :
                               alu_result;   // LD/ST: rs + imm

    wire [31:0] data_wdata =
        isPush ? rs_data :
        isCall ? pc_plus4 :
                 rt_data;   // ST

    wire [31:0] mem_read_data;
    wire dmem_we = memWrite && (state == S_EXECUTE);

    data_memory #(.DEPTH(256), .INIT_FILE(DMEM_FILE)) DMEM (
        .clk(clk), .we(dmem_we), .addr(data_addr), .wdata(data_wdata), .rdata(mem_read_data)
    );

    // ---------------------------------------------------------------
    // Write-back mux
    // ---------------------------------------------------------------
    assign reg_write_data =
        memToReg ? mem_read_data :
        isMove   ? rs_data       :
        isMovSp  ? sp            :
        isCmov   ? cmov_result   :
                   alu_result;

    wire regfile_we = regWrite && ((state == S_EXECUTE && !memRead) || (state == S_MEMORY));

    // ---------------------------------------------------------------
    // Next-PC selection and FSM
    // ---------------------------------------------------------------
    assign pc_next =
        isRet                      ? mem_read_data :
        isCall                     ? rs_data        :
        (isBranch && branch_taken) ? pc_branch       :
                                      pc_plus4;

    assign pc_write = (state == S_EXECUTE && !memRead) ||
                       (state == S_MEMORY) ||
                       (state == S_HALT && interrupt);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_FETCH;
        end else begin
            case (state)
                S_FETCH:   state <= S_EXECUTE;
                S_EXECUTE: state <= isHalt   ? S_HALT :
                                     memRead  ? S_MEMORY :
                                                S_FETCH;
                S_MEMORY:  state <= S_FETCH;
                S_HALT:    state <= interrupt ? S_FETCH : S_HALT;
                default:   state <= S_FETCH;
            endcase
        end
    end

    assign pc_out   = pc;
    assign halt_out = (state == S_HALT);

endmodule
