; Integration smoke test for every instruction NOT already exercised by
; sum_5_to_1 / booth_mult / hamming_weight: AND/OR/XOR/NOR/NOT, SL/SRL/SRA
; (register form), INC/DEC, SLT/SGT, the *I immediate forms, LUI, MOVE,
; MOVE-from-SP, CMOV, PUSH/POP, CALL/RET (indirect), and BMI.
;
; On HALT, R9 == 0 (also stored to Mem[0]) means every check passed;
; otherwise R9 is the number of failed checks.

        ADDI R9, R0, 0        ; fail counter = 0

; ---- R-type ALU ----
        ADDI R1, R0, 12
        ADDI R2, R0, 10
        AND  R3, R1, R2       ; expect 8
        ADDI R4, R0, 8
        SUB  R5, R3, R4
        BZ   R5, T_OR
        INC  R9, R9
T_OR:
        OR   R3, R1, R2       ; expect 14
        ADDI R4, R0, 14
        SUB  R5, R3, R4
        BZ   R5, T_XOR
        INC  R9, R9
T_XOR:
        XOR  R3, R1, R2       ; expect 6
        ADDI R4, R0, 6
        SUB  R5, R3, R4
        BZ   R5, T_NOR
        INC  R9, R9
T_NOR:
        ADDI R1, R0, 0
        ADDI R2, R0, 0
        NOR  R3, R1, R2       ; expect -1
        ADDI R4, R0, -1
        SUB  R5, R3, R4
        BZ   R5, T_NOT
        INC  R9, R9
T_NOT:
        NOT  R3, R1           ; R1=0 -> expect -1
        SUB  R5, R3, R4       ; R4 still -1
        BZ   R5, T_SLL
        INC  R9, R9
T_SLL:
        ADDI R1, R0, 1
        ADDI R2, R0, 4
        SL   R3, R1, R2       ; expect 16
        ADDI R4, R0, 16
        SUB  R5, R3, R4
        BZ   R5, T_SRL
        INC  R9, R9
T_SRL:
        ADDI R1, R0, -1
        ADDI R2, R0, 28
        SRL  R3, R1, R2       ; expect 15
        ADDI R4, R0, 15
        SUB  R5, R3, R4
        BZ   R5, T_SRA
        INC  R9, R9
T_SRA:
        ADDI R1, R0, -16
        ADDI R2, R0, 2
        SRA  R3, R1, R2       ; expect -4
        ADDI R4, R0, -4
        SUB  R5, R3, R4
        BZ   R5, T_INC
        INC  R9, R9
T_INC:
        ADDI R1, R0, 41
        INC  R3, R1           ; expect 42
        ADDI R4, R0, 42
        SUB  R5, R3, R4
        BZ   R5, T_DEC
        INC  R9, R9
T_DEC:
        ADDI R1, R0, 42
        DEC  R3, R1           ; expect 41
        ADDI R4, R0, 41
        SUB  R5, R3, R4
        BZ   R5, T_SLT1
        INC  R9, R9
T_SLT1:
        ADDI R1, R0, -5
        ADDI R2, R0, 3
        SLT  R3, R1, R2       ; expect 1
        ADDI R4, R0, 1
        SUB  R5, R3, R4
        BZ   R5, T_SLT2
        INC  R9, R9
T_SLT2:
        SLT  R3, R2, R1       ; expect 0
        ADDI R4, R0, 0
        SUB  R5, R3, R4
        BZ   R5, T_SGT1
        INC  R9, R9
T_SGT1:
        ADDI R1, R0, 9
        ADDI R2, R0, 2
        SGT  R3, R1, R2       ; expect 1
        ADDI R4, R0, 1
        SUB  R5, R3, R4
        BZ   R5, T_SGT2
        INC  R9, R9
T_SGT2:
        SGT  R3, R2, R1       ; expect 0
        ADDI R4, R0, 0
        SUB  R5, R3, R4
        BZ   R5, T_HAM
        INC  R9, R9
T_HAM:
        ADDI R1, R0, 15
        HAM  R3, R1           ; expect 4
        ADDI R4, R0, 4
        SUB  R5, R3, R4
        BZ   R5, T_ANDI
        INC  R9, R9

; ---- Immediate forms ----
T_ANDI:
        ADDI R1, R0, 12
        ANDI R3, R1, 10       ; expect 8
        ADDI R4, R0, 8
        SUB  R5, R3, R4
        BZ   R5, T_ORI
        INC  R9, R9
T_ORI:
        ORI  R3, R1, 10       ; expect 14
        ADDI R4, R0, 14
        SUB  R5, R3, R4
        BZ   R5, T_XORI
        INC  R9, R9
T_XORI:
        XORI R3, R1, 10       ; expect 6
        ADDI R4, R0, 6
        SUB  R5, R3, R4
        BZ   R5, T_NORI
        INC  R9, R9
T_NORI:
        ADDI R1, R0, 0
        NORI R3, R1, 0        ; expect -1
        ADDI R4, R0, -1
        SUB  R5, R3, R4
        BZ   R5, T_SLTI
        INC  R9, R9
T_SLTI:
        ADDI R1, R0, -5
        SLTI R3, R1, 3        ; expect 1
        ADDI R4, R0, 1
        SUB  R5, R3, R4
        BZ   R5, T_SGTI
        INC  R9, R9
T_SGTI:
        ADDI R1, R0, 9
        SGTI R3, R1, 2        ; expect 1
        SUB  R5, R3, R4       ; R4 still 1
        BZ   R5, T_LUI
        INC  R9, R9

; ---- LUI + constant construction ----
T_LUI:
        LUI  R1, 0xBEEF
        ORI  R1, R1, 0x1234   ; expect 0xBEEF1234
        LUI  R4, 0xBEEF
        ORI  R4, R4, 0x1234
        SUB  R5, R1, R4
        BZ   R5, T_MOVE
        INC  R9, R9

; ---- MOVE / MOVE-from-SP ----
T_MOVE:
        ADDI R1, R0, 77
        MOVE R3, R1            ; expect 77
        SUB  R5, R3, R1
        BZ   R5, T_MOVSP
        INC  R9, R9
T_MOVSP:
        MOVE R3, SP
        ADDI R4, R0, 2040       ; SP_INIT = 0x7F8 = 2040
        SUB  R5, R3, R4
        BZ   R5, T_CMOV
        INC  R9, R9

; ---- CMOV ----
T_CMOV:
        ADDI R1, R0, 5
        ADDI R2, R0, 9
        CMOV R3, R1, R2        ; 5<9 -> expect 5
        SUB  R5, R3, R1
        BZ   R5, T_CMOV2
        INC  R9, R9
T_CMOV2:
        CMOV R3, R2, R1        ; 9<5 false -> expect R1(5)
        SUB  R5, R3, R1
        BZ   R5, T_PUSHPOP
        INC  R9, R9

; ---- PUSH / POP ----
T_PUSHPOP:
        ADDI R1, R0, 1234
        PUSH R1
        ADDI R1, R0, 0          ; clobber R1
        POP  R3                 ; expect 1234 back
        ADDI R4, R0, 1234
        SUB  R5, R3, R4
        BZ   R5, T_CALLRET
        INC  R9, R9

; ---- CALL / RET (indirect) ----
T_CALLRET:
        ADDI R6, R0, 0          ; marker = 0
        LUI  R7, 0
        ORI  R7, R7, SUBROUTINE ; build subroutine's absolute address
        CALL R7
        ADDI R4, R0, 99
        SUB  R5, R6, R4          ; marker must now be 99
        BZ   R5, T_BMI
        INC  R9, R9

; ---- BMI ----
T_BMI:
        ADDI R1, R0, -3
        ADDI R6, R0, 0
        BMI  R1, BMI_TAKEN
        ADDI R6, R0, 1           ; should be skipped
BMI_TAKEN:
        ADDI R4, R0, 0
        SUB  R5, R6, R4          ; R6 must still be 0
        BZ   R5, DONE
        INC  R9, R9

DONE:
        ST   R9, 0(R0)           ; Mem[0] = fail count
        HALT

SUBROUTINE:
        ADDI R6, R0, 99          ; marker = 99
        RET
