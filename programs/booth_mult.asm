; Booth's algorithm: 16x16 -> 32-bit signed multiplication.
; (IIT Kharagpur COA Lab, "Final Program Demonstration", Problem 1)
;
; Data memory convention (this repo's own test vectors -- see docs/README):
;   Mem[0] = M, the multiplicand, stored as a sign-extended 32-bit word
;   Mem[8] = R, the multiplier,   stored as a sign-extended 32-bit word
; Result: R2 = the final 32-bit product = {A[15:0], R[15:0]}
;
; Register allocation:
;   R1 = M            R2 = A (accumulator, later holds the result)
;   R3 = R (shift reg) R4 = Q_minus_1
;   R5 = loop counter  R6 = Q0 (this iteration's tested bit)
;   R7 = scratch (t = Q0-Qm1, then shift scratch)
;   R8 = scratch (bit to splice into R's new MSB)
;   R9 = scratch (A's low 16 bits, positioned for the final combine)

        LD   R1, 0(R0)       ; R1 = M
        LD   R3, 8(R0)       ; R3 = R (raw 32-bit word from memory)
        SLLI R3, R3, 16      ; zero-extend R down to its low 16 bits:
        SRLI R3, R3, 16      ;   R3 <= {16'b0, R[15:0]}
        ADDI R2, R0, 0       ; A = 0
        ADDI R4, R0, 0       ; Q_minus_1 = 0
        ADDI R5, R0, 16      ; Count = 16

BOOTH_LOOP:
        ANDI R6, R3, 1       ; Q0 = R & 1
        SUB  R7, R6, R4      ; t = Q0 - Q_minus_1  (t in {-1,0,1})
        BZ   R7, SHIFT       ; t==0            -> no add/sub this cycle
        BPL  R7, DO_SUB      ; t>0 (10 pattern) -> A = A - M
        ADD  R2, R2, R1      ; t<0 (01 pattern) -> A = A + M
        BR   SHIFT
DO_SUB:
        SUB  R2, R2, R1
SHIFT:
        ANDI R8, R2, 1       ; bit to become R's new MSB = A's current LSB
        SLLI R8, R8, 15
        SRLI R7, R3, 1       ; R >> 1 (logical; R3's upper 16 bits stay 0)
        OR   R3, R7, R8      ; R <= {A[0], R_old[15:1]}
        SRAI R2, R2, 1       ; A <= A >>> 1 (arithmetic, sign-preserving)
        MOVE R4, R6          ; Q_minus_1 <= this iteration's Q0
        SUBI R5, R5, 1       ; Count--
        BPL  R5, BOOTH_LOOP  ; loop while Count > 0

        ; Combine {A[15:0], R[15:0]} into the 32-bit result. Shifting A
        ; left by 16 naturally discards whatever sign-extended garbage is
        ; sitting above bit 15 of A, so no separate masking of A is needed.
        SLLI R9, R2, 16
        OR   R2, R9, R3      ; R2 = final 32-bit product
        HALT
