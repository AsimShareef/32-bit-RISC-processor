#!/usr/bin/env python3
"""
A small two-pass assembler for the 32-bit RISC ISA in docs/ISA.md.

Usage:
    python assemble.py program.asm --hex out.hex --coe out.coe [--listing out.lst]

Output formats:
    .hex  - one 8-hex-digit word per line, for Verilog $readmemh
            (used directly by the Icarus Verilog testbenches)
    .coe  - Xilinx Block Memory Generator COE format
            (MEMORY_INITIALIZATION_RADIX=16; ... ;), for Vivado IP Catalog

This exists because hand-assembling machine code (as the original,
incomplete version of this project's program.txt/ham.txt were) is
extremely easy to get wrong -- and in fact those two files turned out to
use opcodes the processor's control unit never decoded. Every program
shipped in programs/ is produced by this assembler and cross-checked by
simulation, not hand-encoded.
"""
import argparse
import re
import sys

REGISTERS = {f"R{i}": i for i in range(16)}

# --- Opcode / func tables (must match rtl/control_unit.v exactly) ---------

OPCODES = {
    "ADDI": 0x01, "SUBI": 0x02, "ANDI": 0x03, "ORI": 0x04, "XORI": 0x05,
    "NORI": 0x06, "SLLI": 0x07, "SLAI": 0x07, "SRLI": 0x08, "SRAI": 0x09,
    "SLTI": 0x0A, "SGTI": 0x0B, "LUI": 0x0C, "LD": 0x0D, "ST": 0x0E,
    "PUSH": 0x11, "POP": 0x12, "BR": 0x13, "BMI": 0x14, "BPL": 0x15,
    "BZ": 0x16, "CALL": 0x17, "RET": 0x18, "HALT": 0x19, "NOP": 0x1A,
}
# MOVE is special-cased: opcode 0x0F (Rt<-Rs) or 0x10 (Rt<-SP)
MOVE_REG_OPCODE = 0x0F
MOVE_SP_OPCODE = 0x10
RTYPE_OPCODE = 0x00

FUNCS = {
    "ADD": 0x0, "SUB": 0x1, "AND": 0x2, "OR": 0x3, "XOR": 0x4, "NOR": 0x5,
    "NOT": 0x6, "SL": 0x7, "SLA": 0x7, "SLL": 0x7, "SRL": 0x8, "SRA": 0x9,
    "INC": 0xA, "DEC": 0xB, "SLT": 0xC, "SGT": 0xD, "HAM": 0xE, "CMOV": 0xF,
}
RTYPE_UNARY = {"NOT", "INC", "DEC", "HAM"}
ITYPE_3OP = {"ADDI", "SUBI", "ANDI", "ORI", "XORI", "NORI",
             "SLLI", "SLAI", "SRLI", "SRAI", "SLTI", "SGTI"}


class AsmError(Exception):
    pass


def strip_comment(line):
    for marker in (";", "//", "#"):
        idx = line.find(marker)
        if idx != -1:
            line = line[:idx]
    return line.strip()


def tokenize_operands(text):
    """Split 'Rt, imm(Rs)' style operand lists into a flat token list."""
    text = text.replace("(", ", ").replace(")", "")
    parts = [p.strip() for p in text.split(",")]
    return [p for p in parts if p != ""]


def parse_reg(tok):
    tok = tok.upper()
    if tok not in REGISTERS:
        raise AsmError(f"expected register, got '{tok}'")
    return REGISTERS[tok]


def parse_imm(tok, labels, here, bits, is_pc_relative):
    tok = tok.strip()
    if tok.upper() in labels:
        target = labels[tok.upper()]
        val = target - (here + 4) if is_pc_relative else target
    else:
        val = int(tok, 0)
    # Accept either the signed view (e.g. -1) or the raw-bit-pattern/unsigned
    # view (e.g. 0xBEEF) of the field -- both are legal ways to write a
    # 16-/26-bit immediate, since the hardware always sign-extends whatever
    # bit pattern ends up in the field regardless of how it was written.
    lo, hi = -(1 << (bits - 1)), (1 << bits) - 1
    if not (lo <= val <= hi):
        raise AsmError(f"immediate {val} out of range for {bits}-bit field "
                        f"[{lo},{hi}] (token '{tok}')")
    return val & ((1 << bits) - 1)


def encode_r(opcode, rs, rt, rd, func):
    return (opcode << 26) | (rs << 21) | (rt << 16) | (rd << 11) | (func & 0xF)


def encode_i(opcode, rs, rt, imm16):
    return (opcode << 26) | (rs << 21) | (rt << 16) | (imm16 & 0xFFFF)


def encode_j(opcode, imm26):
    return (opcode << 26) | (imm26 & 0x3FFFFFF)


def first_pass(lines):
    """Collect label -> address, and the list of (address, mnemonic, operand_text)."""
    labels = {}
    instrs = []
    addr = 0
    for raw in lines:
        line = strip_comment(raw)
        if not line:
            continue
        while ":" in line:
            label, _, rest = line.partition(":")
            labels[label.strip().upper()] = addr
            line = rest.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        mnem = parts[0].upper()
        operand_text = parts[1] if len(parts) > 1 else ""
        instrs.append((addr, mnem, operand_text))
        addr += 4
    return labels, instrs


def assemble(lines):
    labels, instrs = first_pass(lines)
    words = []
    listing = []

    for addr, mnem, operand_text in instrs:
        ops = tokenize_operands(operand_text)

        if mnem == "RET" or mnem == "HALT" or mnem == "NOP":
            word = encode_i(OPCODES[mnem], 0, 0, 0)

        elif mnem == "CALL":
            rs = parse_reg(ops[0])
            word = encode_i(OPCODES["CALL"], rs, 0, 0)

        elif mnem == "PUSH":
            rs = parse_reg(ops[0])
            word = encode_i(OPCODES["PUSH"], rs, 0, 0)

        elif mnem == "POP":
            rt = parse_reg(ops[0])
            word = encode_i(OPCODES["POP"], 0, rt, 0)

        elif mnem == "MOVE":
            rt = parse_reg(ops[0])
            if ops[1].strip().upper() == "SP":
                word = encode_i(MOVE_SP_OPCODE, 0, rt, 0)
            else:
                rs = parse_reg(ops[1])
                word = encode_i(MOVE_REG_OPCODE, rs, rt, 0)

        elif mnem == "LUI":
            rt = parse_reg(ops[0])
            imm = parse_imm(ops[1], labels, addr, 16, is_pc_relative=False)
            word = encode_i(OPCODES["LUI"], 0, rt, imm)

        elif mnem in ("LD", "ST"):
            rt = parse_reg(ops[0])
            imm = parse_imm(ops[1], labels, addr, 16, is_pc_relative=False)
            rs = parse_reg(ops[2])
            word = encode_i(OPCODES[mnem], rs, rt, imm)

        elif mnem == "BR":
            imm = parse_imm(ops[0], labels, addr, 26, is_pc_relative=True)
            word = encode_j(OPCODES["BR"], imm)

        elif mnem in ("BMI", "BPL", "BZ"):
            rs = parse_reg(ops[0])
            imm = parse_imm(ops[1], labels, addr, 16, is_pc_relative=True)
            word = encode_i(OPCODES[mnem], rs, 0, imm)

        elif mnem in ITYPE_3OP:
            rt = parse_reg(ops[0])
            rs = parse_reg(ops[1])
            imm = parse_imm(ops[2], labels, addr, 16, is_pc_relative=False)
            word = encode_i(OPCODES[mnem], rs, rt, imm)

        elif mnem == "CMOV":
            rd = parse_reg(ops[0])
            rs = parse_reg(ops[1])
            rt = parse_reg(ops[2])
            word = encode_r(RTYPE_OPCODE, rs, rt, rd, FUNCS["CMOV"])

        elif mnem in FUNCS:  # R-type ALU op
            if mnem in RTYPE_UNARY:
                rd = parse_reg(ops[0])
                rs = parse_reg(ops[1])
                rt = 0
            else:
                rd = parse_reg(ops[0])
                rs = parse_reg(ops[1])
                rt = parse_reg(ops[2])
            word = encode_r(RTYPE_OPCODE, rs, rt, rd, FUNCS[mnem])

        else:
            raise AsmError(f"unknown mnemonic '{mnem}' at address {addr:#x}")

        words.append(word)
        listing.append((addr, word, mnem, operand_text))

    return words, listing, labels


def write_hex(words, path):
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w:08X}\n")


def write_coe(words, path):
    with open(path, "w") as f:
        f.write("MEMORY_INITIALIZATION_RADIX = 16;\n")
        f.write("MEMORY_INITIALIZATION_VECTOR =\n")
        f.write(",\n".join(f"{w:08X}" for w in words))
        f.write(";\n")


def write_listing(listing, labels, path):
    with open(path, "w") as f:
        rev_labels = {}
        for name, a in labels.items():
            rev_labels.setdefault(a, []).append(name)
        for addr, word, mnem, operand_text in listing:
            tag = " ".join(rev_labels.get(addr, []))
            f.write(f"{addr:04X}  {word:08X}  {mnem} {operand_text:<20} {tag}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--hex", default=None)
    ap.add_argument("--coe", default=None)
    ap.add_argument("--listing", default=None)
    args = ap.parse_args()

    with open(args.source) as f:
        lines = f.readlines()

    try:
        words, listing, labels = assemble(lines)
    except AsmError as e:
        print(f"assemble error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.hex:
        write_hex(words, args.hex)
    if args.coe:
        write_coe(words, args.coe)
    if args.listing:
        write_listing(listing, labels, args.listing)

    print(f"assembled {len(words)} instructions from {args.source}")


if __name__ == "__main__":
    main()
