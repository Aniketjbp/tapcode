; RAM allocation
CUR_ST  DATA 40H
DgtCode DATA 41H
KeyCode DATA 42H
KeyNo   DATA 43H
Key     DATA 44H
KeyBuf  DATA 50H
STACKST EQU  6FH
; Assume a 24 MHZ crystal
; Counts for a 25 ms delay are:
TH0COUNT EQU 3CH
TL0COUNT EQU 0B0H
mov p0,#0FFH
;F0 in PSW will be used to store the answer from tests
org 0000H
ljmp Init
ORG 0003H
ljmp X0_INTR            ; jump to ext interrupt 0 handler
ORG 000BH
ljmp T0_INTR            ; Jump to timer 0 interrupt handler
ORG 0013H
ljmp X1_INTR            ; Jump to ext interrupt 1 handler
ORG 001BH
ljmp T1_INTR            ; Jump to timer 1 interrupt handler
ORG 0023H
ljmp Ser_INTR           ; Jump to Serial IO handler
org 0030H
T0_INTR: CLR TR0        ; Stop the timer
MOV TH0, #TH0COUNT      ; Re-load counts for 25 ms delay
MOV TL0, #TL0COUNT
SETB TR0                ; Restart T0
SETB ET0                ; Re-enable interrupts from T0
LJMP FSM                ; Now manage the FSM 
ORG 0060H
FSM: PUSH ACC
PUSH PSW
PUSH DPH
PUSH DPL
ACALL DO_TEST           ; Peform the test for this state
ACALL DO_ACTION         ; Perform the action based on test answer
ACALL SET_NEXT          ; Set current state = next state
                        ; and return, cleaning up as we go
POP DPL
POP DPH
POP PSW
POP ACC
RET                                     ; Use ret during testing
;RETI
DO_TEST:
MOV A, CUR_ST           ; Fetch the current state
MOV DPTR, #Test_Tab     ; Table of test numbers for states
MOVC A, @A + DPTR       ; Get the test number for this state
MOV DPTR, #Test_Jmp     ; Jump table for tests
ADD A, ACC              ; A = 2A: each entry is 2 bytes
jmp @A + DPTR           ; Jump to the selected test
; Note: selected test will do ret.

DO_ACTION:
MOV DPTR, #Yes_Actions
JB F0, Sel_Action       ; If test answer = yes, DPTR is correct
MOV DPTR, #No_Actions   ; If Test returned no, modify DPTR
Sel_Action:             ; Now look up the action to be taken
MOV     A, CUR_ST       ; Fetch the current state
MOVC A, @A + DPTR       ; and look up the action number
ADD A, ACC              ; A = 2A : offset in Action jump table
; because each entry is 2 bytes
MOV DPTR, #Action_jmp   ; Jump table for actions
sSJMP @A + DPTR           ; Jump to the selected action
; Note: selected action will do ret
                                       
SET_NEXT:
MOV DPTR, #Yes_Next     ; Array of next states for yes answer
JB F0, Do_Next          ; If answer was yes, DPTR is correct
MOV DPTR, #No_Next      ; Else correct the DPTR to no answer
Do_Next:
MOV A, CUR_ST           ; get the current state
MOVC A, @A+DPTR         ; get the next state
MOV CUR_ST, A           ; and save it as current state
RET

Test_Tab:    DB 0, 1, 1, 1
Yes_Actions: DB 1, 2, 0, 0
NO_Actions:  DB 0, 0, 0, 0
Test_Jmp:
AJMP AnyKey
AJMP TheKey
Action_Jmp:
AJMP DoNothing
AJMP FindKey
AJMP ReportKey
Yes_Next: DB 1, 2, 2, 2
No_Next:  DB 0, 0, 3, 0
AnyKey:
push acc
mov a,p0
mov r4,#00H
mov r7,#04H
loop12:
rrc a
jc l12
inc r4
l12:djnz r7,loop12
mov r3,04H
mov r4,#00H
mov r7,#04H
clr c
loop1:
rrc a
jc l2
inc r4
l2:djnz r7,loop1
mov a,r3
add a,r4
clr c
setb psw.5
subb a,#2h
jz ex
clr psw.5
ex:
mov KeyNo,p0
pop acc
RET
TheKey:
push acc
mov a,p0
mov b,KeyNo
clr c
subb a,b
setb psw.5
jz L11
clr psw.5
L11:
pop acc
RET
DoNothing:
RET
FindKey:
acall TheKey
jnb f0,en
mov KeyCode,KeyNo
;acall ReportKey
en:
RET
ReportKey:
push acc
jnb f0,en1
mov b,#8h
mov a,#0h
add a,Key
div ab
mov a,b
inc a
mov Key,a
add a,#4fh
mov r0,a
mov @r0,KeyNo
en1:
pop acc
RET




X0_INTR:                ; ext interrupt 0 handler
reti
X1_INTR:                ; ext interrupt 0 handler
reti
T1_INTR:                ; Timer 1 handler
reti
Ser_INTR:               ; Serial IO handler
reti
ORG 0200H
Init:
MOV SP, #STACKST        ; SP to top of 8051 memory
MOV CUR_ST, #00         ; Initialize current state to Idle
CLR TR0                 ; Stop the timer (if running)
MOV TH0, #TH0COUNT      ; Load T0 counts for 25 ms delay
MOV TL0, #TL0COUNT
SETB ET0                ; Enable interrupts from T0
SETB EA                 ; Enable interrupts globally
SETB TR0                ; Start T0 timer
   
TST1: acall T0_INTR     ; This is for testing only


sjmp TST1               ; Test ISR by calling it in SW
L1: sjmp L1             ; This represents main program
END
                             
;ACC. . . . . . . .  D ADDR   00E0H   A   
;ACTION_JMP . . . .  C ADDR   00B4H   A   
;ANYKEY . . . . . .  C ADDR   00C2H   A   
;CUR_ST . . . . . .  D ADDR   0040H   A   
;DGTCODE. . . . . .  D ADDR   0041H   A   
;DONOTHING. . . . .  C ADDR   00C4H   A   
;DO_ACTION. . . . .  C ADDR   0083H   A   
;DO_NEXT. . . . . .  C ADDR   009EH   A   
;DO_TEST. . . . . .  C ADDR   0077H   A   
;DPH. . . . . . . .  D ADDR   0083H   A   
;DPL. . . . . . . .  D ADDR   0082H   A   
;EA . . . . . . . .  B ADDR   00A8H.7 A   
;ET0. . . . . . . .  B ADDR   00A8H.1 A   
;F0 . . . . . . . .  B ADDR   00D0H.5 A   
;FINDKEY. . . . . .  C ADDR   00C5H   A   
;FSM. . . . . . . .  C ADDR   0060H   A   
;INIT . . . . . . .  C ADDR   0200H   A   
;KEY. . . . . . . .  D ADDR   0044H   A   
;KEYBUF . . . . . .  D ADDR   0050H   A   
;KEYCODE. . . . . .  D ADDR   0042H   A   
;KEYNO. . . . . . .  D ADDR   0043H   A   
;L1 . . . . . . . .  C ADDR   0218H   A   
;NO_ACTIONS . . . .  C ADDR   00ACH   A   
;NO_NEXT. . . . . .  C ADDR   00BEH   A   
;PSW. . . . . . . .  D ADDR   00D0H   A   
;REPORTKEY. . . . .  C ADDR   00C6H   A   
;SEL_ACTION . . . .  C ADDR   008CH   A   
;SER_INTR . . . . .  C ADDR   00CAH   A   
;SET_NEXT . . . . .  C ADDR   0095H   A   
;SP . . . . . . . .  D ADDR   0081H   A   
;STACKST. . . . . .  N NUMB   006FH   A   
;T0_INTR. . . . . .  C ADDR   0030H   A   
;T1_INTR. . . . . .  C ADDR   00C9H   A   
;TEST_JMP . . . . .  C ADDR   00B0H   A   
;TEST_TAB . . . . .  C ADDR   00A4H   A   
;TH0. . . . . . . .  D ADDR   008CH   A   
;TH0COUNT . . . . .  N NUMB   003CH   A   
;THEKEY . . . . . .  C ADDR   00C3H   A   
;TL0. . . . . . . .  D ADDR   008AH   A   
;TL0COUNT . . . . .  N NUMB   00B0H   A   
;TR0. . . . . . . .  B ADDR   0088H.4 A   
;TST1 . . . . . . .  C ADDR   0214H   A   
;X0_INTR. . . . . .  C ADDR   00C7H   A   
;X1_INTR. . . . . .  C ADDR   00C8H   A   
;YES_ACTIONS. . . .  C ADDR   00A8H   A   
;YES_NEXT . . . . .  C ADDR   00BAH   A   


