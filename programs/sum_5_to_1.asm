; Regression program from the "Final Integration" addendum: sum the
; integers 5 down to 1 (5+4+3+2+1 = 15), store the result to Mem[0],
; then halt. Expected: R1=0, R2=15, Mem[0]=15.
        ADDI R1, R0, 5      ; R1 = 5 (counter)
        ADDI R2, R0, 0      ; R2 = 0 (accumulator)
LOOP:
        ADD  R2, R2, R1     ; R2 = R2 + R1
        SUBI R1, R1, 1      ; R1 = R1 - 1
        BPL  R1, LOOP       ; branch to LOOP if R1 > 0
        ST   R2, 0(R0)      ; Mem[0] = R2
        HALT
