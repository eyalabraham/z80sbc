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
; Modified to support UART 16550 and PPI 5255 on my own version of the z80 SBC
; Copyright Eyal Abraham and Itai Abraham, 17 August 2014
;==================================================================================

defc            SER_BUFSIZE     = $3F
defc            SER_FULLSIZE    = $30
defc            SER_EMPTYSIZE   = 5

defc            COLD_BASIC      = $0200
defc            WARM_BASIC      = COLD_BASIC + 3

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
defc            ESC             = $1B                   ; ESC escape

defc            PPIPA           = $20                   ; 8255 PPI port addresses
defc            PPIPB           = $21
defc            PPIPC           = $22
defc            PPICTRL         = $23
defc            PPIINIT         = $00                   ; 8255 PPI initializtion

defc            RBR             = $00                   ; Rx Buffer Reg. (RBR)
defc            THR             = $00                   ; Tx Holding Register. (THR)
defc            RXTXREG         = $00

defc            IER             = $01                   ; Interrupt Enable Reg.
defc            INTRINIT        = @00000001             ; interrupt on byte receive only
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. Rx Data Available interrupt
;                                  ||||||+---- b1.. Tx Holding Reg Empty interrupt
;                                  |||||+----- b2.. Rx Line Status int
;                                  ||||+------ b3.. MODEM Status int.
;                                  |||+------- b4.. '0'
;                                  ||+-------- b5.. '0'
;                                  |+--------- b6.. '0'
;                                  +---------- b7.. '0'

defc            IIR             = $02                   ; Interrupt Identification Reg. (read only)
;
;                                  76543210
;                                  ||||||||            16550                        82C50
;                                  |||||||+--- b0.. /interrupt pending            /interrupt pending
;                                  ||||||+---- b1.. interrupt priority-0          interrupt priority-0
;                                  |||||+----- b2.. interrupt priority-1          interrupt priority-1
;                                  ||||+------ b3.. '0' or '1' in FIFO mode       '0'
;                                  |||+------- b4.. '0'                           '0'
;                                  ||+-------- b5.. '0'                           '0'
;                                  |+--------- b6.. = FCR.b0                      '0'
;                                  +---------- b7.. = FCR.b0                      '0'

defc            FCR             = $02                   ; FIFO Control Reg. (write only) *** 16550 only ***
defc            FCRINIT         = @00000000             ; initialize with no FIFO control
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. Rx and Tx FIFO enable
;                                  ||||||+---- b1.. Rx FIFO clear/reset
;                                  |||||+----- b2.. Tx FIFO clear/reset
;                                  ||||+------ b3.. RxRDY and TxRDY pins to mode 1
;                                  |||+------- b4.. reserved
;                                  ||+-------- b5.. reserved
;                                  |+--------- b6..
;                                  +---------- b7.. Rx FIFO trigger (1, 4, 8, 14 bytes)

defc            LCR             = $03                   ; Line Control Reg.
defc            LCRINIT         = @00000011             ; 8-bit Rx/Tx, 1 stop bit, no parity
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. character length
;                                  ||||||+---- b1.. character length
;                                  |||||+----- b2.. 1 stop bit
;                                  ||||+------ b3.. parity disabled
;                                  |||+------- b4.. odd parity
;                                  ||+-------- b5.. "stick" parity disabled
;                                  |+--------- b6.. break control disabled
;                                  +---------- b7.. Divisor Latch Access Bit (DLAB)

defc            MCR             = $04                   ; MODEM Control Reg.
defc            MCRINIT         = @00001110             ; out1 & 2 'lo', RTS = Xmit on
defc            MCRLOOP         = @00010000             ; OR mask for loop-back test
defc            RTSXON          = @00000010             ; OR mask for RTS Xmit on
defc            RTSXOFF         = @11111101             ; AND mask for RTS Xmit off
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. DTR
;                                  ||||||+---- b1.. RTS
;                                  |||||+----- b2.. OUT-1 IO pin
;                                  ||||+------ b3.. OUT-2 IO pin
;                                  |||+------- b4.. Loopback mode
;                                  ||+-------- b5.. '0'
;                                  |+--------- b6.. '0'
;                                  +---------- b7.. '0'

defc            LSR             = $05                   ; Line Status Reg.
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. Rx Register Ready
;                                  ||||||+---- b1.. Overrun Error
;                                  |||||+----- b2.. Parity Error
;                                  ||||+------ b3.. Framing Error
;                                  |||+------- b4.. Break interrupt
;                                  ||+-------- b5.. Tx Holding Register Ready / Tx FIFO empty
;                                  |+--------- b6.. Tx Empty (Tx shift reg. empty)
;                                  +---------- b7.. '0' or FIFO error in FIFO mode

defc            MSR             = $06                   ; MODEM Status Reg.
;                                  76543210
;                                  ||||||||
;                                  |||||||+--- b0.. DCTS
;                                  ||||||+---- b1.. DDSR
;                                  |||||+----- b2.. Trailing Edge RI
;                                  ||||+------ b3.. DDCD
;                                  |||+------- b4.. CTS
;                                  ||+-------- b5.. DSR
;                                  |+--------- b6.. RI
;                                  +---------- b7.. DCD

defc            SCRATCH         = $07                   ; Scratchpad Reg. (temp read/write register)
defc            BAUDGENLO       = $00                   ; baud rate generator/div accessed when bit DLAB='1'
defc            BAUDGENHI       = $01
defc            DLABSET         = @10000000             ; DLAB set (or) and clear (and) masks
defc            DLABCLR         = @01111111
defc            BAUDDIVLO       = $08                   ; BAUD rate divisor of 16 for 19200 BAUD
defc            BAUDDIVHI       = $00                   ; with 2.4576MHz crystal

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
; UART receive interrupt routine

serialInt:      PUSH    AF
                PUSH    HL                              ; save work registers

                in      a,(IIR)                         ; read IIR to determine if an interrupt is pending
                bit     0,a                             ; which can only be for a received character?
                JR      NZ,rts0                         ; if not, ignore
;
                in      a,(RBR)
                PUSH    AF
                LD      A,(serBufUsed)
                CP      SER_BUFSIZE                     ; If full then ignore
                JR      NZ,notFull
                POP     AF
                JR      rts0
;
notFull:        LD      HL,(serInPtr)
                INC     HL
                LD      A,L                             ; Only need to check low byte becasuse buffer<256 bytes
                CP      SER_BUFSIZE
                JR      NZ,notWrap
                LD      HL,serBuf
notWrap:        LD      (serInPtr),HL
                POP     AF
                LD      (HL),A
                LD      A,(serBufUsed)
                INC     A
                LD      (serBufUsed),A
                CP      SER_FULLSIZE
                JR      C,rts0
                LD      A,MCRINIT
                and     RTSXOFF
                OUT     (MCR),A                         ; assert RTS to stop transmitter
rts0:           POP     HL
                POP     AF
                EI
                RETI

;------------------------------------------------------------------------------
; Get a byte from serial buffer into A

RXA:
waitForChar:    LD       A,(serBufUsed)
                CP       $00
                JR       Z, waitForChar
                PUSH     HL
                LD       HL,(serRdPtr)
                INC      HL
                LD       A,L                            ; Only need to check low byte becasuse buffer<256 bytes
                CP       SER_BUFSIZE
                JR       NZ, notRdWrap
                LD       HL,serBuf
notRdWrap:      DI
                LD       (serRdPtr),HL
                LD       A,(serBufUsed)
                DEC      A
                LD       (serBufUsed),A
                CP       SER_EMPTYSIZE
                JR       NC,rts1
                LD       A,MCRINIT
                or       RTSXON
                OUT      (MCR),A                        ; deactivate RTS to release transmitter
rts1:
                LD       A,(HL)
                EI
                POP      HL
                RET                                     ; Char ready in A

;------------------------------------------------------------------------------
; Transmit a byte from A

TXA:            PUSH    AF                              ; Store character
conout1:        in      a,(LSR)                         ; Status byte
                BIT     5,A                             ; Set Zero flag if still transmitting character
                JR      Z,conout1                       ; Loop until flag signals ready
                POP     AF                              ; Retrieve character
                out    (THR),a                          ; Output the character
                RET

;------------------------------------------------------------------------------
; Check and return status of serial buffer

.CKINCHAR       LD       A,(serBufUsed)
                CP       $0
                RET

;------------------------------------------------------------------------------
; Print a zero terminater string

PRINT:          LD       A,(HL)                         ; Get character
                OR       A                              ; Is it $00 ?
                RET      Z                              ; Then RETurn on terminator
                RST      08H                            ; Print it
                INC      HL                             ; Next Character
                JR       PRINT                          ; Continue until $00
                RET
;------------------------------------------------------------------------------
; system initialization

INIT:          LD        HL,TEMPSTACK                   ; Temp stack
               LD        SP,HL                          ; Set up a temporary stack
               LD        HL,serBuf
               LD        (serInPtr),HL
               LD        (serRdPtr),HL
               XOR       A                              ; 0 to accumulator
               LD        (serBufUsed),A

; Initialize 8255 PPI
;
                ld          a,PPIINIT                   ; load initializtion bit
                out         (PPICTRL),a                 ; store in 8255 control register

; Initialize 16550 UART
;
                ld          a,INTRINIT
                out         (IER),a                     ; Rx enabled, all other interrupts disabled
;
                ld          a,FCRINIT
                out         (FCR),a                     ; no FIFO
;
                ld          a,LCRINIT
                out         (LCR),a                     ; 8-bit, 1 stop bit, no parity
;
                ld          a,MCRINIT
                out         (MCR),a                     ; all mode controls disabled
;
                ld          a,LCRINIT
                or          a,DLABSET
                out         (LCR),a                     ; enable access to BAUD rate divisor reg.
                push        af
;
                ld          a,BAUDDIVLO                 ; setup BAUD rate divisor
                out         (BAUDGENLO),a               ; low 8 bit divisor
                ld          a,BAUDDIVHI
                out         (BAUDGENHI),a               ; high 8 bit divisor
;
                pop         af
                and         a,DLABCLR
                out         (LCR),a                     ; disable access to BAUD rate divisor

; system and BASIC startup
;
               IM        1
               EI
               LD        HL,SIGNON1                     ; Sign-on message
               CALL      PRINT                          ; Output string
               LD        A,(basicStarted)               ; Check the BASIC STARTED flag
               CP        'Y'                            ; to see if this is power-up
               JR        NZ,COLDSTART                   ; If BASIC not started then always do cold start
               LD        HL,SIGNON2                     ; Cold/warm message
               CALL      PRINT                          ; Output string
CORW:          CALL      RXA
               AND       @11011111                      ; lower to uppercase
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H                            ; echo character
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'                          ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        COLD_BASIC                     ; Start BASIC COLD
CHECKWARM:     CP        'W'
               JR        NZ, CORW
               RST       08H                            ; echo character
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
               JP        WARM_BASIC                     ; Start BASIC WARM

;------------------------------------------------------------------------------
; signon string

SIGNON1:       
defm            ESC,"[2J"
defm            "---------------------------------",CR,LF
defm            " Itai's Z80 Computer",CR,LF
defm            " based on design by Grant Searle",CR,LF
defm            " October 2014 (c)",CR,LF
defm            "---------------------------------",CR,LF,0

SIGNON2:
defb            CR
defb            LF
defm            "Cold or warm start (C or W)? ",0

;------------------------------------------------------------------------------
; padding between modules

defs            (COLD_BASIC - ASMPC), $ff
