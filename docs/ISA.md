# Instruction Set Architecture

32-bit instructions, 16 general-purpose registers `R0`-`R15` (`R0` hardwired
to 0), plus a separate 32-bit stack pointer `SP` (not part of the register
file). All five addressing modes required by the assignment are supported:

| Mode | Instructions |
|---|---|
| Register | RR-type ALU ops, CMOV |
| Immediate | RI-type ALU ops, LUI |
| Base (`Rb + offset`) | LD, ST |
| PC-relative | BR, BMI, BPL, BZ |
| Indirect (through a register) | CALL |

Data memory is byte-addressed but **every load/store address must be a
multiple of 8** (per the assignment spec) -- `data_memory.v` only decodes
`addr[AW+2:3]`, so the low 3 address bits are ignored in hardware exactly
as a real aligned-access-only memory would. PUSH/POP/CALL/RET therefore
move `SP` by 8, not 4.

## Instruction formats

```
R-type (opcode 0x00 only):
 31         26 25      21 20      16 15      11 10      5 4     0
[  opcode=0  ][   rs    ][   rt    ][   rd    ][ unused  ][ func ]

I-type (everything else with a register+immediate):
 31         26 25      21 20      16 15                        0
[   opcode   ][   rs    ][   rt    ][          imm16            ]

J-type (BR only):
 31         26 25                                              0
[   opcode   ][                   imm26                        ]
```

## Opcode table

| Opcode (hex) | Mnemonic | Format | Semantics |
|---|---|---|---|
| 0x00 | *R-type* | R | see func table below |
| 0x01 | ADDI  Rt, Rs, imm | I | `Rt <= Rs + sext(imm)` |
| 0x02 | SUBI  Rt, Rs, imm | I | `Rt <= Rs - sext(imm)` |
| 0x03 | ANDI  Rt, Rs, imm | I | `Rt <= Rs & sext(imm)` |
| 0x04 | ORI   Rt, Rs, imm | I | `Rt <= Rs \| sext(imm)` |
| 0x05 | XORI  Rt, Rs, imm | I | `Rt <= Rs ^ sext(imm)` |
| 0x06 | NORI  Rt, Rs, imm | I | `Rt <= ~(Rs \| sext(imm))` |
| 0x07 | SLLI/SLAI Rt, Rs, imm | I | `Rt <= Rs << imm[4:0]` |
| 0x08 | SRLI  Rt, Rs, imm | I | `Rt <= Rs >> imm[4:0]` (logical) |
| 0x09 | SRAI  Rt, Rs, imm | I | `Rt <= Rs >>> imm[4:0]` (arithmetic) |
| 0x0A | SLTI  Rt, Rs, imm | I | `Rt <= (Rs < sext(imm)) ? 1 : 0` (signed) |
| 0x0B | SGTI  Rt, Rs, imm | I | `Rt <= (Rs > sext(imm)) ? 1 : 0` (signed) |
| 0x0C | LUI   Rt, imm     | I | `Rt <= {imm[15:0], 16'b0}` |
| 0x0D | LD    Rt, imm(Rs) | I | `Rt <= Mem[Rs + sext(imm)]` |
| 0x0E | ST    Rt, imm(Rs) | I | `Mem[Rs + sext(imm)] <= Rt` |
| 0x0F | MOVE  Rt, Rs      | I | `Rt <= Rs` |
| 0x10 | MOVE  Rt, SP      | I | `Rt <= SP` (assembler emits this opcode for `MOVE Rt,SP`) |
| 0x11 | PUSH  Rs          | I | `Mem[SP-8] <= Rs ; SP <= SP - 8` |
| 0x12 | POP   Rt          | I | `Rt <= Mem[SP] ; SP <= SP + 8` |
| 0x13 | BR    imm26       | J | `PC <= PC + 4 + sext(imm26)` (unconditional) |
| 0x14 | BMI   Rs, imm     | I | `if (Rs < 0)  PC <= PC + 4 + sext(imm)` |
| 0x15 | BPL   Rs, imm     | I | `if (Rs > 0)  PC <= PC + 4 + sext(imm)` |
| 0x16 | BZ    Rs, imm     | I | `if (Rs == 0) PC <= PC + 4 + sext(imm)` |
| 0x17 | CALL  Rs          | I | `Mem[SP-8] <= PC+4 ; SP <= SP-8 ; PC <= Rs` (indirect) |
| 0x18 | RET               | I | `PC <= Mem[SP] ; SP <= SP + 8` |
| 0x19 | HALT              | I | freeze PC; resume on `interrupt` pulse (next instr) or reset |
| 0x1A | NOP               | I | no operation |

## R-type `func` table (opcode 0x00)

| func (hex) | Mnemonic | `RES` |
|---|---|---|
| 0x0 | ADD  Rd,Rs,Rt | `Rs + Rt` |
| 0x1 | SUB  Rd,Rs,Rt | `Rs - Rt` |
| 0x2 | AND  Rd,Rs,Rt | `Rs & Rt` |
| 0x3 | OR   Rd,Rs,Rt | `Rs \| Rt` |
| 0x4 | XOR  Rd,Rs,Rt | `Rs ^ Rt` |
| 0x5 | NOR  Rd,Rs,Rt | `~(Rs \| Rt)` |
| 0x6 | NOT  Rd,Rs    | `~Rs` |
| 0x7 | SL/SLA Rd,Rs,Rt | `Rs << Rt[4:0]` |
| 0x8 | SRL  Rd,Rs,Rt | `Rs >> Rt[4:0]` |
| 0x9 | SRA  Rd,Rs,Rt | `Rs >>> Rt[4:0]` |
| 0xA | INC  Rd,Rs    | `Rs + 1` |
| 0xB | DEC  Rd,Rs    | `Rs - 1` |
| 0xC | SLT  Rd,Rs,Rt | `(Rs < Rt) ? 1 : 0` (signed) |
| 0xD | SGT  Rd,Rs,Rt | `(Rs > Rt) ? 1 : 0` (signed) |
| 0xE | HAM  Rd,Rs    | population count of `Rs` |
| 0xF | *(reserved)* | decoded as CMOV, see below |

`CMOV Rd, Rs, Rt` uses opcode 0x00 with func=0xF: `Rd <= (Rs < Rt) ? Rs : Rt`
(signed compare-select, per the spec's definition).

All R-type instructions write `Rd`. All I-type register-writing
instructions write `Rt`.

## Design decisions worth calling out

- **Why not derive `aluOp` arithmetically from the opcode (as the original,
  incomplete version of this project did)?** The original `control_unit.v`
  set `aluOp = opcode[3:0]` for every immediate ALU instruction, which
  collided with opcode `0x00` (RR-type) and left `ADD` with no immediate
  form at all -- `ADDI`, used in every sample program in the assignment,
  could not be encoded. Each opcode now gets an explicit case arm, like a
  real control ROM / microcode table, which is also what the "RTL
  micro-operations" deliverable in the assignment is asking for.
- **Why does `CALL` take a register, not an immediate?** The spec lists
  "indirect addressing" as a required mode but nothing in the original code
  used it. `CALL Rs` (jump to the address held in `Rs`) is the natural home
  for it, and sidesteps a real bug in the original code where `CALL` used
  an un-shifted, 16-bit-only immediate as an absolute jump target.
- **Why sign-extend `BR`'s offset instead of zero-extending it (as the
  original `imm_gen.v` did)?** Zero-extension meant `BR` could only ever
  jump forward; any backward branch (e.g. the bottom of a loop written with
  `BR` instead of a conditional branch) silently produced the wrong target.
- **Why does `HALT` respond to an `interrupt` pin, and why does the FPGA
  wrapper still work with a single reset button?** The main assignment
  defines `HALT` as "waits for an interrupt on input pin INT"; a later
  addendum instead wants `HALT` to freeze until a manual reset for the
  demo. Both are satisfied by the same behaviour: `HALT` freezes the PC and
  waits for *either* signal -- an `interrupt` pulse resumes execution at the
  next instruction, a `reset` restarts the whole program from `PC=0`.
