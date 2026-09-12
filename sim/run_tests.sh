#!/usr/bin/env bash
# Assembles every program and runs every testbench. Requires Icarus
# Verilog (iverilog/vvp) and Python 3 on PATH.
set -e
cd "$(dirname "$0")/.."

mkdir -p build

echo "== assembling programs =="
python tools/assemble.py programs/sum_5_to_1.asm    --hex build/sum_5_to_1.hex
python tools/assemble.py programs/booth_mult.asm     --hex build/booth_mult.hex
python tools/assemble.py programs/hamming_weight.asm --hex build/hamming_weight.hex
python tools/assemble.py programs/isa_selftest.asm   --hex build/isa_selftest.hex

run_tb () {
    name=$1
    tb=$2
    echo
    echo "== $name =="
    iverilog -g2012 -o "build/$name.out" rtl/*.v "$tb"
    vvp "build/$name.out"
}

run_tb tb_alu            sim/tb_alu.v
run_tb tb_processor_sum  sim/tb_processor_sum.v
run_tb tb_booth          sim/tb_booth.v
run_tb tb_hamming        sim/tb_hamming.v
run_tb tb_isa_selftest   sim/tb_isa_selftest.v

echo
echo "== all testbenches completed -- check PASS/FAIL lines above =="
