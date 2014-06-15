;==================================================================================
; Contents of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==================================================================================

; Minimum 6850 ACIA interrupt driven serial I/O to run modified NASCOM Basic 4.7
; Full input buffering with incoming data hardware handshaking
; Handshake shows full before the buffer is totally filled to allow run-on from the sender

defc            SER_BUFSIZE     = $3F
defc            SER_FULLSIZE    = $30
defc            SER_EMPTYSIZE   = 5

defc            RTS_HIGH        = $D6
defc            RTS_LOW         = $96

defc            serBuf          = $8000
defc            serInPtr        = serBuf + SER_BUFSIZE
defc            serRdPtr        = serInPtr + 2
defc            serBufUsed      = serRdPtr + 2
defc            basicStarted    = serBufUsed + 1
defc            TEMPSTACK       = $80ED                 ; Top of BASIC line input buffer so is "free ram" when BASIC resets

defc            CR              = $0D
defc            LF              = $0A
defc            CS              = $0C                   ; Clear screen

                org $0000

;------------------------------------------------------------------------------
; Reset

.RST00          DI                                      ; Disable interrupts
                JP       INIT                           ; Initialize Hardware and go

defs            4, $ff                                  ; byte padding between vectors

;------------------------------------------------------------------------------
; TX a character over RS232 

.RST08          JP      TXA

defs            5, $ff                                  ; byte padding between vectors

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

.RST10          JP      RXA

defs            5, $ff                                  ; byte padding between vectors

;------------------------------------------------------------------------------
; Check serial status

.RST18          JP      CKINCHAR

defs            29, $ff                                 ; byte padding between vectors

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR [ for IM 1 ]

.RST38          JR      serialInt       

;------------------------------------------------------------------------------
serialInt:      PUSH     AF
                PUSH     HL

                IN       A,($80)
                AND      $01                            ; Check if interupt due to read buffer full
                JR       Z,rts0                         ; if not, ignore

                IN       A,($81)
                PUSH     AF
                LD       A,(serBufUsed)
                CP       SER_BUFSIZE                    ; If full then ignore
                JR       NZ,notFull
                POP      AF
                JR       rts0

notFull:        LD       HL,(serInPtr)
                INC      HL
                LD       A,L                            ; Only need to check low byte becasuse buffer<256 bytes
;                CP       ((serBuf + SER_BUFSIZE) ~ $FF) ; @@- replace with code the evaluates properly to a byte for this assembler
                JR       NZ, notWrap
                LD       HL,serBuf
notWrap:        LD       (serInPtr),HL
                POP      AF
                LD       (HL),A
                LD       A,(serBufUsed)
                INC      A
                LD       (serBufUsed),A
                CP       SER_FULLSIZE
                JR       C,rts0
                LD       A,RTS_HIGH
                OUT      ($80),A
rts0:           POP      HL
                POP      AF
                EI
                RETI

;------------------------------------------------------------------------------
RXA:
waitForChar:    LD       A,(serBufUsed)
                CP       $00
                JR       Z, waitForChar
                PUSH     HL
                LD       HL,(serRdPtr)
                INC      HL
                LD       A,L                            ; Only need to check low byte becasuse buffer<256 bytes
;                CP       ((serBuf+SER_BUFSIZE) ~ $FF) ; @@- replace with code the evaluates properly to a byte for this assembler
                JR       NZ, notRdWrap
                LD       HL,serBuf
notRdWrap:      DI
                LD       (serRdPtr),HL
                LD       A,(serBufUsed)
                DEC      A
                LD       (serBufUsed),A
                CP       SER_EMPTYSIZE
                JR       NC,rts1
                LD       A,RTS_LOW
                OUT      ($80),A
rts1:
                LD       A,(HL)
                EI
                POP      HL
                RET                                     ; Char ready in A

;------------------------------------------------------------------------------
TXA:            PUSH     AF                             ; Store character
conout1:        IN       A,($80)                        ; Status byte       
                BIT      1,A                            ; Set Zero flag if still transmitting character       
                JR       Z,conout1                      ; Loop until flag signals ready
                POP      AF                             ; Retrieve character
                OUT      ($81),A                        ; Output the character
                RET

;------------------------------------------------------------------------------
.CKINCHAR       LD       A,(serBufUsed)
                CP       $0
                RET

PRINT:          LD       A,(HL)                         ; Get character
                OR       A                              ; Is it $00 ?
                RET      Z                              ; Then RETurn on terminator
                RST      08H                            ; Print it
                INC      HL                             ; Next Character
                JR       PRINT                          ; Continue until $00
                RET
;------------------------------------------------------------------------------
INIT:
               LD        HL,TEMPSTACK                   ; Temp stack
               LD        SP,HL                          ; Set up a temporary stack
               LD        HL,serBuf
               LD        (serInPtr),HL
               LD        (serRdPtr),HL
               XOR       A                              ; 0 to accumulator
               LD        (serBufUsed),A
               LD        A,RTS_LOW
               OUT       ($80),A                        ; Initialise ACIA
               IM        1
               EI
               LD        HL,SIGNON1                     ; Sign-on message
               CALL      PRINT                          ; Output string
               LD        A,(basicStarted)               ; Check the BASIC STARTED flag
               CP        'Y'                            ; to see if this is power-up
               JR        NZ,COLDSTART                   ; If not BASIC started then always do cold start
               LD        HL,SIGNON2                     ; Cold/warm message
               CALL      PRINT                          ; Output string
CORW:
               CALL      RXA
               AND       @11011111                      ; lower to uppercase
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'                          ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $0150                          ; Start BASIC COLD
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
               JP        $0153                          ; Start BASIC WARM

;------------------------------------------------------------------------------
; signon string

SIGNON1:       
defb            CS                                      ; @@- will this clear the screen? replace with VT100 code?
defm            "Z80 SBC By Grant Searle",CR,LF,0

SIGNON2:
defb            CR
defb            LF
defm            "Cold or warm start (C or W)? ",0
