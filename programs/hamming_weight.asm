; Total Hamming Weight of a 5-word array in data memory.
; (IIT Kharagpur COA Lab, "Final Program Demonstration", Problem 2)
;
; Data memory convention: Mem[24], Mem[32], Mem[40], Mem[48], Mem[56] hold
; the 5 input words (byte addresses, 8-byte-aligned per the ISA spec).
; Result: R3 = sum of popcount(word) over all 5 words.
;
; This follows the assignment's own pseudocode verbatim, using the HAM
; instruction it explicitly requires.

        ADDI R3, R0, 0        ; R3 = TotalSum = 0
        ADDI R4, R0, 5        ; R4 = Counter = 5
        ADDI R5, R0, 24       ; R5 = CurrentAddress = 24
LOOP:
        LD   R6, 0(R5)        ; R6 = Mem[CurrentAddress]
        HAM  R7, R6           ; R7 = HammingWeight(R6)
        ADD  R3, R3, R7       ; TotalSum = TotalSum + R7
        ADDI R5, R5, 8        ; CurrentAddress += 8
        SUBI R4, R4, 1        ; Counter--
        BPL  R4, LOOP         ; loop while Counter > 0
        HALT
