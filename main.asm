; da65 V2.19 - Git c097401f8
; Input file: clean.nes
; Page:       1


        .setcpu "6502"

; ----------------------------------------------------------------------------
tmp12           := $0012                                       ; Appears to have multiple uses. One is for ram init along with $13
tmp13           := $0013
tmp14           := $0014                                       ; at least one use is to send nametable to ppu (with $15)
tmp15           := $0015
jmp1E           := $001E                                       ; used for indirect jumping at 8029.  related to rendering
ppuNametableSelect:= $0029                                     ; need confirmation.  0,1,2 or 3 for 2000, 2400, 2800 or 2C00
aBackup         := $002B
xBackup         := $002C
yBackup         := $002D
currentPpuMask  := $002E
controllerBeingRead:= $002F                                    ; set to 1 while controller is being read
controllerInput := $0030                                       ; used only during reading.  buttons left in x register
ppuRenderDirection:= $0035                                     ; need confirmation.  0 for horiz, 1 for vert
; also used as nmi wait variable at 8D6F
currentScrollX  := $0036                                       ; appears to always be 0
currentScrollY  := $0037                                       ; appears to always be 0
aStorage        := $0038
startStorage    := $003A
selectStorage   := $003B
nmiWaitVar      := $003C
ppuPatternTables:= $003D                                       ; need confirmation.  Select background and sprite tables (00, 10, 08 or 18 for bg & sprite)
rngSeed         := $0056
L0061           := $0061
lastZPAddress   := $00FF                                       ; This causes tetris-ram.awk to add '.bss' after zeropage
stack           := $0100
oamStaging      := $0200
playfield       := $030A
playfieldStash  := $03D2                                       ; playfield copied here while paused
tetrominoX_A    := $0570                                       ; todo: figure out why 2
tetrominoY_A    := $0571                                       ; todo: figure out why 2
tetrominoOrientation_A:= $0573                                 ; todo: figure out why 2
tetrominoX_B    := $0584                                       ; todo: confirm this
tetrominoY_B    := $0585                                       ; todo: confirm this
tetrominoOrientation_B:= $0586                                 ; 0 2 4 or 6
maxMenuOptions  := $0615                                       ; Set to 3 normally. 7 when $C004 is 1 
PPUCTRL         := $2000
PPUMASK         := $2001
PPUSTATUS       := $2002
OAMADDR         := $2003
OAMDATA         := $2004
PPUSCROLL       := $2005
PPUADDR         := $2006
PPUDATA         := $2007
SQ1_VOL         := $4000
SQ1_SWEEP       := $4001
SQ1_LO          := $4002
SQ1_HI          := $4003
SQ2_VOL         := $4004
SQ2_SWEEP       := $4005
SQ2_LO          := $4006
SQ2_HI          := $4007
TRI_LINEAR      := $4008
TRI_LO          := $400A
TRI_HI          := $400B
NOISE_VOL       := $400C
NOISE_LO        := $400E
NOISE_HI        := $400F
DMC_FREQ        := $4010
DMC_RAW         := $4011
DMC_START       := $4012                                       ; start << 6 + $C000
DMC_LEN         := $4013                                       ; len << 4 + 1
OAMDMA          := $4014
SND_CHN         := $4015
JOY1            := $4016
JOY2            := $4017
; ----------------------------------------------------------------------------
; $8002 is incremented during bootup.  mmc1 remnant?
reset:
        jmp     resetContinued                                 ; 8000 4C 05 81

; ----------------------------------------------------------------------------
irq:
        rti                                                    ; 8003 40

; ----------------------------------------------------------------------------
nmi:
        sta     aBackup                                        ; 8004 85 2B
        stx     xBackup                                        ; 8006 86 2C
        sty     yBackup                                        ; 8008 84 2D
        lda     PPUSTATUS                                      ; 800A AD 02 20
        lda     #$08                                           ; 800D A9 08
        ora     ppuNametableSelect                             ; 800F 05 29
        ora     ppuRenderDirection                             ; 8011 05 35
        sta     PPUCTRL                                        ; 8013 8D 00 20
        ldx     $42                                            ; 8016 A6 42
        beq     L801E                                          ; 8018 F0 04
        ldx     #$00                                           ; 801A A2 00
        stx     $42                                            ; 801C 86 42
L801E:
        ldy     #$00                                           ; 801E A0 00
        sty     PPUMASK                                        ; 8020 8C 01 20
        cpy     $3F                                            ; 8023 C4 3F
        beq     L8029                                          ; 8025 F0 02
        dec     $3F                                            ; 8027 C6 3F
L8029:
        jmp     (jmp1E)                                        ; 8029 6C 1E 00

; ----------------------------------------------------------------------------
resetPpuRegistersAndCopyOamStaging:
        lda     currentScrollX                                 ; 802C A5 36
        sta     PPUSCROLL                                      ; 802E 8D 05 20
        lda     currentScrollY                                 ; 8031 A5 37
        sta     PPUSCROLL                                      ; 8033 8D 05 20
        lda     currentPpuMask                                 ; 8036 A5 2E
        sta     PPUMASK                                        ; 8038 8D 01 20
        lda     #$80                                           ; 803B A9 80
        ora     ppuNametableSelect                             ; 803D 05 29
        ora     ppuPatternTables                               ; 803F 05 3D
        sta     PPUCTRL                                        ; 8041 8D 00 20
        lda     #$00                                           ; 8044 A9 00
        sta     OAMADDR                                        ; 8046 8D 03 20
        lda     #$02                                           ; 8049 A9 02
        sta     OAMDMA                                         ; 804B 8D 14 40
        rts                                                    ; 804E 60

; ----------------------------------------------------------------------------
finishNmi:
        jsr     pollControllerAndCheckButtons                  ; 804F 20 5C 80
        jsr     LBC73                                          ; 8052 20 73 BC
        ldy     yBackup                                        ; 8055 A4 2D
        ldx     xBackup                                        ; 8057 A6 2C
        lda     aBackup                                        ; 8059 A5 2B
        rti                                                    ; 805B 40

; ----------------------------------------------------------------------------
pollControllerAndCheckButtons:
        lda     #$00                                           ; 805C A9 00
        sta     nmiWaitVar                                     ; 805E 85 3C
        sta     selectStorage                                  ; 8060 85 3B
        sta     startStorage                                   ; 8062 85 3A
        sta     aStorage                                       ; 8064 85 38
        jsr     pollController                                 ; 8066 20 CE 8F
        bne     @checkSelectPressed                            ; 8069 D0 04
        inx                                                    ; 806B E8
        stx     nmiWaitVar                                     ; 806C 86 3C
        rts                                                    ; 806E 60

; ----------------------------------------------------------------------------
@checkSelectPressed:
        txa                                                    ; 806F 8A
        and     #BUTTON_SELECT                                 ; 8070 29 04
        beq     @checkAPressed                                 ; 8072 F0 03
        sta     selectStorage                                  ; 8074 85 3B
        rts                                                    ; 8076 60

; ----------------------------------------------------------------------------
@checkAPressed:
        txa                                                    ; 8077 8A
        and     #BUTTON_A                                      ; 8078 29 01
        beq     @checkStartPressed                             ; 807A F0 02
        sta     aStorage                                       ; 807C 85 38
@checkStartPressed:
        txa                                                    ; 807E 8A
        and     #BUTTON_START                                  ; 807F 29 08
        beq     @ret                                           ; 8081 F0 02
        sta     startStorage                                   ; 8083 85 3A
@ret:
        rts                                                    ; 8085 60

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
unknownRoutine02:
        ldy     #$00                                           ; 8086 A0 00
        cpy     $41                                            ; 8088 C4 41
        beq     L80C4                                          ; 808A F0 38
L808C:
        lda     $04D2,y                                        ; 808C B9 D2 04
        cmp     #$FF                                           ; 808F C9 FF
        bne     L80AC                                          ; 8091 D0 19
        lda     $04CA,y                                        ; 8093 B9 CA 04
L8096:
        ldx     $04C2,y                                        ; 8096 BE C2 04
        stx     PPUADDR                                        ; 8099 8E 06 20
        ldx     $04BA,y                                        ; 809C BE BA 04
        stx     PPUADDR                                        ; 809F 8E 06 20
        sta     PPUDATA                                        ; 80A2 8D 07 20
        iny                                                    ; 80A5 C8
        dec     $41                                            ; 80A6 C6 41
        bne     L808C                                          ; 80A8 D0 E2
        beq     L80C4                                          ; 80AA F0 18
L80AC:
        ldx     $04C2,y                                        ; 80AC BE C2 04
        stx     PPUADDR                                        ; 80AF 8E 06 20
        ldx     $04BA,y                                        ; 80B2 BE BA 04
        stx     PPUADDR                                        ; 80B5 8E 06 20
        ldx     PPUDATA                                        ; 80B8 AE 07 20
        and     PPUDATA                                        ; 80BB 2D 07 20
        ora     $04CA,y                                        ; 80BE 19 CA 04
        jmp     L8096                                          ; 80C1 4C 96 80

; ----------------------------------------------------------------------------
L80C4:
        jsr     L9CFE                                          ; 80C4 20 FE 9C
        jsr     resetPpuRegistersAndCopyOamStaging             ; 80C7 20 2C 80
        jmp     finishNmi                                      ; 80CA 4C 4F 80

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
unknownRoutine08:
        lda     $3E                                            ; 80CD A5 3E
        beq     L80FF                                          ; 80CF F0 2E
        ldy     #$00                                           ; 80D1 A0 00
        lda     tmp13                                          ; 80D3 A5 13
        sta     PPUADDR                                        ; 80D5 8D 06 20
        lda     tmp12                                          ; 80D8 A5 12
        sta     PPUADDR                                        ; 80DA 8D 06 20
L80DD:
        lda     ($10),y                                        ; 80DD B1 10
        sta     PPUDATA                                        ; 80DF 8D 07 20
        iny                                                    ; 80E2 C8
        cpy     $34                                            ; 80E3 C4 34
        bcc     L80DD                                          ; 80E5 90 F6
        lda     $34                                            ; 80E7 A5 34
        clc                                                    ; 80E9 18
        adc     $10                                            ; 80EA 65 10
        sta     $10                                            ; 80EC 85 10
        bcc     L80F2                                          ; 80EE 90 02
        inc     $11                                            ; 80F0 E6 11
L80F2:
        dec     $3E                                            ; 80F2 C6 3E
        lda     tmp12                                          ; 80F4 A5 12
        clc                                                    ; 80F6 18
        adc     $34                                            ; 80F7 65 34
        sta     tmp12                                          ; 80F9 85 12
        bcc     L80FF                                          ; 80FB 90 02
        inc     tmp13                                          ; 80FD E6 13
L80FF:
        jsr     resetPpuRegistersAndCopyOamStaging             ; 80FF 20 2C 80
        jmp     finishNmi                                      ; 8102 4C 4F 80

; ----------------------------------------------------------------------------
resetContinued:
        cld                                                    ; 8105 D8
        sei                                                    ; 8106 78
        inc     reset+2                                        ; 8107 EE 02 80
        lda     #$08                                           ; 810A A9 08
        sta     PPUCTRL                                        ; 810C 8D 00 20
        lda     #$00                                           ; 810F A9 00
        sta     PPUMASK                                        ; 8111 8D 01 20
        sta     SND_CHN                                        ; 8114 8D 15 40
@vblankWait1:
        lda     PPUSTATUS                                      ; 8117 AD 02 20
        bpl     @vblankWait1                                   ; 811A 10 FB
@vblankWait2:
        lda     PPUSTATUS                                      ; 811C AD 02 20
        bpl     @vblankWait2                                   ; 811F 10 FB
        ldx     #$FF                                           ; 8121 A2 FF
        txs                                                    ; 8123 9A
        jsr     setCNROMBank0                                  ; 8124 20 70 8F
        jsr     initRoutine                                    ; 8127 20 50 81
        lda     #$00                                           ; 812A A9 00
        sta     ppuPatternTables                               ; 812C 85 3D
        jsr     L997B                                          ; 812E 20 7B 99
        lda     #$00                                           ; 8131 A9 00
        sta     ppuPatternTables                               ; 8133 85 3D
        lda     #$03                                           ; 8135 A9 03
        sta     $0613                                          ; 8137 8D 13 06
        inc     $0613                                          ; 813A EE 13 06
        jsr     LBC1F                                          ; 813D 20 1F BC
        lda     #$01                                           ; 8140 A9 01
        jsr     L90F9                                          ; 8142 20 F9 90
        ldy     #$F0                                           ; 8145 A0 F0
        jsr     L8FBB                                          ; 8147 20 BB 8F
        jsr     clearOamStagingAndStageHeartSprites            ; 814A 20 5E 83
        jmp     L83BD                                          ; 814D 4C BD 83

; ----------------------------------------------------------------------------
; need a better name
initRoutine:
        lda     #$00                                           ; 8150 A9 00
        ldy     #$10                                           ; 8152 A0 10
; this doesn't touch the first 16 bytes of zp.  FDS remnant?
@initZeroPage:
        sta     $00,y                                          ; 8154 99 00 00
        iny                                                    ; 8157 C8
        bne     @initZeroPage                                  ; 8158 D0 FA
        lda     #$17                                           ; 815A A9 17
@initRngSeed:
        sta     rngSeed,y                                      ; 815C 99 56 00
        ror     a                                              ; 815F 6A
        adc     #$26                                           ; 8160 69 26
        iny                                                    ; 8162 C8
        cpy     #$07                                           ; 8163 C0 07
        bcc     @initRngSeed                                   ; 8165 90 F5
        jsr     blankOutNametables                             ; 8167 20 F8 8F
        jsr     initRam                                        ; 816A 20 16 90
        lda     #$FF                                           ; 816D A9 FF
        sta     $0579                                          ; 816F 8D 79 05
        jsr     drawCreditScreenPatch                          ; 8172 20 AB 81
        lda     #<unknownRoutine02                             ; 8175 A9 86
        sta     jmp1E                                          ; 8177 85 1E
        lda     #>unknownRoutine02                             ; 8179 A9 80
        sta     jmp1E+1                                        ; 817B 85 1F
        ldx     #$96                                           ; 817D A2 96
@nextByte:
        lda     unknownTable01,x                               ; 817F BD 88 AF
        sta     $04D9,x                                        ; 8182 9D D9 04
        dex                                                    ; 8185 CA
        bne     @nextByte                                      ; 8186 D0 F7
        lda     #$00                                           ; 8188 A9 00
        jsr     L9D54                                          ; 818A 20 54 9D
        lda     #$03                                           ; 818D A9 03
        ldy     debugExtraMusic                                ; 818F AC 04 C0
        beq     L8196                                          ; 8192 F0 02
        lda     #$07                                           ; 8194 A9 07
L8196:
        sta     maxMenuOptions                                 ; 8196 8D 15 06
        rts                                                    ; 8199 60

; ----------------------------------------------------------------------------
; address, length, data, null
ntCreditScreenPatch:
        .byte   $E9,$2D,$0D,$0D,$1C,$0F,$0E,$13                ; 819A E9 2D 0D 0D 1C 0F 0E 13
        .byte   $1E,$00,$1D,$0D,$1C,$0F,$0F,$18                ; 81A2 1E 00 1D 0D 1C 0F 0F 18
        .byte   $00                                            ; 81AA 00
; ----------------------------------------------------------------------------
; this writes 'credit screen' to the nametable but is overwritten
drawCreditScreenPatch:
        ldy     #$00                                           ; 81AB A0 00
; this routine looks like it can write multiple patches, but is hardcoded to the above
@checkForNextPatch:
        lda     ntCreditScreenPatch,y                          ; 81AD B9 9A 81
        beq     @resetScroll                                   ; 81B0 F0 1D
        sta     PPUADDR                                        ; 81B2 8D 06 20
        iny                                                    ; 81B5 C8
        lda     ntCreditScreenPatch,y                          ; 81B6 B9 9A 81
        sta     PPUADDR                                        ; 81B9 8D 06 20
        iny                                                    ; 81BC C8
        lda     ntCreditScreenPatch,y                          ; 81BD B9 9A 81
        tax                                                    ; 81C0 AA
@nextByte:
        iny                                                    ; 81C1 C8
        lda     ntCreditScreenPatch,y                          ; 81C2 B9 9A 81
        sta     PPUDATA                                        ; 81C5 8D 07 20
        dex                                                    ; 81C8 CA
        bne     @nextByte                                      ; 81C9 D0 F6
        iny                                                    ; 81CB C8
        jmp     @checkForNextPatch                             ; 81CC 4C AD 81

; ----------------------------------------------------------------------------
@resetScroll:
        sta     PPUSCROLL                                      ; 81CF 8D 05 20
        sta     PPUSCROLL                                      ; 81D2 8D 05 20
        rts                                                    ; 81D5 60

; ----------------------------------------------------------------------------
L81D6:
        .byte   $30                                            ; 81D6 30
L81D7:
        .byte   $40,$50,$68,$88,$A8,$B8,$E7                    ; 81D7 40 50 68 88 A8 B8 E7
L81DE:
        .byte   $04,$04,$06,$08,$08,$04,$0C                    ; 81DE 04 04 06 08 08 04 0C
; ----------------------------------------------------------------------------
L81E5:
        lda     #$07                                           ; 81E5 A9 07
        jsr     L90F9                                          ; 81E7 20 F9 90
        lda     #$06                                           ; 81EA A9 06
        sta     currentPpuMask                                 ; 81EC 85 2E
        sta     PPUMASK                                        ; 81EE 8D 01 20
        lda     #$00                                           ; 81F1 A9 00
        sta     PPUCTRL                                        ; 81F3 8D 00 20
        lda     ppuNametableSelect                             ; 81F6 A5 29
        eor     #$03                                           ; 81F8 49 03
        asl     a                                              ; 81FA 0A
        asl     a                                              ; 81FB 0A
        adc     #$20                                           ; 81FC 69 20
        sta     PPUADDR                                        ; 81FE 8D 06 20
        lda     #$00                                           ; 8201 A9 00
        sta     PPUADDR                                        ; 8203 8D 06 20
        tax                                                    ; 8206 AA
        lda     #$32                                           ; 8207 A9 32
        ldy     #$03                                           ; 8209 A0 03
L820B:
        sta     PPUDATA                                        ; 820B 8D 07 20
        dex                                                    ; 820E CA
        bne     L820B                                          ; 820F D0 FA
        dey                                                    ; 8211 88
        bmi     L821B                                          ; 8212 30 07
        bne     L820B                                          ; 8214 D0 F5
        ldx     #$C0                                           ; 8216 A2 C0
        jmp     L820B                                          ; 8218 4C 0B 82

; ----------------------------------------------------------------------------
L821B:
        ldx     #$40                                           ; 821B A2 40
L821D:
        sty     PPUDATA                                        ; 821D 8C 07 20
        dex                                                    ; 8220 CA
        bne     L821D                                          ; 8221 D0 FA
        lda     #$80                                           ; 8223 A9 80
        ora     ppuNametableSelect                             ; 8225 05 29
        eor     #$03                                           ; 8227 49 03
        ora     ppuPatternTables                               ; 8229 05 3D
        sta     PPUCTRL                                        ; 822B 8D 00 20
        lda     #$08                                           ; 822E A9 08
        sta     $26                                            ; 8230 85 26
        jsr     L91EE                                          ; 8232 20 EE 91
        lda     #$06                                           ; 8235 A9 06
        jsr     L92DD                                          ; 8237 20 DD 92
        lda     #$0C                                           ; 823A A9 0C
        jsr     L92DD                                          ; 823C 20 DD 92
        ldx     #$30                                           ; 823F A2 30
        stx     oamStaging+1                                   ; 8241 8E 01 02
        ldx     #$20                                           ; 8244 A2 20
        stx     oamStaging+2                                   ; 8246 8E 02 02
        ldx     #$00                                           ; 8249 A2 00
        stx     oamStaging+3                                   ; 824B 8E 03 02
        stx     tetrominoX_A                                   ; 824E 8E 70 05
        lda     #$1E                                           ; 8251 A9 1E
        sta     currentPpuMask                                 ; 8253 85 2E
L8255:
        lda     #$1E                                           ; 8255 A9 1E
        sta     $05C7                                          ; 8257 8D C7 05
        lda     L81D6,x                                        ; 825A BD D6 81
        sta     oamStaging                                     ; 825D 8D 00 02
        txa                                                    ; 8260 8A
        pha                                                    ; 8261 48
        ldx     #$28                                           ; 8262 A2 28
        jsr     L93C6                                          ; 8264 20 C6 93
        pla                                                    ; 8267 68
        tax                                                    ; 8268 AA
        lda     #$28                                           ; 8269 A9 28
        sta     $3F                                            ; 826B 85 3F
L826D:
        jsr     L82EC                                          ; 826D 20 EC 82
        lda     ppuNametableSelect                             ; 8270 A5 29
        eor     #$03                                           ; 8272 49 03
        ora     #$80                                           ; 8274 09 80
        ora     ppuPatternTables                               ; 8276 05 3D
        sta     PPUCTRL                                        ; 8278 8D 00 20
        lda     tetrominoX_A                                   ; 827B AD 70 05
        clc                                                    ; 827E 18
        adc     $05C7                                          ; 827F 6D C7 05
        sta     tetrominoX_A                                   ; 8282 8D 70 05
        bcc     L8289                                          ; 8285 90 02
        lda     #$FF                                           ; 8287 A9 FF
L8289:
        sta     PPUSCROLL                                      ; 8289 8D 05 20
        lda     #$00                                           ; 828C A9 00
        sta     PPUSCROLL                                      ; 828E 8D 05 20
        ldy     $05C7                                          ; 8291 AC C7 05
        beq     L829D                                          ; 8294 F0 07
        dey                                                    ; 8296 88
        dey                                                    ; 8297 88
        beq     L829D                                          ; 8298 F0 03
        sty     $05C7                                          ; 829A 8C C7 05
L829D:
        stx     $1C                                            ; 829D 86 1C
        lda     L81DE,x                                        ; 829F BD DE 81
        sta     tmp14                                          ; 82A2 85 14
L82A4:
        jsr     pollController                                 ; 82A4 20 CE 8F
        txa                                                    ; 82A7 8A
        sta     $0598                                          ; 82A8 8D 98 05
        bne     L82E6                                          ; 82AB D0 39
        dec     tmp14                                          ; 82AD C6 14
        bne     L82A4                                          ; 82AF D0 F3
        ldx     $1C                                            ; 82B1 A6 1C
        lda     #$00                                           ; 82B3 A9 00
        sta     PPUSCROLL                                      ; 82B5 8D 05 20
        sta     PPUSCROLL                                      ; 82B8 8D 05 20
        cmp     tetrominoX_A                                   ; 82BB CD 70 05
        bne     L826D                                          ; 82BE D0 AD
        sta     $05C7                                          ; 82C0 8D C7 05
        lda     L81D7,x                                        ; 82C3 BD D7 81
        sta     oamStaging                                     ; 82C6 8D 00 02
        lda     $3F                                            ; 82C9 A5 3F
        bne     L826D                                          ; 82CB D0 A0
        inx                                                    ; 82CD E8
        cpx     #$07                                           ; 82CE E0 07
        bcc     L8255                                          ; 82D0 90 83
        ldx     #$2C                                           ; 82D2 A2 2C
        jsr     L93C6                                          ; 82D4 20 C6 93
        ldy     #$C8                                           ; 82D7 A0 C8
        jsr     L8FBB                                          ; 82D9 20 BB 8F
        lda     $0598                                          ; 82DC AD 98 05
        bne     L82E6                                          ; 82DF D0 05
        ldy     #$C8                                           ; 82E1 A0 C8
        jsr     L8FBB                                          ; 82E3 20 BB 8F
L82E6:
        lda     #$F0                                           ; 82E6 A9 F0
        sta     oamStaging                                     ; 82E8 8D 00 02
        rts                                                    ; 82EB 60

; ----------------------------------------------------------------------------
L82EC:
        inc     $42                                            ; 82EC E6 42
        jsr     L9059                                          ; 82EE 20 59 90
        lda     PPUSTATUS                                      ; 82F1 AD 02 20
        ldy     #$A0                                           ; 82F4 A0 A0
L82F6:
        nop                                                    ; 82F6 EA
        nop                                                    ; 82F7 EA
        nop                                                    ; 82F8 EA
        iny                                                    ; 82F9 C8
        bne     L82F6                                          ; 82FA D0 FA
L82FC:
        lda     PPUSTATUS                                      ; 82FC AD 02 20
        and     #$40                                           ; 82FF 29 40
        beq     L82FC                                          ; 8301 F0 F9
        rts                                                    ; 8303 60

; ----------------------------------------------------------------------------
L8304:
        jsr     LC3CB                                          ; 8304 20 CB C3
        ldy     #$00                                           ; 8307 A0 00
        jsr     L8C74                                          ; 8309 20 74 8C
        jsr     L8D5E                                          ; 830C 20 5E 8D
        lda     #$00                                           ; 830F A9 00
        jsr     L8C4C                                          ; 8311 20 4C 8C
        lda     #$12                                           ; 8314 A9 12
        jsr     L92DD                                          ; 8316 20 DD 92
        jsr     resetOamStaging                                ; 8319 20 53 83
        lda     #$08                                           ; 831C A9 08
        sta     ppuPatternTables                               ; 831E 85 3D
        jsr     LE000                                          ; 8320 20 00 E0
        lda     $0614                                          ; 8323 AD 14 06
        jsr     LBC1F                                          ; 8326 20 1F BC
        jsr     clearOamStagingAndStageHeartSprites            ; 8329 20 5E 83
        lda     #$00                                           ; 832C A9 00
        sta     ppuPatternTables                               ; 832E 85 3D
        lda     #$FF                                           ; 8330 A9 FF
        jsr     L8C4C                                          ; 8332 20 4C 8C
        lda     #$00                                           ; 8335 A9 00
        jsr     L92DD                                          ; 8337 20 DD 92
        jsr     L8774                                          ; 833A 20 74 87
        jsr     L8F49                                          ; 833D 20 49 8F
        rts                                                    ; 8340 60

; ----------------------------------------------------------------------------
L8341:
        lda     #$05                                           ; 8341 A9 05
        ldx     $0596                                          ; 8343 AE 96 05
        cpx     #$05                                           ; 8346 E0 05
        bne     L834C                                          ; 8348 D0 02
        lda     #$06                                           ; 834A A9 06
L834C:
        jsr     LBC1F                                          ; 834C 20 1F BC
        rts                                                    ; 834F 60

; ----------------------------------------------------------------------------
heartXCoordinates:
        .byte   $33,$3C,$45                                    ; 8350 33 3C 45
; ----------------------------------------------------------------------------
resetOamStaging:
        lda     #$F0                                           ; 8353 A9 F0
        ldy     #$00                                           ; 8355 A0 00
@nextByte:
        sta     oamStaging,y                                   ; 8357 99 00 02
        iny                                                    ; 835A C8
        bne     @nextByte                                      ; 835B D0 FA
        rts                                                    ; 835D 60

; ----------------------------------------------------------------------------
clearOamStagingAndStageHeartSprites:
        jsr     resetOamStaging                                ; 835E 20 53 83
        ldx     #$00                                           ; 8361 A2 00
@clearNextAttr:
        inx                                                    ; 8363 E8
        inx                                                    ; 8364 E8
        lda     #$00                                           ; 8365 A9 00
        sta     oamStaging,x                                   ; 8367 9D 00 02
        inx                                                    ; 836A E8
        inx                                                    ; 836B E8
        cpx     #$30                                           ; 836C E0 30
        bcc     @clearNextAttr                                 ; 836E 90 F3
        ldx     #$10                                           ; 8370 A2 10
        ldy     #$00                                           ; 8372 A0 00
@stageNextHeart:
        lda     #$F0                                           ; 8374 A9 F0
        sta     oamStaging,x                                   ; 8376 9D 00 02
        inx                                                    ; 8379 E8
        lda     #$60                                           ; 837A A9 60
        sta     oamStaging,x                                   ; 837C 9D 00 02
        inx                                                    ; 837F E8
        lda     #$02                                           ; 8380 A9 02
        sta     oamStaging,x                                   ; 8382 9D 00 02
        inx                                                    ; 8385 E8
        lda     heartXCoordinates,y                            ; 8386 B9 50 83
        sta     oamStaging,x                                   ; 8389 9D 00 02
        inx                                                    ; 838C E8
        iny                                                    ; 838D C8
        cpy     #$03                                           ; 838E C0 03
        bcc     @stageNextHeart                                ; 8390 90 E2
        rts                                                    ; 8392 60

; ----------------------------------------------------------------------------
L8393:
        lda     #$00                                           ; 8393 A9 00
        sta     $0587                                          ; 8395 8D 87 05
        sta     $0588                                          ; 8398 8D 88 05
        sta     $0589                                          ; 839B 8D 89 05
        sta     $058A                                          ; 839E 8D 8A 05
        sta     $058B                                          ; 83A1 8D 8B 05
        sta     $058C                                          ; 83A4 8D 8C 05
        sta     $058D                                          ; 83A7 8D 8D 05
        sta     $058E                                          ; 83AA 8D 8E 05
        lda     #$03                                           ; 83AD A9 03
        sta     $059E                                          ; 83AF 8D 9E 05
L83B2:
        lda     #$04                                           ; 83B2 A9 04
        jsr     L90F9                                          ; 83B4 20 F9 90
        lda     #$00                                           ; 83B7 A9 00
        jsr     L92DD                                          ; 83B9 20 DD 92
        rts                                                    ; 83BC 60

; ----------------------------------------------------------------------------
L83BD:
        lda     #$02                                           ; 83BD A9 02
        jsr     L90F9                                          ; 83BF 20 F9 90
        lda     #$03                                           ; 83C2 A9 03
        jsr     LBC1F                                          ; 83C4 20 1F BC
        lda     #$01                                           ; 83C7 A9 01
        sta     nmiWaitVar                                     ; 83C9 85 3C
L83CB:
        lda     nmiWaitVar                                     ; 83CB A5 3C
        beq     L840C                                          ; 83CD F0 3D
        lda     $0612                                          ; 83CF AD 12 06
        bne     L83CB                                          ; 83D2 D0 F7
        jsr     LC3CB                                          ; 83D4 20 CB C3
        jsr     L8733                                          ; 83D7 20 33 87
        jsr     L83B2                                          ; 83DA 20 B2 83
        lda     #$00                                           ; 83DD A9 00
        jsr     LBC1F                                          ; 83DF 20 1F BC
        jsr     L863A                                          ; 83E2 20 3A 86
        lda     $0598                                          ; 83E5 AD 98 05
        bne     L840C                                          ; 83E8 D0 22
        jsr     L9580                                          ; 83EA 20 80 95
        ldy     #$C8                                           ; 83ED A0 C8
        jsr     L8FBB                                          ; 83EF 20 BB 8F
        lda     $0598                                          ; 83F2 AD 98 05
        bne     L840C                                          ; 83F5 D0 15
        ldy     #$C8                                           ; 83F7 A0 C8
        jsr     L8FBB                                          ; 83F9 20 BB 8F
        lda     $0598                                          ; 83FC AD 98 05
        bne     L840C                                          ; 83FF D0 0B
        jsr     L81E5                                          ; 8401 20 E5 81
        jsr     LC3CB                                          ; 8404 20 CB C3
        lda     $0598                                          ; 8407 AD 98 05
        beq     L83BD                                          ; 840A F0 B1
L840C:
        jsr     LC3CB                                          ; 840C 20 CB C3
        lda     #$03                                           ; 840F A9 03
        jsr     L90F9                                          ; 8411 20 F9 90
        lda     #$00                                           ; 8414 A9 00
        jsr     L92DD                                          ; 8416 20 DD 92
        jsr     L87CF                                          ; 8419 20 CF 87
        jsr     L8393                                          ; 841C 20 93 83
L841F:
        jsr     L8F49                                          ; 841F 20 49 8F
        ldy     $0597                                          ; 8422 AC 97 05
        jsr     L8C74                                          ; 8425 20 74 8C
L8428:
        ldx     $0595                                          ; 8428 AE 95 05
        lda     L8907,x                                        ; 842B BD 07 89
        sta     $0575                                          ; 842E 8D 75 05
        lda     #$19                                           ; 8431 A9 19
        sta     $0580                                          ; 8433 8D 80 05
        lda     #$00                                           ; 8436 A9 00
        sta     $057F                                          ; 8438 8D 7F 05
        sta     $057A                                          ; 843B 8D 7A 05
        sta     $057B                                          ; 843E 8D 7B 05
        sta     $057C                                          ; 8441 8D 7C 05
        sta     $057D                                          ; 8444 8D 7D 05
        sta     $0581                                          ; 8447 8D 81 05
        sta     $0582                                          ; 844A 8D 82 05
        sta     $0618                                          ; 844D 8D 18 06
        sta     $0619                                          ; 8450 8D 19 06
        sta     $061A                                          ; 8453 8D 1A 06
        jsr     L91EE                                          ; 8456 20 EE 91
        lda     #$06                                           ; 8459 A9 06
        jsr     L92DD                                          ; 845B 20 DD 92
        jsr     L8E62                                          ; 845E 20 62 8E
        jsr     L8E7B                                          ; 8461 20 7B 8E
        jsr     L8D5E                                          ; 8464 20 5E 8D
        jsr     L8EE4                                          ; 8467 20 E4 8E
L846A:
        jsr     L8EB1                                          ; 846A 20 B1 8E
        lda     $0598                                          ; 846D AD 98 05
        bne     L8475                                          ; 8470 D0 03
        jmp     L8511                                          ; 8472 4C 11 85

; ----------------------------------------------------------------------------
L8475:
        ldx     #$24                                           ; 8475 A2 24
        jsr     L93C6                                          ; 8477 20 C6 93
        ldy     #$1E                                           ; 847A A0 1E
        jsr     L902E                                          ; 847C 20 2E 90
        ldx     #$24                                           ; 847F A2 24
        jsr     L93C6                                          ; 8481 20 C6 93
        jsr     L8CE7                                          ; 8484 20 E7 8C
        dec     $0574                                          ; 8487 CE 74 05
        ldy     #$14                                           ; 848A A0 14
        jsr     L902E                                          ; 848C 20 2E 90
        ldx     #$24                                           ; 848F A2 24
        jsr     L93C6                                          ; 8491 20 C6 93
        ldx     tetrominoX_A                                   ; 8494 AE 70 05
        ldy     tetrominoY_A                                   ; 8497 AC 71 05
        jsr     L8D36                                          ; 849A 20 36 8D
        ldy     #$14                                           ; 849D A0 14
        jsr     L902E                                          ; 849F 20 2E 90
        jsr     L8CE7                                          ; 84A2 20 E7 8C
        jsr     L8B0E                                          ; 84A5 20 0E 8B
        jsr     L962E                                          ; 84A8 20 2E 96
        lda     $059E                                          ; 84AB AD 9E 05
        beq     L84B3                                          ; 84AE F0 03
        jmp     L841F                                          ; 84B0 4C 1F 84

; ----------------------------------------------------------------------------
L84B3:
        jsr     LC3CB                                          ; 84B3 20 CB C3
        ldx     #$00                                           ; 84B6 A2 00
L84B8:
        lda     LAE17,x                                        ; 84B8 BD 17 AE
        sta     playfield,x                                    ; 84BB 9D 0A 03
        inx                                                    ; 84BE E8
        cpx     #$C8                                           ; 84BF E0 C8
        bcc     L84B8                                          ; 84C1 90 F5
        jsr     L8D5E                                          ; 84C3 20 5E 8D
        ldy     #$C8                                           ; 84C6 A0 C8
        jsr     L8FBB                                          ; 84C8 20 BB 8F
        lda     #$0A                                           ; 84CB A9 0A
        sta     $26                                            ; 84CD 85 26
        jsr     LC3CB                                          ; 84CF 20 CB C3
        jsr     L94D9                                          ; 84D2 20 D9 94
        jsr     L9580                                          ; 84D5 20 80 95
        lda     $05B8                                          ; 84D8 AD B8 05
        bmi     L84E0                                          ; 84DB 30 03
        jsr     L942F                                          ; 84DD 20 2F 94
L84E0:
        ldy     #$C8                                           ; 84E0 A0 C8
        sty     $3F                                            ; 84E2 84 3F
L84E4:
        jsr     pollController                                 ; 84E4 20 CE 8F
        txa                                                    ; 84E7 8A
        bne     L8504                                          ; 84E8 D0 1A
        ldy     $05B8                                          ; 84EA AC B8 05
        bpl     L84F6                                          ; 84ED 10 07
        lda     $0612                                          ; 84EF AD 12 06
        bne     L84E4                                          ; 84F2 D0 F0
        beq     L8504                                          ; 84F4 F0 0E
L84F6:
        lda     $0612                                          ; 84F6 AD 12 06
        bne     L8500                                          ; 84F9 D0 05
        lda     #$04                                           ; 84FB A9 04
        jsr     LBC1F                                          ; 84FD 20 1F BC
L8500:
        lda     $3F                                            ; 8500 A5 3F
        bne     L84E4                                          ; 8502 D0 E0
L8504:
        lda     #$02                                           ; 8504 A9 02
        jsr     LC3CD                                          ; 8506 20 CD C3
        ldy     #$3C                                           ; 8509 A0 3C
        jsr     L902E                                          ; 850B 20 2E 90
        jmp     L83BD                                          ; 850E 4C BD 83

; ----------------------------------------------------------------------------
L8511:
        lda     $0575                                          ; 8511 AD 75 05
        sta     $3F                                            ; 8514 85 3F
L8516:
        lda     tetrominoX_A                                   ; 8516 AD 70 05
        sta     tetrominoX_B                                   ; 8519 8D 84 05
        lda     tetrominoY_A                                   ; 851C AD 71 05
        sta     tetrominoY_B                                   ; 851F 8D 85 05
        lda     tetrominoOrientation_A                         ; 8522 AD 73 05
        sta     tetrominoOrientation_B                         ; 8525 8D 86 05
        lda     #$00                                           ; 8528 A9 00
        sta     $0599                                          ; 852A 8D 99 05
        cmp     nmiWaitVar                                     ; 852D C5 3C
        beq     L853A                                          ; 852F F0 09
        ldx     #$FF                                           ; 8531 A2 FF
        stx     $05BA                                          ; 8533 8E BA 05
        inx                                                    ; 8536 E8
        stx     $05BB                                          ; 8537 8E BB 05
L853A:
        lda     $3F                                            ; 853A A5 3F
        beq     L85BB                                          ; 853C F0 7D
        jsr     pollController                                 ; 853E 20 CE 8F
        beq     L8516                                          ; 8541 F0 D3
        lda     #$00                                           ; 8543 A9 00
        sta     nmiWaitVar                                     ; 8545 85 3C
        txa                                                    ; 8547 8A
        and     #BUTTON_LEFT+BUTTON_RIGHT                      ; 8548 29 C0
        bne     @leftOrRightPressed                            ; 854A D0 1F
        sta     $05BB                                          ; 854C 8D BB 05
        txa                                                    ; 854F 8A
        and     #BUTTON_A                                      ; 8550 29 01
        and     $05BA                                          ; 8552 2D BA 05
        bne     L85B0                                          ; 8555 D0 59
        txa                                                    ; 8557 8A
        and     #BUTTON_SELECT                                 ; 8558 29 04
        bne     L8594                                          ; 855A D0 38
        txa                                                    ; 855C 8A
        and     #BUTTON_START                                  ; 855D 29 08
        bne     L85AA                                          ; 855F D0 49
        txa                                                    ; 8561 8A
        and     #BUTTON_DOWN                                   ; 8562 29 20
        and     $05BA                                          ; 8564 2D BA 05
        bne     L85D5                                          ; 8567 D0 6C
        beq     L8516                                          ; 8569 F0 AB
@leftOrRightPressed:
        lda     $05BB                                          ; 856B AD BB 05
        beq     L8583                                          ; 856E F0 13
        cmp     #$FF                                           ; 8570 C9 FF
        beq     L8585                                          ; 8572 F0 11
        lda     #$FF                                           ; 8574 A9 FF
        dec     $05BB                                          ; 8576 CE BB 05
        beq     L8585                                          ; 8579 F0 0A
        ldy     #$01                                           ; 857B A0 01
        jsr     L902E                                          ; 857D 20 2E 90
        jmp     L8516                                          ; 8580 4C 16 85

; ----------------------------------------------------------------------------
L8583:
        lda     #$19                                           ; 8583 A9 19
L8585:
        sta     $05BB                                          ; 8585 8D BB 05
        lda     #$FF                                           ; 8588 A9 FF
        sta     $05BA                                          ; 858A 8D BA 05
        txa                                                    ; 858D 8A
        and     #BUTTON_LEFT                                   ; 858E 29 40
        beq     L85E6                                          ; 8590 F0 54
        bne     L85E0                                          ; 8592 D0 4C
L8594:
        txa                                                    ; 8594 8A
        and     #BUTTON_B                                      ; 8595 29 02
        beq     L85A4                                          ; 8597 F0 0B
        lda     debugEndingScreen                              ; 8599 AD 05 C0
        beq     L85A4                                          ; 859C F0 06
        jsr     L8304                                          ; 859E 20 04 83
        jmp     L841F                                          ; 85A1 4C 1F 84

; ----------------------------------------------------------------------------
L85A4:
        jsr     L8A74                                          ; 85A4 20 74 8A
        jmp     L8516                                          ; 85A7 4C 16 85

; ----------------------------------------------------------------------------
L85AA:
        jsr     L8A1D                                          ; 85AA 20 1D 8A
        jmp     L8516                                          ; 85AD 4C 16 85

; ----------------------------------------------------------------------------
L85B0:
        eor     #$FF                                           ; 85B0 49 FF
        sta     $05BA                                          ; 85B2 8D BA 05
        jsr     L8A92                                          ; 85B5 20 92 8A
        jmp     L846A                                          ; 85B8 4C 6A 84

; ----------------------------------------------------------------------------
L85BB:
        inc     tetrominoY_B                                   ; 85BB EE 85 05
        jsr     L8AB4                                          ; 85BE 20 B4 8A
        lda     $0598                                          ; 85C1 AD 98 05
        beq     L85CF                                          ; 85C4 F0 09
        dec     tetrominoY_B                                   ; 85C6 CE 85 05
        jsr     L8B52                                          ; 85C9 20 52 8B
        jmp     L846A                                          ; 85CC 4C 6A 84

; ----------------------------------------------------------------------------
L85CF:
        jsr     L8CC8                                          ; 85CF 20 C8 8C
        jmp     L8511                                          ; 85D2 4C 11 85

; ----------------------------------------------------------------------------
L85D5:
        eor     #$FF                                           ; 85D5 49 FF
        sta     $05BA                                          ; 85D7 8D BA 05
        jsr     L8A00                                          ; 85DA 20 00 8A
        jmp     L85EE                                          ; 85DD 4C EE 85

; ----------------------------------------------------------------------------
L85E0:
        dec     tetrominoX_B                                   ; 85E0 CE 84 05
        jmp     L85E9                                          ; 85E3 4C E9 85

; ----------------------------------------------------------------------------
L85E6:
        inc     tetrominoX_B                                   ; 85E6 EE 84 05
L85E9:
        jsr     L8AB4                                          ; 85E9 20 B4 8A
        ldx     #$04                                           ; 85EC A2 04
L85EE:
        ldy     $0598                                          ; 85EE AC 98 05
        bne     L8605                                          ; 85F1 D0 12
        jsr     L93C6                                          ; 85F3 20 C6 93
        jsr     L8CC8                                          ; 85F6 20 C8 8C
        ldy     #$02                                           ; 85F9 A0 02
        lda     $05BB                                          ; 85FB AD BB 05
        bpl     L8602                                          ; 85FE 10 02
        ldy     #$08                                           ; 8600 A0 08
L8602:
        jsr     L902E                                          ; 8602 20 2E 90
L8605:
        jmp     L8516                                          ; 8605 4C 16 85

; ----------------------------------------------------------------------------
L8608:
        ldx     $061A                                          ; 8608 AE 1A 06
        beq     L8621                                          ; 860B F0 14
        inc     $18                                            ; 860D E6 18
        inc     $0618                                          ; 860F EE 18 06
        bne     L8619                                          ; 8612 D0 05
        inc     $0619                                          ; 8614 EE 19 06
        inc     $19                                            ; 8617 E6 19
L8619:
        dec     $061A                                          ; 8619 CE 1A 06
        lsr     a                                              ; 861C 4A
        lsr     a                                              ; 861D 4A
        lsr     a                                              ; 861E 4A
        lsr     a                                              ; 861F 4A
        rts                                                    ; 8620 60

; ----------------------------------------------------------------------------
L8621:
        and     #$0F                                           ; 8621 29 0F
        inx                                                    ; 8623 E8
        inc     $061A                                          ; 8624 EE 1A 06
        rts                                                    ; 8627 60

; ----------------------------------------------------------------------------
L8628:
        ldx     $061C                                          ; 8628 AE 1C 06
        lda     $0619                                          ; 862B AD 19 06
        clc                                                    ; 862E 18
        adc     unknownTable02+1,x                             ; 862F 7D 51 9D
        sta     $19                                            ; 8632 85 19
        lda     unknownTable02,x                               ; 8634 BD 50 9D
        sta     $18                                            ; 8637 85 18
        rts                                                    ; 8639 60

; ----------------------------------------------------------------------------
L863A:
        jsr     L8E62                                          ; 863A 20 62 8E
        jsr     L8E7B                                          ; 863D 20 7B 8E
        inc     $061B                                          ; 8640 EE 1B 06
        jsr     L8628                                          ; 8643 20 28 86
        ldy     #$C8                                           ; 8646 A0 C8
L8648:
        lda     ($18),y                                        ; 8648 B1 18
        sta     $0309,y                                        ; 864A 99 09 03
        dey                                                    ; 864D 88
        bne     L8648                                          ; 864E D0 F8
        lda     $0618                                          ; 8650 AD 18 06
        clc                                                    ; 8653 18
        adc     #$C8                                           ; 8654 69 C8
        sta     $0618                                          ; 8656 8D 18 06
        jsr     L8D5E                                          ; 8659 20 5E 8D
L865C:
        ldy     #$08                                           ; 865C A0 08
        jsr     L8FBB                                          ; 865E 20 BB 8F
        lda     $0598                                          ; 8661 AD 98 05
        bne     L8676                                          ; 8664 D0 10
        ldy     $0618                                          ; 8666 AC 18 06
        cpy     #$FF                                           ; 8669 C0 FF
        bcc     L8679                                          ; 866B 90 0C
        beq     L8679                                          ; 866D F0 0A
        lda     $0619                                          ; 866F AD 19 06
        cmp     #$03                                           ; 8672 C9 03
        bcc     L8679                                          ; 8674 90 03
L8676:
        jmp     L871B                                          ; 8676 4C 1B 87

; ----------------------------------------------------------------------------
L8679:
        jsr     L8628                                          ; 8679 20 28 86
        lda     ($18),y                                        ; 867C B1 18
        jsr     L8608                                          ; 867E 20 08 86
        cmp     #$08                                           ; 8681 C9 08
        beq     L86B9                                          ; 8683 F0 34
        bcs     L86D2                                          ; 8685 B0 4B
        sta     $0572                                          ; 8687 8D 72 05
        jsr     L8628                                          ; 868A 20 28 86
        ldy     $0618                                          ; 868D AC 18 06
        lda     ($18),y                                        ; 8690 B1 18
        jsr     L8608                                          ; 8692 20 08 86
        sta     tetrominoOrientation_A                         ; 8695 8D 73 05
        sta     tetrominoOrientation_B                         ; 8698 8D 86 05
        jsr     L8E9C                                          ; 869B 20 9C 8E
        ldx     #$FF                                           ; 869E A2 FF
        stx     $0574                                          ; 86A0 8E 74 05
        ldx     #$0F                                           ; 86A3 A2 0F
        stx     tetrominoX_A                                   ; 86A5 8E 70 05
        stx     tetrominoX_B                                   ; 86A8 8E 84 05
        ldy     #$06                                           ; 86AB A0 06
        sty     tetrominoY_A                                   ; 86AD 8C 71 05
        sty     tetrominoY_B                                   ; 86B0 8C 85 05
        jsr     L8D36                                          ; 86B3 20 36 8D
        jmp     L865C                                          ; 86B6 4C 5C 86

; ----------------------------------------------------------------------------
L86B9:
        ldx     #$00                                           ; 86B9 A2 00
        jsr     L93C6                                          ; 86BB 20 C6 93
        ldx     tetrominoOrientation_A                         ; 86BE AE 73 05
        inx                                                    ; 86C1 E8
        inx                                                    ; 86C2 E8
        cpx     #$08                                           ; 86C3 E0 08
        bcc     L86C9                                          ; 86C5 90 02
        ldx     #$00                                           ; 86C7 A2 00
L86C9:
        stx     tetrominoOrientation_B                         ; 86C9 8E 86 05
        jsr     L8CC8                                          ; 86CC 20 C8 8C
        jmp     L865C                                          ; 86CF 4C 5C 86

; ----------------------------------------------------------------------------
L86D2:
        cmp     #$09                                           ; 86D2 C9 09
        bne     L86DC                                          ; 86D4 D0 06
        dec     tetrominoX_B                                   ; 86D6 CE 84 05
        jmp     L86E3                                          ; 86D9 4C E3 86

; ----------------------------------------------------------------------------
L86DC:
        cmp     #$0A                                           ; 86DC C9 0A
        bne     L86EE                                          ; 86DE D0 0E
        inc     tetrominoX_B                                   ; 86E0 EE 84 05
L86E3:
        ldx     #$04                                           ; 86E3 A2 04
        jsr     L93C6                                          ; 86E5 20 C6 93
        jsr     L8CC8                                          ; 86E8 20 C8 8C
        jmp     L865C                                          ; 86EB 4C 5C 86

; ----------------------------------------------------------------------------
L86EE:
        cmp     #$0C                                           ; 86EE C9 0C
        bne     L86FB                                          ; 86F0 D0 09
        inc     tetrominoY_B                                   ; 86F2 EE 85 05
        jsr     L8CC8                                          ; 86F5 20 C8 8C
        jmp     L865C                                          ; 86F8 4C 5C 86

; ----------------------------------------------------------------------------
L86FB:
        cmp     #$0D                                           ; 86FB C9 0D
        bne     L8711                                          ; 86FD D0 12
        ldx     tetrominoX_A                                   ; 86FF AE 70 05
        stx     tetrominoX_B                                   ; 8702 8E 84 05
        ldy     tetrominoY_A                                   ; 8705 AC 71 05
        sty     tetrominoY_B                                   ; 8708 8C 85 05
        jsr     L8B52                                          ; 870B 20 52 8B
        jmp     L865C                                          ; 870E 4C 5C 86

; ----------------------------------------------------------------------------
L8711:
        cmp     #$0B                                           ; 8711 C9 0B
        bne     L871B                                          ; 8713 D0 06
        jsr     L8A92                                          ; 8715 20 92 8A
        jmp     L865C                                          ; 8718 4C 5C 86

; ----------------------------------------------------------------------------
L871B:
        jsr     L8CE7                                          ; 871B 20 E7 8C
        lda     rngSeed                                        ; 871E A5 56
        and     #$02                                           ; 8720 29 02
        jsr     L9D54                                          ; 8722 20 54 9D
        lda     $0598                                          ; 8725 AD 98 05
        bne     L872F                                          ; 8728 D0 05
        ldy     #$5A                                           ; 872A A0 5A
        jsr     L8FBB                                          ; 872C 20 BB 8F
L872F:
        dec     $061B                                          ; 872F CE 1B 06
        rts                                                    ; 8732 60

; ----------------------------------------------------------------------------
L8733:
        ldx     #$FF                                           ; 8733 A2 FF
        stx     $0574                                          ; 8735 8E 74 05
        inx                                                    ; 8738 E8
        stx     $0618                                          ; 8739 8E 18 06
        stx     $0619                                          ; 873C 8E 19 06
        stx     $061A                                          ; 873F 8E 1A 06
        stx     $0598                                          ; 8742 8E 98 05
        stx     $057F                                          ; 8745 8E 7F 05
        jsr     L8628                                          ; 8748 20 28 86
        ldx     #$19                                           ; 874B A2 19
        stx     $0580                                          ; 874D 8E 80 05
        ldy     #$00                                           ; 8750 A0 00
        jsr     L8C74                                          ; 8752 20 74 8C
        ldy     #$00                                           ; 8755 A0 00
        lda     ($18),y                                        ; 8757 B1 18
        jsr     L8608                                          ; 8759 20 08 86
        sta     $0596                                          ; 875C 8D 96 05
        tay                                                    ; 875F A8
        ldx     L8914,y                                        ; 8760 BE 14 89
        stx     $0597                                          ; 8763 8E 97 05
        ldy     #$00                                           ; 8766 A0 00
        lda     ($18),y                                        ; 8768 B1 18
        jsr     L8608                                          ; 876A 20 08 86
        sta     $0595                                          ; 876D 8D 95 05
        jsr     L91EE                                          ; 8770 20 EE 91
        rts                                                    ; 8773 60

; ----------------------------------------------------------------------------
L8774:
        ldx     #$08                                           ; 8774 A2 08
        lda     #$03                                           ; 8776 A9 03
        sta     $2A                                            ; 8778 85 2A
        lda     #$00                                           ; 877A A9 00
        sta     $0598                                          ; 877C 8D 98 05
        ldy     #$07                                           ; 877F A0 07
L8781:
        sty     $1C                                            ; 8781 84 1C
        lda     $0587,y                                        ; 8783 B9 87 05
        bne     L8797                                          ; 8786 D0 0F
        lda     $0598                                          ; 8788 AD 98 05
        bne     L8795                                          ; 878B D0 08
        lda     #$32                                           ; 878D A9 32
        dec     $0598                                          ; 878F CE 98 05
        jmp     L8797                                          ; 8792 4C 97 87

; ----------------------------------------------------------------------------
L8795:
        lda     #$0A                                           ; 8795 A9 0A
L8797:
        ldy     #$02                                           ; 8797 A0 02
        jsr     L9323                                          ; 8799 20 23 93
        inc     $0598                                          ; 879C EE 98 05
        inx                                                    ; 879F E8
        ldy     $1C                                            ; 87A0 A4 1C
        dey                                                    ; 87A2 88
        bpl     L8781                                          ; 87A3 10 DC
        jsr     L9054                                          ; 87A5 20 54 90
        rts                                                    ; 87A8 60

; ----------------------------------------------------------------------------
L87A9:
        .byte   $05,$07,$09,$0B,$0D,$05,$07,$09                ; 87A9 05 07 09 0B 0D 05 07 09
        .byte   $0B,$0D,$15,$17,$19,$15,$17,$19                ; 87B1 0B 0D 15 17 19 15 17 19
L87B9:
        .byte   $09,$09,$09,$09,$09,$0B,$0B,$0B                ; 87B9 09 09 09 09 09 0B 0B 0B
        .byte   $0B,$0B,$09,$09,$09,$0B,$0B,$0B                ; 87C1 0B 0B 09 09 09 0B 0B 0B
L87C9:
        .byte   $00,$0A                                        ; 87C9 00 0A
L87CB:
        .byte   $05,$03                                        ; 87CB 05 03
L87CD:
        .byte   $0A,$06                                        ; 87CD 0A 06
; ----------------------------------------------------------------------------
L87CF:
        ldx     #$00                                           ; 87CF A2 00
        stx     $0596                                          ; 87D1 8E 96 05
        stx     $0595                                          ; 87D4 8E 95 05
        stx     $05B9                                          ; 87D7 8E B9 05
        jsr     L891A                                          ; 87DA 20 1A 89
        lda     #$01                                           ; 87DD A9 01
        jsr     L89DB                                          ; 87DF 20 DB 89
        lda     #$03                                           ; 87E2 A9 03
        sta     $3F                                            ; 87E4 85 3F
L87E6:
        lda     $3F                                            ; 87E6 A5 3F
        bne     L87E6                                          ; 87E8 D0 FC
        jsr     pollController                                 ; 87EA 20 CE 8F
        beq     L87E6                                          ; 87ED F0 F7
        txa                                                    ; 87EF 8A
        and     #$F1                                           ; 87F0 29 F1
        bne     L880E                                          ; 87F2 D0 1A
        ldx     $05B9                                          ; 87F4 AE B9 05
        beq     L8809                                          ; 87F7 F0 10
        ldx     #$00                                           ; 87F9 A2 00
        jsr     L93C6                                          ; 87FB 20 C6 93
        lda     #$03                                           ; 87FE A9 03
        jsr     L89DB                                          ; 8800 20 DB 89
        dec     $05B9                                          ; 8803 CE B9 05
        jsr     L891A                                          ; 8806 20 1A 89
L8809:
        lda     #$14                                           ; 8809 A9 14
        jmp     L8890                                          ; 880B 4C 90 88

; ----------------------------------------------------------------------------
L880E:
        and     #$F0                                           ; 880E 29 F0
        bne     L8831                                          ; 8810 D0 1F
        lda     #$02                                           ; 8812 A9 02
        jsr     L89DB                                          ; 8814 20 DB 89
        inc     $05B9                                          ; 8817 EE B9 05
        ldx     #$18                                           ; 881A A2 18
        jsr     L93C6                                          ; 881C 20 C6 93
        jsr     L891A                                          ; 881F 20 1A 89
        lda     $05B9                                          ; 8822 AD B9 05
        cmp     #$02                                           ; 8825 C9 02
        bcs     L882E                                          ; 8827 B0 05
        lda     #$14                                           ; 8829 A9 14
        jmp     L8890                                          ; 882B 4C 90 88

; ----------------------------------------------------------------------------
L882E:
        jmp     L889A                                          ; 882E 4C 9A 88

; ----------------------------------------------------------------------------
L8831:
        pha                                                    ; 8831 48
        ldx     #$14                                           ; 8832 A2 14
        jsr     L93C6                                          ; 8834 20 C6 93
        lda     #$03                                           ; 8837 A9 03
        jsr     L89DB                                          ; 8839 20 DB 89
        pla                                                    ; 883C 68
        tax                                                    ; 883D AA
        ldy     $05B9                                          ; 883E AC B9 05
        and     #$10                                           ; 8841 29 10
        beq     L8854                                          ; 8843 F0 0F
        lda     $0595,y                                        ; 8845 B9 95 05
        sec                                                    ; 8848 38
        sbc     L87CB,y                                        ; 8849 F9 CB 87
        bcs     L888B                                          ; 884C B0 3D
        adc     L87CD,y                                        ; 884E 79 CD 87
        jmp     L888B                                          ; 8851 4C 8B 88

; ----------------------------------------------------------------------------
L8854:
        txa                                                    ; 8854 8A
        and     #$20                                           ; 8855 29 20
        beq     L886B                                          ; 8857 F0 12
        lda     $0595,y                                        ; 8859 B9 95 05
        clc                                                    ; 885C 18
        adc     L87CB,y                                        ; 885D 79 CB 87
        cmp     L87CD,y                                        ; 8860 D9 CD 87
        bcc     L888B                                          ; 8863 90 26
        sbc     L87CD,y                                        ; 8865 F9 CD 87
        jmp     L888B                                          ; 8868 4C 8B 88

; ----------------------------------------------------------------------------
L886B:
        txa                                                    ; 886B 8A
        and     #$40                                           ; 886C 29 40
        beq     L887F                                          ; 886E F0 0F
        ldx     $0595,y                                        ; 8870 BE 95 05
        dex                                                    ; 8873 CA
        txa                                                    ; 8874 8A
        bpl     L888B                                          ; 8875 10 14
        ldx     L87CD,y                                        ; 8877 BE CD 87
        dex                                                    ; 887A CA
        txa                                                    ; 887B 8A
        jmp     L888B                                          ; 887C 4C 8B 88

; ----------------------------------------------------------------------------
L887F:
        ldx     $0595,y                                        ; 887F BE 95 05
        inx                                                    ; 8882 E8
        txa                                                    ; 8883 8A
        cmp     L87CD,y                                        ; 8884 D9 CD 87
        bcc     L888B                                          ; 8887 90 02
        lda     #$00                                           ; 8889 A9 00
L888B:
        sta     $0595,y                                        ; 888B 99 95 05
        lda     #$0C                                           ; 888E A9 0C
L8890:
        sta     $3F                                            ; 8890 85 3F
        lda     #$01                                           ; 8892 A9 01
        jsr     L89DB                                          ; 8894 20 DB 89
        jmp     L87E6                                          ; 8897 4C E6 87

; ----------------------------------------------------------------------------
L889A:
        lda     $0614                                          ; 889A AD 14 06
        jsr     LBC1F                                          ; 889D 20 1F BC
        lda     #$01                                           ; 88A0 A9 01
        jsr     L8977                                          ; 88A2 20 77 89
        jsr     L8A83                                          ; 88A5 20 83 8A
L88A8:
        jsr     pollController                                 ; 88A8 20 CE 8F
        txa                                                    ; 88AB 8A
        beq     L88A8                                          ; 88AC F0 FA
        and     #$F1                                           ; 88AE 29 F1
        beq     L88F2                                          ; 88B0 F0 40
        and     #$01                                           ; 88B2 29 01
        bne     L88E3                                          ; 88B4 D0 2D
        txa                                                    ; 88B6 8A
        pha                                                    ; 88B7 48
        lda     #$03                                           ; 88B8 A9 03
        jsr     L8977                                          ; 88BA 20 77 89
        pla                                                    ; 88BD 68
        and     #$50                                           ; 88BE 29 50
        bne     L88D0                                          ; 88C0 D0 0E
        ldx     $0614                                          ; 88C2 AE 14 06
        inx                                                    ; 88C5 E8
        cpx     maxMenuOptions                                 ; 88C6 EC 15 06
        bcc     L88DD                                          ; 88C9 90 12
        ldx     #$FF                                           ; 88CB A2 FF
        jmp     L88DD                                          ; 88CD 4C DD 88

; ----------------------------------------------------------------------------
L88D0:
        ldx     $0614                                          ; 88D0 AE 14 06
        bmi     L88D9                                          ; 88D3 30 04
        dex                                                    ; 88D5 CA
        jmp     L88DD                                          ; 88D6 4C DD 88

; ----------------------------------------------------------------------------
L88D9:
        ldx     maxMenuOptions                                 ; 88D9 AE 15 06
        dex                                                    ; 88DC CA
L88DD:
        stx     $0614                                          ; 88DD 8E 14 06
        jmp     L889A                                          ; 88E0 4C 9A 88

; ----------------------------------------------------------------------------
L88E3:
        lda     #$02                                           ; 88E3 A9 02
        jsr     L8977                                          ; 88E5 20 77 89
        ldx     $0596                                          ; 88E8 AE 96 05
        lda     L8914,x                                        ; 88EB BD 14 89
        sta     $0597                                          ; 88EE 8D 97 05
        rts                                                    ; 88F1 60

; ----------------------------------------------------------------------------
L88F2:
        ldx     #$00                                           ; 88F2 A2 00
        jsr     L93C6                                          ; 88F4 20 C6 93
        lda     #$03                                           ; 88F7 A9 03
        jsr     L8977                                          ; 88F9 20 77 89
        dec     $05B9                                          ; 88FC CE B9 05
        jsr     L891A                                          ; 88FF 20 1A 89
        lda     #$14                                           ; 8902 A9 14
        jmp     L8890                                          ; 8904 4C 90 88

; ----------------------------------------------------------------------------
L8907:
        .byte   $50,$41,$32,$28,$20,$19,$14,$11                ; 8907 50 41 32 28 20 19 14 11
        .byte   $0F,$0D,$08,$06,$05                            ; 890F 0F 0D 08 06 05
L8914:
        .byte   $00,$03,$06,$08,$0A,$0C                        ; 8914 00 03 06 08 0A 0C
; ----------------------------------------------------------------------------
L891A:
        ldx     #$00                                           ; 891A A2 00
L891C:
        lda     #$01                                           ; 891C A9 01
        stx     $1C                                            ; 891E 86 1C
        cpx     $05B9                                          ; 8920 EC B9 05
        beq     L892B                                          ; 8923 F0 06
        lda     #$02                                           ; 8925 A9 02
        bcc     L892B                                          ; 8927 90 02
        lda     #$03                                           ; 8929 A9 03
L892B:
        sta     $2A                                            ; 892B 85 2A
        txa                                                    ; 892D 8A
        asl     a                                              ; 892E 0A
        asl     a                                              ; 892F 0A
        adc     $1C                                            ; 8930 65 1C
        sta     $1D                                            ; 8932 85 1D
        tay                                                    ; 8934 A8
        lda     L8965,x                                        ; 8935 BD 65 89
        tay                                                    ; 8938 A8
        lda     #$05                                           ; 8939 A9 05
        sta     tmp14                                          ; 893B 85 14
        lda     L8962,x                                        ; 893D BD 62 89
        tax                                                    ; 8940 AA
L8941:
        stx     tetrominoX_A                                   ; 8941 8E 70 05
        ldx     $1D                                            ; 8944 A6 1D
        lda     L8968,x                                        ; 8946 BD 68 89
        inc     $1D                                            ; 8949 E6 1D
        ldx     tetrominoX_A                                   ; 894B AE 70 05
        jsr     L9323                                          ; 894E 20 23 93
        inx                                                    ; 8951 E8
        inx                                                    ; 8952 E8
        dec     tmp14                                          ; 8953 C6 14
        bne     L8941                                          ; 8955 D0 EA
        ldx     $1C                                            ; 8957 A6 1C
        inx                                                    ; 8959 E8
        cpx     #$03                                           ; 895A E0 03
        bcc     L891C                                          ; 895C 90 BE
        jsr     L9054                                          ; 895E 20 54 90
        rts                                                    ; 8961 60

; ----------------------------------------------------------------------------
L8962:
        .byte   $05,$13,$0B                                    ; 8962 05 13 0B
L8965:
        .byte   $05,$05,$11                                    ; 8965 05 05 11
L8968:
        .byte   $2C,$5B,$5D,$2C,$2C,$2C,$71,$72                ; 8968 2C 5B 5D 2C 2C 2C 71 72
        .byte   $2C,$2C,$2C,$57,$59,$2C,$2C                    ; 8970 2C 2C 2C 57 59 2C 2C
; ----------------------------------------------------------------------------
L8977:
        ldy     debugExtraMusic                                ; 8977 AC 04 C0
        bne     L89AC                                          ; 897A D0 30
        sta     $2A                                            ; 897C 85 2A
        ldx     $0614                                          ; 897E AE 14 06
        inx                                                    ; 8981 E8
        stx     tmp15                                          ; 8982 86 15
        txa                                                    ; 8984 8A
        asl     a                                              ; 8985 0A
        pha                                                    ; 8986 48
        asl     a                                              ; 8987 0A
        asl     a                                              ; 8988 0A
        adc     tmp15                                          ; 8989 65 15
        sta     tmp15                                          ; 898B 85 15
        pla                                                    ; 898D 68
        clc                                                    ; 898E 18
        adc     #$15                                           ; 898F 69 15
        tay                                                    ; 8991 A8
        lda     #$09                                           ; 8992 A9 09
        sta     tmp14                                          ; 8994 85 14
        ldx     #$07                                           ; 8996 A2 07
L8998:
        stx     tmp14                                          ; 8998 86 14
        ldx     tmp15                                          ; 899A A6 15
        lda     L89AD,x                                        ; 899C BD AD 89
        inc     tmp15                                          ; 899F E6 15
        ldx     tmp14                                          ; 89A1 A6 14
        jsr     L9323                                          ; 89A3 20 23 93
        inx                                                    ; 89A6 E8
        inx                                                    ; 89A7 E8
        cpx     #$19                                           ; 89A8 E0 19
        bcc     L8998                                          ; 89AA 90 EC
L89AC:
        rts                                                    ; 89AC 60

; ----------------------------------------------------------------------------
L89AD:
        .byte   $2C,$2C,$58,$2E,$72,$5E,$2C,$2C                ; 89AD 2C 2C 58 2E 72 5E 2C 2C
        .byte   $2C,$2C,$2C,$5B,$5A,$72,$5B,$59                ; 89B5 2C 2C 2C 5B 5A 72 5B 59
        .byte   $2C,$2C,$2C,$2C,$5F,$5F,$72,$5C                ; 89BD 2C 2C 2C 2C 5F 5F 72 5C
        .byte   $2C,$2C,$2C,$2C,$2C,$5B,$71,$5F                ; 89C5 2C 2C 2C 2C 2C 5B 71 5F
        .byte   $2C,$2C,$2C,$2C                                ; 89CD 2C 2C 2C 2C
L89D1:
        .byte   $75,$77,$79,$7B,$7D,$7F,$83,$87                ; 89D1 75 77 79 7B 7D 7F 83 87
        .byte   $8B,$8F                                        ; 89D9 8B 8F
; ----------------------------------------------------------------------------
L89DB:
        sta     $2A                                            ; 89DB 85 2A
        ldy     $05B9                                          ; 89DD AC B9 05
        lda     L87C9,y                                        ; 89E0 B9 C9 87
        clc                                                    ; 89E3 18
        adc     $0595,y                                        ; 89E4 79 95 05
        tax                                                    ; 89E7 AA
        lda     L87B9,x                                        ; 89E8 BD B9 87
        sta     tetrominoY_A                                   ; 89EB 8D 71 05
        lda     L87A9,x                                        ; 89EE BD A9 87
        tax                                                    ; 89F1 AA
        lda     $0595,y                                        ; 89F2 B9 95 05
        tay                                                    ; 89F5 A8
        lda     L89D1,y                                        ; 89F6 B9 D1 89
        ldy     tetrominoY_A                                   ; 89F9 AC 71 05
        jsr     L9335                                          ; 89FC 20 35 93
        rts                                                    ; 89FF 60

; ----------------------------------------------------------------------------
L8A00:
        lda     tetrominoOrientation_A                         ; 8A00 AD 73 05
        pha                                                    ; 8A03 48
        clc                                                    ; 8A04 18
        adc     #$02                                           ; 8A05 69 02
        cmp     #$08                                           ; 8A07 C9 08
        bcc     L8A0D                                          ; 8A09 90 02
        lda     #$00                                           ; 8A0B A9 00
L8A0D:
        sta     tetrominoOrientation_B                         ; 8A0D 8D 86 05
        sta     tetrominoOrientation_A                         ; 8A10 8D 73 05
        jsr     L8AB4                                          ; 8A13 20 B4 8A
        pla                                                    ; 8A16 68
        sta     tetrominoOrientation_A                         ; 8A17 8D 73 05
        ldx     #$00                                           ; 8A1A A2 00
        rts                                                    ; 8A1C 60

; ----------------------------------------------------------------------------
L8A1D:
        lda     $3F                                            ; 8A1D A5 3F
        pha                                                    ; 8A1F 48
        jsr     L8CE7                                          ; 8A20 20 E7 8C
        ldx     #$C8                                           ; 8A23 A2 C8
; would be easier to read as playfield-1 and playfieldStash-1
@copyLoop:
        lda     $0309,x                                        ; 8A25 BD 09 03
        sta     playfield+199,x                                ; 8A28 9D D1 03
        dex                                                    ; 8A2B CA
        bne     @copyLoop                                      ; 8A2C D0 F7
        ldx     #$C8                                           ; 8A2E A2 C8
L8A30:
        lda     playfieldPausedTiles,x                         ; 8A30 BD C0 AE
        sta     $0309,x                                        ; 8A33 9D 09 03
        dex                                                    ; 8A36 CA
        bne     L8A30                                          ; 8A37 D0 F7
        jsr     L976C                                          ; 8A39 20 6C 97
        lda     #$06                                           ; 8A3C A9 06
        jsr     L92DD                                          ; 8A3E 20 DD 92
        jsr     L8D5E                                          ; 8A41 20 5E 8D
        jsr     L8A83                                          ; 8A44 20 83 8A
L8A47:
        lda     startStorage                                   ; 8A47 A5 3A
        beq     L8A47                                          ; 8A49 F0 FC
        jsr     L8A83                                          ; 8A4B 20 83 8A
        ldx     #$C8                                           ; 8A4E A2 C8
L8A50:
        lda     playfield+199,x                                ; 8A50 BD D1 03
        sta     $0309,x                                        ; 8A53 9D 09 03
        dex                                                    ; 8A56 CA
        bne     L8A50                                          ; 8A57 D0 F7
        jsr     L91EE                                          ; 8A59 20 EE 91
        lda     #$06                                           ; 8A5C A9 06
        jsr     L92DD                                          ; 8A5E 20 DD 92
        jsr     L8D5E                                          ; 8A61 20 5E 8D
        dec     $0574                                          ; 8A64 CE 74 05
        ldx     tetrominoX_A                                   ; 8A67 AE 70 05
        ldy     tetrominoY_A                                   ; 8A6A AC 71 05
        jsr     L8D36                                          ; 8A6D 20 36 8D
        pla                                                    ; 8A70 68
        sta     $3F                                            ; 8A71 85 3F
        rts                                                    ; 8A73 60

; ----------------------------------------------------------------------------
L8A74:
        lda     $0579                                          ; 8A74 AD 79 05
        eor     #$FF                                           ; 8A77 49 FF
        sta     $0579                                          ; 8A79 8D 79 05
        jsr     L8EFD                                          ; 8A7C 20 FD 8E
        jsr     L8A83                                          ; 8A7F 20 83 8A
        rts                                                    ; 8A82 60

; ----------------------------------------------------------------------------
L8A83:
        lda     $3F                                            ; 8A83 A5 3F
        pha                                                    ; 8A85 48
        lda     #$00                                           ; 8A86 A9 00
        sta     nmiWaitVar                                     ; 8A88 85 3C
@waitForNmi:
        lda     nmiWaitVar                                     ; 8A8A A5 3C
        beq     @waitForNmi                                    ; 8A8C F0 FC
        pla                                                    ; 8A8E 68
        sta     $3F                                            ; 8A8F 85 3F
        rts                                                    ; 8A91 60

; ----------------------------------------------------------------------------
L8A92:
        ldx     #$08                                           ; 8A92 A2 08
        jsr     L93C6                                          ; 8A94 20 C6 93
L8A97:
        inc     tetrominoY_B                                   ; 8A97 EE 85 05
        inc     $0581                                          ; 8A9A EE 81 05
        bne     L8AA2                                          ; 8A9D D0 03
        inc     $0582                                          ; 8A9F EE 82 05
L8AA2:
        jsr     L8AB4                                          ; 8AA2 20 B4 8A
        lda     $0598                                          ; 8AA5 AD 98 05
        beq     L8A97                                          ; 8AA8 F0 ED
        dec     tetrominoY_B                                   ; 8AAA CE 85 05
        jsr     L8B52                                          ; 8AAD 20 52 8B
        jsr     L8A83                                          ; 8AB0 20 83 8A
        rts                                                    ; 8AB3 60

; ----------------------------------------------------------------------------
L8AB4:
        jsr     L8E9C                                          ; 8AB4 20 9C 8E
        ldy     #$00                                           ; 8AB7 A0 00
        sty     $0598                                          ; 8AB9 8C 98 05
L8ABC:
        sty     $1C                                            ; 8ABC 84 1C
        lda     ($43),y                                        ; 8ABE B1 43
        beq     L8AED                                          ; 8AC0 F0 2B
        sta     tmp14                                          ; 8AC2 85 14
        lda     $1C                                            ; 8AC4 A5 1C
        and     #$03                                           ; 8AC6 29 03
        clc                                                    ; 8AC8 18
        adc     tetrominoX_B                                   ; 8AC9 6D 84 05
        tax                                                    ; 8ACC AA
        lda     $1C                                            ; 8ACD A5 1C
        and     #$0C                                           ; 8ACF 29 0C
        lsr     a                                              ; 8AD1 4A
        lsr     a                                              ; 8AD2 4A
        clc                                                    ; 8AD3 18
        adc     tetrominoY_B                                   ; 8AD4 6D 85 05
        tay                                                    ; 8AD7 A8
        lda     $0599                                          ; 8AD8 AD 99 05
        beq     L8AE5                                          ; 8ADB F0 08
        lda     tmp14                                          ; 8ADD A5 14
        jsr     L8C2F                                          ; 8ADF 20 2F 8C
        jmp     L8AED                                          ; 8AE2 4C ED 8A

; ----------------------------------------------------------------------------
L8AE5:
        jsr     L8AF5                                          ; 8AE5 20 F5 8A
        lda     $0598                                          ; 8AE8 AD 98 05
        bne     L8AF4                                          ; 8AEB D0 07
L8AED:
        ldy     $1C                                            ; 8AED A4 1C
        iny                                                    ; 8AEF C8
        cpy     #$10                                           ; 8AF0 C0 10
        bcc     L8ABC                                          ; 8AF2 90 C8
L8AF4:
        rts                                                    ; 8AF4 60

; ----------------------------------------------------------------------------
L8AF5:
        cpx     #$0B                                           ; 8AF5 E0 0B
        beq     L8B0A                                          ; 8AF7 F0 11
        cpx     #$16                                           ; 8AF9 E0 16
        beq     L8B0A                                          ; 8AFB F0 0D
        cpy     #$1A                                           ; 8AFD C0 1A
        bcs     L8B0A                                          ; 8AFF B0 09
        jsr     L8C3C                                          ; 8B01 20 3C 8C
        tax                                                    ; 8B04 AA
        lda     playfield,x                                    ; 8B05 BD 0A 03
        beq     L8B0D                                          ; 8B08 F0 03
L8B0A:
        inc     $0598                                          ; 8B0A EE 98 05
L8B0D:
        rts                                                    ; 8B0D 60

; ----------------------------------------------------------------------------
L8B0E:
        ldy     #$12                                           ; 8B0E A0 12
L8B10:
        sty     $1C                                            ; 8B10 84 1C
        tya                                                    ; 8B12 98
        jsr     L8E93                                          ; 8B13 20 93 8E
        tax                                                    ; 8B16 AA
        ldy     #$14                                           ; 8B17 A0 14
        sta     $1D                                            ; 8B19 85 1D
        lda     #$37                                           ; 8B1B A9 37
L8B1D:
        sta     playfield,x                                    ; 8B1D 9D 0A 03
        inx                                                    ; 8B20 E8
        dey                                                    ; 8B21 88
        bne     L8B1D                                          ; 8B22 D0 F9
        jsr     L8C1F                                          ; 8B24 20 1F 8C
        jsr     L8D5E                                          ; 8B27 20 5E 8D
        ldy     $1C                                            ; 8B2A A4 1C
        dey                                                    ; 8B2C 88
        dey                                                    ; 8B2D 88
        bpl     L8B10                                          ; 8B2E 10 E0
        dec     $059E                                          ; 8B30 CE 9E 05
        jsr     L8F49                                          ; 8B33 20 49 8F
        ldy     #$14                                           ; 8B36 A0 14
        jsr     L902E                                          ; 8B38 20 2E 90
        inc     $059E                                          ; 8B3B EE 9E 05
        jsr     L8F49                                          ; 8B3E 20 49 8F
        ldy     #$14                                           ; 8B41 A0 14
        jsr     L902E                                          ; 8B43 20 2E 90
        dec     $059E                                          ; 8B46 CE 9E 05
        jsr     L8F49                                          ; 8B49 20 49 8F
        ldy     #$28                                           ; 8B4C A0 28
        jsr     L902E                                          ; 8B4E 20 2E 90
        rts                                                    ; 8B51 60

; ----------------------------------------------------------------------------
L8B52:
        jsr     L8CE7                                          ; 8B52 20 E7 8C
        lda     #$01                                           ; 8B55 A9 01
        sta     $0599                                          ; 8B57 8D 99 05
        jsr     L8AB4                                          ; 8B5A 20 B4 8A
        dec     $0599                                          ; 8B5D CE 99 05
        ldx     #$0C                                           ; 8B60 A2 0C
        jsr     L93C6                                          ; 8B62 20 C6 93
        jsr     L8D5E                                          ; 8B65 20 5E 8D
        jsr     L8D74                                          ; 8B68 20 74 8D
        jsr     L8DBE                                          ; 8B6B 20 BE 8D
        jsr     L8D5E                                          ; 8B6E 20 5E 8D
        jsr     L8E62                                          ; 8B71 20 62 8E
        lda     $061B                                          ; 8B74 AD 1B 06
        bne     L8B81                                          ; 8B77 D0 08
        lda     $057F                                          ; 8B79 AD 7F 05
        cmp     $0580                                          ; 8B7C CD 80 05
        bcs     L8B82                                          ; 8B7F B0 01
L8B81:
        rts                                                    ; 8B81 60

; ----------------------------------------------------------------------------
L8B82:
        jsr     L8CE7                                          ; 8B82 20 E7 8C
        jsr     L8C1F                                          ; 8B85 20 1F 8C
        ldx     #$C8                                           ; 8B88 A2 C8
L8B8A:
        lda     #$00                                           ; 8B8A A9 00
        sta     playfield+199,x                                ; 8B8C 9D D1 03
        dex                                                    ; 8B8F CA
        bne     L8B8A                                          ; 8B90 D0 F8
        ldx     #$00                                           ; 8B92 A2 00
        stx     tmp14                                          ; 8B94 86 14
L8B96:
        ldy     #$0A                                           ; 8B96 A0 0A
L8B98:
        lda     playfield,x                                    ; 8B98 BD 0A 03
        bne     L8BAB                                          ; 8B9B D0 0E
        inx                                                    ; 8B9D E8
        dey                                                    ; 8B9E 88
        bne     L8B98                                          ; 8B9F D0 F7
        inc     tmp14                                          ; 8BA1 E6 14
        lda     tmp14                                          ; 8BA3 A5 14
        cmp     #$14                                           ; 8BA5 C9 14
        bcc     L8B96                                          ; 8BA7 90 ED
        bcs     L8BD9                                          ; 8BA9 B0 2E
L8BAB:
        lda     #$14                                           ; 8BAB A9 14
        sec                                                    ; 8BAD 38
        sbc     $0597                                          ; 8BAE ED 97 05
        cmp     tmp14                                          ; 8BB1 C5 14
        bcc     L8BB7                                          ; 8BB3 90 02
        lda     tmp14                                          ; 8BB5 A5 14
L8BB7:
        jsr     L8E93                                          ; 8BB7 20 93 8E
        tax                                                    ; 8BBA AA
        lda     #$14                                           ; 8BBB A9 14
        sec                                                    ; 8BBD 38
        sbc     $0597                                          ; 8BBE ED 97 05
        cmp     #$14                                           ; 8BC1 C9 14
        beq     L8BD9                                          ; 8BC3 F0 14
        jsr     L8E93                                          ; 8BC5 20 93 8E
        tay                                                    ; 8BC8 A8
L8BC9:
        lda     playfield,x                                    ; 8BC9 BD 0A 03
        sta     playfieldStash,y                               ; 8BCC 99 D2 03
        inx                                                    ; 8BCF E8
        cpx     #$C8                                           ; 8BD0 E0 C8
        bcs     L8BD9                                          ; 8BD2 B0 05
        iny                                                    ; 8BD4 C8
        cpy     #$C8                                           ; 8BD5 C0 C8
        bcc     L8BC9                                          ; 8BD7 90 F0
L8BD9:
        jsr     L962E                                          ; 8BD9 20 2E 96
        jsr     L8C72                                          ; 8BDC 20 72 8C
        jsr     L8D5E                                          ; 8BDF 20 5E 8D
        lda     #$06                                           ; 8BE2 A9 06
        jsr     L92DD                                          ; 8BE4 20 DD 92
        inc     $0595                                          ; 8BE7 EE 95 05
        ldx     #$C8                                           ; 8BEA A2 C8
L8BEC:
        lda     playfield+199,x                                ; 8BEC BD D1 03
        sta     $0309,x                                        ; 8BEF 9D 09 03
        dex                                                    ; 8BF2 CA
        bne     L8BEC                                          ; 8BF3 D0 F7
        lda     $0595                                          ; 8BF5 AD 95 05
        cmp     #$0A                                           ; 8BF8 C9 0A
        bcc     L8C18                                          ; 8BFA 90 1C
        jsr     L8304                                          ; 8BFC 20 04 83
        lda     #$00                                           ; 8BFF A9 00
        sta     $0595                                          ; 8C01 8D 95 05
        ldx     $0596                                          ; 8C04 AE 96 05
        cpx     #$05                                           ; 8C07 E0 05
        beq     L8C0C                                          ; 8C09 F0 01
        inx                                                    ; 8C0B E8
L8C0C:
        stx     $0596                                          ; 8C0C 8E 96 05
        ldy     L8914,x                                        ; 8C0F BC 14 89
        sty     $0597                                          ; 8C12 8C 97 05
        jsr     L8C74                                          ; 8C15 20 74 8C
L8C18:
        ldx     #$FF                                           ; 8C18 A2 FF
        txs                                                    ; 8C1A 9A
        jmp     L8428                                          ; 8C1B 4C 28 84

; ----------------------------------------------------------------------------
        rts                                                    ; 8C1E 60

; ----------------------------------------------------------------------------
L8C1F:
        ldx     #$00                                           ; 8C1F A2 00
        lda     #$F0                                           ; 8C21 A9 F0
L8C23:
        sta     oamStaging,x                                   ; 8C23 9D 00 02
        inx                                                    ; 8C26 E8
        inx                                                    ; 8C27 E8
        inx                                                    ; 8C28 E8
        inx                                                    ; 8C29 E8
        cpx     #$10                                           ; 8C2A E0 10
        bcc     L8C23                                          ; 8C2C 90 F5
        rts                                                    ; 8C2E 60

; ----------------------------------------------------------------------------
L8C2F:
        pha                                                    ; 8C2F 48
        jsr     L8C3C                                          ; 8C30 20 3C 8C
        tax                                                    ; 8C33 AA
        pla                                                    ; 8C34 68
        clc                                                    ; 8C35 18
        adc     #$32                                           ; 8C36 69 32
        sta     playfield,x                                    ; 8C38 9D 0A 03
        rts                                                    ; 8C3B 60

; ----------------------------------------------------------------------------
L8C3C:
        txa                                                    ; 8C3C 8A
        sec                                                    ; 8C3D 38
        sbc     #$0C                                           ; 8C3E E9 0C
        sta     tmp15                                          ; 8C40 85 15
        tya                                                    ; 8C42 98
        sec                                                    ; 8C43 38
        sbc     #$06                                           ; 8C44 E9 06
        jsr     L8E93                                          ; 8C46 20 93 8E
        adc     tmp15                                          ; 8C49 65 15
        rts                                                    ; 8C4B 60

; ----------------------------------------------------------------------------
L8C4C:
        sta     tmp14                                          ; 8C4C 85 14
        lda     #$00                                           ; 8C4E A9 00
        sta     $2A                                            ; 8C50 85 2A
        ldy     #$1A                                           ; 8C52 A0 1A
L8C54:
        ldx     #$03                                           ; 8C54 A2 03
L8C56:
        lda     tmp14                                          ; 8C56 A5 14
        beq     L8C64                                          ; 8C58 F0 0A
        txa                                                    ; 8C5A 8A
        clc                                                    ; 8C5B 18
        adc     #$3D                                           ; 8C5C 69 3D
        cpy     #$1A                                           ; 8C5E C0 1A
        beq     L8C64                                          ; 8C60 F0 02
        adc     #$0F                                           ; 8C62 69 0F
L8C64:
        jsr     L9323                                          ; 8C64 20 23 93
        inx                                                    ; 8C67 E8
        cpx     #$09                                           ; 8C68 E0 09
        bcc     L8C56                                          ; 8C6A 90 EA
        iny                                                    ; 8C6C C8
        cpy     #$1C                                           ; 8C6D C0 1C
        bcc     L8C54                                          ; 8C6F 90 E3
        rts                                                    ; 8C71 60

; ----------------------------------------------------------------------------
L8C72:
        ldy     #$00                                           ; 8C72 A0 00
L8C74:
        lda     #$00                                           ; 8C74 A9 00
        ldx     #$C8                                           ; 8C76 A2 C8
L8C78:
        sta     $0309,x                                        ; 8C78 9D 09 03
        dex                                                    ; 8C7B CA
        bne     L8C78                                          ; 8C7C D0 FA
        tya                                                    ; 8C7E 98
        beq     L8CC7                                          ; 8C7F F0 46
        jsr     L8E93                                          ; 8C81 20 93 8E
        tay                                                    ; 8C84 A8
        ldx     #$C8                                           ; 8C85 A2 C8
L8C87:
        lda     #$0A                                           ; 8C87 A9 0A
        sta     tmp14                                          ; 8C89 85 14
        lda     rngSeed+5                                      ; 8C8B A5 5B
        and     #$03                                           ; 8C8D 29 03
        sta     tmp15                                          ; 8C8F 85 15
        lda     rngSeed+6                                      ; 8C91 A5 5C
        and     #$03                                           ; 8C93 29 03
        clc                                                    ; 8C95 18
        adc     tmp15                                          ; 8C96 65 15
        adc     #$02                                           ; 8C98 69 02
        sta     tmp15                                          ; 8C9A 85 15
L8C9C:
        lda     tmp15                                          ; 8C9C A5 15
        beq     L8CBD                                          ; 8C9E F0 1D
        cmp     tmp14                                          ; 8CA0 C5 14
        bcs     L8CAB                                          ; 8CA2 B0 07
        jsr     generateNextPseudoRandomNumber                 ; 8CA4 20 92 90
        lda     rngSeed                                        ; 8CA7 A5 56
        bmi     L8CBD                                          ; 8CA9 30 12
L8CAB:
        jsr     generateNextPseudoRandomNumber                 ; 8CAB 20 92 90
        lda     rngSeed+2                                      ; 8CAE A5 58
        and     #$07                                           ; 8CB0 29 07
        cmp     #$06                                           ; 8CB2 C9 06
        bcs     L8CAB                                          ; 8CB4 B0 F5
        adc     #$33                                           ; 8CB6 69 33
        sta     $0309,x                                        ; 8CB8 9D 09 03
        dec     tmp15                                          ; 8CBB C6 15
L8CBD:
        dex                                                    ; 8CBD CA
        dey                                                    ; 8CBE 88
        beq     L8CC7                                          ; 8CBF F0 06
        dec     tmp14                                          ; 8CC1 C6 14
        beq     L8C87                                          ; 8CC3 F0 C2
        bne     L8C9C                                          ; 8CC5 D0 D5
L8CC7:
        rts                                                    ; 8CC7 60

; ----------------------------------------------------------------------------
L8CC8:
        jsr     L8CE7                                          ; 8CC8 20 E7 8C
        dec     $0574                                          ; 8CCB CE 74 05
        lda     tetrominoOrientation_B                         ; 8CCE AD 86 05
        sta     tetrominoOrientation_A                         ; 8CD1 8D 73 05
        jsr     L8E9C                                          ; 8CD4 20 9C 8E
        ldy     tetrominoY_B                                   ; 8CD7 AC 85 05
        sty     tetrominoY_A                                   ; 8CDA 8C 71 05
        ldx     tetrominoX_B                                   ; 8CDD AE 84 05
        stx     tetrominoX_A                                   ; 8CE0 8E 70 05
        jsr     L8D36                                          ; 8CE3 20 36 8D
        rts                                                    ; 8CE6 60

; ----------------------------------------------------------------------------
L8CE7:
        lda     #$00                                           ; 8CE7 A9 00
        sta     $0574                                          ; 8CE9 8D 74 05
        jsr     L8E9C                                          ; 8CEC 20 9C 8E
        ldx     tetrominoX_A                                   ; 8CEF AE 70 05
        ldy     tetrominoY_A                                   ; 8CF2 AC 71 05
        jsr     L8D36                                          ; 8CF5 20 36 8D
        rts                                                    ; 8CF8 60

; ----------------------------------------------------------------------------
L8CF9:
        lda     ($43),y                                        ; 8CF9 B1 43
        bne     L8CFE                                          ; 8CFB D0 01
        rts                                                    ; 8CFD 60

; ----------------------------------------------------------------------------
L8CFE:
        and     $0574                                          ; 8CFE 2D 74 05
        bne     L8D0E                                          ; 8D01 D0 0B
        lda     #$F0                                           ; 8D03 A9 F0
        sta     oamStaging,x                                   ; 8D05 9D 00 02
        sta     oamStaging+3,x                                 ; 8D08 9D 03 02
        jmp     L8D31                                          ; 8D0B 4C 31 8D

; ----------------------------------------------------------------------------
L8D0E:
        clc                                                    ; 8D0E 18
        adc     #$32                                           ; 8D0F 69 32
        sta     oamStaging+1,x                                 ; 8D11 9D 01 02
        tya                                                    ; 8D14 98
        and     #$03                                           ; 8D15 29 03
        clc                                                    ; 8D17 18
        adc     tetrominoX_A                                   ; 8D18 6D 70 05
        asl     a                                              ; 8D1B 0A
        asl     a                                              ; 8D1C 0A
        asl     a                                              ; 8D1D 0A
        sta     oamStaging+3,x                                 ; 8D1E 9D 03 02
        tya                                                    ; 8D21 98
        lsr     a                                              ; 8D22 4A
        lsr     a                                              ; 8D23 4A
        clc                                                    ; 8D24 18
        adc     tetrominoY_A                                   ; 8D25 6D 71 05
        asl     a                                              ; 8D28 0A
        asl     a                                              ; 8D29 0A
        asl     a                                              ; 8D2A 0A
        sta     oamStaging,x                                   ; 8D2B 9D 00 02
        dec     oamStaging,x                                   ; 8D2E DE 00 02
L8D31:
        inx                                                    ; 8D31 E8
        inx                                                    ; 8D32 E8
        inx                                                    ; 8D33 E8
        inx                                                    ; 8D34 E8
        rts                                                    ; 8D35 60

; ----------------------------------------------------------------------------
L8D36:
        stx     tetrominoX_A                                   ; 8D36 8E 70 05
        sty     tetrominoY_A                                   ; 8D39 8C 71 05
        ldx     #$20                                           ; 8D3C A2 20
        ldy     #$00                                           ; 8D3E A0 00
L8D40:
        jsr     L8CF9                                          ; 8D40 20 F9 8C
        iny                                                    ; 8D43 C8
        cpy     #$10                                           ; 8D44 C0 10
        bcc     L8D40                                          ; 8D46 90 F8
        rts                                                    ; 8D48 60

; ----------------------------------------------------------------------------
L8D49:
        lda     $0577                                          ; 8D49 AD 77 05
        asl     a                                              ; 8D4C 0A
        asl     a                                              ; 8D4D 0A
        asl     a                                              ; 8D4E 0A
        ora     $0578                                          ; 8D4F 0D 78 05
        tax                                                    ; 8D52 AA
        lda     LFEC0,x                                        ; 8D53 BD C0 FE
        sta     $43                                            ; 8D56 85 43
        lda     LFEC0+1,x                                      ; 8D58 BD C1 FE
        sta     $44                                            ; 8D5B 85 44
        rts                                                    ; 8D5D 60

; ----------------------------------------------------------------------------
L8D5E:
        inc     $42                                            ; 8D5E E6 42
        jsr     L9059                                          ; 8D60 20 59 90
        lda     #<renderPlayfieldColumns01                     ; 8D63 A9 00
        sta     jmp1E                                          ; 8D65 85 1E
        lda     #>renderPlayfieldColumns01                     ; 8D67 A9 F8
        sta     jmp1E+1                                        ; 8D69 85 1F
        lda     #$04                                           ; 8D6B A9 04
        sta     ppuRenderDirection                             ; 8D6D 85 35
L8D6F:
        lda     ppuRenderDirection                             ; 8D6F A5 35
        bne     L8D6F                                          ; 8D71 D0 FC
        rts                                                    ; 8D73 60

; ----------------------------------------------------------------------------
L8D74:
        ldy     #$FF                                           ; 8D74 A0 FF
        sty     $059A                                          ; 8D76 8C 9A 05
        sty     $059B                                          ; 8D79 8C 9B 05
        sty     $059C                                          ; 8D7C 8C 9C 05
        sty     $059D                                          ; 8D7F 8C 9D 05
        iny                                                    ; 8D82 C8
        sty     $1C                                            ; 8D83 84 1C
L8D85:
        sty     tetrominoY_A                                   ; 8D85 8C 71 05
        tya                                                    ; 8D88 98
        jsr     L8E93                                          ; 8D89 20 93 8E
        tax                                                    ; 8D8C AA
        lda     #$0A                                           ; 8D8D A9 0A
        sta     $1D                                            ; 8D8F 85 1D
L8D91:
        lda     playfield,x                                    ; 8D91 BD 0A 03
        beq     L8DA5                                          ; 8D94 F0 0F
        inx                                                    ; 8D96 E8
        dec     $1D                                            ; 8D97 C6 1D
        bne     L8D91                                          ; 8D99 D0 F6
        lda     tetrominoY_A                                   ; 8D9B AD 71 05
        ldx     $1C                                            ; 8D9E A6 1C
        sta     $059A,x                                        ; 8DA0 9D 9A 05
        inc     $1C                                            ; 8DA3 E6 1C
L8DA5:
        ldy     tetrominoY_A                                   ; 8DA5 AC 71 05
        iny                                                    ; 8DA8 C8
        cpy     #$14                                           ; 8DA9 C0 14
        bcc     L8D85                                          ; 8DAB 90 D8
        ldx     $1C                                            ; 8DAD A6 1C
        beq     L8DBD                                          ; 8DAF F0 0C
        txa                                                    ; 8DB1 8A
        dex                                                    ; 8DB2 CA
        inc     $057A,x                                        ; 8DB3 FE 7A 05
        clc                                                    ; 8DB6 18
        adc     $057F                                          ; 8DB7 6D 7F 05
        sta     $057F                                          ; 8DBA 8D 7F 05
L8DBD:
        rts                                                    ; 8DBD 60

; ----------------------------------------------------------------------------
L8DBE:
        lda     $059A                                          ; 8DBE AD 9A 05
        bmi     L8E22                                          ; 8DC1 30 5F
        lda     #$00                                           ; 8DC3 A9 00
L8DC5:
        sta     $1C                                            ; 8DC5 85 1C
        jsr     L8E93                                          ; 8DC7 20 93 8E
        tax                                                    ; 8DCA AA
        ldy     $1C                                            ; 8DCB A4 1C
        lda     $059A,y                                        ; 8DCD B9 9A 05
        bmi     L8DEF                                          ; 8DD0 30 1D
        jsr     L8E93                                          ; 8DD2 20 93 8E
        tay                                                    ; 8DD5 A8
        lda     #$0A                                           ; 8DD6 A9 0A
        sta     $1D                                            ; 8DD8 85 1D
L8DDA:
        lda     playfield,y                                    ; 8DDA B9 0A 03
        sta     playfieldStash,x                               ; 8DDD 9D D2 03
        inx                                                    ; 8DE0 E8
        iny                                                    ; 8DE1 C8
        dec     $1D                                            ; 8DE2 C6 1D
        bne     L8DDA                                          ; 8DE4 D0 F4
        lda     $1C                                            ; 8DE6 A5 1C
        clc                                                    ; 8DE8 18
        adc     #$01                                           ; 8DE9 69 01
        cmp     #$04                                           ; 8DEB C9 04
        bcc     L8DC5                                          ; 8DED 90 D6
L8DEF:
        lda     #$00                                           ; 8DEF A9 00
        jsr     L8E23                                          ; 8DF1 20 23 8E
        lda     #$FF                                           ; 8DF4 A9 FF
        jsr     L8E23                                          ; 8DF6 20 23 8E
        lda     #$00                                           ; 8DF9 A9 00
        jsr     L8E23                                          ; 8DFB 20 23 8E
        lda     #$FF                                           ; 8DFE A9 FF
        jsr     L8E23                                          ; 8E00 20 23 8E
        ldy     #$00                                           ; 8E03 A0 00
L8E05:
        lda     $059A,y                                        ; 8E05 B9 9A 05
        bmi     L8E22                                          ; 8E08 30 18
        jsr     L8E93                                          ; 8E0A 20 93 8E
        clc                                                    ; 8E0D 18
        adc     #$09                                           ; 8E0E 69 09
        tax                                                    ; 8E10 AA
L8E11:
        lda     $0300,x                                        ; 8E11 BD 00 03
        sta     playfield,x                                    ; 8E14 9D 0A 03
        dex                                                    ; 8E17 CA
        bne     L8E11                                          ; 8E18 D0 F7
        stx     playfield                                      ; 8E1A 8E 0A 03
        iny                                                    ; 8E1D C8
        cpy     #$04                                           ; 8E1E C0 04
        bcc     L8E05                                          ; 8E20 90 E3
L8E22:
        rts                                                    ; 8E22 60

; ----------------------------------------------------------------------------
L8E23:
        sta     tmp15                                          ; 8E23 85 15
        ldx     #$00                                           ; 8E25 A2 00
L8E27:
        stx     $1C                                            ; 8E27 86 1C
        lda     $059A,x                                        ; 8E29 BD 9A 05
        bmi     L8E54                                          ; 8E2C 30 26
        jsr     L8E93                                          ; 8E2E 20 93 8E
        tay                                                    ; 8E31 A8
        txa                                                    ; 8E32 8A
        jsr     L8E93                                          ; 8E33 20 93 8E
        tax                                                    ; 8E36 AA
        lda     #$0A                                           ; 8E37 A9 0A
        sta     $1D                                            ; 8E39 85 1D
L8E3B:
        lda     playfieldStash,x                               ; 8E3B BD D2 03
        and     tmp15                                          ; 8E3E 25 15
        bne     L8E44                                          ; 8E40 D0 02
        lda     #$31                                           ; 8E42 A9 31
L8E44:
        sta     playfield,y                                    ; 8E44 99 0A 03
        inx                                                    ; 8E47 E8
        iny                                                    ; 8E48 C8
        dec     $1D                                            ; 8E49 C6 1D
        bne     L8E3B                                          ; 8E4B D0 EE
        ldx     $1C                                            ; 8E4D A6 1C
        inx                                                    ; 8E4F E8
        cpx     #$04                                           ; 8E50 E0 04
        bcc     L8E27                                          ; 8E52 90 D3
L8E54:
        ldx     #$10                                           ; 8E54 A2 10
        jsr     L93C6                                          ; 8E56 20 C6 93
        jsr     L8D5E                                          ; 8E59 20 5E 8D
        ldy     #$07                                           ; 8E5C A0 07
        jsr     L902E                                          ; 8E5E 20 2E 90
        rts                                                    ; 8E61 60

; ----------------------------------------------------------------------------
L8E62:
        lda     #$03                                           ; 8E62 A9 03
        sta     $2A                                            ; 8E64 85 2A
        lda     $057F                                          ; 8E66 AD 7F 05
        sec                                                    ; 8E69 38
        sbc     $0580                                          ; 8E6A ED 80 05
        bcc     L8E71                                          ; 8E6D 90 02
        lda     #$00                                           ; 8E6F A9 00
L8E71:
        jsr     L908C                                          ; 8E71 20 8C 90
        ldx     #$07                                           ; 8E74 A2 07
        ldy     #$0A                                           ; 8E76 A0 0A
        jmp     L96CC                                          ; 8E78 4C CC 96

; ----------------------------------------------------------------------------
L8E7B:
        lda     #$03                                           ; 8E7B A9 03
        sta     $2A                                            ; 8E7D 85 2A
        ldx     #$07                                           ; 8E7F A2 07
        ldy     #$08                                           ; 8E81 A0 08
        lda     $0595                                          ; 8E83 AD 95 05
        jsr     L96CC                                          ; 8E86 20 CC 96
        ldx     #$07                                           ; 8E89 A2 07
        ldy     #$06                                           ; 8E8B A0 06
        lda     $0596                                          ; 8E8D AD 96 05
        jmp     L96CC                                          ; 8E90 4C CC 96

; ----------------------------------------------------------------------------
L8E93:
        asl     a                                              ; 8E93 0A
        sta     tmp14                                          ; 8E94 85 14
        asl     a                                              ; 8E96 0A
        asl     a                                              ; 8E97 0A
        clc                                                    ; 8E98 18
        adc     tmp14                                          ; 8E99 65 14
        rts                                                    ; 8E9B 60

; ----------------------------------------------------------------------------
L8E9C:
        lda     $0572                                          ; 8E9C AD 72 05
        asl     a                                              ; 8E9F 0A
        asl     a                                              ; 8EA0 0A
        asl     a                                              ; 8EA1 0A
        ora     tetrominoOrientation_A                         ; 8EA2 0D 73 05
        tax                                                    ; 8EA5 AA
        lda     LFEC0,x                                        ; 8EA6 BD C0 FE
        sta     $43                                            ; 8EA9 85 43
        lda     LFEC0+1,x                                      ; 8EAB BD C1 FE
        sta     $44                                            ; 8EAE 85 44
        rts                                                    ; 8EB0 60

; ----------------------------------------------------------------------------
L8EB1:
        lda     #$FF                                           ; 8EB1 A9 FF
        sta     $0574                                          ; 8EB3 8D 74 05
        lda     $0578                                          ; 8EB6 AD 78 05
        sta     tetrominoOrientation_A                         ; 8EB9 8D 73 05
        lda     $0577                                          ; 8EBC AD 77 05
        sta     $0572                                          ; 8EBF 8D 72 05
        jsr     L8E9C                                          ; 8EC2 20 9C 8E
        ldx     #$0F                                           ; 8EC5 A2 0F
        stx     tetrominoX_A                                   ; 8EC7 8E 70 05
        stx     tetrominoX_B                                   ; 8ECA 8E 84 05
        ldy     #$06                                           ; 8ECD A0 06
        sty     tetrominoY_A                                   ; 8ECF 8C 71 05
        sty     tetrominoY_B                                   ; 8ED2 8C 85 05
        jsr     L8D36                                          ; 8ED5 20 36 8D
        jsr     L8AB4                                          ; 8ED8 20 B4 8A
        jsr     L8EE4                                          ; 8EDB 20 E4 8E
        ldy     #$0A                                           ; 8EDE A0 0A
        jsr     L902E                                          ; 8EE0 20 2E 90
        rts                                                    ; 8EE3 60

; ----------------------------------------------------------------------------
L8EE4:
        jsr     generateNextPseudoRandomNumber                 ; 8EE4 20 92 90
        lda     rngSeed+3                                      ; 8EE7 A5 59
        and     #$07                                           ; 8EE9 29 07
        eor     $0577                                          ; 8EEB 4D 77 05
        beq     L8EE4                                          ; 8EEE F0 F4
        sta     $0577                                          ; 8EF0 8D 77 05
        dec     $0577                                          ; 8EF3 CE 77 05
        lda     rngSeed+1                                      ; 8EF6 A5 57
        and     #$06                                           ; 8EF8 29 06
        sta     $0578                                          ; 8EFA 8D 78 05
L8EFD:
        jsr     L8D49                                          ; 8EFD 20 49 8D
        ldx     #$00                                           ; 8F00 A2 00
        ldy     #$0F                                           ; 8F02 A0 0F
L8F04:
        jsr     L8F10                                          ; 8F04 20 10 8F
        dey                                                    ; 8F07 88
        bpl     L8F04                                          ; 8F08 10 FA
        inc     $42                                            ; 8F0A E6 42
        jsr     L9059                                          ; 8F0C 20 59 90
        rts                                                    ; 8F0F 60

; ----------------------------------------------------------------------------
L8F10:
        lda     ($43),y                                        ; 8F10 B1 43
        bne     L8F15                                          ; 8F12 D0 01
        rts                                                    ; 8F14 60

; ----------------------------------------------------------------------------
L8F15:
        and     $0579                                          ; 8F15 2D 79 05
        bne     L8F25                                          ; 8F18 D0 0B
        lda     #$F0                                           ; 8F1A A9 F0
        sta     oamStaging,x                                   ; 8F1C 9D 00 02
        sta     oamStaging+3,x                                 ; 8F1F 9D 03 02
        jmp     L8F44                                          ; 8F22 4C 44 8F

; ----------------------------------------------------------------------------
L8F25:
        clc                                                    ; 8F25 18
        adc     #$32                                           ; 8F26 69 32
        sta     oamStaging+1,x                                 ; 8F28 9D 01 02
        tya                                                    ; 8F2B 98
        and     #$03                                           ; 8F2C 29 03
        asl     a                                              ; 8F2E 0A
        asl     a                                              ; 8F2F 0A
        asl     a                                              ; 8F30 0A
        adc     #$C9                                           ; 8F31 69 C9
        sta     oamStaging+3,x                                 ; 8F33 9D 03 02
        tya                                                    ; 8F36 98
        and     #$0C                                           ; 8F37 29 0C
        asl     a                                              ; 8F39 0A
        adc     #$98                                           ; 8F3A 69 98
        sta     oamStaging,x                                   ; 8F3C 9D 00 02
        lda     #$00                                           ; 8F3F A9 00
        sta     oamStaging+2,x                                 ; 8F41 9D 02 02
L8F44:
        inx                                                    ; 8F44 E8
        inx                                                    ; 8F45 E8
        inx                                                    ; 8F46 E8
        inx                                                    ; 8F47 E8
        rts                                                    ; 8F48 60

; ----------------------------------------------------------------------------
L8F49:
        ldx     #$00                                           ; 8F49 A2 00
        ldy     #$00                                           ; 8F4B A0 00
        lda     #$1F                                           ; 8F4D A9 1F
L8F4F:
        cpy     $059E                                          ; 8F4F CC 9E 05
        bcc     L8F56                                          ; 8F52 90 02
        lda     #$F0                                           ; 8F54 A9 F0
L8F56:
        sta     oamStaging+16,x                                ; 8F56 9D 10 02
        inx                                                    ; 8F59 E8
        inx                                                    ; 8F5A E8
        inx                                                    ; 8F5B E8
        inx                                                    ; 8F5C E8
        iny                                                    ; 8F5D C8
        cpy     #$03                                           ; 8F5E C0 03
        bcc     L8F4F                                          ; 8F60 90 ED
        inc     $42                                            ; 8F62 E6 42
        jsr     L9059                                          ; 8F64 20 59 90
        rts                                                    ; 8F67 60

; ----------------------------------------------------------------------------
unusedMMC1Registers:
        .word   $8002                                          ; 8F68 02 80
        .word   $BFFF                                          ; 8F6A FF BF
        .word   $C000                                          ; 8F6C 00 C0
        .word   $FFF9                                          ; 8F6E F9 FF
; ----------------------------------------------------------------------------
setCNROMBank0:
        lda     debugMMC1Support                               ; 8F70 AD 03 C0
        beq     unusedBankSwitch                               ; 8F73 F0 06
        lda     #$00                                           ; 8F75 A9 00
        sta     cnromBank                                      ; 8F77 8D 01 C0
        rts                                                    ; 8F7A 60

; ----------------------------------------------------------------------------
; see tcrf.net
unusedBankSwitch:
        lda     #$02                                           ; 8F7B A9 02
        ldy     #$00                                           ; 8F7D A0 00
        jsr     cnromOrMMC1BankSwitch                          ; 8F7F 20 97 8F
        lda     #$00                                           ; 8F82 A9 00
        ldy     #$02                                           ; 8F84 A0 02
        jsr     cnromOrMMC1BankSwitch                          ; 8F86 20 97 8F
        lda     #$00                                           ; 8F89 A9 00
        ldy     #$04                                           ; 8F8B A0 04
        jsr     cnromOrMMC1BankSwitch                          ; 8F8D 20 97 8F
        lda     #$00                                           ; 8F90 A9 00
        ldy     #$06                                           ; 8F92 A0 06
        jmp     cnromOrMMC1BankSwitch                          ; 8F94 4C 97 8F

; ----------------------------------------------------------------------------
cnromOrMMC1BankSwitch:
        ldx     debugMMC1Support                               ; 8F97 AE 03 C0
        beq     mmc1BankSwitch                                 ; 8F9A F0 06
        lsr     a                                              ; 8F9C 4A
        tax                                                    ; 8F9D AA
        sta     cnromBank,x                                    ; 8F9E 9D 01 C0
        rts                                                    ; 8FA1 60

; ----------------------------------------------------------------------------
mmc1BankSwitch:
        ldx     #$00                                           ; 8FA2 A2 00
        tax                                                    ; 8FA4 AA
        lda     unusedMMC1Registers,y                          ; 8FA5 B9 68 8F
        sta     $24                                            ; 8FA8 85 24
        lda     unusedMMC1Registers+1,y                        ; 8FAA B9 69 8F
        sta     $25                                            ; 8FAD 85 25
        txa                                                    ; 8FAF 8A
        ldy     #$00                                           ; 8FB0 A0 00
        ldx     #$05                                           ; 8FB2 A2 05
@mmc1Loop:
        sta     ($24),y                                        ; 8FB4 91 24
        lsr     a                                              ; 8FB6 4A
        dex                                                    ; 8FB7 CA
        bne     @mmc1Loop                                      ; 8FB8 D0 FA
        rts                                                    ; 8FBA 60

; ----------------------------------------------------------------------------
L8FBB:
        sty     $3F                                            ; 8FBB 84 3F
        jsr     L8A83                                          ; 8FBD 20 83 8A
L8FC0:
        lda     $3F                                            ; 8FC0 A5 3F
        beq     L8FCA                                          ; 8FC2 F0 06
        jsr     pollController                                 ; 8FC4 20 CE 8F
        txa                                                    ; 8FC7 8A
        beq     L8FC0                                          ; 8FC8 F0 F6
L8FCA:
        sta     $0598                                          ; 8FCA 8D 98 05
        rts                                                    ; 8FCD 60

; ----------------------------------------------------------------------------
; leaves buttons in x register
pollController:
        lda     controllerBeingRead                            ; 8FCE A5 2F
        beq     @pollControllerActual                          ; 8FD0 F0 04
        lda     #$00                                           ; 8FD2 A9 00
        tax                                                    ; 8FD4 AA
        rts                                                    ; 8FD5 60

; ----------------------------------------------------------------------------
@pollControllerActual:
        inc     controllerBeingRead                            ; 8FD6 E6 2F
        lda     #$01                                           ; 8FD8 A9 01
        sta     JOY1                                           ; 8FDA 8D 16 40
        lda     #$00                                           ; 8FDD A9 00
        sta     JOY1                                           ; 8FDF 8D 16 40
        ldx     #$08                                           ; 8FE2 A2 08
@nextButton:
        lda     JOY1                                           ; 8FE4 AD 16 40
        and     #$03                                           ; 8FE7 29 03
        cmp     #$01                                           ; 8FE9 C9 01
        ror     controllerInput                                ; 8FEB 66 30
        dex                                                    ; 8FED CA
        bne     @nextButton                                    ; 8FEE D0 F4
        jsr     generateNextPseudoRandomNumber                 ; 8FF0 20 92 90
        dec     controllerBeingRead                            ; 8FF3 C6 2F
        ldx     controllerInput                                ; 8FF5 A6 30
        rts                                                    ; 8FF7 60

; ----------------------------------------------------------------------------
blankOutNametables:
        ldy     #$10                                           ; 8FF8 A0 10
        lda     #$20                                           ; 8FFA A9 20
        sta     PPUADDR                                        ; 8FFC 8D 06 20
        lda     #$00                                           ; 8FFF A9 00
        sta     PPUADDR                                        ; 9001 8D 06 20
        ldx     #$00                                           ; 9004 A2 00
@blankLoop:
        sta     PPUDATA                                        ; 9006 8D 07 20
        dex                                                    ; 9009 CA
        bne     @blankLoop                                     ; 900A D0 FA
        dey                                                    ; 900C 88
        bne     @blankLoop                                     ; 900D D0 F7
        stx     PPUSCROLL                                      ; 900F 8E 05 20
        stx     PPUSCROLL                                      ; 9012 8E 05 20
        rts                                                    ; 9015 60

; ----------------------------------------------------------------------------
initRam:
        ldx     #$02                                           ; 9016 A2 02
@nextPage:
        jsr     @initPage                                      ; 9018 20 21 90
        inx                                                    ; 901B E8
        cpx     #$08                                           ; 901C E0 08
        bcc     @nextPage                                      ; 901E 90 F8
        rts                                                    ; 9020 60

; ----------------------------------------------------------------------------
@initPage:
        stx     tmp13                                          ; 9021 86 13
        ldy     #$00                                           ; 9023 A0 00
        tya                                                    ; 9025 98
        sty     tmp12                                          ; 9026 84 12
@nextByte:
        sta     (tmp12),y                                      ; 9028 91 12
        iny                                                    ; 902A C8
        bne     @nextByte                                      ; 902B D0 FB
        rts                                                    ; 902D 60

; ----------------------------------------------------------------------------
L902E:
        tya                                                    ; 902E 98
        lsr     a                                              ; 902F 4A
        sta     tmp14                                          ; 9030 85 14
        lda     $3F                                            ; 9032 A5 3F
        sec                                                    ; 9034 38
        sbc     tmp14                                          ; 9035 E5 14
        bcs     L903B                                          ; 9037 B0 02
        lda     #$00                                           ; 9039 A9 00
L903B:
        pha                                                    ; 903B 48
        sty     $3F                                            ; 903C 84 3F
        ldy     #$01                                           ; 903E A0 01
        jsr     L9047                                          ; 9040 20 47 90
        pla                                                    ; 9043 68
        sta     $3F                                            ; 9044 85 3F
        rts                                                    ; 9046 60

; ----------------------------------------------------------------------------
L9047:
        pha                                                    ; 9047 48
L9048:
        lda     $3E,y                                          ; 9048 B9 3E 00
        bne     L9048                                          ; 904B D0 FB
        pla                                                    ; 904D 68
        rts                                                    ; 904E 60

; ----------------------------------------------------------------------------
L904F:
        ldy     #$00                                           ; 904F A0 00
        jmp     L9047                                          ; 9051 4C 47 90

; ----------------------------------------------------------------------------
L9054:
        ldy     #$03                                           ; 9054 A0 03
        jmp     L9047                                          ; 9056 4C 47 90

; ----------------------------------------------------------------------------
L9059:
        pha                                                    ; 9059 48
        tya                                                    ; 905A 98
        pha                                                    ; 905B 48
        txa                                                    ; 905C 8A
        pha                                                    ; 905D 48
        ldy     #$04                                           ; 905E A0 04
        jsr     L9047                                          ; 9060 20 47 90
        pla                                                    ; 9063 68
        tax                                                    ; 9064 AA
        pla                                                    ; 9065 68
        tay                                                    ; 9066 A8
        pla                                                    ; 9067 68
        rts                                                    ; 9068 60

; ----------------------------------------------------------------------------
        ldx     #$00                                           ; 9069 A2 00
        stx     $47                                            ; 906B 86 47
        stx     $48                                            ; 906D 86 48
        stx     $49                                            ; 906F 86 49
L9071:
        lsr     $45                                            ; 9071 46 45
        bcc     L9082                                          ; 9073 90 0D
        lda     $48                                            ; 9075 A5 48
        clc                                                    ; 9077 18
        adc     $46                                            ; 9078 65 46
        sta     $48                                            ; 907A 85 48
        lda     $49                                            ; 907C A5 49
        adc     $47                                            ; 907E 65 47
        sta     $49                                            ; 9080 85 49
L9082:
        asl     $46                                            ; 9082 06 46
        rol     $47                                            ; 9084 26 47
        inx                                                    ; 9086 E8
        cpx     #$08                                           ; 9087 E0 08
        bcc     L9071                                          ; 9089 90 E6
        rts                                                    ; 908B 60

; ----------------------------------------------------------------------------
L908C:
        eor     #$FF                                           ; 908C 49 FF
        clc                                                    ; 908E 18
        adc     #$01                                           ; 908F 69 01
        rts                                                    ; 9091 60

; ----------------------------------------------------------------------------
generateNextPseudoRandomNumber:
        php                                                    ; 9092 08
        pha                                                    ; 9093 48
        txa                                                    ; 9094 8A
        pha                                                    ; 9095 48
        tya                                                    ; 9096 98
        pha                                                    ; 9097 48
        lda     tmp14                                          ; 9098 A5 14
        eor     rngSeed+8                                      ; 909A 45 5E
        sta     rngSeed+8                                      ; 909C 85 5E
        ldx     #$00                                           ; 909E A2 00
        ldy     #$08                                           ; 90A0 A0 08
@shiftRightLoop:
        lda     rngSeed+1,x                                    ; 90A2 B5 57
        adc     rngSeed+8                                      ; 90A4 65 5E
        sta     rngSeed+8                                      ; 90A6 85 5E
        and     #$01                                           ; 90A8 29 01
        cmp     #$01                                           ; 90AA C9 01
        ror     rngSeed,x                                      ; 90AC 76 56
        inx                                                    ; 90AE E8
        dey                                                    ; 90AF 88
        bne     @shiftRightLoop                                ; 90B0 D0 F0
        pla                                                    ; 90B2 68
        tay                                                    ; 90B3 A8
        pla                                                    ; 90B4 68
        tax                                                    ; 90B5 AA
        pla                                                    ; 90B6 68
        plp                                                    ; 90B7 28
        rts                                                    ; 90B8 60

; ----------------------------------------------------------------------------
L90B9:
        .addr   unknownTable03                                 ; 90B9 7B 97
        .addr   LA563                                          ; 90BB 63 A5
        .addr   LA963                                          ; 90BD 63 A9
        .addr   LB41F                                          ; 90BF 1F B4
        .addr   LB01F                                          ; 90C1 1F B0
        .addr   LB81F                                          ; 90C3 1F B8
        .addr   LA163                                          ; 90C5 63 A1
        .addr   L9D63                                          ; 90C7 63 9D
        .addr   L9D63                                          ; 90C9 63 9D
        .addr   LB81F                                          ; 90CB 1F B8
        .addr   LB01F                                          ; 90CD 1F B0
        .addr   introScreenPalette                             ; 90CF 86 9C
        .addr   L9297                                          ; 90D1 97 92
        .addr   L9287                                          ; 90D3 87 92
        .addr   L9277                                          ; 90D5 77 92
        .addr   L9207                                          ; 90D7 07 92
        .addr   L9267                                          ; 90D9 67 92
        .addr   L9247                                          ; 90DB 47 92
        .addr   L9267                                          ; 90DD 67 92
        .addr   L9297                                          ; 90DF 97 92
        .addr   L9297                                          ; 90E1 97 92
        .addr   L9217                                          ; 90E3 17 92
; ----------------------------------------------------------------------------
L90E5:
        .byte   $00,$00,$02,$00,$00,$00,$02,$00                ; 90E5 00 00 02 00 00 00 02 00
        .byte   $00,$00                                        ; 90ED 00 00
L90EF:
        .byte   $00,$00,$00,$00,$00,$00,$18,$00                ; 90EF 00 00 00 00 00 00 18 00
        .byte   $00,$00                                        ; 90F7 00 00
; ----------------------------------------------------------------------------
L90F9:
        sta     $27                                            ; 90F9 85 27
        jsr     L91EE                                          ; 90FB 20 EE 91
        jsr     L9167                                          ; 90FE 20 67 91
        lda     ppuPatternTables                               ; 9101 A5 3D
        sta     PPUCTRL                                        ; 9103 8D 00 20
        lda     #$00                                           ; 9106 A9 00
        sta     PPUMASK                                        ; 9108 8D 01 20
        ldx     $27                                            ; 910B A6 27
        lda     L90E5,x                                        ; 910D BD E5 90
        ldy     #$02                                           ; 9110 A0 02
        jsr     cnromOrMMC1BankSwitch                          ; 9112 20 97 8F
        lda     ppuNametableSelect                             ; 9115 A5 29
        eor     #$03                                           ; 9117 49 03
        sta     ppuNametableSelect                             ; 9119 85 29
        sta     $28                                            ; 911B 85 28
        asl     a                                              ; 911D 0A
        asl     a                                              ; 911E 0A
        adc     #$20                                           ; 911F 69 20
        sta     PPUADDR                                        ; 9121 8D 06 20
        lda     #$00                                           ; 9124 A9 00
        sta     PPUADDR                                        ; 9126 8D 06 20
        lda     $27                                            ; 9129 A5 27
        sta     $26                                            ; 912B 85 26
        asl     a                                              ; 912D 0A
        tax                                                    ; 912E AA
        lda     L90B9,x                                        ; 912F BD B9 90
        sta     $18                                            ; 9132 85 18
        lda     L90B9+1,x                                      ; 9134 BD BA 90
        sta     $19                                            ; 9137 85 19
        ldy     #$00                                           ; 9139 A0 00
        ldx     #$04                                           ; 913B A2 04
L913D:
        lda     ($18),y                                        ; 913D B1 18
        sta     PPUDATA                                        ; 913F 8D 07 20
        iny                                                    ; 9142 C8
        bne     L913D                                          ; 9143 D0 F8
        inc     $19                                            ; 9145 E6 19
        dex                                                    ; 9147 CA
        bne     L913D                                          ; 9148 D0 F3
        stx     PPUSCROLL                                      ; 914A 8E 05 20
        stx     PPUSCROLL                                      ; 914D 8E 05 20
        ldx     $26                                            ; 9150 A6 26
        lda     L90EF,x                                        ; 9152 BD EF 90
        sta     ppuPatternTables                               ; 9155 85 3D
        ora     #$80                                           ; 9157 09 80
        ora     ppuNametableSelect                             ; 9159 05 29
        sta     PPUCTRL                                        ; 915B 8D 00 20
        inc     $42                                            ; 915E E6 42
        jsr     L9059                                          ; 9160 20 59 90
        jsr     L91A3                                          ; 9163 20 A3 91
        rts                                                    ; 9166 60

; ----------------------------------------------------------------------------
L9167:
        ldy     #$00                                           ; 9167 A0 00
        sty     $0598                                          ; 9169 8C 98 05
L916C:
        lda     $049A,y                                        ; 916C B9 9A 04
        cmp     #$0F                                           ; 916F C9 0F
        beq     L918B                                          ; 9171 F0 18
        inc     $0598                                          ; 9173 EE 98 05
        and     #$F0                                           ; 9176 29 F0
        bne     L917F                                          ; 9178 D0 05
        lda     #$0F                                           ; 917A A9 0F
        jmp     L918B                                          ; 917C 4C 8B 91

; ----------------------------------------------------------------------------
L917F:
        sec                                                    ; 917F 38
        sbc     #$10                                           ; 9180 E9 10
        sta     tmp14                                          ; 9182 85 14
        lda     $049A,y                                        ; 9184 B9 9A 04
        and     #$0F                                           ; 9187 29 0F
        ora     tmp14                                          ; 9189 05 14
L918B:
        sta     $049A,y                                        ; 918B 99 9A 04
        iny                                                    ; 918E C8
        cpy     #$10                                           ; 918F C0 10
        bcc     L916C                                          ; 9191 90 D9
        lda     #$06                                           ; 9193 A9 06
        jsr     L92DD                                          ; 9195 20 DD 92
        ldy     #$03                                           ; 9198 A0 03
        jsr     L902E                                          ; 919A 20 2E 90
        lda     $0598                                          ; 919D AD 98 05
        bne     L9167                                          ; 91A0 D0 C5
        rts                                                    ; 91A2 60

; ----------------------------------------------------------------------------
L91A3:
        lda     $26                                            ; 91A3 A5 26
        asl     a                                              ; 91A5 0A
        tax                                                    ; 91A6 AA
        lda     L90B9+1+21,x                                   ; 91A7 BD CF 90
        sta     $18                                            ; 91AA 85 18
        lda     L90B9+1+21+1,x                                 ; 91AC BD D0 90
        sta     $19                                            ; 91AF 85 19
L91B1:
        ldy     #$00                                           ; 91B1 A0 00
        sty     $0598                                          ; 91B3 8C 98 05
L91B6:
        lda     $049A,y                                        ; 91B6 B9 9A 04
        cmp     ($18),y                                        ; 91B9 D1 18
        beq     L91D6                                          ; 91BB F0 19
        inc     $0598                                          ; 91BD EE 98 05
        cmp     #$0F                                           ; 91C0 C9 0F
        bne     L91C9                                          ; 91C2 D0 05
        lda     #$00                                           ; 91C4 A9 00
        jmp     L91CE                                          ; 91C6 4C CE 91

; ----------------------------------------------------------------------------
L91C9:
        and     #$F0                                           ; 91C9 29 F0
        clc                                                    ; 91CB 18
        adc     #$10                                           ; 91CC 69 10
L91CE:
        sta     tmp14                                          ; 91CE 85 14
        lda     ($18),y                                        ; 91D0 B1 18
        and     #$0F                                           ; 91D2 29 0F
        ora     tmp14                                          ; 91D4 05 14
L91D6:
        sta     $049A,y                                        ; 91D6 99 9A 04
        iny                                                    ; 91D9 C8
        cpy     #$10                                           ; 91DA C0 10
        bcc     L91B6                                          ; 91DC 90 D8
        lda     #$06                                           ; 91DE A9 06
        jsr     L92DD                                          ; 91E0 20 DD 92
        ldy     #$03                                           ; 91E3 A0 03
        jsr     L902E                                          ; 91E5 20 2E 90
        lda     $0598                                          ; 91E8 AD 98 05
        bne     L91B1                                          ; 91EB D0 C4
        rts                                                    ; 91ED 60

; ----------------------------------------------------------------------------
L91EE:
        lda     $26                                            ; 91EE A5 26
        asl     a                                              ; 91F0 0A
        tax                                                    ; 91F1 AA
        lda     L90B9+1+21,x                                   ; 91F2 BD CF 90
        sta     $18                                            ; 91F5 85 18
        lda     L90B9+1+21+1,x                                 ; 91F7 BD D0 90
        sta     $19                                            ; 91FA 85 19
        ldy     #$0F                                           ; 91FC A0 0F
L91FE:
        lda     ($18),y                                        ; 91FE B1 18
        sta     $049A,y                                        ; 9200 99 9A 04
        dey                                                    ; 9203 88
        bpl     L91FE                                          ; 9204 10 F8
        rts                                                    ; 9206 60

; ----------------------------------------------------------------------------
L9207:
        .byte   $0F,$00,$10,$30,$0F,$2A,$16,$30                ; 9207 0F 00 10 30 0F 2A 16 30
        .byte   $0F,$19,$37,$02,$0F,$00,$30,$02                ; 920F 0F 19 37 02 0F 00 30 02
L9217:
        .byte   $0F,$00,$10,$30,$0F,$16,$37,$07                ; 9217 0F 00 10 30 0F 16 37 07
        .byte   $0F,$27,$37,$0C,$0F,$00,$20,$0C                ; 921F 0F 27 37 0C 0F 00 20 0C
        .byte   $0F,$2A,$16,$30,$0F,$2A,$12,$30                ; 9227 0F 2A 16 30 0F 2A 12 30
        .byte   $0F,$37,$16,$30,$0F,$00,$21,$30                ; 922F 0F 37 16 30 0F 00 21 30
        .byte   $0F,$37,$12,$30,$0F,$37,$17,$39                ; 9237 0F 37 12 30 0F 37 17 39
        .byte   $0F,$37,$1A,$30,$0F,$37,$16,$30                ; 923F 0F 37 1A 30 0F 37 16 30
L9247:
        .byte   $0F,$0F,$07,$27,$0F,$0F,$08,$28                ; 9247 0F 0F 07 27 0F 0F 08 28
        .byte   $0F,$08,$18,$28,$0F,$0C,$0F,$10                ; 924F 0F 08 18 28 0F 0C 0F 10
        .byte   $20,$08,$17,$37,$20,$07,$17,$37                ; 9257 20 08 17 37 20 07 17 37
        .byte   $20,$17,$27,$37,$20,$1C,$10,$20                ; 925F 20 17 27 37 20 1C 10 20
L9267:
        .byte   $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F                ; 9267 0F 0F 0F 0F 0F 0F 0F 0F
        .byte   $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F                ; 926F 0F 0F 0F 0F 0F 0F 0F 0F
L9277:
        .byte   $0F,$30,$10,$00,$0F,$31,$30,$2A                ; 9277 0F 30 10 00 0F 31 30 2A
        .byte   $0F,$31,$30,$16,$0F,$31,$30,$11                ; 927F 0F 31 30 16 0F 31 30 11
L9287:
        .byte   $0F,$27,$17,$37,$0F,$1C,$2C,$3B                ; 9287 0F 27 17 37 0F 1C 2C 3B
        .byte   $0F,$00,$10,$20,$0F,$1C,$17,$27                ; 928F 0F 00 10 20 0F 1C 17 27
L9297:
        .byte   $0F,$11,$2C,$31,$0F,$16,$37,$07                ; 9297 0F 11 2C 31 0F 16 37 07
        .byte   $0F,$00,$10,$30,$0F,$00,$20,$0C                ; 929F 0F 00 10 30 0F 00 20 0C
unknownTable08:
        .byte   $27,$92,$10,$3F,$10,$01,$9A,$04                ; 92A7 27 92 10 3F 10 01 9A 04
        .byte   $00,$3F,$10,$01,$67,$92,$10,$3F                ; 92AF 00 3F 10 01 67 92 10 3F
        .byte   $10,$01,$37,$92,$10,$3F,$10,$01                ; 92B7 10 01 37 92 10 3F 10 01
        .byte   $17,$92,$00,$3F,$10,$01,$9A,$04                ; 92BF 17 92 00 3F 10 01 9A 04
        .byte   $10,$3F,$10,$01,$57,$92,$00,$3F                ; 92C7 10 3F 10 01 57 92 00 3F
        .byte   $10,$01,$AA,$04,$10,$3F,$10,$01                ; 92CF 10 01 AA 04 10 3F 10 01
        .byte   $9A,$04,$00,$3F,$10,$02                        ; 92D7 9A 04 00 3F 10 02
; ----------------------------------------------------------------------------
L92DD:
        pha                                                    ; 92DD 48
        inc     $42                                            ; 92DE E6 42
        jsr     L9059                                          ; 92E0 20 59 90
        lda     #<unknownRoutine08                             ; 92E3 A9 CD
        sta     jmp1E                                          ; 92E5 85 1E
        lda     #>unknownRoutine08                             ; 92E7 A9 80
        sta     jmp1E+1                                        ; 92E9 85 1F
        pla                                                    ; 92EB 68
        tax                                                    ; 92EC AA
        lda     unknownTable08,x                               ; 92ED BD A7 92
        sta     $10                                            ; 92F0 85 10
        lda     unknownTable08+1,x                             ; 92F2 BD A8 92
        sta     $11                                            ; 92F5 85 11
        lda     unknownTable08+2,x                             ; 92F7 BD A9 92
        sta     tmp12                                          ; 92FA 85 12
        lda     unknownTable08+3,x                             ; 92FC BD AA 92
        cmp     #$20                                           ; 92FF C9 20
        bne     L9309                                          ; 9301 D0 06
        lda     $28                                            ; 9303 A5 28
        asl     a                                              ; 9305 0A
        asl     a                                              ; 9306 0A
        adc     #$20                                           ; 9307 69 20
L9309:
        sta     tmp13                                          ; 9309 85 13
        lda     unknownTable08+4,x                             ; 930B BD AB 92
        sta     $34                                            ; 930E 85 34
        lda     unknownTable08+5,x                             ; 9310 BD AC 92
        sta     $33                                            ; 9313 85 33
        sta     $3E                                            ; 9315 85 3E
        jsr     L904F                                          ; 9317 20 4F 90
        lda     #<unknownRoutine02                             ; 931A A9 86
        sta     jmp1E                                          ; 931C 85 1E
        lda     #>unknownRoutine02                             ; 931E A9 80
        sta     jmp1E+1                                        ; 9320 85 1F
        rts                                                    ; 9322 60

; ----------------------------------------------------------------------------
L9323:
        sta     $32                                            ; 9323 85 32
        txa                                                    ; 9325 8A
        pha                                                    ; 9326 48
        tya                                                    ; 9327 98
        pha                                                    ; 9328 48
        lda     $32                                            ; 9329 A5 32
        jsr     L9335                                          ; 932B 20 35 93
        pla                                                    ; 932E 68
        tay                                                    ; 932F A8
        pla                                                    ; 9330 68
        tax                                                    ; 9331 AA
        lda     $32                                            ; 9332 A5 32
        rts                                                    ; 9334 60

; ----------------------------------------------------------------------------
L9335:
        sta     $4A                                            ; 9335 85 4A
        tya                                                    ; 9337 98
        lsr     a                                              ; 9338 4A
        pha                                                    ; 9339 48
        lsr     a                                              ; 933A 4A
        lsr     a                                              ; 933B 4A
        sta     $4D                                            ; 933C 85 4D
        tya                                                    ; 933E 98
        asl     a                                              ; 933F 0A
        asl     a                                              ; 9340 0A
        asl     a                                              ; 9341 0A
        asl     a                                              ; 9342 0A
        asl     a                                              ; 9343 0A
        sta     $4E                                            ; 9344 85 4E
        txa                                                    ; 9346 8A
        clc                                                    ; 9347 18
        adc     $4E                                            ; 9348 65 4E
        sta     $4E                                            ; 934A 85 4E
        lda     #$00                                           ; 934C A9 00
        adc     $4D                                            ; 934E 65 4D
        sta     $4D                                            ; 9350 85 4D
        lda     $28                                            ; 9352 A5 28
        asl     a                                              ; 9354 0A
        asl     a                                              ; 9355 0A
        adc     $4D                                            ; 9356 65 4D
        adc     #$20                                           ; 9358 69 20
        sta     $4D                                            ; 935A 85 4D
        lda     #$FF                                           ; 935C A9 FF
        sta     $4B                                            ; 935E 85 4B
        jsr     L93A4                                          ; 9360 20 A4 93
        lda     #$03                                           ; 9363 A9 03
        sta     $4C                                            ; 9365 85 4C
        txa                                                    ; 9367 8A
        lsr     a                                              ; 9368 4A
        lsr     a                                              ; 9369 4A
        bcc     L9370                                          ; 936A 90 04
        asl     $4C                                            ; 936C 06 4C
        asl     $4C                                            ; 936E 06 4C
L9370:
        sta     $4E                                            ; 9370 85 4E
        pla                                                    ; 9372 68
        lsr     a                                              ; 9373 4A
        bcc     L937E                                          ; 9374 90 08
        asl     $4C                                            ; 9376 06 4C
        asl     $4C                                            ; 9378 06 4C
        asl     $4C                                            ; 937A 06 4C
        asl     $4C                                            ; 937C 06 4C
L937E:
        asl     a                                              ; 937E 0A
        asl     a                                              ; 937F 0A
        asl     a                                              ; 9380 0A
        clc                                                    ; 9381 18
        adc     $4E                                            ; 9382 65 4E
        clc                                                    ; 9384 18
        adc     #$C0                                           ; 9385 69 C0
        sta     $4E                                            ; 9387 85 4E
        lda     $28                                            ; 9389 A5 28
        asl     a                                              ; 938B 0A
        asl     a                                              ; 938C 0A
        adc     #$23                                           ; 938D 69 23
        sta     $4D                                            ; 938F 85 4D
        lda     $2A                                            ; 9391 A5 2A
        sta     $4A                                            ; 9393 85 4A
        lda     $4C                                            ; 9395 A5 4C
        eor     #$FF                                           ; 9397 49 FF
        sta     $4B                                            ; 9399 85 4B
        lda     $4C                                            ; 939B A5 4C
L939D:
        lsr     a                                              ; 939D 4A
        bcs     L93A4                                          ; 939E B0 04
        asl     $4A                                            ; 93A0 06 4A
        bcc     L939D                                          ; 93A2 90 F9
L93A4:
        ldy     $41                                            ; 93A4 A4 41
        cpy     #$08                                           ; 93A6 C0 08
        beq     L93A4                                          ; 93A8 F0 FA
        lda     $4B                                            ; 93AA A5 4B
        sta     $04D2,y                                        ; 93AC 99 D2 04
        lda     $4E                                            ; 93AF A5 4E
        sta     $04BA,y                                        ; 93B1 99 BA 04
        lda     $4D                                            ; 93B4 A5 4D
        sta     $04C2,y                                        ; 93B6 99 C2 04
        lda     $4A                                            ; 93B9 A5 4A
        sta     $04CA,y                                        ; 93BB 99 CA 04
        inc     $41                                            ; 93BE E6 41
        iny                                                    ; 93C0 C8
        cpy     $41                                            ; 93C1 C4 41
        bne     L93A4                                          ; 93C3 D0 DF
        rts                                                    ; 93C5 60

; ----------------------------------------------------------------------------
L93C6:
        lda     #$0A                                           ; 93C6 A9 0A
        sta     $05F9                                          ; 93C8 8D F9 05
        inx                                                    ; 93CB E8
        inx                                                    ; 93CC E8
        inx                                                    ; 93CD E8
        ldy     #$03                                           ; 93CE A0 03
L93D0:
        lda     L93DB,x                                        ; 93D0 BD DB 93
        sta     SQ2_VOL,y                                      ; 93D3 99 04 40
        dex                                                    ; 93D6 CA
        dey                                                    ; 93D7 88
        bpl     L93D0                                          ; 93D8 10 F6
        rts                                                    ; 93DA 60

; ----------------------------------------------------------------------------
L93DB:
        .byte   $5F,$8B,$0E,$7C,$1F,$A9,$2E,$3B                ; 93DB 5F 8B 0E 7C 1F A9 2E 3B
        .byte   $DF,$A3,$9E,$B8,$9F,$A9,$2E,$6F                ; 93E3 DF A3 9E B8 9F A9 2E 6F
        .byte   $9F,$81,$1E,$58,$DF,$19,$FE,$48                ; 93EB 9F 81 1E 58 DF 19 FE 48
        .byte   $DF,$2A,$01,$8E,$9F,$F9,$1E,$57                ; 93F3 DF 2A 01 8E 9F F9 1E 57
        .byte   $9F,$F9,$D2,$52,$43,$00,$60,$3B                ; 93FB 9F F9 D2 52 43 00 60 3B
        .byte   $9F,$8C,$80,$F9,$00,$00,$00,$00                ; 9403 9F 8C 80 F9 00 00 00 00
; ----------------------------------------------------------------------------
L940B:
        pha                                                    ; 940B 48
        lda     #$30                                           ; 940C A9 30
        ldx     tetrominoX_A                                   ; 940E AE 70 05
        ldy     tetrominoY_A                                   ; 9411 AC 71 05
        jsr     L9323                                          ; 9414 20 23 93
        jsr     L9054                                          ; 9417 20 54 90
        pla                                                    ; 941A 68
        ldx     tetrominoX_A                                   ; 941B AE 70 05
        ldy     tetrominoY_A                                   ; 941E AC 71 05
        jsr     L9323                                          ; 9421 20 23 93
        jmp     L9054                                          ; 9424 4C 54 90

; ----------------------------------------------------------------------------
L9427:
        .byte   $04,$08,$12,$18                                ; 9427 04 08 12 18
L942B:
        .byte   $03,$08,$02,$02                                ; 942B 03 08 02 02
; ----------------------------------------------------------------------------
L942F:
        jsr     L956F                                          ; 942F 20 6F 95
        sta     $1C                                            ; 9432 85 1C
        lda     $05B8                                          ; 9434 AD B8 05
        clc                                                    ; 9437 18
        adc     #$0E                                           ; 9438 69 0E
        sta     tetrominoY_A                                   ; 943A 8D 71 05
        lda     L9427                                          ; 943D AD 27 94
        sta     tetrominoX_A                                   ; 9440 8D 70 05
        lda     #$03                                           ; 9443 A9 03
        sta     $1D                                            ; 9445 85 1D
        sta     $3F                                            ; 9447 85 3F
L9449:
        lda     $0612                                          ; 9449 AD 12 06
        bne     L9453                                          ; 944C D0 05
        lda     #$04                                           ; 944E A9 04
        jsr     LBC1F                                          ; 9450 20 1F BC
L9453:
        lda     $3F                                            ; 9453 A5 3F
        bne     L9449                                          ; 9455 D0 F2
        jsr     pollController                                 ; 9457 20 CE 8F
        bne     L9467                                          ; 945A D0 0B
        ldx     $1C                                            ; 945C A6 1C
        lda     $04DA,x                                        ; 945E BD DA 04
        jsr     L940B                                          ; 9461 20 0B 94
        jmp     L9449                                          ; 9464 4C 49 94

; ----------------------------------------------------------------------------
L9467:
        txa                                                    ; 9467 8A
        ldx     $1C                                            ; 9468 A6 1C
        and     #$33                                           ; 946A 29 33
        beq     L9449                                          ; 946C F0 DB
        and     #$32                                           ; 946E 29 32
        beq     L94CF                                          ; 9470 F0 5D
        and     #$30                                           ; 9472 29 30
        beq     L94BC                                          ; 9474 F0 46
        and     #$20                                           ; 9476 29 20
        beq     L948C                                          ; 9478 F0 12
        dec     $04DA,x                                        ; 947A DE DA 04
        lda     $04DA,x                                        ; 947D BD DA 04
        cmp     #$0B                                           ; 9480 C9 0B
        bcs     L949D                                          ; 9482 B0 19
        lda     #$24                                           ; 9484 A9 24
        sta     $04DA,x                                        ; 9486 9D DA 04
        jmp     L949D                                          ; 9489 4C 9D 94

; ----------------------------------------------------------------------------
L948C:
        inc     $04DA,x                                        ; 948C FE DA 04
        lda     $04DA,x                                        ; 948F BD DA 04
        cmp     #$24                                           ; 9492 C9 24
        bcc     L949D                                          ; 9494 90 07
        beq     L949D                                          ; 9496 F0 05
        lda     #$0B                                           ; 9498 A9 0B
        sta     $04DA,x                                        ; 949A 9D DA 04
L949D:
        lda     $04DA,x                                        ; 949D BD DA 04
        ldx     tetrominoX_A                                   ; 94A0 AE 70 05
        ldy     tetrominoY_A                                   ; 94A3 AC 71 05
        jsr     L9335                                          ; 94A6 20 35 93
L94A9:
        lda     #$00                                           ; 94A9 A9 00
        sta     nmiWaitVar                                     ; 94AB 85 3C
L94AD:
        lda     nmiWaitVar                                     ; 94AD A5 3C
        bne     L9449                                          ; 94AF D0 98
        ldx     $1C                                            ; 94B1 A6 1C
        lda     $04DA,x                                        ; 94B3 BD DA 04
        jsr     L940B                                          ; 94B6 20 0B 94
        jmp     L94AD                                          ; 94B9 4C AD 94

; ----------------------------------------------------------------------------
L94BC:
        lda     $1D                                            ; 94BC A5 1D
        cmp     #$03                                           ; 94BE C9 03
        bcc     L94C5                                          ; 94C0 90 03
        jmp     L9449                                          ; 94C2 4C 49 94

; ----------------------------------------------------------------------------
L94C5:
        inc     $1D                                            ; 94C5 E6 1D
        dec     $1C                                            ; 94C7 C6 1C
        dec     tetrominoX_A                                   ; 94C9 CE 70 05
        jmp     L94A9                                          ; 94CC 4C A9 94

; ----------------------------------------------------------------------------
L94CF:
        inc     $1C                                            ; 94CF E6 1C
        inc     tetrominoX_A                                   ; 94D1 EE 70 05
        dec     $1D                                            ; 94D4 C6 1D
        bne     L94A9                                          ; 94D6 D0 D1
        rts                                                    ; 94D8 60

; ----------------------------------------------------------------------------
L94D9:
        lda     #$00                                           ; 94D9 A9 00
L94DB:
        sta     $05B8                                          ; 94DB 8D B8 05
        jsr     L9579                                          ; 94DE 20 79 95
        tax                                                    ; 94E1 AA
        ldy     #$07                                           ; 94E2 A0 07
L94E4:
        lda     $04DA,x                                        ; 94E4 BD DA 04
        cmp     #$0A                                           ; 94E7 C9 0A
        bcc     L94ED                                          ; 94E9 90 02
        lda     #$00                                           ; 94EB A9 00
L94ED:
        cmp     $0587,y                                        ; 94ED D9 87 05
        bcc     L9508                                          ; 94F0 90 16
        bne     L94F8                                          ; 94F2 D0 04
        inx                                                    ; 94F4 E8
        dey                                                    ; 94F5 88
        bpl     L94E4                                          ; 94F6 10 EC
L94F8:
        lda     $05B8                                          ; 94F8 AD B8 05
        clc                                                    ; 94FB 18
        adc     #$01                                           ; 94FC 69 01
        cmp     #$0A                                           ; 94FE C9 0A
        bcc     L94DB                                          ; 9500 90 D9
        lda     #$FF                                           ; 9502 A9 FF
        sta     $05B8                                          ; 9504 8D B8 05
        rts                                                    ; 9507 60

; ----------------------------------------------------------------------------
L9508:
        lda     $05B8                                          ; 9508 AD B8 05
        jsr     L956F                                          ; 950B 20 6F 95
        sta     tmp14                                          ; 950E 85 14
        inc     tmp14                                          ; 9510 E6 14
        ldx     #$87                                           ; 9512 A2 87
L9514:
        lda     $04D9,x                                        ; 9514 BD D9 04
        sta     $04E8,x                                        ; 9517 9D E8 04
        dex                                                    ; 951A CA
        cpx     tmp14                                          ; 951B E4 14
        bcs     L9514                                          ; 951D B0 F5
        lda     $05B8                                          ; 951F AD B8 05
        jsr     L956F                                          ; 9522 20 6F 95
        tax                                                    ; 9525 AA
        lda     #$0B                                           ; 9526 A9 0B
        sta     $04DA,x                                        ; 9528 9D DA 04
        inx                                                    ; 952B E8
        sta     $04DA,x                                        ; 952C 9D DA 04
        inx                                                    ; 952F E8
        sta     $04DA,x                                        ; 9530 9D DA 04
        inx                                                    ; 9533 E8
        ldy     #$07                                           ; 9534 A0 07
L9536:
        lda     $0587,y                                        ; 9536 B9 87 05
        bne     L954B                                          ; 9539 D0 10
        lda     #$32                                           ; 953B A9 32
        sta     $04DA,x                                        ; 953D 9D DA 04
        inx                                                    ; 9540 E8
        dey                                                    ; 9541 88
        bpl     L9536                                          ; 9542 10 F2
L9544:
        lda     $0587,y                                        ; 9544 B9 87 05
        bne     L954B                                          ; 9547 D0 02
        lda     #$0A                                           ; 9549 A9 0A
L954B:
        sta     $04DA,x                                        ; 954B 9D DA 04
        inx                                                    ; 954E E8
        dey                                                    ; 954F 88
        bpl     L9544                                          ; 9550 10 F2
        lda     #$32                                           ; 9552 A9 32
        sta     $04DA,x                                        ; 9554 9D DA 04
        sta     $04DC,x                                        ; 9557 9D DC 04
        lda     $0596                                          ; 955A AD 96 05
        bne     L9561                                          ; 955D D0 02
        lda     #$0A                                           ; 955F A9 0A
L9561:
        sta     $04DB,x                                        ; 9561 9D DB 04
        lda     $0595                                          ; 9564 AD 95 05
        bne     L956B                                          ; 9567 D0 02
        lda     #$0A                                           ; 9569 A9 0A
L956B:
        sta     $04DD,x                                        ; 956B 9D DD 04
        rts                                                    ; 956E 60

; ----------------------------------------------------------------------------
L956F:
        sta     tmp14                                          ; 956F 85 14
        asl     a                                              ; 9571 0A
        asl     a                                              ; 9572 0A
        asl     a                                              ; 9573 0A
        asl     a                                              ; 9574 0A
        sec                                                    ; 9575 38
        sbc     tmp14                                          ; 9576 E5 14
        rts                                                    ; 9578 60

; ----------------------------------------------------------------------------
L9579:
        jsr     L956F                                          ; 9579 20 6F 95
        clc                                                    ; 957C 18
        adc     #$03                                           ; 957D 69 03
        rts                                                    ; 957F 60

; ----------------------------------------------------------------------------
L9580:
        lda     #$05                                           ; 9580 A9 05
        jsr     L90F9                                          ; 9582 20 F9 90
        lda     #$04                                           ; 9585 A9 04
        jsr     LBC1F                                          ; 9587 20 1F BC
        lda     #$01                                           ; 958A A9 01
        sta     $2A                                            ; 958C 85 2A
        ldy     #$0E                                           ; 958E A0 0E
        ldx     #$00                                           ; 9590 A2 00
L9592:
        sty     tetrominoY_A                                   ; 9592 8C 71 05
        ldy     #$00                                           ; 9595 A0 00
L9597:
        lda     L9427,y                                        ; 9597 B9 27 94
        sta     tetrominoX_A                                   ; 959A 8D 70 05
        lda     L942B,y                                        ; 959D B9 2B 94
        sta     $1C                                            ; 95A0 85 1C
        sty     $1D                                            ; 95A2 84 1D
        ldy     tetrominoY_A                                   ; 95A4 AC 71 05
L95A7:
        lda     $04DA,x                                        ; 95A7 BD DA 04
        stx     tmp14                                          ; 95AA 86 14
        ldx     tetrominoX_A                                   ; 95AC AE 70 05
        jsr     L9323                                          ; 95AF 20 23 93
        inc     tetrominoX_A                                   ; 95B2 EE 70 05
        ldx     tmp14                                          ; 95B5 A6 14
        inx                                                    ; 95B7 E8
        dec     $1C                                            ; 95B8 C6 1C
        bne     L95A7                                          ; 95BA D0 EB
        ldy     $1D                                            ; 95BC A4 1D
        iny                                                    ; 95BE C8
        cpy     #$04                                           ; 95BF C0 04
        bcc     L9597                                          ; 95C1 90 D4
        ldy     tetrominoY_A                                   ; 95C3 AC 71 05
        iny                                                    ; 95C6 C8
        cpy     #$18                                           ; 95C7 C0 18
        bcc     L9592                                          ; 95C9 90 C7
        jsr     L9054                                          ; 95CB 20 54 90
        lda     #$09                                           ; 95CE A9 09
        sta     $26                                            ; 95D0 85 26
        jsr     L91A3                                          ; 95D2 20 A3 91
        rts                                                    ; 95D5 60

; ----------------------------------------------------------------------------
L95D6:
        .byte   $A0                                            ; 95D6 A0
L95D7:
        .byte   $05,$A4,$05,$A8,$05,$AC,$05,$B0                ; 95D7 05 A4 05 A8 05 AC 05 B0
        .byte   $05                                            ; 95DF 05
L95E0:
        .byte   $07,$0B,$0E,$11,$14                            ; 95E0 07 0B 0E 11 14
L95E5:
        .byte   $01,$04,$0A,$1E,$78                            ; 95E5 01 04 0A 1E 78
L95EA:
        .byte   $00,$01,$01,$01,$01                            ; 95EA 00 01 01 01 01
L95EF:
        .byte   $06,$0A,$0D,$10,$13                            ; 95EF 06 0A 0D 10 13
; ----------------------------------------------------------------------------
L95F4:
        ldx     $059F                                          ; 95F4 AE 9F 05
        ldy     L95EA,x                                        ; 95F7 BC EA 95
        ldx     tetrominoX_A                                   ; 95FA AE 70 05
L95FD:
        lda     ($18),y                                        ; 95FD B1 18
        clc                                                    ; 95FF 18
        adc     #$01                                           ; 9600 69 01
        cmp     #$0A                                           ; 9602 C9 0A
        bcc     L9608                                          ; 9604 90 02
        lda     #$00                                           ; 9606 A9 00
L9608:
        sta     ($18),y                                        ; 9608 91 18
        bne     L9610                                          ; 960A D0 04
        iny                                                    ; 960C C8
        jmp     L95FD                                          ; 960D 4C FD 95

; ----------------------------------------------------------------------------
L9610:
        sty     $1C                                            ; 9610 84 1C
        lda     tetrominoX_A                                   ; 9612 AD 70 05
        sec                                                    ; 9615 38
        sbc     $1C                                            ; 9616 E5 1C
        tax                                                    ; 9618 AA
L9619:
        sty     $1C                                            ; 9619 84 1C
        lda     ($18),y                                        ; 961B B1 18
        bne     L9621                                          ; 961D D0 02
        lda     #$0A                                           ; 961F A9 0A
L9621:
        ldy     tetrominoY_A                                   ; 9621 AC 71 05
        jsr     L9323                                          ; 9624 20 23 93
        ldy     $1C                                            ; 9627 A4 1C
        inx                                                    ; 9629 E8
        dey                                                    ; 962A 88
        bpl     L9619                                          ; 962B 10 EC
        rts                                                    ; 962D 60

; ----------------------------------------------------------------------------
L962E:
        jsr     L9751                                          ; 962E 20 51 97
        ldx     #$01                                           ; 9631 A2 01
L9633:
        stx     $059F                                          ; 9633 8E 9F 05
        lda     $0579,x                                        ; 9636 BD 79 05
        ldy     L95EF,x                                        ; 9639 BC EF 95
        ldx     #$0C                                           ; 963C A2 0C
        jsr     L96CC                                          ; 963E 20 CC 96
        ldx     $059F                                          ; 9641 AE 9F 05
        inx                                                    ; 9644 E8
        cpx     #$05                                           ; 9645 E0 05
        bcc     L9633                                          ; 9647 90 EA
        lda     #$00                                           ; 9649 A9 00
        ldy     #$04                                           ; 964B A0 04
L964D:
        sta     $058F,y                                        ; 964D 99 8F 05
        sta     $05A0,y                                        ; 9650 99 A0 05
        sta     $05A4,y                                        ; 9653 99 A4 05
        sta     $05A8,y                                        ; 9656 99 A8 05
        sta     $05AC,y                                        ; 9659 99 AC 05
        sta     $05B0,y                                        ; 965C 99 B0 05
        dey                                                    ; 965F 88
        bpl     L964D                                          ; 9660 10 EB
        lda     #$00                                           ; 9662 A9 00
        sta     $059F                                          ; 9664 8D 9F 05
        jsr     L9743                                          ; 9667 20 43 97
L966A:
        ldx     $0581                                          ; 966A AE 81 05
        beq     L9678                                          ; 966D F0 09
L966F:
        dec     $0581                                          ; 966F CE 81 05
        jsr     L96EB                                          ; 9672 20 EB 96
        jmp     L966A                                          ; 9675 4C 6A 96

; ----------------------------------------------------------------------------
L9678:
        ldx     $0582                                          ; 9678 AE 82 05
        beq     L9683                                          ; 967B F0 06
        dec     $0582                                          ; 967D CE 82 05
        jmp     L966F                                          ; 9680 4C 6F 96

; ----------------------------------------------------------------------------
L9683:
        ldx     #$01                                           ; 9683 A2 01
L9685:
        stx     $059F                                          ; 9685 8E 9F 05
        jsr     L9743                                          ; 9688 20 43 97
L968B:
        ldx     $059F                                          ; 968B AE 9F 05
        lda     $0579,x                                        ; 968E BD 79 05
        beq     L96A7                                          ; 9691 F0 14
        dec     $0579,x                                        ; 9693 DE 79 05
        lda     L95E5,x                                        ; 9696 BD E5 95
        sta     $05B5                                          ; 9699 8D B5 05
L969C:
        jsr     L96EB                                          ; 969C 20 EB 96
        dec     $05B5                                          ; 969F CE B5 05
        bne     L969C                                          ; 96A2 D0 F8
        jmp     L968B                                          ; 96A4 4C 8B 96

; ----------------------------------------------------------------------------
L96A7:
        ldx     $059F                                          ; 96A7 AE 9F 05
        inx                                                    ; 96AA E8
        cpx     #$05                                           ; 96AB E0 05
        bcc     L9685                                          ; 96AD 90 D6
        ldy     #$78                                           ; 96AF A0 78
        jsr     L8FBB                                          ; 96B1 20 BB 8F
        rts                                                    ; 96B4 60

; ----------------------------------------------------------------------------
L96B5:
        cmp     #$63                                           ; 96B5 C9 63
        bcc     L96BB                                          ; 96B7 90 02
        lda     #$63                                           ; 96B9 A9 63
L96BB:
        ldy     #$FF                                           ; 96BB A0 FF
L96BD:
        iny                                                    ; 96BD C8
        sec                                                    ; 96BE 38
        sbc     #$0A                                           ; 96BF E9 0A
        bcs     L96BD                                          ; 96C1 B0 FA
        adc     #$0A                                           ; 96C3 69 0A
        sty     $05B6                                          ; 96C5 8C B6 05
        sta     $05B7                                          ; 96C8 8D B7 05
        rts                                                    ; 96CB 60

; ----------------------------------------------------------------------------
L96CC:
        sty     tetrominoY_A                                   ; 96CC 8C 71 05
        jsr     L96B5                                          ; 96CF 20 B5 96
        ldy     tetrominoY_A                                   ; 96D2 AC 71 05
        lda     $05B6                                          ; 96D5 AD B6 05
        bne     L96DC                                          ; 96D8 D0 02
        lda     #$32                                           ; 96DA A9 32
L96DC:
        jsr     L9323                                          ; 96DC 20 23 93
        inx                                                    ; 96DF E8
        lda     $05B7                                          ; 96E0 AD B7 05
        bne     L96E7                                          ; 96E3 D0 02
        lda     #$0A                                           ; 96E5 A9 0A
L96E7:
        jsr     L9335                                          ; 96E7 20 35 93
        rts                                                    ; 96EA 60

; ----------------------------------------------------------------------------
L96EB:
        lda     #$87                                           ; 96EB A9 87
        sta     $18                                            ; 96ED 85 18
        lda     #$05                                           ; 96EF A9 05
        sta     $19                                            ; 96F1 85 19
        lda     #$0F                                           ; 96F3 A9 0F
        sta     tetrominoX_A                                   ; 96F5 8D 70 05
        lda     #$02                                           ; 96F8 A9 02
        sta     tetrominoY_A                                   ; 96FA 8D 71 05
        lda     #$03                                           ; 96FD A9 03
        sta     $2A                                            ; 96FF 85 2A
        jsr     L95F4                                          ; 9701 20 F4 95
        ldx     #$01                                           ; 9704 A2 01
        stx     $2A                                            ; 9706 86 2A
        lda     #$8F                                           ; 9708 A9 8F
        sta     $18                                            ; 970A 85 18
        lda     #$05                                           ; 970C A9 05
        sta     $19                                            ; 970E 85 19
        lda     #$14                                           ; 9710 A9 14
        sta     tetrominoX_A                                   ; 9712 8D 70 05
        lda     #$18                                           ; 9715 A9 18
        sta     tetrominoY_A                                   ; 9717 8D 71 05
        jsr     L95F4                                          ; 971A 20 F4 95
        lda     $059F                                          ; 971D AD 9F 05
        asl     a                                              ; 9720 0A
        tax                                                    ; 9721 AA
        lda     L95D6,x                                        ; 9722 BD D6 95
        sta     $18                                            ; 9725 85 18
        lda     L95D7,x                                        ; 9727 BD D7 95
        sta     $19                                            ; 972A 85 19
        ldx     $059F                                          ; 972C AE 9F 05
        lda     #$14                                           ; 972F A9 14
        sta     tetrominoX_A                                   ; 9731 8D 70 05
        lda     L95E0,x                                        ; 9734 BD E0 95
        sta     tetrominoY_A                                   ; 9737 8D 71 05
        jsr     L95F4                                          ; 973A 20 F4 95
        ldx     #$14                                           ; 973D A2 14
        jsr     L93C6                                          ; 973F 20 C6 93
        rts                                                    ; 9742 60

; ----------------------------------------------------------------------------
L9743:
        ldx     $059F                                          ; 9743 AE 9F 05
        ldy     L95E0,x                                        ; 9746 BC E0 95
        ldx     #$14                                           ; 9749 A2 14
        lda     #$0A                                           ; 974B A9 0A
        jsr     L9323                                          ; 974D 20 23 93
        rts                                                    ; 9750 60

; ----------------------------------------------------------------------------
L9751:
        ldx     #$C8                                           ; 9751 A2 C8
L9753:
        lda     LAD62,x                                        ; 9753 BD 62 AD
        sta     $0309,x                                        ; 9756 9D 09 03
        dex                                                    ; 9759 CA
        bne     L9753                                          ; 975A D0 F7
        jsr     L976C                                          ; 975C 20 6C 97
        lda     #$06                                           ; 975F A9 06
        jsr     L92DD                                          ; 9761 20 DD 92
        jsr     L8D5E                                          ; 9764 20 5E 8D
        lda     #$01                                           ; 9767 A9 01
        sta     $2A                                            ; 9769 85 2A
        rts                                                    ; 976B 60

; ----------------------------------------------------------------------------
L976C:
        jsr     L91EE                                          ; 976C 20 EE 91
        ldx     #$07                                           ; 976F A2 07
L9771:
        lda     L9217,x                                        ; 9771 BD 17 92
        sta     $049A,x                                        ; 9774 9D 9A 04
        dex                                                    ; 9777 CA
        bpl     L9771                                          ; 9778 10 F7
        rts                                                    ; 977A 60

; ----------------------------------------------------------------------------
; possible nametable
unknownTable03:
        .byte   $00,$00,$00,$00,$00,$00,$DF,$E0                ; 977B 00 00 00 00 00 00 DF E0
        .byte   $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0                ; 9783 E0 E0 E0 E0 E0 E0 E0 E0
        .byte   $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0                ; 978B E0 E0 E0 E0 E0 E0 E0 E0
        .byte   $E0,$E1,$00,$00,$00,$00,$00,$00                ; 9793 E0 E1 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 979B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97A3 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97AB 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 97B3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 97BB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97C3 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97CB 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 97D3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 97DB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97E3 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 97EB 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 97F3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 97FB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 9803 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 980B 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9813 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 981B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$E4,$E5,$E5,$E6,$E4,$E5                ; 9823 30 30 E4 E5 E5 E6 E4 E5
        .byte   $E5,$E7,$E8,$E9,$EA,$EB,$30,$30                ; 982B E5 E7 E8 E9 EA EB 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9833 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 983B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$EC,$00,$00,$ED,$EC,$00                ; 9843 30 30 EC 00 00 ED EC 00
        .byte   $00,$EE,$EF,$00,$F1,$F2,$30,$30                ; 984B 00 EE EF 00 F1 F2 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9853 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 985B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$EC,$00,$00,$F3,$EC,$00                ; 9863 30 30 EC 00 00 F3 EC 00
        .byte   $00,$F4,$F5,$00,$00,$ED,$30,$30                ; 986B 00 F4 F5 00 00 ED 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9873 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 987B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$EC,$00,$00,$ED,$EC,$00                ; 9883 30 30 EC 00 00 ED EC 00
        .byte   $EE,$30,$EF,$00,$F6,$F7,$30,$30                ; 988B EE 30 EF 00 F6 F7 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9893 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 989B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$F8,$F9,$F9,$F7,$F8,$F9                ; 98A3 30 30 F8 F9 F9 F7 F8 F9
        .byte   $FA,$FB,$FC,$F9,$F4,$30,$30,$30                ; 98AB FA FB FC F9 F4 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 98B3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 98BB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 98C3 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 98CB 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 98D3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 98DB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 98E3 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 98EB 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 98F3 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 98FB 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 9903 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 990B 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9913 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$E2,$30                ; 991B 00 00 00 00 00 00 E2 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 9923 30 30 30 30 30 30 30 30
        .byte   $30,$30,$30,$30,$30,$30,$30,$30                ; 992B 30 30 30 30 30 30 30 30
        .byte   $30,$E3,$00,$00,$00,$00,$00,$00                ; 9933 30 E3 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FD,$FE                ; 993B 00 00 00 00 00 00 FD FE
        .byte   $FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE                ; 9943 FE FE FE FE FE FE FE FE
        .byte   $FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE                ; 994B FE FE FE FE FE FE FE FE
        .byte   $FE,$FF,$00,$00,$00,$00,$00,$00                ; 9953 FE FF 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; 995B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; 9963 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; 996B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; 9973 00 00 00 00 00 00 00 00
; ----------------------------------------------------------------------------
L997B:
        lda     #$00                                           ; 997B A9 00
        sta     $05BC                                          ; 997D 8D BC 05
        jsr     L9A2C                                          ; 9980 20 2C 9A
        jsr     drawBPSLogo                                    ; 9983 20 22 9C
        lda     #$88                                           ; 9986 A9 88
        sta     PPUCTRL                                        ; 9988 8D 00 20
        inc     $05BC                                          ; 998B EE BC 05
        jsr     L9A2C                                          ; 998E 20 2C 9A
        jsr     L9059                                          ; 9991 20 59 90
        lda     #$1E                                           ; 9994 A9 1E
        sta     currentPpuMask                                 ; 9996 85 2E
        jsr     L9CDD                                          ; 9998 20 DD 9C
        lda     #$40                                           ; 999B A9 40
        sta     $3F                                            ; 999D 85 3F
        lda     #$02                                           ; 999F A9 02
        sta     $40                                            ; 99A1 85 40
L99A3:
        lda     #$40                                           ; 99A3 A9 40
        sec                                                    ; 99A5 38
        sbc     $3F                                            ; 99A6 E5 3F
        lsr     a                                              ; 99A8 4A
        lsr     a                                              ; 99A9 4A
        ora     #$B8                                           ; 99AA 09 B8
        sta     SQ1_VOL                                        ; 99AC 8D 00 40
        sta     SQ2_VOL                                        ; 99AF 8D 04 40
        lda     $40                                            ; 99B2 A5 40
        bne     L99A3                                          ; 99B4 D0 ED
        ldy     #$07                                           ; 99B6 A0 07
        sty     $3F                                            ; 99B8 84 3F
L99BA:
        jsr     L9059                                          ; 99BA 20 59 90
        lda     $3F                                            ; 99BD A5 3F
        asl     a                                              ; 99BF 0A
        ora     #$B0                                           ; 99C0 09 B0
        sta     SQ1_VOL                                        ; 99C2 8D 00 40
        sta     SQ2_VOL                                        ; 99C5 8D 04 40
        lda     $3F                                            ; 99C8 A5 3F
        bne     L99BA                                          ; 99CA D0 EE
        ldy     #$0A                                           ; 99CC A0 0A
        jsr     L902E                                          ; 99CE 20 2E 90
        lda     #$30                                           ; 99D1 A9 30
        sta     SQ1_VOL                                        ; 99D3 8D 00 40
        sta     SQ2_VOL                                        ; 99D6 8D 04 40
        ldy     #$5A                                           ; 99D9 A0 5A
        jsr     L902E                                          ; 99DB 20 2E 90
        ldx     #$00                                           ; 99DE A2 00
        jsr     L9A64                                          ; 99E0 20 64 9A
        jsr     L9AE9                                          ; 99E3 20 E9 9A
        jsr     L9A16                                          ; 99E6 20 16 9A
        ldx     #$02                                           ; 99E9 A2 02
        jsr     L9A64                                          ; 99EB 20 64 9A
        ldy     #$22                                           ; 99EE A0 22
        jsr     L902E                                          ; 99F0 20 2E 90
        lda     #$00                                           ; 99F3 A9 00
        sta     SQ1_VOL                                        ; 99F5 8D 00 40
        sta     SQ2_VOL                                        ; 99F8 8D 04 40
        lda     SND_CHN                                        ; 99FB AD 15 40
        and     #$E0                                           ; 99FE 29 E0
        sta     SND_CHN                                        ; 9A00 8D 15 40
        ldy     #$64                                           ; 9A03 A0 64
        jsr     L902E                                          ; 9A05 20 2E 90
        lda     #$F0                                           ; 9A08 A9 F0
        ldy     #$00                                           ; 9A0A A0 00
L9A0C:
        sta     oamStaging,y                                   ; 9A0C 99 00 02
        iny                                                    ; 9A0F C8
        bne     L9A0C                                          ; 9A10 D0 FA
        jsr     L9CF2                                          ; 9A12 20 F2 9C
        rts                                                    ; 9A15 60

; ----------------------------------------------------------------------------
L9A16:
        ldx     #$00                                           ; 9A16 A2 00
L9A18:
        lda     L9A24,x                                        ; 9A18 BD 24 9A
        sta     SQ1_VOL,x                                      ; 9A1B 9D 00 40
        inx                                                    ; 9A1E E8
        cpx     #$08                                           ; 9A1F E0 08
        bne     L9A18                                          ; 9A21 D0 F5
        rts                                                    ; 9A23 60

; ----------------------------------------------------------------------------
L9A24:
        .byte   $8F,$00,$20,$40,$8F,$00,$20,$40                ; 9A24 8F 00 20 40 8F 00 20 40
; ----------------------------------------------------------------------------
L9A2C:
        ldx     #$00                                           ; 9A2C A2 00
        lda     $05BC                                          ; 9A2E AD BC 05
        and     #$01                                           ; 9A31 29 01
        asl     a                                              ; 9A33 0A
        asl     a                                              ; 9A34 0A
        asl     a                                              ; 9A35 0A
        tay                                                    ; 9A36 A8
L9A37:
        lda     L9A4C,y                                        ; 9A37 B9 4C 9A
        sta     SQ1_VOL,x                                      ; 9A3A 9D 00 40
        inx                                                    ; 9A3D E8
        iny                                                    ; 9A3E C8
        cpx     #$08                                           ; 9A3F E0 08
        bne     L9A37                                          ; 9A41 D0 F4
        lda     SND_CHN                                        ; 9A43 AD 15 40
        ora     #$03                                           ; 9A46 09 03
        sta     SND_CHN                                        ; 9A48 8D 15 40
        rts                                                    ; 9A4B 60

; ----------------------------------------------------------------------------
L9A4C:
        .byte   $B8,$00,$FF,$03,$B8,$00,$FC,$03                ; 9A4C B8 00 FF 03 B8 00 FC 03
        .byte   $84,$AF,$FF,$03,$84,$AF,$FC,$03                ; 9A54 84 AF FF 03 84 AF FC 03
; ----------------------------------------------------------------------------
L9A5C:
        .addr   L9BCC                                          ; 9A5C CC 9B
        .addr   L9C11                                          ; 9A5E 11 9C
; ----------------------------------------------------------------------------
unknownTable09:
        .byte   $FB,$10,$00,$03                                ; 9A60 FB 10 00 03
; ----------------------------------------------------------------------------
L9A64:
        lda     L9A5C,x                                        ; 9A64 BD 5C 9A
        sta     $16                                            ; 9A67 85 16
        lda     L9A5C+1,x                                      ; 9A69 BD 5D 9A
        sta     $17                                            ; 9A6C 85 17
        lda     unknownTable09,x                               ; 9A6E BD 60 9A
        sta     $05C8                                          ; 9A71 8D C8 05
        lda     unknownTable09+1,x                             ; 9A74 BD 61 9A
        sta     $05C6                                          ; 9A77 8D C6 05
        ldy     #$00                                           ; 9A7A A0 00
        sty     $05BF                                          ; 9A7C 8C BF 05
        lda     ($16),y                                        ; 9A7F B1 16
        sta     $05BD                                          ; 9A81 8D BD 05
        iny                                                    ; 9A84 C8
        lda     ($16),y                                        ; 9A85 B1 16
        sta     $05BE                                          ; 9A87 8D BE 05
        iny                                                    ; 9A8A C8
        lda     ($16),y                                        ; 9A8B B1 16
        sta     $05C3                                          ; 9A8D 8D C3 05
        iny                                                    ; 9A90 C8
        lda     ($16),y                                        ; 9A91 B1 16
        sta     $05C4                                          ; 9A93 8D C4 05
        iny                                                    ; 9A96 C8
        sty     $05C5                                          ; 9A97 8C C5 05
L9A9A:
        lda     $05BF                                          ; 9A9A AD BF 05
        beq     L9AA6                                          ; 9A9D F0 07
        ldx     #$F0                                           ; 9A9F A2 F0
        ldy     #$F0                                           ; 9AA1 A0 F0
        jsr     L9AF6                                          ; 9AA3 20 F6 9A
L9AA6:
        ldy     $05C5                                          ; 9AA6 AC C5 05
        lda     ($16),y                                        ; 9AA9 B1 16
        cmp     #$FF                                           ; 9AAB C9 FF
        beq     L9AE9                                          ; 9AAD F0 3A
        sta     tmp14                                          ; 9AAF 85 14
        iny                                                    ; 9AB1 C8
        lda     ($16),y                                        ; 9AB2 B1 16
        sta     tmp15                                          ; 9AB4 85 15
        iny                                                    ; 9AB6 C8
        lda     ($16),y                                        ; 9AB7 B1 16
        sta     $05C0                                          ; 9AB9 8D C0 05
        iny                                                    ; 9ABC C8
        lda     ($16),y                                        ; 9ABD B1 16
        sta     $05BF                                          ; 9ABF 8D BF 05
        ldx     $05BD                                          ; 9AC2 AE BD 05
        ldy     $05BE                                          ; 9AC5 AC BE 05
        jsr     L9AF6                                          ; 9AC8 20 F6 9A
        ldy     $05C0                                          ; 9ACB AC C0 05
        jsr     sleepRoutine                                   ; 9ACE 20 31 9B
        lda     $05BE                                          ; 9AD1 AD BE 05
        clc                                                    ; 9AD4 18
        adc     $05C8                                          ; 9AD5 6D C8 05
        sta     $05BE                                          ; 9AD8 8D BE 05
        lda     $05C5                                          ; 9ADB AD C5 05
        clc                                                    ; 9ADE 18
        adc     #$04                                           ; 9ADF 69 04
        sta     $05C5                                          ; 9AE1 8D C5 05
        dec     $05C6                                          ; 9AE4 CE C6 05
        bne     L9A9A                                          ; 9AE7 D0 B1
L9AE9:
        ldx     #$F0                                           ; 9AE9 A2 F0
        ldy     #$F0                                           ; 9AEB A0 F0
        jsr     L9059                                          ; 9AED 20 59 90
        jsr     L9AF6                                          ; 9AF0 20 F6 9A
        jmp     L9059                                          ; 9AF3 4C 59 90

; ----------------------------------------------------------------------------
L9AF6:
        stx     $05C1                                          ; 9AF6 8E C1 05
        sty     $05C2                                          ; 9AF9 8C C2 05
        ldy     #$00                                           ; 9AFC A0 00
L9AFE:
        lda     (tmp14),y                                      ; 9AFE B1 14
        cmp     #$80                                           ; 9B00 C9 80
        beq     L9B30                                          ; 9B02 F0 2C
        asl     a                                              ; 9B04 0A
        asl     a                                              ; 9B05 0A
        tax                                                    ; 9B06 AA
        lda     $05C2                                          ; 9B07 AD C2 05
        cmp     #$F0                                           ; 9B0A C9 F0
        bne     L9B19                                          ; 9B0C D0 0B
        sta     oamStaging,x                                   ; 9B0E 9D 00 02
        sta     oamStaging+3,x                                 ; 9B11 9D 03 02
        iny                                                    ; 9B14 C8
        iny                                                    ; 9B15 C8
L9B16:
        iny                                                    ; 9B16 C8
        bne     L9AFE                                          ; 9B17 D0 E5
L9B19:
        iny                                                    ; 9B19 C8
        lda     $05C1                                          ; 9B1A AD C1 05
        clc                                                    ; 9B1D 18
        adc     (tmp14),y                                      ; 9B1E 71 14
        sta     oamStaging+3,x                                 ; 9B20 9D 03 02
        iny                                                    ; 9B23 C8
        lda     $05C2                                          ; 9B24 AD C2 05
        clc                                                    ; 9B27 18
        adc     (tmp14),y                                      ; 9B28 71 14
        sta     oamStaging,x                                   ; 9B2A 9D 00 02
        jmp     L9B16                                          ; 9B2D 4C 16 9B

; ----------------------------------------------------------------------------
L9B30:
        rts                                                    ; 9B30 60

; ----------------------------------------------------------------------------
; y controls number of cycles
sleepRoutine:
        ldx     #$00                                           ; 9B31 A2 00
@sleepLoop:
        nop                                                    ; 9B33 EA
        dex                                                    ; 9B34 CA
        bne     @sleepLoop                                     ; 9B35 D0 FC
        dey                                                    ; 9B37 88
        cpy     #$FF                                           ; 9B38 C0 FF
        bne     @sleepLoop                                     ; 9B3A D0 F7
        rts                                                    ; 9B3C 60

; ----------------------------------------------------------------------------
introScreenSprites:
        .byte   $F0,$D6,$03,$F0,$F0,$D7,$03,$F0                ; 9B3D F0 D6 03 F0 F0 D7 03 F0
        .byte   $F0,$D8,$03,$F0,$F0,$D9,$03,$F0                ; 9B45 F0 D8 03 F0 F0 D9 03 F0
        .byte   $F0,$DA,$03,$F0,$F0,$DB,$03,$F0                ; 9B4D F0 DA 03 F0 F0 DB 03 F0
        .byte   $F0,$DC,$03,$F0,$F0,$DD,$03,$F0                ; 9B55 F0 DC 03 F0 F0 DD 03 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B5D F0 D5 23 F0 F0 D5 23 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B65 F0 D5 23 F0 F0 D5 23 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B6D F0 D5 23 F0 F0 D5 23 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B75 F0 D5 23 F0 F0 D5 23 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B7D F0 D5 23 F0 F0 D5 23 F0
        .byte   $F0,$D5,$23,$F0,$F0,$D5,$23,$F0                ; 9B85 F0 D5 23 F0 F0 D5 23 F0
; above sprite table stops here
unknownTable04:
        .byte   $34,$00,$00,$35,$08,$02,$36,$10                ; 9B8D 34 00 00 35 08 02 36 10
        .byte   $04,$37,$18,$06,$38,$20,$08,$39                ; 9B95 04 37 18 06 38 20 08 39
        .byte   $28,$0A,$3A,$30,$0C,$3B,$38,$0E                ; 9B9D 28 0A 3A 30 0C 3B 38 0E
        .byte   $3C,$40,$10,$3D,$48,$12,$3E,$50                ; 9BA5 3C 40 10 3D 48 12 3E 50
        .byte   $14,$3F,$58,$16,$80,$2C,$00,$00                ; 9BAD 14 3F 58 16 80 2C 00 00
        .byte   $2D,$08,$00,$2E,$00,$08,$2F,$08                ; 9BB5 2D 08 00 2E 00 08 2F 08
        .byte   $08,$80,$30,$00,$00,$31,$08,$00                ; 9BBD 08 80 30 00 00 31 08 00
        .byte   $32,$00,$08,$33,$08,$08,$80                    ; 9BC5 32 00 08 33 08 08 80
L9BCC:
        .byte   $50,$90,$50,$40,$8D,$9B,$14,$01                ; 9BCC 50 90 50 40 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BD4 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BDC 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BE4 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BEC 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BF4 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9BFC 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$14,$01,$8D,$9B,$14,$01                ; 9C04 8D 9B 14 01 8D 9B 14 01
        .byte   $8D,$9B,$00,$00,$FF                            ; 9C0C 8D 9B 00 00 FF
L9C11:
        .byte   $A5,$61,$A5,$61,$B2,$9B,$64,$01                ; 9C11 A5 61 A5 61 B2 9B 64 01
        .byte   $BF,$9B,$FF,$01,$B2,$9B,$8C,$00                ; 9C19 BF 9B FF 01 B2 9B 8C 00
        .byte   $FF                                            ; 9C21 FF
; ----------------------------------------------------------------------------
drawBPSLogo:
        lda     #$20                                           ; 9C22 A9 20
        sta     PPUADDR                                        ; 9C24 8D 06 20
        lda     #$00                                           ; 9C27 A9 00
        sta     PPUADDR                                        ; 9C29 8D 06 20
        tax                                                    ; 9C2C AA
        tay                                                    ; 9C2D A8
@blankLoop:
        sta     PPUDATA                                        ; 9C2E 8D 07 20
        iny                                                    ; 9C31 C8
        bne     @blankLoop                                     ; 9C32 D0 FA
        inx                                                    ; 9C34 E8
        cpx     #$04                                           ; 9C35 E0 04
        bcc     @blankLoop                                     ; 9C37 90 F5
        lda     #<unknownTable03                               ; 9C39 A9 7B
        sta     tmp14                                          ; 9C3B 85 14
        lda     #>unknownTable03                               ; 9C3D A9 97
        sta     tmp15                                          ; 9C3F 85 15
        ldx     #$21                                           ; 9C41 A2 21
        stx     PPUADDR                                        ; 9C43 8E 06 20
        ldx     #$00                                           ; 9C46 A2 00
        stx     PPUADDR                                        ; 9C48 8E 06 20
        inx                                                    ; 9C4B E8
@sendByte:
        lda     (tmp14),y                                      ; 9C4C B1 14
        sta     PPUDATA                                        ; 9C4E 8D 07 20
        iny                                                    ; 9C51 C8
        bne     @sendByte                                      ; 9C52 D0 F8
        inc     tmp15                                          ; 9C54 E6 15
        dex                                                    ; 9C56 CA
        bpl     @sendByte                                      ; 9C57 10 F3
        ldx     #$4F                                           ; 9C59 A2 4F
@spriteLoop:
        lda     introScreenSprites,x                           ; 9C5B BD 3D 9B
        sta     oamStaging+176,x                               ; 9C5E 9D B0 02
        dex                                                    ; 9C61 CA
        bpl     @spriteLoop                                    ; 9C62 10 F7
@vblankWait:
        lda     PPUSTATUS                                      ; 9C64 AD 02 20
        bpl     @vblankWait                                    ; 9C67 10 FB
        lda     #$3F                                           ; 9C69 A9 3F
        sta     PPUADDR                                        ; 9C6B 8D 06 20
        inx                                                    ; 9C6E E8
        stx     PPUADDR                                        ; 9C6F 8E 06 20
@paletteLoop:
        lda     introScreenPalette,x                           ; 9C72 BD 86 9C
        sta     PPUDATA                                        ; 9C75 8D 07 20
        inx                                                    ; 9C78 E8
        cpx     #$20                                           ; 9C79 E0 20
        bcc     @paletteLoop                                   ; 9C7B 90 F5
        ldy     #$00                                           ; 9C7D A0 00
        sty     PPUSCROLL                                      ; 9C7F 8C 05 20
        sty     PPUSCROLL                                      ; 9C82 8C 05 20
        rts                                                    ; 9C85 60

; ----------------------------------------------------------------------------
introScreenPalette:
        .byte   $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F                ; 9C86 0F 0F 0F 0F 0F 0F 0F 0F
        .byte   $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F                ; 9C8E 0F 0F 0F 0F 0F 0F 0F 0F
        .byte   $0F,$0F,$30,$00,$0F,$30,$27,$0F                ; 9C96 0F 0F 30 00 0F 30 27 0F
        .byte   $0F,$27,$0F,$30,$0F,$2C,$3C,$30                ; 9C9E 0F 27 0F 30 0F 2C 3C 30
; above palette table ends here
unknownTable05:
        .byte   $03,$0C,$08,$03,$1C,$08,$01,$0C                ; 9CA6 03 0C 08 03 1C 08 01 0C
        .byte   $08,$02,$0C,$08,$03,$2C,$08,$02                ; 9CAE 08 02 0C 08 03 2C 08 02
        .byte   $01,$08,$03,$3C,$08,$01,$1C,$01                ; 9CB6 01 08 03 3C 08 01 1C 01
        .byte   $FF                                            ; 9CBE FF
L9CBF:
        .byte   $03,$1C,$05,$02,$0C,$05,$01,$0C                ; 9CBF 03 1C 05 02 0C 05 01 0C
        .byte   $05,$03,$0C,$05,$02,$0F,$05,$01                ; 9CC7 05 03 0C 05 02 0F 05 01
        .byte   $0F,$05,$03,$0F,$14,$FF                        ; 9CCF 0F 05 03 0F 14 FF
; ----------------------------------------------------------------------------
; has at least one palette table
addressTable01:
        .addr   introScreenPalette                             ; 9CD5 86 9C
        .addr   unknownTable05                                 ; 9CD7 A6 9C
        .addr   introScreenPalette                             ; 9CD9 86 9C
        .addr   L9CBF                                          ; 9CDB BF 9C
; ----------------------------------------------------------------------------
L9CDD:
        ldy     #$00                                           ; 9CDD A0 00
L9CDF:
        lda     introScreenPalette,y                           ; 9CDF B9 86 9C
        sta     $049A,y                                        ; 9CE2 99 9A 04
        iny                                                    ; 9CE5 C8
        cpy     #$10                                           ; 9CE6 C0 10
        bcc     L9CDF                                          ; 9CE8 90 F5
L9CEA:
        ldx     #$00                                           ; 9CEA A2 00
        stx     $53                                            ; 9CEC 86 53
        inx                                                    ; 9CEE E8
        stx     $54                                            ; 9CEF 86 54
        rts                                                    ; 9CF1 60

; ----------------------------------------------------------------------------
L9CF2:
        jsr     L9CEA                                          ; 9CF2 20 EA 9C
        lda     #$06                                           ; 9CF5 A9 06
        sta     $40                                            ; 9CF7 85 40
L9CF9:
        lda     $40                                            ; 9CF9 A5 40
        bne     L9CF9                                          ; 9CFB D0 FC
        rts                                                    ; 9CFD 60

; ----------------------------------------------------------------------------
L9CFE:
        ldx     $40                                            ; 9CFE A6 40
        beq     L9D45                                          ; 9D00 F0 43
        ldy     $53                                            ; 9D02 A4 53
        bne     L9D10                                          ; 9D04 D0 0A
        lda     addressTable01,x                               ; 9D06 BD D5 9C
        sta     $20                                            ; 9D09 85 20
        lda     addressTable01+1,x                             ; 9D0B BD D6 9C
        sta     $21                                            ; 9D0E 85 21
L9D10:
        dec     $54                                            ; 9D10 C6 54
        bne     L9D45                                          ; 9D12 D0 31
        lda     ($20),y                                        ; 9D14 B1 20
        sta     $55                                            ; 9D16 85 55
        bmi     L9D46                                          ; 9D18 30 2C
        inc     $53                                            ; 9D1A E6 53
        iny                                                    ; 9D1C C8
        lda     ($20),y                                        ; 9D1D B1 20
        ldy     $55                                            ; 9D1F A4 55
        sta     $049A,y                                        ; 9D21 99 9A 04
        lda     #$3F                                           ; 9D24 A9 3F
        sta     PPUADDR                                        ; 9D26 8D 06 20
        lda     #$00                                           ; 9D29 A9 00
        sta     PPUADDR                                        ; 9D2B 8D 06 20
        ldy     #$00                                           ; 9D2E A0 00
L9D30:
        lda     $049A,y                                        ; 9D30 B9 9A 04
        sta     PPUDATA                                        ; 9D33 8D 07 20
        iny                                                    ; 9D36 C8
        cpy     #$10                                           ; 9D37 C0 10
        bcc     L9D30                                          ; 9D39 90 F5
        inc     $53                                            ; 9D3B E6 53
        ldy     $53                                            ; 9D3D A4 53
        lda     ($20),y                                        ; 9D3F B1 20
        sta     $54                                            ; 9D41 85 54
        inc     $53                                            ; 9D43 E6 53
L9D45:
        rts                                                    ; 9D45 60

; ----------------------------------------------------------------------------
L9D46:
        ldy     #$00                                           ; 9D46 A0 00
        sty     $53                                            ; 9D48 84 53
        sty     $40                                            ; 9D4A 84 40
        iny                                                    ; 9D4C C8
        sty     $54                                            ; 9D4D 84 54
        rts                                                    ; 9D4F 60

; ----------------------------------------------------------------------------
unknownTable02:
        .byte   $00,$F0,$00,$F4                                ; 9D50 00 F0 00 F4
; ----------------------------------------------------------------------------
L9D54:
        sta     $061C                                          ; 9D54 8D 1C 06
        ldy     #$00                                           ; 9D57 A0 00
        sty     $0618                                          ; 9D59 8C 18 06
        sty     $0619                                          ; 9D5C 8C 19 06
        jsr     L8628                                          ; 9D5F 20 28 86
        rts                                                    ; 9D62 60

; ----------------------------------------------------------------------------
L9D63:
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D63 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D6B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D73 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D7B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D83 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D8B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D93 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9D9B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DA3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DAB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DB3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DBB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DC3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$0D,$1C,$0F,$0E                ; 9DCB 32 32 32 32 0D 1C 0F 0E
        .byte   $13,$1E,$1D,$32,$32,$32,$32,$32                ; 9DD3 13 1E 1D 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DDB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DE3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DEB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DF3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9DFB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E03 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E0B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E13 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E1B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E23 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E2B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E33 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E3B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$1A,$1C,$19,$0E,$1F                ; 9E43 32 32 32 1A 1C 19 0E 1F
        .byte   $0D,$0F,$0E,$32,$0C,$23,$32,$23                ; 9E4B 0D 0F 0E 32 0C 23 32 23
        .byte   $0B,$1D,$1F,$0B,$15,$13,$32,$18                ; 9E53 0B 1D 1F 0B 15 13 32 18
        .byte   $0B,$11,$19,$1D,$12,$13,$32,$32                ; 9E5B 0B 11 19 1D 12 13 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E63 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E6B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E73 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9E7B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$1A,$1C,$19,$11,$1C                ; 9E83 32 32 32 1A 1C 19 11 1C
        .byte   $0B,$17,$17,$0F,$0E,$32,$0C,$23                ; 9E8B 0B 17 17 0F 0E 32 0C 23
        .byte   $32,$0C,$19,$0C,$32,$1C,$1F,$1E                ; 9E93 32 0C 19 0C 32 1C 1F 1E
        .byte   $12,$0F,$1C,$10,$19,$1C,$0E,$32                ; 9E9B 12 0F 1C 10 19 1C 0E 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9EA3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9EAB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9EB3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9EBB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$11,$1C,$0B,$1A,$12                ; 9EC3 32 32 32 11 1C 0B 1A 12
        .byte   $13,$0D,$1D,$32,$0C,$23,$32,$12                ; 9ECB 13 0D 1D 32 0C 23 32 12
        .byte   $0B,$18,$1D,$32,$14,$0B,$18,$1D                ; 9ED3 0B 18 1D 32 14 0B 18 1D
        .byte   $1D,$0F,$18,$32,$32,$32,$32,$32                ; 9EDB 1D 0F 18 32 32 32 32 32
        .byte   $32,$32,$32,$0B,$18,$0E,$32,$15                ; 9EE3 32 32 32 0B 18 0E 32 15
        .byte   $0B,$24,$1F,$23,$1F,$15,$13,$32                ; 9EEB 0B 24 1F 23 1F 15 13 32
        .byte   $1E,$0B,$15,$13,$17,$19,$1E,$19                ; 9EF3 1E 0B 15 13 17 19 1E 19
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9EFB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F03 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F0B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F13 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F1B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$17,$1F,$1D,$13,$0D                ; 9F23 32 32 32 17 1F 1D 13 0D
        .byte   $32,$0C,$23,$32,$32,$32,$32,$32                ; 9F2B 32 0C 23 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F33 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F3B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$12,$13,$1D,$0B,$1D                ; 9F43 32 32 32 12 13 1D 0B 1D
        .byte   $12,$13,$32,$24,$0F,$1C,$19,$32                ; 9F4B 12 13 32 24 0F 1C 19 32
        .byte   $23,$19,$1E,$1D,$1F,$17,$19,$1E                ; 9F53 23 19 1E 1D 1F 17 19 1E
        .byte   $19,$32,$0B,$18,$0E,$32,$32,$32                ; 9F5B 19 32 0B 18 0E 32 32 32
        .byte   $32,$32,$32,$12,$13,$1C,$19,$1D                ; 9F63 32 32 32 12 13 1C 19 1D
        .byte   $12,$13,$32,$1E,$0B,$11,$1F,$0D                ; 9F6B 12 13 32 1E 0B 11 1F 0D
        .byte   $12,$13,$32,$32,$32,$32,$32,$32                ; 9F73 12 13 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F7B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F83 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F8B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F93 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9F9B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$1D,$19,$1F,$18,$0E                ; 9FA3 32 32 32 1D 19 1F 18 0E
        .byte   $32,$0C,$23,$32,$12,$13,$1C,$19                ; 9FAB 32 0C 23 32 12 13 1C 19
        .byte   $1D,$12,$13,$32,$1D,$1F,$24,$1F                ; 9FB3 1D 12 13 32 1D 1F 24 1F
        .byte   $15,$13,$32,$32,$32,$32,$32,$32                ; 9FBB 15 13 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FC3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FCB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FD3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FDB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FE3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FEB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FF3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; 9FFB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A003 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A00B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A013 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A01B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$1D,$1A                ; A023 32 32 32 32 32 32 1D 1A
        .byte   $0F,$0D,$13,$0B,$16,$32,$1E,$12                ; A02B 0F 0D 13 0B 16 32 1E 12
        .byte   $0B,$18,$15,$1D,$32,$1E,$19,$32                ; A033 0B 18 15 1D 32 1E 19 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A03B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A043 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A04B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A053 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A05B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$1E,$0B                ; A063 32 32 32 32 32 32 1E 0B
        .byte   $15,$0B,$12,$13,$1C,$19,$32,$15                ; A06B 15 0B 12 13 1C 19 32 15
        .byte   $19,$1D,$0F,$15,$13,$32,$32,$32                ; A073 19 1D 0F 15 13 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A07B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$1E,$12                ; A083 32 32 32 32 32 32 1E 12
        .byte   $19,$17,$0B,$1D,$32,$19,$1E,$0B                ; A08B 19 17 0B 1D 32 19 1E 0B
        .byte   $15,$0F,$32,$32,$32,$32,$32,$32                ; A093 15 0F 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A09B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$0B,$18                ; A0A3 32 32 32 32 32 32 0B 18
        .byte   $0E,$32,$19,$1F,$1C,$32,$0C,$1A                ; A0AB 0E 32 19 1F 1C 32 0C 1A
        .byte   $1D,$32,$1D,$1E,$0B,$10,$10,$32                ; A0B3 1D 32 1D 1E 0B 10 10 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0BB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0C3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0CB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0D3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0DB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0E3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0EB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0F3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A0FB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A103 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A10B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A113 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A11B 32 32 32 32 32 32 32 32
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A123 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A12B FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A133 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A13B FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A143 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A14B FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A153 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A15B FF FF FF FF FF FF FF FF
LA163:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A163 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A16B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A173 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A17B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A183 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A18B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A193 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A19B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1A3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1AB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1B3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1BB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1C3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1CB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1D3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1DB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1E3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1EB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1F3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A1FB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A203 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A20B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A213 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A21B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A223 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A22B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A233 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A23B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A243 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A24B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A253 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A25B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A263 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$80                ; A26B 00 00 00 00 00 00 00 80
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A273 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A27B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A283 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$81,$82                ; A28B 00 00 00 00 00 00 81 82
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A293 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A29B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2A3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$84,$85                ; A2AB 00 00 00 00 00 00 84 85
        .byte   $E2,$00,$00,$00,$00,$00,$00,$00                ; A2B3 E2 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2BB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2C3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$87,$88                ; A2CB 00 00 00 00 00 00 87 88
        .byte   $E1,$00,$00,$00,$00,$00,$00,$00                ; A2D3 E1 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2DB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2E3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$8A,$9C                ; A2EB 00 00 00 00 00 00 8A 9C
        .byte   $8C,$00,$00,$00,$00,$00,$00,$00                ; A2F3 8C 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A2FB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A303 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$A1,$A2                ; A30B 00 00 00 00 00 00 A1 A2
        .byte   $A3,$00,$00,$00,$00,$00,$00,$00                ; A313 A3 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A31B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$80,$00,$00,$00,$00                ; A323 00 00 00 80 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$8D,$A2                ; A32B 00 00 00 00 00 00 8D A2
        .byte   $A3,$00,$00,$00,$00,$00,$00,$00                ; A333 A3 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A33B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$81,$82,$00,$00,$00,$00                ; A343 00 00 81 82 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$96,$97                ; A34B 00 00 00 00 00 00 96 97
        .byte   $71,$00,$00,$00,$00,$00,$00,$00                ; A353 71 00 00 00 00 00 00 00
        .byte   $00,$00,$92,$93,$00,$00,$00,$00                ; A35B 00 00 92 93 00 00 00 00
        .byte   $00,$00,$90,$91,$E2,$00,$00,$00                ; A363 00 00 90 91 E2 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$8D,$A2                ; A36B 00 00 00 00 00 00 8D A2
        .byte   $A3,$00,$00,$00,$00,$00,$00,$00                ; A373 A3 00 00 00 00 00 00 00
        .byte   $00,$00,$DA,$DB,$00,$00,$00,$00                ; A37B 00 00 DA DB 00 00 00 00
        .byte   $E7,$E5,$87,$A8,$E1,$E5,$00,$E7                ; A383 E7 E5 87 A8 E1 E5 00 E7
        .byte   $E7,$00,$92,$93,$E7,$E7,$B2,$B3                ; A38B E7 00 92 93 E7 E7 B2 B3
        .byte   $B4,$E6,$00,$E6,$E7,$7C,$00,$E7                ; A393 B4 E6 00 E6 E7 7C 00 E7
        .byte   $E5,$D6,$D7,$D8,$D9,$E7,$7C,$E7                ; A39B E5 D6 D7 D8 D9 E7 7C E7
        .byte   $74,$75,$8A,$8B,$8C,$00,$DF,$98                ; A3A3 74 75 8A 8B 8C 00 DF 98
        .byte   $E5,$E5,$DA,$DB,$00,$E6,$8D,$A2                ; A3AB E5 E5 DA DB 00 E6 8D A2
        .byte   $A3,$E5,$E7,$7C,$F3,$E7,$78,$79                ; A3B3 A3 E5 E7 7C F3 E7 78 79
        .byte   $CF,$D0,$D1,$D3,$D4,$D5,$78,$79                ; A3BB CF D0 D1 D3 D4 D5 78 79
        .byte   $76,$77,$8D,$8E,$8F,$00,$72,$73                ; A3C3 76 77 8D 8E 8F 00 72 73
        .byte   $E5,$D6,$D7,$D8,$D9,$E5,$C0,$C1                ; A3CB E5 D6 D7 D8 D9 E5 C0 C1
        .byte   $C2,$00,$78,$79,$92,$93,$7A,$7B                ; A3D3 C2 00 78 79 92 93 7A 7B
        .byte   $E5,$CB,$CC,$CD,$CE,$E6,$7A,$00                ; A3DB E5 CB CC CD CE E6 7A 00
        .byte   $00,$F8,$8D,$8E,$8F,$00,$F1,$F2                ; A3E3 00 F8 8D 8E 8F 00 F1 F2
        .byte   $CF,$D0,$D1,$D3,$D4,$DD,$C0,$C1                ; A3EB CF D0 D1 D3 D4 DD C0 C1
        .byte   $C2,$00,$F1,$DE,$EE,$EF,$DE,$F2                ; A3F3 C2 00 F1 DE EE EF DE F2
        .byte   $00,$8A,$8B,$8B,$8C,$00,$F1,$F2                ; A3FB 00 8A 8B 8B 8C 00 F1 F2
        .byte   $DE,$F2,$96,$97,$71,$E5,$F3,$F4                ; A403 DE F2 96 97 71 E5 F3 F4
        .byte   $00,$CB,$CC,$CD,$CE,$00,$C4,$C5                ; A40B 00 CB CC CD CE 00 C4 C5
        .byte   $C6,$00,$F3,$FD,$FE,$FF,$DC,$F4                ; A413 C6 00 F3 FD FE FF DC F4
        .byte   $00,$8D,$8E,$8E,$8F,$00,$F3,$F4                ; A41B 00 8D 8E 8E 8F 00 F3 F4
        .byte   $F3,$F4,$8D,$8E,$8F,$00,$F5,$F6                ; A423 F3 F4 8D 8E 8F 00 F5 F6
        .byte   $00,$8A,$9C,$9C,$8C,$E5,$C9,$C9                ; A42B 00 8A 9C 9C 8C E5 C9 C9
        .byte   $CA,$00,$E8,$E9,$EA,$EB,$EC,$ED                ; A433 CA 00 E8 E9 EA EB EC ED
        .byte   $00,$AC,$BC,$BC,$AE,$00,$F5,$F6                ; A43B 00 AC BC BC AE 00 F5 F6
        .byte   $F8,$F8,$A4,$A5,$A6,$00,$7A,$F8                ; A443 F8 F8 A4 A5 A6 00 7A F8
        .byte   $00,$B2,$B3,$B3,$B4,$00,$C9,$C9                ; A44B 00 B2 B3 B3 B4 00 C9 C9
        .byte   $CA,$00,$F8,$F9,$FA,$FB,$FC,$F8                ; A453 CA 00 F8 F9 FA FB FC F8
        .byte   $00,$B5,$C3,$C3,$B7,$00,$F7,$F8                ; A45B 00 B5 C3 C3 B7 00 F7 F8
        .byte   $00,$F8,$AC,$AD,$AE,$00,$00,$00                ; A463 00 F8 AC AD AE 00 00 00
        .byte   $E5,$8A,$9C,$9C,$8C,$00,$B3,$B3                ; A46B E5 8A 9C 9C 8C 00 B3 B3
        .byte   $B3,$00,$00,$8A,$9C,$9C,$8C,$00                ; A473 B3 00 00 8A 9C 9C 8C 00
        .byte   $00,$AC,$BC,$BC,$AE,$00,$F3,$F3                ; A47B 00 AC BC BC AE 00 F3 F3
        .byte   $00,$00,$B5,$B6,$B7,$00,$00,$00                ; A483 00 00 B5 B6 B7 00 00 00
        .byte   $00,$96,$97,$97,$71,$00,$A5,$A5                ; A48B 00 96 97 97 71 00 A5 A5
        .byte   $A5,$00,$00,$B2,$B3,$B3,$B4,$E5                ; A493 A5 00 00 B2 B3 B3 B4 E5
        .byte   $00,$B5,$C3,$C3,$B7,$00,$E5,$00                ; A49B 00 B5 C3 C3 B7 00 E5 00
        .byte   $E4,$E4,$E4,$E4,$E4,$E4,$E4,$E4                ; A4A3 E4 E4 E4 E4 E4 E4 E4 E4
        .byte   $E4,$E4,$E4,$E4,$E4,$E4,$E4,$E4                ; A4AB E4 E4 E4 E4 E4 E4 E4 E4
        .byte   $E4,$E4,$E4,$E4,$E4,$E4,$E4,$E4                ; A4B3 E4 E4 E4 E4 E4 E4 E4 E4
        .byte   $E4,$E4,$E4,$E4,$E4,$E4,$E4,$E4                ; A4BB E4 E4 E4 E4 E4 E4 E4 E4
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4C3 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4CB E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4D3 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4DB E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4E3 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4EB E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4F3 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A4FB E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A503 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A50B E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A513 E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3                ; A51B E3 E3 E3 E3 E3 E3 E3 E3
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A523 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; A52B FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$77,$DD,$FF,$FF,$FF                ; A533 FF FF FF 77 DD FF FF FF
        .byte   $3F,$CF,$FF,$33,$CC,$FF,$EF,$FF                ; A53B 3F CF FF 33 CC FF EF FF
        .byte   $70,$DC,$50,$10,$C0,$F3,$00,$CC                ; A543 70 DC 50 10 C0 F3 00 CC
        .byte   $77,$DD,$05,$01,$CC,$FF,$99,$DD                ; A54B 77 DD 05 01 CC FF 99 DD
        .byte   $07,$0D,$00,$00,$00,$00,$09,$0D                ; A553 07 0D 00 00 00 00 09 0D
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A55B 00 00 00 00 00 00 00 00
LA563:
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A563 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A56B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A573 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A57B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A583 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A58B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A593 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A59B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5A3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5AB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5B3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5BB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5C3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5CB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5D3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5DB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5E3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5EB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5F3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A5FB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A603 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A60B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A613 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A61B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A623 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A62B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A633 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A63B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$1E,$17,$32,$0B,$18,$0E                ; A643 32 32 1E 17 32 0B 18 0E
        .byte   $32,$26,$32,$01,$09,$08,$07,$32                ; A64B 32 26 32 01 09 08 07 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A653 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A65B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$20,$28,$19,$32,$0F,$16                ; A663 32 32 20 28 19 32 0F 16
        .byte   $0F,$0D,$1E,$1C,$19,$18,$19,$1C                ; A66B 0F 0D 1E 1C 19 18 19 1C
        .byte   $11,$1E,$0F,$0D,$12,$18,$13,$0D                ; A673 11 1E 0F 0D 12 18 13 0D
        .byte   $0B,$32,$32,$32,$32,$32,$32,$32                ; A67B 0B 32 32 32 32 32 32 32
        .byte   $32,$32,$29,$A3,$0F,$16,$19,$1C                ; A683 32 32 29 A3 0F 16 19 1C
        .byte   $11,$A3,$2A,$32,$32,$32,$32,$32                ; A68B 11 A3 2A 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A693 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A69B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A6A3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A6AB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A6B3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A6BB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$1E,$0F,$1E,$1C,$13,$1D                ; A6C3 32 32 1E 0F 1E 1C 13 1D
        .byte   $32,$16,$13,$0D,$0F,$18,$1D,$0F                ; A6CB 32 16 13 0D 0F 18 1D 0F
        .byte   $0E,$32,$1E,$19,$32,$18,$13,$18                ; A6D3 0E 32 1E 19 32 18 13 18
        .byte   $1E,$0F,$18,$0E,$19,$32,$32,$32                ; A6DB 1E 0F 18 0E 19 32 32 32
        .byte   $32,$32,$0B,$18,$0E,$32,$1D,$1F                ; A6E3 32 32 0B 18 0E 32 1D 1F
        .byte   $0C,$16,$13,$0D,$0F,$18,$1D,$0F                ; A6EB 0C 16 13 0D 0F 18 1D 0F
        .byte   $0E,$32,$1E,$19,$32,$32,$32,$32                ; A6F3 0E 32 1E 19 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A6FB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$0C,$1F,$16,$16,$0F,$1E                ; A703 32 32 0C 1F 16 16 0F 1E
        .byte   $DE,$1A,$1C,$19,$19,$10,$32,$1D                ; A70B DE 1A 1C 19 19 10 32 1D
        .byte   $19,$10,$1E,$21,$0B,$1C,$0F,$25                ; A713 19 10 1E 21 0B 1C 0F 25
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A71B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A723 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A72B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A733 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A73B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$26,$01,$09,$08,$08,$32                ; A743 32 32 26 01 09 08 08 32
        .byte   $0C,$1F,$16,$16,$0F,$1E,$DE,$1A                ; A74B 0C 1F 16 16 0F 1E DE 1A
        .byte   $1C,$19,$19,$10,$32,$1D,$19,$10                ; A753 1C 19 19 10 32 1D 19 10
        .byte   $1E,$21,$0B,$1C,$0F,$25,$32,$32                ; A75B 1E 21 0B 1C 0F 25 32 32
        .byte   $32,$32,$0B,$16,$16,$32,$1C,$13                ; A763 32 32 0B 16 16 32 1C 13
        .byte   $11,$12,$1E,$1D,$32,$1C,$0F,$1D                ; A76B 11 12 1E 1D 32 1C 0F 1D
        .byte   $0F,$1C,$20,$0F,$0E,$25,$32,$32                ; A773 0F 1C 20 0F 0E 25 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A77B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A783 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A78B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A793 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A79B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A7A3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A7AB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A7B3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A7BB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$19,$1C,$13,$11,$13,$18                ; A7C3 32 32 19 1C 13 11 13 18
        .byte   $0B,$16,$32,$0D,$19,$18,$0D,$0F                ; A7CB 0B 16 32 0D 19 18 0D 0F
        .byte   $1A,$1E,$27,$32,$0E,$0F,$1D,$13                ; A7D3 1A 1E 27 32 0E 0F 1D 13
        .byte   $11,$18,$32,$0B,$18,$0E,$32,$32                ; A7DB 11 18 32 0B 18 0E 32 32
        .byte   $32,$32,$1A,$1C,$19,$11,$1C,$0B                ; A7E3 32 32 1A 1C 19 11 1C 0B
        .byte   $17,$32,$0C,$23,$32,$0B,$16,$0F                ; A7EB 17 32 0C 23 32 0B 16 0F
        .byte   $22,$0F,$23,$32,$1A,$0B,$24,$12                ; A7F3 22 0F 23 32 1A 0B 24 12
        .byte   $13,$1E,$18,$19,$20,$25,$32,$32                ; A7FB 13 1E 18 19 20 25 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A803 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A80B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A813 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A81B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A823 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A82B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A833 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A83B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A843 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A84B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A853 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A85B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A863 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A86B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A873 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A87B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A883 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A88B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A893 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A89B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8A3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8AB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8B3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8BB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8C3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8CB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8D3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8DB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8E3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8EB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8F3 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A8FB 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A903 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A90B 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A913 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; A91B 32 32 32 32 32 32 32 32
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A923 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A92B 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A933 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A93B 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A943 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A94B 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A953 55 55 55 55 55 55 55 55
        .byte   $55,$55,$55,$55,$55,$55,$55,$55                ; A95B 55 55 55 55 55 55 55 55
LA963:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A963 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A96B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A973 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A97B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A983 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A98B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A993 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; A99B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$03,$04                ; A9A3 00 00 00 00 00 00 03 04
        .byte   $05,$00,$04,$05,$00,$03,$04,$05                ; A9AB 05 00 04 05 00 03 04 05
        .byte   $00,$06,$07,$E5,$EF,$F0,$00,$08                ; A9B3 00 06 07 E5 EF F0 00 08
        .byte   $09,$0A,$00,$00,$00,$00,$00,$00                ; A9BB 09 0A 00 00 00 00 00 00
        .byte   $00,$B6,$B7,$9C,$9D,$00,$0B,$0C                ; A9C3 00 B6 B7 9C 9D 00 0B 0C
        .byte   $0D,$00,$0C,$0E,$00,$0B,$0C,$0D                ; A9CB 0D 00 0C 0E 00 0B 0C 0D
        .byte   $00,$0C,$0F,$A6,$EC,$ED,$00,$10                ; A9D3 00 0C 0F A6 EC ED 00 10
        .byte   $11,$12,$9D,$9C,$9D,$9C,$BA,$00                ; A9DB 11 12 9D 9C 9D 9C BA 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$13                ; A9E3 00 9A C2 C3 C2 C3 C2 13
        .byte   $C2,$C3,$13,$14,$C2,$C3,$13,$C3                ; A9EB C2 C3 13 14 C2 C3 13 C3
        .byte   $C2,$13,$E4,$A7,$EB,$EE,$C2,$16                ; A9F3 C2 13 E4 A7 EB EE C2 16
        .byte   $17,$18,$C2,$C3,$C2,$C3,$9A,$00                ; A9FB 17 18 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$19                ; AA03 00 9B C4 C5 C4 C5 C4 19
        .byte   $C4,$C5,$19,$1A,$C4,$C5,$19,$C5                ; AA0B C4 C5 19 1A C4 C5 19 C5
        .byte   $C4,$19,$E3,$E2,$E9,$EA,$C4,$1C                ; AA13 C4 19 E3 E2 E9 EA C4 1C
        .byte   $1D,$72,$73,$C5,$C4,$C5,$9B,$00                ; AA1B 1D 72 73 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AA23 00 9A C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$C2,$1F                ; AA2B C2 C3 C2 C3 C2 C3 C2 1F
        .byte   $20,$A9,$CC,$E6,$F1,$C3,$C2,$C3                ; AA33 20 A9 CC E6 F1 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AA3B C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$C5                ; AA43 00 9B C4 C5 C4 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$21,$22                ; AA4B C4 C5 C4 C5 C4 C5 21 22
        .byte   $23,$24,$CD,$CB,$C7,$C5,$C4,$C5                ; AA53 23 24 CD CB C7 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$9B,$00                ; AA5B C4 C5 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AA63 00 9A C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$25,$26,$27                ; AA6B C2 C3 C2 C3 C2 25 26 27
        .byte   $28,$29,$2A,$AA,$C8,$C3,$C2,$C3                ; AA73 28 29 2A AA C8 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AA7B C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$C5                ; AA83 00 9B C4 C5 C4 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$2B,$2C,$2D,$2E                ; AA8B C4 C5 C4 C5 2B 2C 2D 2E
        .byte   $2F,$30,$31,$CF,$C9,$C5,$C4,$C5                ; AA93 2F 30 31 CF C9 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$9B,$00                ; AA9B C4 C5 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AAA3 00 9A C2 C3 C2 C3 C2 C3
        .byte   $C2,$33,$34,$C3,$35,$36,$37,$38                ; AAAB C2 33 34 C3 35 36 37 38
        .byte   $39,$3A,$3B,$AB,$D0,$33,$34,$C3                ; AAB3 39 3A 3B AB D0 33 34 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AABB C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$C5                ; AAC3 00 9B C4 C5 C4 C5 C4 C5
        .byte   $3D,$3E,$3F,$40,$A4,$41,$42,$43                ; AACB 3D 3E 3F 40 A4 41 42 43
        .byte   $44,$45,$46,$AC,$D1,$3E,$3F,$40                ; AAD3 44 45 46 AC D1 3E 3F 40
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$9B,$00                ; AADB C4 C5 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AAE3 00 9A C2 C3 C2 C3 C2 C3
        .byte   $47,$48,$49,$4A,$A3,$4B,$4C,$4D                ; AAEB 47 48 49 4A A3 4B 4C 4D
        .byte   $4E,$4F,$50,$D2,$47,$48,$49,$4A                ; AAF3 4E 4F 50 D2 47 48 49 4A
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AAFB C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$C5                ; AB03 00 9B C4 C5 C4 C5 C4 C5
        .byte   $51,$52,$53,$54,$DA,$DB,$56,$57                ; AB0B 51 52 53 54 DA DB 56 57
        .byte   $58,$59,$5A,$D3,$51,$52,$53,$54                ; AB13 58 59 5A D3 51 52 53 54
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$9B,$00                ; AB1B C4 C5 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AB23 00 9A C2 C3 C2 C3 C2 C3
        .byte   $AD,$5C,$5D,$5E,$DC,$DD,$01,$60                ; AB2B AD 5C 5D 5E DC DD 01 60
        .byte   $61,$62,$63,$D4,$E7,$5C,$5D,$AF                ; AB33 61 62 63 D4 E7 5C 5D AF
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AB3B C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$C4,$C5                ; AB43 00 9B C4 C5 C4 C5 C4 C5
        .byte   $AE,$65,$66,$67,$DE,$E0,$02,$69                ; AB4B AE 65 66 67 DE E0 02 69
        .byte   $6A,$6B,$6C,$D5,$E8,$65,$66,$B0                ; AB53 6A 6B 6C D5 E8 65 66 B0
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$9B,$00                ; AB5B C4 C5 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$74,$75                ; AB63 00 9A C2 C3 C2 C3 74 75
        .byte   $76,$77,$78,$79,$7A,$7B,$7C,$7D                ; AB6B 76 77 78 79 7A 7B 7C 7D
        .byte   $7E,$7F,$80,$81,$82,$83,$84,$85                ; AB73 7E 7F 80 81 82 83 84 85
        .byte   $86,$87,$C2,$C3,$C2,$C3,$9A,$00                ; AB7B 86 87 C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$88,$89                ; AB83 00 9B C4 C5 C4 C5 88 89
        .byte   $8A,$8A,$8A,$90,$91,$92,$8A,$8A                ; AB8B 8A 8A 8A 90 91 92 8A 8A
        .byte   $8A,$8A,$93,$94,$95,$8A,$8A,$8A                ; AB93 8A 8A 93 94 95 8A 8A 8A
        .byte   $96,$97,$C4,$C5,$C4,$C5,$9B,$00                ; AB9B 96 97 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$8B,$8C                ; ABA3 00 9A C2 C3 C2 C3 8B 8C
        .byte   $8C,$8C,$8A,$8A,$8A,$8A,$8C,$8C                ; ABAB 8C 8C 8A 8A 8A 8A 8C 8C
        .byte   $8A,$8A,$8A,$8A,$8C,$8C,$8C,$8C                ; ABB3 8A 8A 8A 8A 8C 8C 8C 8C
        .byte   $8C,$8D,$C2,$C3,$C2,$C3,$9A,$00                ; ABBB 8C 8D C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$8F,$8C                ; ABC3 00 9B C4 C5 C4 C5 8F 8C
        .byte   $8C,$8C,$8A,$8A,$8A,$8A,$8C,$8C                ; ABCB 8C 8C 8A 8A 8A 8A 8C 8C
        .byte   $8A,$8A,$8A,$8A,$B3,$8C,$8C,$8C                ; ABD3 8A 8A 8A 8A B3 8C 8C 8C
        .byte   $8C,$8E,$C4,$C5,$C4,$C5,$9B,$00                ; ABDB 8C 8E C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$8F,$8C                ; ABE3 00 9A C2 C3 C2 C3 8F 8C
        .byte   $B3,$8C,$8C,$8C,$8C,$8C,$8C,$8C                ; ABEB B3 8C 8C 8C 8C 8C 8C 8C
        .byte   $B3,$8C,$8C,$B2,$C2,$B5,$8C,$8C                ; ABF3 B3 8C 8C B2 C2 B5 8C 8C
        .byte   $8C,$8E,$C2,$C3,$C2,$C3,$9A,$00                ; ABFB 8C 8E C2 C3 C2 C3 9A 00
        .byte   $00,$9B,$C4,$C5,$C4,$C5,$B1,$B2                ; AC03 00 9B C4 C5 C4 C5 B1 B2
        .byte   $C4,$B5,$8C,$8C,$8C,$8C,$8C,$B2                ; AC0B C4 B5 8C 8C 8C 8C 8C B2
        .byte   $C4,$B5,$B2,$C5,$C4,$C5,$B5,$B3                ; AC13 C4 B5 B2 C5 C4 C5 B5 B3
        .byte   $B3,$B4,$C4,$C5,$C4,$C5,$9B,$00                ; AC1B B3 B4 C4 C5 C4 C5 9B 00
        .byte   $00,$9A,$C2,$C3,$C2,$C3,$C2,$C3                ; AC23 00 9A C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$B5,$B3,$8C,$8C,$B2,$C3                ; AC2B C2 C3 B5 B3 8C 8C B2 C3
        .byte   $C2,$C3,$C2,$C3,$98,$C3,$C2,$C3                ; AC33 C2 C3 C2 C3 98 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$9A,$00                ; AC3B C2 C3 C2 C3 C2 C3 9A 00
        .byte   $00,$B9,$C4,$C5,$C4,$C5,$C4,$C5                ; AC43 00 B9 C4 C5 C4 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$B5,$B2,$C4,$C5                ; AC4B C4 C5 C4 C5 B5 B2 C4 C5
        .byte   $C4,$C5,$C4,$98,$98,$98,$C4,$C5                ; AC53 C4 C5 C4 98 98 98 C4 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$B9,$00                ; AC5B C4 C5 C4 C5 C4 C5 B9 00
        .byte   $BE,$BA,$C2,$C3,$C2,$C3,$C2,$C3                ; AC63 BE BA C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$C2,$C3                ; AC6B C2 C3 C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$C3,$C2,$C3                ; AC73 C2 C3 C2 C3 C2 C3 C2 C3
        .byte   $C2,$C3,$C2,$C3,$C2,$D6,$BA,$00                ; AC7B C2 C3 C2 C3 C2 D6 BA 00
        .byte   $BF,$BB,$C4,$C5,$C4,$C5,$C4,$C5                ; AC83 BF BB C4 C5 C4 C5 C4 C5
        .byte   $98,$98,$98,$C5,$C4,$C5,$C4,$C5                ; AC8B 98 98 98 C5 C4 C5 C4 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$C5,$98,$C5                ; AC93 C4 C5 C4 C5 C4 C5 98 C5
        .byte   $C4,$C5,$C4,$C5,$C4,$D7,$BB,$00                ; AC9B C4 C5 C4 C5 C4 D7 BB 00
        .byte   $C0,$BC,$C2,$C3,$C2,$C3,$C2,$98                ; ACA3 C0 BC C2 C3 C2 C3 C2 98
        .byte   $99,$99,$98,$00,$98,$C3,$C2,$C3                ; ACAB 99 99 98 00 98 C3 C2 C3
        .byte   $98,$98,$99,$00,$00,$99,$99,$99                ; ACB3 98 98 99 00 00 99 99 99
        .byte   $98,$98,$C2,$C3,$C2,$D8,$BC,$00                ; ACBB 98 98 C2 C3 C2 D8 BC 00
        .byte   $C1,$BD,$C4,$C5,$C4,$C5,$98,$98                ; ACC3 C1 BD C4 C5 C4 C5 98 98
        .byte   $99,$99,$98,$98,$98,$98,$00,$98                ; ACCB 99 99 98 98 98 98 00 98
        .byte   $98,$98,$99,$99,$99,$99,$99,$99                ; ACD3 98 98 99 99 99 99 99 99
        .byte   $98,$98,$C4,$C5,$C4,$D9,$BD,$00                ; ACDB 98 98 C4 C5 C4 D9 BD 00
        .byte   $00,$C3,$C2,$C3,$C2,$C3,$99,$99                ; ACE3 00 C3 C2 C3 C2 C3 99 99
        .byte   $99,$99,$98,$98,$99,$99,$99,$99                ; ACEB 99 99 98 98 99 99 99 99
        .byte   $98,$98,$98,$98,$99,$99,$99,$99                ; ACF3 98 98 98 98 99 99 99 99
        .byte   $99,$99,$C2,$C3,$C2,$C3,$C2,$00                ; ACFB 99 99 C2 C3 C2 C3 C2 00
        .byte   $00,$C5,$C4,$C5,$C4,$C5,$99,$99                ; AD03 00 C5 C4 C5 C4 C5 99 99
        .byte   $99,$99,$98,$98,$99,$99,$99,$99                ; AD0B 99 99 98 98 99 99 99 99
        .byte   $98,$98,$98,$98,$99,$99,$99,$99                ; AD13 98 98 98 98 99 99 99 99
        .byte   $99,$99,$00,$00,$00,$00,$00,$00                ; AD1B 99 99 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; AD23 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; AD2B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; AD33 00 00 00 00 00 00 00 00
        .byte   $00,$00,$50,$77,$DD,$50,$00,$00                ; AD3B 00 00 50 77 DD 50 00 00
        .byte   $00,$0C,$CF,$3F,$FF,$0F,$03,$00                ; AD43 00 0C CF 3F FF 0F 03 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; AD4B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$20,$00,$80,$A0,$00,$00                ; AD53 00 00 20 00 80 A0 00 00
        .byte   $00,$08,$02,$0A,$00,$0A,$02                    ; AD5B 00 08 02 0A 00 0A 02
LAD62:
        .byte   $00,$32,$32,$32,$32,$32,$32,$32                ; AD62 00 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$0E,$1C,$19,$1A,$1D                ; AD6A 32 32 32 0E 1C 19 1A 1D
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AD72 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$01                ; AD7A 32 32 32 32 32 32 32 01
        .byte   $32,$16,$13,$18,$0F,$32,$32,$32                ; AD82 32 16 13 18 0F 32 32 32
        .byte   $32,$32,$32,$32,$22,$32,$04,$0A                ; AD8A 32 32 32 32 22 32 04 0A
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AD92 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$02,$32,$16                ; AD9A 32 32 32 32 32 02 32 16
        .byte   $13,$18,$0F,$1D,$32,$32,$32,$32                ; ADA2 13 18 0F 1D 32 32 32 32
        .byte   $32,$32,$22,$32,$01,$0A,$0A,$32                ; ADAA 32 32 22 32 01 0A 0A 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; ADB2 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$03,$32,$16,$13,$18                ; ADBA 32 32 32 03 32 16 13 18
        .byte   $0F,$1D,$32,$32,$32,$32,$32,$32                ; ADC2 0F 1D 32 32 32 32 32 32
        .byte   $22,$32,$03,$0A,$0A,$32,$32,$32                ; ADCA 22 32 03 0A 0A 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; ADD2 32 32 32 32 32 32 32 32
        .byte   $32,$04,$32,$16,$13,$18,$0F,$1D                ; ADDA 32 04 32 16 13 18 0F 1D
        .byte   $32,$32,$32,$32,$32,$32,$22,$32                ; ADE2 32 32 32 32 32 32 22 32
        .byte   $01,$02,$0A,$0A,$32,$32,$32,$32                ; ADEA 01 02 0A 0A 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; ADF2 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; ADFA 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE02 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$1E,$12,$13,$1D,$32                ; AE0A 32 32 32 1E 12 13 1D 32
        .byte   $1D,$1E,$0B,$11,$0F                            ; AE12 1D 1E 0B 11 0F
LAE17:
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE17 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE1F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE27 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE2F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE37 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$11,$0B,$17,$0F,$32                ; AE3F 32 32 32 11 0B 17 0F 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE47 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$19                ; AE4F 32 32 32 32 32 32 32 19
        .byte   $20,$0F,$1C,$32,$32,$32,$32,$32                ; AE57 20 0F 1C 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE5F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE67 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE6F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE77 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE7F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE87 32 32 32 32 32 32 32 32
        .byte   $32,$32,$1A,$16,$0F,$0B,$1D,$0F                ; AE8F 32 32 1A 16 0F 0B 1D 0F
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AE97 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$1E                ; AE9F 32 32 32 32 32 32 32 1E
        .byte   $1C,$23,$32,$32,$32,$32,$32,$32                ; AEA7 1C 23 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AEAF 32 32 32 32 32 32 32 32
        .byte   $32,$32,$0B,$11,$0B,$13,$18,$32                ; AEB7 32 32 0B 11 0B 13 18 32
        .byte   $32                                            ; AEBF 32
; copied to playfield when paused
playfieldPausedTiles:
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AEC0 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AEC8 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AED0 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AED8 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AEE0 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$12,$13,$1E,$32                ; AEE8 32 32 32 32 12 13 1E 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AEF0 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$1D                ; AEF8 32 32 32 32 32 32 32 1D
        .byte   $1E,$0B,$1C,$1E,$32,$32,$32,$32                ; AF00 1E 0B 1C 1E 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF08 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$1E,$19,$32                ; AF10 32 32 32 32 32 1E 19 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF18 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$0D,$19                ; AF20 32 32 32 32 32 32 0D 19
        .byte   $18,$1E,$13,$18,$1F,$0F,$32,$32                ; AF28 18 1E 13 18 1F 0F 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF30 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$11,$0B,$17,$0F                ; AF38 32 32 32 32 11 0B 17 0F
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF40 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF48 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF50 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF58 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF60 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF68 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF70 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF78 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; AF80 32 32 32 32 32 32 32 32
; copied to $04D9 during init at $817D
unknownTable01:
        .byte   $32,$0C,$1A,$1D,$32,$32,$32,$01                ; AF88 32 0C 1A 1D 32 32 32 01
        .byte   $0A,$0A,$0A,$0A,$32,$0A,$32,$09                ; AF90 0A 0A 0A 0A 32 0A 32 09
        .byte   $0C,$1A,$1D,$32,$32,$32,$32,$09                ; AF98 0C 1A 1D 32 32 32 32 09
        .byte   $0A,$0A,$0A,$32,$0A,$32,$08,$0C                ; AFA0 0A 0A 0A 32 0A 32 08 0C
        .byte   $1A,$1D,$32,$32,$32,$32,$08,$0A                ; AFA8 1A 1D 32 32 32 32 08 0A
        .byte   $0A,$0A,$32,$0A,$32,$07,$0C,$1A                ; AFB0 0A 0A 32 0A 32 07 0C 1A
        .byte   $1D,$32,$32,$32,$32,$07,$0A,$0A                ; AFB8 1D 32 32 32 32 07 0A 0A
        .byte   $0A,$32,$0A,$32,$06,$0C,$1A,$1D                ; AFC0 0A 32 0A 32 06 0C 1A 1D
        .byte   $32,$32,$32,$32,$06,$0A,$0A,$0A                ; AFC8 32 32 32 32 06 0A 0A 0A
        .byte   $32,$0A,$32,$05,$0C,$1A,$1D,$32                ; AFD0 32 0A 32 05 0C 1A 1D 32
        .byte   $32,$32,$32,$05,$0A,$0A,$0A,$32                ; AFD8 32 32 32 05 0A 0A 0A 32
        .byte   $0A,$32,$04,$0C,$1A,$1D,$32,$32                ; AFE0 0A 32 04 0C 1A 1D 32 32
        .byte   $32,$32,$04,$0A,$0A,$0A,$32,$0A                ; AFE8 32 32 04 0A 0A 0A 32 0A
        .byte   $32,$03,$0C,$1A,$1D,$32,$32,$32                ; AFF0 32 03 0C 1A 1D 32 32 32
        .byte   $32,$03,$0A,$0A,$0A,$32,$0A,$32                ; AFF8 32 03 0A 0A 0A 32 0A 32
        .byte   $02,$0C,$1A,$1D,$32,$32,$32,$32                ; B000 02 0C 1A 1D 32 32 32 32
        .byte   $02,$0A,$0A,$0A,$32,$0A,$32,$01                ; B008 02 0A 0A 0A 32 0A 32 01
        .byte   $0C,$1A,$1D,$32,$32,$32,$32,$01                ; B010 0C 1A 1D 32 32 32 32 01
        .byte   $0A,$0A,$0A,$32,$0A,$32,$0A                    ; B018 0A 0A 0A 32 0A 32 0A
LB01F:
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B01F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B027 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B02F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B037 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B03F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B047 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B04F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B057 32 32 32 32 32 32 32 32
        .byte   $32,$1D,$0D,$19,$1C,$0F,$32,$32                ; B05F 32 1D 0D 19 1C 0F 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$0A                ; B067 32 32 32 32 32 32 32 0A
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B06F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$B8,$32,$32,$32,$32                ; B077 32 32 32 B8 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B07F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B087 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B08F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$B7,$32,$32,$32,$32                ; B097 32 32 32 B7 32 32 32 32
        .byte   $32,$16,$13,$20,$0F,$1D,$32,$32                ; B09F 32 16 13 20 0F 1D 32 32
        .byte   $32,$CE,$98,$92,$92,$92,$92,$92                ; B0A7 32 CE 98 92 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$99                ; B0AF 92 92 92 92 92 92 92 99
        .byte   $32,$32,$32,$B6,$32,$32,$32,$32                ; B0B7 32 32 32 B6 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B0BF 32 32 32 32 32 32 32 32
        .byte   $32,$CE,$90,$D0,$CF,$CF,$CF,$CF                ; B0C7 32 CE 90 D0 CF CF CF CF
        .byte   $CF,$CF,$CF,$CF,$CF,$CF,$D1,$91                ; B0CF CF CF CF CF CF CF D1 91
        .byte   $32,$32,$A9,$AA,$AB,$32,$32,$32                ; B0D7 32 32 A9 AA AB 32 32 32
        .byte   $32,$1C,$19,$1F,$18,$0E,$32,$32                ; B0DF 32 1C 19 1F 18 0E 32 32
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B0E7 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B0EF 00 00 00 00 00 00 90 91
        .byte   $32,$AC,$AD,$AE,$AF,$B5,$32,$32                ; B0F7 32 AC AD AE AF B5 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B0FF 32 32 32 32 32 32 32 32
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B107 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B10F 00 00 00 00 00 00 90 91
        .byte   $32,$B0,$B1,$B2,$B3,$B4,$32,$32                ; B117 32 B0 B1 B2 B3 B4 32 32
        .byte   $32,$1D,$1E,$0B,$11,$0F,$32,$32                ; B11F 32 1D 1E 0B 11 0F 32 32
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B127 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B12F 00 00 00 00 00 00 90 91
        .byte   $32,$BB,$A2,$A2,$A2,$BA,$32,$32                ; B137 32 BB A2 A2 A2 BA 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B13F 32 32 32 32 32 32 32 32
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B147 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B14F 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A4,$A5,$70,$A0,$32,$32                ; B157 32 A1 A4 A5 70 A0 32 32
        .byte   $32,$16,$13,$18,$0F,$1D,$32,$32                ; B15F 32 16 13 18 0F 1D 32 32
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B167 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B16F 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A8,$A5,$A8,$A0,$32,$32                ; B177 32 A1 A8 A5 A8 A0 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$C0                ; B17F 32 32 32 32 32 32 32 C0
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B187 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B18F 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A7,$A5,$A7,$A0,$32,$32                ; B197 32 A1 A7 A5 A7 A0 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$B6                ; B19F 32 32 32 32 32 32 32 B6
        .byte   $32,$CE,$90,$91,$00,$00,$00,$00                ; B1A7 32 CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B1AF 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A4,$A5,$70,$A0,$32,$32                ; B1B7 32 A1 A4 A5 70 A0 32 32
        .byte   $32,$32,$32,$32,$32,$32,$A9,$AA                ; B1BF 32 32 32 32 32 32 A9 AA
        .byte   $AB,$CE,$90,$91,$00,$00,$00,$00                ; B1C7 AB CE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B1CF 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A8,$A5,$A8,$A0,$32,$32                ; B1D7 32 A1 A8 A5 A8 A0 32 32
        .byte   $A2,$A2,$A2,$A2,$A2,$A2,$A2,$A2                ; B1DF A2 A2 A2 A2 A2 A2 A2 A2
        .byte   $A2,$A2,$90,$91,$00,$00,$00,$00                ; B1E7 A2 A2 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B1EF 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A7,$A5,$A7,$A0,$32,$32                ; B1F7 32 A1 A7 A5 A7 A0 32 32
        .byte   $BD,$BF,$BE,$BD,$BE,$BD,$BE,$BD                ; B1FF BD BF BE BD BE BD BE BD
        .byte   $BF,$BE,$90,$91,$00,$00,$00,$00                ; B207 BF BE 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B20F 00 00 00 00 00 00 90 91
        .byte   $32,$A1,$A4,$A5,$70,$A0,$32,$32                ; B217 32 A1 A4 A5 70 A0 32 32
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B21F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$90,$91,$00,$00,$00,$00                ; B227 00 00 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B22F 00 00 00 00 00 00 90 91
        .byte   $9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D                ; B237 9D 9D 9D 9D 9D 9D 9D 9D
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B23F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$90,$91,$00,$00,$00,$00                ; B247 00 00 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B24F 00 00 00 00 00 00 90 91
        .byte   $CA,$CB,$CB,$CB,$CB,$CC,$9B,$9B                ; B257 CA CB CB CB CB CC 9B 9B
        .byte   $9D,$9D,$9D,$9D,$9D,$9D,$9D,$9D                ; B25F 9D 9D 9D 9D 9D 9D 9D 9D
        .byte   $9D,$9D,$90,$91,$00,$00,$00,$00                ; B267 9D 9D 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B26F 00 00 00 00 00 00 90 91
        .byte   $C1,$C3,$C4,$C5,$C6,$C2,$9B,$9B                ; B277 C1 C3 C4 C5 C6 C2 9B 9B
        .byte   $9B,$9B,$9B,$9B,$9B,$9B,$9B,$9B                ; B27F 9B 9B 9B 9B 9B 9B 9B 9B
        .byte   $9B,$CD,$90,$91,$00,$00,$00,$00                ; B287 9B CD 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B28F 00 00 00 00 00 00 90 91
        .byte   $C1,$00,$00,$00,$00,$C2,$9B,$9B                ; B297 C1 00 00 00 00 C2 9B 9B
        .byte   $CD,$9C,$D2,$9C,$D2,$9C,$D2,$9C                ; B29F CD 9C D2 9C D2 9C D2 9C
        .byte   $D3,$CD,$90,$91,$00,$00,$00,$00                ; B2A7 D3 CD 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B2AF 00 00 00 00 00 00 90 91
        .byte   $C1,$00,$00,$00,$00,$C2,$9B,$9B                ; B2B7 C1 00 00 00 00 C2 9B 9B
        .byte   $9B,$9B,$9B,$9B,$9B,$9B,$9B,$9B                ; B2BF 9B 9B 9B 9B 9B 9B 9B 9B
        .byte   $9B,$CD,$90,$91,$00,$00,$00,$00                ; B2C7 9B CD 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B2CF 00 00 00 00 00 00 90 91
        .byte   $C1,$00,$00,$00,$00,$C2,$9B,$9B                ; B2D7 C1 00 00 00 00 C2 9B 9B
        .byte   $9B,$CD,$98,$99,$9B,$CD,$98,$99                ; B2DF 9B CD 98 99 9B CD 98 99
        .byte   $9B,$CD,$90,$91,$00,$00,$00,$00                ; B2E7 9B CD 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B2EF 00 00 00 00 00 00 90 91
        .byte   $C1,$00,$00,$00,$00,$C2,$9B,$9B                ; B2F7 C1 00 00 00 00 C2 9B 9B
        .byte   $9B,$CD,$90,$91,$9B,$CD,$90,$91                ; B2FF 9B CD 90 91 9B CD 90 91
        .byte   $9B,$CD,$90,$91,$00,$00,$00,$00                ; B307 9B CD 90 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$91                ; B30F 00 00 00 00 00 00 90 91
        .byte   $C8,$C7,$C7,$C7,$C7,$C9,$C9,$9B                ; B317 C8 C7 C7 C7 C7 C9 C9 9B
        .byte   $92,$92,$93,$94,$92,$92,$93,$94                ; B31F 92 92 93 94 92 92 93 94
        .byte   $92,$92,$93,$91,$00,$00,$00,$00                ; B327 92 92 93 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$94                ; B32F 00 00 00 00 00 00 90 94
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; B337 92 92 92 92 92 92 92 92
        .byte   $9A,$D0,$CF,$CF,$CF,$CF,$CF,$CF                ; B33F 9A D0 CF CF CF CF CF CF
        .byte   $CF,$CF,$D1,$91,$00,$00,$00,$00                ; B347 CF CF D1 91 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$90,$9A                ; B34F 00 00 00 00 00 00 90 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B357 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$91,$00,$40,$41,$42,$43,$44                ; B35F 9A 91 00 40 41 42 43 44
        .byte   $45,$00,$90,$94,$92,$92,$92,$92                ; B367 45 00 90 94 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$93,$9A                ; B36F 92 92 92 92 92 92 93 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B377 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$91,$00,$50,$51,$52,$53,$54                ; B37F 9A 91 00 50 51 52 53 54
        .byte   $55,$00,$90,$9A,$9A,$9A,$9A,$9A                ; B387 55 00 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B38F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B397 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$94,$92,$92,$92,$92,$92,$92                ; B39F 9A 94 92 92 92 92 92 92
        .byte   $92,$92,$93,$9A,$9A,$9A,$9A,$9A                ; B3A7 92 92 93 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3AF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3B7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3BF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3C7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3CF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B3D7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; B3DF FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$33,$50,$50,$10,$AA,$EE                ; B3E7 FF FF 33 50 50 10 AA EE
        .byte   $FF,$FF,$33,$55,$55,$11,$FF,$FF                ; B3EF FF FF 33 55 55 11 FF FF
        .byte   $0F,$0F,$03,$55,$55,$11,$FF,$FF                ; B3F7 0F 0F 03 55 55 11 FF FF
        .byte   $00,$00,$00,$55,$55,$11,$00,$00                ; B3FF 00 00 00 55 55 11 00 00
        .byte   $00,$00,$00,$55,$55,$11,$00,$00                ; B407 00 00 00 55 55 11 00 00
        .byte   $00,$00,$00,$05,$05,$01,$00,$00                ; B40F 00 00 00 05 05 01 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B417 00 00 00 00 00 00 00 00
LB41F:
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B41F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B427 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B42F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B437 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B43F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B447 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B44F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B457 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B45F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B467 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B46F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B477 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$97,$95,$95,$95,$95                ; B47F 9A 9A 9A 97 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$96,$9A                ; B487 95 95 95 95 95 95 96 9A
        .byte   $9A,$97,$95,$95,$95,$95,$95,$95                ; B48F 9A 97 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$96,$9A,$9A,$9A                ; B497 95 95 95 95 96 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$2D,$2D,$48,$4B                ; B49F 9A 9A 9A 91 2D 2D 48 4B
        .byte   $4C,$4D,$4E,$2D,$2D,$2D,$90,$9A                ; B4A7 4C 4D 4E 2D 2D 2D 90 9A
        .byte   $9A,$91,$2D,$2D,$4F,$61,$47,$62                ; B4AF 9A 91 2D 2D 4F 61 47 62
        .byte   $63,$2D,$2D,$2D,$90,$9A,$9A,$9A                ; B4B7 63 2D 2D 2D 90 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$2C,$2C,$58,$5B                ; B4BF 9A 9A 9A 91 2C 2C 58 5B
        .byte   $5C,$5D,$5E,$2C,$2C,$2C,$90,$9A                ; B4C7 5C 5D 5E 2C 2C 2C 90 9A
        .byte   $9A,$91,$2C,$2C,$5F,$71,$71,$72                ; B4CF 9A 91 2C 2C 5F 71 71 72
        .byte   $73,$2C,$2C,$2C,$90,$9A,$9A,$9A                ; B4D7 73 2C 2C 2C 90 9A 9A 9A
        .byte   $9A,$9A,$9A,$94,$92,$92,$92,$92                ; B4DF 9A 9A 9A 94 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$93,$9A                ; B4E7 92 92 92 92 92 92 93 9A
        .byte   $9A,$94,$92,$92,$92,$92,$92,$92                ; B4EF 9A 94 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$93,$9A,$9A,$9A                ; B4F7 92 92 92 92 93 9A 9A 9A
        .byte   $9A,$9A,$9A,$97,$95,$95,$95,$95                ; B4FF 9A 9A 9A 97 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$96,$9A                ; B507 95 95 95 95 95 95 96 9A
        .byte   $9A,$9A,$9A,$97,$95,$95,$95,$95                ; B50F 9A 9A 9A 97 95 95 95 95
        .byte   $95,$95,$96,$9A,$9A,$9A,$9A,$9A                ; B517 95 95 96 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$64,$65,$66,$67                ; B51F 9A 9A 9A 91 64 65 66 67
        .byte   $68,$69,$6A,$6B,$6C,$6D,$90,$9A                ; B527 68 69 6A 6B 6C 6D 90 9A
        .byte   $9A,$9A,$9A,$91,$64,$65,$66,$67                ; B52F 9A 9A 9A 91 64 65 66 67
        .byte   $68,$69,$90,$9A,$9A,$9A,$9A,$9A                ; B537 68 69 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$74,$75,$76,$77                ; B53F 9A 9A 9A 91 74 75 76 77
        .byte   $78,$79,$7A,$7B,$7C,$7D,$90,$9A                ; B547 78 79 7A 7B 7C 7D 90 9A
        .byte   $9A,$9A,$9A,$91,$74,$75,$76,$77                ; B54F 9A 9A 9A 91 74 75 76 77
        .byte   $78,$79,$90,$9A,$9A,$9A,$9A,$9A                ; B557 78 79 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$6E,$6F,$80,$81                ; B55F 9A 9A 9A 91 6E 6F 80 81
        .byte   $84,$85,$88,$89,$8C,$8D,$90,$9A                ; B567 84 85 88 89 8C 8D 90 9A
        .byte   $9A,$9A,$9A,$91,$6A,$6B,$6C,$6D                ; B56F 9A 9A 9A 91 6A 6B 6C 6D
        .byte   $6E,$6F,$90,$9A,$9A,$9A,$9A,$9A                ; B577 6E 6F 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$91,$7E,$7F,$82,$83                ; B57F 9A 9A 9A 91 7E 7F 82 83
        .byte   $86,$87,$8A,$8B,$8E,$8F,$90,$9A                ; B587 86 87 8A 8B 8E 8F 90 9A
        .byte   $9A,$9A,$9A,$91,$7A,$7B,$7C,$7D                ; B58F 9A 9A 9A 91 7A 7B 7C 7D
        .byte   $7E,$7F,$90,$9A,$9A,$9A,$9A,$9A                ; B597 7E 7F 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$94,$92,$92,$92,$92                ; B59F 9A 9A 9A 94 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$93,$9A                ; B5A7 92 92 92 92 92 92 93 9A
        .byte   $9A,$9A,$9A,$94,$92,$92,$92,$92                ; B5AF 9A 9A 9A 94 92 92 92 92
        .byte   $92,$92,$93,$9A,$9A,$9A,$9A,$9A                ; B5B7 92 92 93 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5BF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5C7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5CF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5D7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5DF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5E7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5EF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5F7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B5FF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$97,$95,$95,$95,$95,$95,$95                ; B607 9A 97 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$96,$9A,$9A,$9A                ; B60F 95 95 95 95 96 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B617 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B61F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$91,$2D,$2D,$46,$47,$48,$49                ; B627 9A 91 2D 2D 46 47 48 49
        .byte   $4A,$2D,$2D,$2D,$90,$9A,$9A,$9A                ; B62F 4A 2D 2D 2D 90 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B637 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B63F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$91,$2C,$2C,$56,$57,$58,$59                ; B647 9A 91 2C 2C 56 57 58 59
        .byte   $5A,$2C,$2C,$2C,$90,$9A,$9A,$9A                ; B64F 5A 2C 2C 2C 90 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B657 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B65F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$94,$92,$92,$92,$92,$92,$92                ; B667 9A 94 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$93,$9A,$93,$9A                ; B66F 92 92 92 92 93 9A 93 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B677 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$97,$95,$95                ; B67F 9A 9A 9A 9A 9A 97 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B687 95 95 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B68F 95 95 95 95 95 95 95 95
        .byte   $96,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B697 96 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2D,$2D                ; B69F 9A 9A 9A 9A 9A 91 2D 2D
        .byte   $2D,$2D,$2D,$48,$49,$2F,$4E,$62                ; B6A7 2D 2D 2D 48 49 2F 4E 62
        .byte   $4A,$4E,$2D,$2D,$2D,$2D,$2D,$2D                ; B6AF 4A 4E 2D 2D 2D 2D 2D 2D
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B6B7 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2C,$2C                ; B6BF 9A 9A 9A 9A 9A 91 2C 2C
        .byte   $2C,$2C,$2C,$58,$59,$2E,$5E,$72                ; B6C7 2C 2C 2C 58 59 2E 5E 72
        .byte   $5A,$5E,$2C,$2C,$2C,$2C,$2C,$2C                ; B6CF 5A 5E 2C 2C 2C 2C 2C 2C
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B6D7 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2D,$2D                ; B6DF 9A 9A 9A 9A 9A 91 2D 2D
        .byte   $2D,$2D,$2D,$4B,$4E,$4A,$2B,$62                ; B6E7 2D 2D 2D 4B 4E 4A 2B 62
        .byte   $61,$4B,$4F,$49,$48,$2D,$2D,$2D                ; B6EF 61 4B 4F 49 48 2D 2D 2D
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B6F7 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2C,$2C                ; B6FF 9A 9A 9A 9A 9A 91 2C 2C
        .byte   $2C,$2C,$2C,$5B,$5E,$5A,$72,$72                ; B707 2C 2C 2C 5B 5E 5A 72 72
        .byte   $71,$5B,$5F,$59,$58,$2C,$2C,$2C                ; B70F 71 5B 5F 59 58 2C 2C 2C
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B717 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2D,$2D                ; B71F 9A 9A 9A 9A 9A 91 2D 2D
        .byte   $2D,$2D,$2D,$3F,$4C,$4F,$49,$62                ; B727 2D 2D 2D 3F 4C 4F 49 62
        .byte   $3F,$4C,$2D,$2D,$2D,$2D,$2D,$2D                ; B72F 3F 4C 2D 2D 2D 2D 2D 2D
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B737 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2C,$2C                ; B73F 9A 9A 9A 9A 9A 91 2C 2C
        .byte   $2C,$2C,$2C,$5F,$5C,$5F,$59,$72                ; B747 2C 2C 2C 5F 5C 5F 59 72
        .byte   $5F,$5C,$2C,$2C,$2C,$2C,$2C,$2C                ; B74F 5F 5C 2C 2C 2C 2C 2C 2C
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B757 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2D,$2D                ; B75F 9A 9A 9A 9A 9A 91 2D 2D
        .byte   $2D,$2D,$2D,$4B,$4F,$61,$49,$3F                ; B767 2D 2D 2D 4B 4F 61 49 3F
        .byte   $4C,$2D,$2D,$2D,$2D,$2D,$2D,$2D                ; B76F 4C 2D 2D 2D 2D 2D 2D 2D
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B777 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$2C,$2C                ; B77F 9A 9A 9A 9A 9A 91 2C 2C
        .byte   $2C,$2C,$2C,$5B,$5F,$71,$59,$5F                ; B787 2C 2C 2C 5B 5F 71 59 5F
        .byte   $5C,$2C,$2C,$2C,$2C,$2C,$2C,$2C                ; B78F 5C 2C 2C 2C 2C 2C 2C 2C
        .byte   $90,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B797 90 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$94,$92,$92                ; B79F 9A 9A 9A 9A 9A 94 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; B7A7 92 92 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; B7AF 92 92 92 92 92 92 92 92
        .byte   $93,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B7B7 93 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B7BF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B7C7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B7CF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B7D7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B7DF 00 00 00 00 00 00 00 00
        .byte   $00,$0F,$0F,$03,$0C,$0F,$0F,$00                ; B7E7 00 0F 0F 03 0C 0F 0F 00
        .byte   $00,$FF,$FF,$33,$00,$FF,$33,$00                ; B7EF 00 FF FF 33 00 FF 33 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B7F7 00 00 00 00 00 00 00 00
        .byte   $00,$00,$0C,$0F,$0F,$00,$00,$00                ; B7FF 00 00 0C 0F 0F 00 00 00
        .byte   $00,$CC,$FF,$FF,$FF,$FF,$00,$00                ; B807 00 CC FF FF FF FF 00 00
        .byte   $00,$CC,$FF,$FF,$FF,$FF,$00,$00                ; B80F 00 CC FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; B817 00 00 00 00 00 00 00 00
LB81F:
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B81F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B827 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B82F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B837 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B83F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B847 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B84F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B857 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B85F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$98,$92,$92,$92,$92,$92                ; B867 9A D4 98 92 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$99,$9A,$9A                ; B86F 92 92 92 92 92 99 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B877 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B87F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$90,$97,$95,$95,$95,$95                ; B887 9A D4 90 97 95 95 95 95
        .byte   $95,$95,$95,$95,$96,$91,$9A,$9A                ; B88F 95 95 95 95 96 91 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B897 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B89F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$90,$91,$00,$40,$41,$42                ; B8A7 9A D4 90 91 00 40 41 42
        .byte   $43,$44,$45,$00,$90,$91,$9A,$9A                ; B8AF 43 44 45 00 90 91 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8B7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8BF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$90,$91,$00,$50,$51,$50                ; B8C7 9A D4 90 91 00 50 51 50
        .byte   $53,$50,$55,$00,$90,$91,$9A,$9A                ; B8CF 53 50 55 00 90 91 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8D7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8DF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$90,$94,$92,$92,$92,$92                ; B8E7 9A D4 90 94 92 92 92 92
        .byte   $92,$92,$92,$92,$93,$91,$9A,$9A                ; B8EF 92 92 92 92 93 91 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8F7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B8FF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$90,$9A,$9A,$9A,$9A,$9A                ; B907 9A D4 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$9A,$9A                ; B90F 9A 9A 9A 9A 9A 91 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B917 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$D4,$98,$92,$92,$92,$92,$92                ; B91F 9A D4 98 92 92 92 92 92
        .byte   $92,$92,$93,$9A,$9A,$9A,$9A,$9A                ; B927 92 92 93 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$94,$92,$92                ; B92F 9A 9A 9A 9A 9A 94 92 92
        .byte   $92,$92,$92,$92,$92,$99,$9A,$9A                ; B937 92 92 92 92 92 99 9A 9A
        .byte   $9A,$D4,$90,$9A,$9A,$9A,$9A,$9A                ; B93F 9A D4 90 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B947 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; B94F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$91,$9A,$9A                ; B957 9A 9A 9A 9A 9A 91 9A 9A
        .byte   $9A,$D4,$90,$97,$95,$95,$95,$95                ; B95F 9A D4 90 97 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B967 95 95 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B96F 95 95 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$96,$91,$9A,$9A                ; B977 95 95 95 95 96 91 9A 9A
        .byte   $9A,$D4,$90,$91,$18,$0B,$17,$0F                ; B97F 9A D4 90 91 18 0B 17 0F
        .byte   $32,$32,$32,$1D,$0D,$0A,$1C,$0F                ; B987 32 32 32 1D 0D 0A 1C 0F
        .byte   $32,$1C,$19,$1F,$18,$0E,$32,$1D                ; B98F 32 1C 19 1F 18 0E 32 1D
        .byte   $1E,$0B,$11,$0F,$90,$91,$9A,$9A                ; B997 1E 0B 11 0F 90 91 9A 9A
        .byte   $9A,$D4,$90,$94,$92,$92,$92,$92                ; B99F 9A D4 90 94 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; B9A7 92 92 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; B9AF 92 92 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$93,$91,$9A,$9A                ; B9B7 92 92 92 92 93 91 9A 9A
        .byte   $9A,$D4,$90,$97,$95,$95,$95,$95                ; B9BF 9A D4 90 97 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B9C7 95 95 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$95,$95,$95,$95                ; B9CF 95 95 95 95 95 95 95 95
        .byte   $95,$95,$95,$95,$96,$91,$9A,$9A                ; B9D7 95 95 95 95 96 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; B9DF 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B9E7 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; B9EF 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; B9F7 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; B9FF 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA07 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA0F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BA17 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BA1F 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA27 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA2F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BA37 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BA3F 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA47 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA4F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BA57 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BA5F 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA67 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA6F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BA77 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BA7F 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA87 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BA8F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BA97 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BA9F 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BAA7 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BAAF 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BAB7 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BABF 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BAC7 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BACF 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BAD7 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BADF 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BAE7 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BAEF 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BAF7 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$91,$32,$32,$32,$32                ; BAFF 9A D4 90 91 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BB07 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$32,$32,$32,$32                ; BB0F 32 32 32 32 32 32 32 32
        .byte   $32,$32,$32,$32,$90,$91,$9A,$9A                ; BB17 32 32 32 32 90 91 9A 9A
        .byte   $9A,$D4,$90,$94,$92,$92,$92,$92                ; BB1F 9A D4 90 94 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; BB27 92 92 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$92,$92,$92,$92                ; BB2F 92 92 92 92 92 92 92 92
        .byte   $92,$92,$92,$92,$93,$91,$9A,$9A                ; BB37 92 92 92 92 93 91 9A 9A
        .byte   $9A,$D4,$9E,$CF,$CF,$CF,$CF,$CF                ; BB3F 9A D4 9E CF CF CF CF CF
        .byte   $CF,$CF,$CF,$CF,$CF,$CF,$CF,$CF                ; BB47 CF CF CF CF CF CF CF CF
        .byte   $CF,$CF,$CF,$CF,$CF,$CF,$CF,$CF                ; BB4F CF CF CF CF CF CF CF CF
        .byte   $CF,$CF,$CF,$CF,$CF,$9F,$9A,$9A                ; BB57 CF CF CF CF CF 9F 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB5F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB67 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB6F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB77 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB7F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB87 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB8F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB97 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BB9F 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBA7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBAF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBB7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBBF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBC7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBCF 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $9A,$9A,$9A,$9A,$9A,$9A,$9A,$9A                ; BBD7 9A 9A 9A 9A 9A 9A 9A 9A
        .byte   $00,$00,$40,$50,$50,$10,$00,$00                ; BBDF 00 00 40 50 50 10 00 00
        .byte   $00,$00,$44,$5A,$5A,$11,$00,$00                ; BBE7 00 00 44 5A 5A 11 00 00
        .byte   $44,$55,$55,$55,$55,$55,$55,$11                ; BBEF 44 55 55 55 55 55 55 11
        .byte   $44,$55,$55,$55,$55,$55,$55,$11                ; BBF7 44 55 55 55 55 55 55 11
        .byte   $44,$55,$55,$55,$55,$55,$55,$11                ; BBFF 44 55 55 55 55 55 55 11
        .byte   $44,$55,$55,$55,$55,$55,$55,$11                ; BC07 44 55 55 55 55 55 55 11
        .byte   $04,$05,$05,$05,$05,$05,$05,$01                ; BC0F 04 05 05 05 05 05 05 01
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BC17 00 00 00 00 00 00 00 00
; ----------------------------------------------------------------------------
LBC1F:
        ldx     $0616                                          ; BC1F AE 16 06
        bne     LBC29                                          ; BC22 D0 05
        cmp     $0613                                          ; BC24 CD 13 06
        beq     LBC55                                          ; BC27 F0 2C
LBC29:
        sta     $0613                                          ; BC29 8D 13 06
        cmp     #$FF                                           ; BC2C C9 FF
        beq     LBC56                                          ; BC2E F0 26
        lda     #$00                                           ; BC30 A9 00
        sta     $0616                                          ; BC32 8D 16 06
        sta     $0612                                          ; BC35 8D 12 06
        ldy     #$3C                                           ; BC38 A0 3C
        lda     #$00                                           ; BC3A A9 00
LBC3C:
        sta     $05D4,y                                        ; BC3C 99 D4 05
        dey                                                    ; BC3F 88
        bpl     LBC3C                                          ; BC40 10 FA
        lda     $0613                                          ; BC42 AD 13 06
        jsr     LBD55                                          ; BC45 20 55 BD
        jsr     LC334                                          ; BC48 20 34 C3
        lda     #$0F                                           ; BC4B A9 0F
        sta     SND_CHN                                        ; BC4D 8D 15 40
        lda     #$FF                                           ; BC50 A9 FF
        sta     $0612                                          ; BC52 8D 12 06
LBC55:
        rts                                                    ; BC55 60

; ----------------------------------------------------------------------------
LBC56:
        lda     #$00                                           ; BC56 A9 00
        sta     $0616                                          ; BC58 8D 16 06
        sta     $0612                                          ; BC5B 8D 12 06
        sta     $05FD                                          ; BC5E 8D FD 05
        sta     $05E9                                          ; BC61 8D E9 05
        sta     $05D5                                          ; BC64 8D D5 05
        ldx     #$0F                                           ; BC67 A2 0F
LBC69:
        sta     SQ1_VOL,x                                      ; BC69 9D 00 40
        dex                                                    ; BC6C CA
        bpl     LBC69                                          ; BC6D 10 FA
        stx     $0613                                          ; BC6F 8E 13 06
        rts                                                    ; BC72 60

; ----------------------------------------------------------------------------
LBC73:
        lda     $0612                                          ; BC73 AD 12 06
        bne     LBC79                                          ; BC76 D0 01
        rts                                                    ; BC78 60

; ----------------------------------------------------------------------------
LBC79:
        lda     $0616                                          ; BC79 AD 16 06
        beq     LBCAE                                          ; BC7C F0 30
        dec     $0617                                          ; BC7E CE 17 06
        bne     LBCAE                                          ; BC81 D0 2B
        sta     $0617                                          ; BC83 8D 17 06
        ldx     $05D7                                          ; BC86 AE D7 05
        dex                                                    ; BC89 CA
        stx     $05D7                                          ; BC8A 8E D7 05
        stx     $05EB                                          ; BC8D 8E EB 05
        stx     $05FF                                          ; BC90 8E FF 05
        cpx     $05D6                                          ; BC93 EC D6 05
        bcs     LBC9B                                          ; BC96 B0 03
        stx     $05D6                                          ; BC98 8E D6 05
LBC9B:
        cpx     $05EA                                          ; BC9B EC EA 05
        bcs     LBCA3                                          ; BC9E B0 03
        stx     $05EA                                          ; BCA0 8E EA 05
LBCA3:
        cpx     $05FE                                          ; BCA3 EC FE 05
        bcs     LBCAB                                          ; BCA6 B0 03
        stx     $05FE                                          ; BCA8 8E FE 05
LBCAB:
        txa                                                    ; BCAB 8A
        beq     LBC56                                          ; BCAC F0 A8
LBCAE:
        ldx     #$00                                           ; BCAE A2 00
        jsr     LC006                                          ; BCB0 20 06 C0
        ldx     #$14                                           ; BCB3 A2 14
        jsr     LC006                                          ; BCB5 20 06 C0
        ldx     #$28                                           ; BCB8 A2 28
        jsr     LC006                                          ; BCBA 20 06 C0
        jsr     LC2ED                                          ; BCBD 20 ED C2
        jsr     LC1FF                                          ; BCC0 20 FF C1
        jsr     LC21D                                          ; BCC3 20 1D C2
        jsr     LBCCA                                          ; BCC6 20 CA BC
        rts                                                    ; BCC9 60

; ----------------------------------------------------------------------------
LBCCA:
        ldx     #$00                                           ; BCCA A2 00
        jsr     LBCF5                                          ; BCCC 20 F5 BC
        ldx     #$14                                           ; BCCF A2 14
        jsr     LBCF5                                          ; BCD1 20 F5 BC
        ldx     #$28                                           ; BCD4 A2 28
        lda     $05D5,x                                        ; BCD6 BD D5 05
        cmp     $05D6,x                                        ; BCD9 DD D6 05
        beq     LBCF4                                          ; BCDC F0 16
        bcc     LBCE9                                          ; BCDE 90 09
        lda     #$00                                           ; BCE0 A9 00
        sta     $05D5,x                                        ; BCE2 9D D5 05
        sta     TRI_LINEAR                                     ; BCE5 8D 08 40
        rts                                                    ; BCE8 60

; ----------------------------------------------------------------------------
LBCE9:
        lda     #$FF                                           ; BCE9 A9 FF
        sta     TRI_LINEAR                                     ; BCEB 8D 08 40
        lda     $05D6,x                                        ; BCEE BD D6 05
        sta     $05D5,x                                        ; BCF1 9D D5 05
LBCF4:
        rts                                                    ; BCF4 60

; ----------------------------------------------------------------------------
LBCF5:
        lda     $05E7,x                                        ; BCF5 BD E7 05
        and     #$30                                           ; BCF8 29 30
        cmp     #$30                                           ; BCFA C9 30
        beq     LBD15                                          ; BCFC F0 17
        lda     $05D5,x                                        ; BCFE BD D5 05
        cmp     $05D6,x                                        ; BD01 DD D6 05
        beq     LBD40                                          ; BD04 F0 3A
        bcs     LBD0E                                          ; BD06 B0 06
        lda     #$00                                           ; BD08 A9 00
        sta     $05D5,x                                        ; BD0A 9D D5 05
        rts                                                    ; BD0D 60

; ----------------------------------------------------------------------------
LBD0E:
        lda     $05D5,x                                        ; BD0E BD D5 05
        sta     $05D6,x                                        ; BD11 9D D6 05
        rts                                                    ; BD14 60

; ----------------------------------------------------------------------------
LBD15:
        lda     $05D5,x                                        ; BD15 BD D5 05
        cmp     $05D6,x                                        ; BD18 DD D6 05
        beq     LBD40                                          ; BD1B F0 23
        bmi     LBD31                                          ; BD1D 30 12
        clc                                                    ; BD1F 18
        adc     $05D9,x                                        ; BD20 7D D9 05
        cmp     $05D6,x                                        ; BD23 DD D6 05
        bpl     LBD2B                                          ; BD26 10 03
        lda     $05D6,x                                        ; BD28 BD D6 05
LBD2B:
        sta     $05D5,x                                        ; BD2B 9D D5 05
        jmp     LBD43                                          ; BD2E 4C 43 BD

; ----------------------------------------------------------------------------
LBD31:
        clc                                                    ; BD31 18
        adc     $05D8,x                                        ; BD32 7D D8 05
        cmp     $05D6,x                                        ; BD35 DD D6 05
        bmi     LBD3D                                          ; BD38 30 03
        lda     $05D6,x                                        ; BD3A BD D6 05
LBD3D:
        sta     $05D5,x                                        ; BD3D 9D D5 05
LBD40:
        lda     $05D5,x                                        ; BD40 BD D5 05
LBD43:
        ldy     $05E5,x                                        ; BD43 BC E5 05
        beq     LBD49                                          ; BD46 F0 01
        rts                                                    ; BD48 60

; ----------------------------------------------------------------------------
LBD49:
        ldy     $05E6,x                                        ; BD49 BC E6 05
        lsr     a                                              ; BD4C 4A
        lsr     a                                              ; BD4D 4A
        ora     $05E7,x                                        ; BD4E 1D E7 05
        sta     SQ1_VOL,y                                      ; BD51 99 00 40
        rts                                                    ; BD54 60

; ----------------------------------------------------------------------------
LBD55:
        ldy     #$00                                           ; BD55 A0 00
        sty     $60                                            ; BD57 84 60
        asl     a                                              ; BD59 0A
        rol     $60                                            ; BD5A 26 60
        sta     $5F                                            ; BD5C 85 5F
        asl     a                                              ; BD5E 0A
        rol     $60                                            ; BD5F 26 60
        asl     a                                              ; BD61 0A
        rol     $60                                            ; BD62 26 60
        clc                                                    ; BD64 18
        adc     $5F                                            ; BD65 65 5F
        bcc     LBD6B                                          ; BD67 90 02
        inc     $60                                            ; BD69 E6 60
LBD6B:
        clc                                                    ; BD6B 18
        adc     #<unknownTable0A                               ; BD6C 69 E1
        sta     $5F                                            ; BD6E 85 5F
        lda     $60                                            ; BD70 A5 60
        adc     #>unknownTable0A                               ; BD72 69 C3
        sta     $60                                            ; BD74 85 60
        lda     ($5F),y                                        ; BD76 B1 5F
        sta     $05D1                                          ; BD78 8D D1 05
        iny                                                    ; BD7B C8
        lda     ($5F),y                                        ; BD7C B1 5F
        sta     $05D2                                          ; BD7E 8D D2 05
        iny                                                    ; BD81 C8
        lda     ($5F),y                                        ; BD82 B1 5F
        sta     $05CB                                          ; BD84 8D CB 05
        iny                                                    ; BD87 C8
        lda     ($5F),y                                        ; BD88 B1 5F
        sta     $05CC                                          ; BD8A 8D CC 05
        iny                                                    ; BD8D C8
        lda     ($5F),y                                        ; BD8E B1 5F
        sta     $05DC                                          ; BD90 8D DC 05
        iny                                                    ; BD93 C8
        lda     ($5F),y                                        ; BD94 B1 5F
        sta     $05DD                                          ; BD96 8D DD 05
        iny                                                    ; BD99 C8
        lda     ($5F),y                                        ; BD9A B1 5F
        sta     $05F0                                          ; BD9C 8D F0 05
        iny                                                    ; BD9F C8
        lda     ($5F),y                                        ; BDA0 B1 5F
        sta     $05F1                                          ; BDA2 8D F1 05
        iny                                                    ; BDA5 C8
        lda     ($5F),y                                        ; BDA6 B1 5F
        sta     $0604                                          ; BDA8 8D 04 06
        iny                                                    ; BDAB C8
        lda     ($5F),y                                        ; BDAC B1 5F
        sta     $0605                                          ; BDAE 8D 05 06
        lda     #$02                                           ; BDB1 A9 02
        sta     $05DA                                          ; BDB3 8D DA 05
        sta     $05EE                                          ; BDB6 8D EE 05
        sta     $0602                                          ; BDB9 8D 02 06
        sta     $05CA                                          ; BDBC 8D CA 05
        lda     #$FF                                           ; BDBF A9 FF
        sta     $05D0                                          ; BDC1 8D D0 05
        lda     #$00                                           ; BDC4 A9 00
        sta     $05E5                                          ; BDC6 8D E5 05
        sta     $05F9                                          ; BDC9 8D F9 05
        sta     $060D                                          ; BDCC 8D 0D 06
        lda     #$B0                                           ; BDCF A9 B0
        sta     $05E7                                          ; BDD1 8D E7 05
        sta     $05FB                                          ; BDD4 8D FB 05
        sta     $060F                                          ; BDD7 8D 0F 06
        lda     #$1F                                           ; BDDA A9 1F
        sta     $05D7                                          ; BDDC 8D D7 05
        sta     $05EB                                          ; BDDF 8D EB 05
        sta     $05FF                                          ; BDE2 8D FF 05
        lda     #$02                                           ; BDE5 A9 02
        sta     $0600                                          ; BDE7 8D 00 06
        lda     #$FE                                           ; BDEA A9 FE
        sta     $0601                                          ; BDEC 8D 01 06
        lda     #$00                                           ; BDEF A9 00
        sta     $05E6                                          ; BDF1 8D E6 05
        lda     #$04                                           ; BDF4 A9 04
        sta     $05FA                                          ; BDF6 8D FA 05
        lda     #$08                                           ; BDF9 A9 08
        sta     $060E                                          ; BDFB 8D 0E 06
        rts                                                    ; BDFE 60

; ----------------------------------------------------------------------------
        .byte   $00,$63,$88,$FF,$BC,$FF,$FF,$EF                ; BDFF 00 63 88 FF BC FF FF EF
        .byte   $FF,$F0,$2E,$EC,$DD,$FF,$FF,$FF                ; BE07 FF F0 2E EC DD FF FF FF
        .byte   $FF,$E7,$EA,$F8,$F5,$FF,$FF,$FF                ; BE0F FF E7 EA F8 F5 FF FF FF
        .byte   $FF,$5F,$AE,$FF,$FE,$FF,$FF,$FF                ; BE17 FF 5F AE FF FE FF FF FF
        .byte   $FF,$D3,$8B,$DB,$EF,$FF,$FF,$FF                ; BE1F FF D3 8B DB EF FF FF FF
        .byte   $F7,$0F,$D6,$FD,$FA,$FF,$FF,$FF                ; BE27 F7 0F D6 FD FA FF FF FF
        .byte   $FF,$41,$0A,$6F,$FF,$F7,$FF,$FF                ; BE2F FF 41 0A 6F FF F7 FF FF
        .byte   $FF,$37,$87,$DB,$F8,$FF,$FF,$FF                ; BE37 FF 37 87 DB F8 FF FF FF
        .byte   $DF,$E3,$B0,$B3,$FF,$FF,$FF,$FF                ; BE3F DF E3 B0 B3 FF FF FF FF
        .byte   $FF,$06,$94,$DF,$DE,$FF,$FF,$FF                ; BE47 FF 06 94 DF DE FF FF FF
        .byte   $7F,$CE,$70,$FF,$FF,$FF,$FF,$FF                ; BE4F 7F CE 70 FF FF FF FF FF
        .byte   $FF,$2D,$E8,$D7,$FD,$FF,$FF,$FF                ; BE57 FF 2D E8 D7 FD FF FF FF
        .byte   $FE,$1A,$7C,$FE,$FF,$FF,$FF,$FF                ; BE5F FE 1A 7C FE FF FF FF FF
        .byte   $FF,$80,$92,$DD,$AF,$FF,$FF,$FF                ; BE67 FF 80 92 DD AF FF FF FF
        .byte   $BF,$6C,$EB,$EF,$F7,$FF,$FF,$FF                ; BE6F BF 6C EB EF F7 FF FF FF
        .byte   $FE,$50,$2F,$FF,$FF,$FF,$FF,$FB                ; BE77 FE 50 2F FF FF FF FF FB
        .byte   $FF,$5D,$AA,$F2,$DF,$FF,$FF,$FF                ; BE7F FF 5D AA F2 DF FF FF FF
        .byte   $FF,$E6,$5E,$FF,$E2,$FF,$FF,$FF                ; BE87 FF E6 5E FF E2 FF FF FF
        .byte   $FF,$75,$ED,$77,$E7,$FF,$FF,$FF                ; BE8F FF 75 ED 77 E7 FF FF FF
        .byte   $FF,$AE,$DF,$EF,$BC,$FF,$FF,$FF                ; BE97 FF AE DF EF BC FF FF FF
        .byte   $FF,$A4,$6A,$BA,$FF,$FF,$FF,$F7                ; BE9F FF A4 6A BA FF FF FF F7
        .byte   $FF,$0D,$5D,$F3,$FC,$FF,$FF,$FF                ; BEA7 FF 0D 5D F3 FC FF FF FF
        .byte   $7F,$92,$4C,$A6,$FF,$FF,$FF,$FF                ; BEAF 7F 92 4C A6 FF FF FF FF
        .byte   $FF,$FA,$B8,$FE,$F0,$FF,$FF,$FF                ; BEB7 FF FA B8 FE F0 FF FF FF
        .byte   $FF,$18,$D0,$F9,$EC,$FF,$BF,$CD                ; BEBF FF 18 D0 F9 EC FF BF CD
        .byte   $FF,$5B,$58,$6E,$EF,$FF,$FF,$FF                ; BEC7 FF 5B 58 6E EF FF FF FF
        .byte   $FF,$F5,$6B,$97,$BE,$FF,$FF,$FF                ; BECF FF F5 6B 97 BE FF FF FF
        .byte   $FF,$32,$08,$FB,$AD,$FF,$FF,$FF                ; BED7 FF 32 08 FB AD FF FF FF
        .byte   $FF,$5D,$6A,$FD,$FB,$FF,$FE,$FF                ; BEDF FF 5D 6A FD FB FF FE FF
        .byte   $FF,$4D,$D1,$FF,$FE,$FF,$FF,$FF                ; BEE7 FF 4D D1 FF FE FF FF FF
        .byte   $FF,$FF,$81,$BC,$ED,$FF,$FF,$F7                ; BEEF FF FF 81 BC ED FF FF F7
        .byte   $EE,$6D,$F3,$EF,$FF,$FF,$FF,$FF                ; BEF7 EE 6D F3 EF FF FF FF FF
        .byte   $FF,$00,$00,$00,$00,$00,$00,$00                ; BEFF FF 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF07 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF0F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF17 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$40,$00,$00                ; BF1F 00 00 00 00 00 40 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF27 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF2F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF37 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$10,$00                ; BF3F 00 00 00 00 00 00 10 00
        .byte   $00,$00,$00,$00,$00,$20,$01,$00                ; BF47 00 00 00 00 00 20 01 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF4F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF57 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF5F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF67 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF6F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF77 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF7F 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF87 00 00 00 00 00 00 00 00
        .byte   $04,$00,$00,$00,$00,$04,$00,$00                ; BF8F 04 00 00 00 00 04 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BF97 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$01,$00,$00                ; BF9F 00 00 00 00 00 01 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFA7 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFAF 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFB7 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFBF 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFC7 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFCF 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFD7 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$01,$00,$00                ; BFDF 00 00 00 00 00 01 00 00
        .byte   $00,$00,$00,$00,$00,$01,$00,$00                ; BFE7 00 00 00 00 00 01 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFEF 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; BFF7 00 00 00 00 00 00 00 00
        .byte   $80,$80                                        ; BFFF 80 80
; need to confirm.  Most likely for bus conflict avoidance
cnromBank:
        .byte   $00,$01                                        ; C001 00 01
; https://tcrf.net/Tetris_(NES,_Bullet-Proof_Software)
debugMMC1Support:
        .byte   $01                                            ; C003 01
; see link above
debugExtraMusic:
        .byte   $00                                            ; C004 00
; B+Select to see ending screen
debugEndingScreen:
        .byte   $00                                            ; C005 00
; ----------------------------------------------------------------------------
LC006:
        lda     $0612                                          ; C006 AD 12 06
        bne     LC00C                                          ; C009 D0 01
        rts                                                    ; C00B 60

; ----------------------------------------------------------------------------
LC00C:
        lda     $05E5,x                                        ; C00C BD E5 05
        beq     LC014                                          ; C00F F0 03
        dec     $05E5,x                                        ; C011 DE E5 05
LC014:
        dec     $05DA,x                                        ; C014 DE DA 05
        beq     LC024                                          ; C017 F0 0B
        dec     $05DB,x                                        ; C019 DE DB 05
        bne     LC023                                          ; C01C D0 05
        lda     #$00                                           ; C01E A9 00
        sta     $05D6,x                                        ; C020 9D D6 05
LC023:
        rts                                                    ; C023 60

; ----------------------------------------------------------------------------
LC024:
        lda     $05DC,x                                        ; C024 BD DC 05
        sta     $5F                                            ; C027 85 5F
        lda     $05DD,x                                        ; C029 BD DD 05
        sta     $60                                            ; C02C 85 60
        jmp     LC03C                                          ; C02E 4C 3C C0

; ----------------------------------------------------------------------------
LC031:
        clc                                                    ; C031 18
        adc     $5F                                            ; C032 65 5F
        sta     $5F                                            ; C034 85 5F
        lda     #$00                                           ; C036 A9 00
        adc     $60                                            ; C038 65 60
        sta     $60                                            ; C03A 85 60
LC03C:
        ldy     #$00                                           ; C03C A0 00
        lda     ($5F),y                                        ; C03E B1 5F
        bmi     LC072                                          ; C040 30 30
        sta     $05E3,x                                        ; C042 9D E3 05
        lda     $05DA,x                                        ; C045 BD DA 05
        lda     $05DA,x                                        ; C048 BD DA 05
        bne     LC059                                          ; C04B D0 0C
        lda     $05DE,x                                        ; C04D BD DE 05
        sta     $05DA,x                                        ; C050 9D DA 05
        lda     $05DF,x                                        ; C053 BD DF 05
        sta     $05DB,x                                        ; C056 9D DB 05
LC059:
        lda     $05D7,x                                        ; C059 BD D7 05
        sta     $05D6,x                                        ; C05C 9D D6 05
        clc                                                    ; C05F 18
        lda     #$01                                           ; C060 A9 01
        adc     $5F                                            ; C062 65 5F
        sta     $05DC,x                                        ; C064 9D DC 05
        lda     #$00                                           ; C067 A9 00
        adc     $60                                            ; C069 65 60
        sta     $05DD,x                                        ; C06B 9D DD 05
        jmp     LC278                                          ; C06E 4C 78 C2

; ----------------------------------------------------------------------------
        rts                                                    ; C071 60

; ----------------------------------------------------------------------------
LC072:
        cmp     #$F0                                           ; C072 C9 F0
        bpl     LC0F0                                          ; C074 10 7A
        sec                                                    ; C076 38
        sbc     #$90                                           ; C077 E9 90
        tay                                                    ; C079 A8
        lda     LC091,y                                        ; C07A B9 91 C0
        sta     $05DB,x                                        ; C07D 9D DB 05
        sta     $05DF,x                                        ; C080 9D DF 05
        lda     LC0C1,y                                        ; C083 B9 C1 C0
        sta     $05DA,x                                        ; C086 9D DA 05
        sta     $05DE,x                                        ; C089 9D DE 05
        lda     #$01                                           ; C08C A9 01
        jmp     LC031                                          ; C08E 4C 31 C0

; ----------------------------------------------------------------------------
LC091:
        .byte   $01,$02,$03,$04,$06,$07,$0A,$0D                ; C091 01 02 03 04 06 07 0A 0D
        .byte   $0F,$15,$1D,$21,$2D,$3D,$45,$5D                ; C099 0F 15 1D 21 2D 3D 45 5D
        .byte   $05,$08,$09,$12,$13,$1C,$2B,$58                ; C0A1 05 08 09 12 13 1C 2B 58
        .byte   $58,$58,$09,$21,$2D,$3D,$45,$5D                ; C0A9 58 58 09 21 2D 3D 45 5D
        .byte   $01,$02,$03,$04,$06,$07,$0A,$0D                ; C0B1 01 02 03 04 06 07 0A 0D
        .byte   $0F,$15,$1D,$21,$2D,$3D,$45,$5D                ; C0B9 0F 15 1D 21 2D 3D 45 5D
LC0C1:
        .byte   $01,$03,$04,$06,$08,$09,$0C,$10                ; C0C1 01 03 04 06 08 09 0C 10
        .byte   $12,$18,$20,$24,$30,$40,$48,$60                ; C0C9 12 18 20 24 30 40 48 60
        .byte   $07,$0A,$0B,$14,$15,$1E,$2D,$5A                ; C0D1 07 0A 0B 14 15 1E 2D 5A
        .byte   $5A,$5A,$5A,$5A,$5A,$5A,$5A,$5A                ; C0D9 5A 5A 5A 5A 5A 5A 5A 5A
        .byte   $06,$08,$09,$0C,$10,$12,$18,$20                ; C0E1 06 08 09 0C 10 12 18 20
        .byte   $24,$30,$40,$48,$60,$90,$90                    ; C0E9 24 30 40 48 60 90 90
; ----------------------------------------------------------------------------
LC0F0:
        sec                                                    ; C0F0 38
        sbc     #$F7                                           ; C0F1 E9 F7
        asl     a                                              ; C0F3 0A
        tay                                                    ; C0F4 A8
        lda     LC102,y                                        ; C0F5 B9 02 C1
        sta     L0061                                          ; C0F8 85 61
        lda     LC102+1,y                                      ; C0FA B9 03 C1
        sta     $62                                            ; C0FD 85 62
        jmp     (L0061)                                        ; C0FF 6C 61 00

; ----------------------------------------------------------------------------
LC102:
        .addr   LC114                                          ; C102 14 C1
        .addr   LC183                                          ; C104 83 C1
        .addr   LC175                                          ; C106 75 C1
        .addr   LC123                                          ; C108 23 C1
        .addr   LC149                                          ; C10A 49 C1
        .addr   LC135                                          ; C10C 35 C1
        .addr   LC1C7                                          ; C10E C7 C1
        .addr   LC1E5                                          ; C110 E5 C1
        .addr   LC1D3                                          ; C112 D3 C1
; ----------------------------------------------------------------------------
LC114:
        ldy     #$01                                           ; C114 A0 01
        lda     ($5F),y                                        ; C116 B1 5F
        sta     $05DA,x                                        ; C118 9D DA 05
        sta     $05DB,x                                        ; C11B 9D DB 05
        lda     #$02                                           ; C11E A9 02
        jmp     LC031                                          ; C120 4C 31 C0

; ----------------------------------------------------------------------------
LC123:
        ldy     #$01                                           ; C123 A0 01
        lda     ($5F),y                                        ; C125 B1 5F
        sta     $05DA,x                                        ; C127 9D DA 05
        iny                                                    ; C12A C8
        lda     ($5F),y                                        ; C12B B1 5F
        sta     $05DB,x                                        ; C12D 9D DB 05
        lda     #$03                                           ; C130 A9 03
        jmp     LC031                                          ; C132 4C 31 C0

; ----------------------------------------------------------------------------
LC135:
        lda     $5F                                            ; C135 A5 5F
        clc                                                    ; C137 18
        adc     #$01                                           ; C138 69 01
        sta     $05E1,x                                        ; C13A 9D E1 05
        lda     $60                                            ; C13D A5 60
        adc     #$00                                           ; C13F 69 00
        sta     $05E2,x                                        ; C141 9D E2 05
        lda     #$01                                           ; C144 A9 01
        jmp     LC031                                          ; C146 4C 31 C0

; ----------------------------------------------------------------------------
LC149:
        lda     $05E0,x                                        ; C149 BD E0 05
        beq     LC162                                          ; C14C F0 14
        dec     $05E0,x                                        ; C14E DE E0 05
        beq     LC170                                          ; C151 F0 1D
LC153:
        lda     $05E1,x                                        ; C153 BD E1 05
        sta     $5F                                            ; C156 85 5F
        lda     $05E2,x                                        ; C158 BD E2 05
        sta     $60                                            ; C15B 85 60
        lda     #$00                                           ; C15D A9 00
        jmp     LC031                                          ; C15F 4C 31 C0

; ----------------------------------------------------------------------------
LC162:
        ldy     #$01                                           ; C162 A0 01
        lda     ($5F),y                                        ; C164 B1 5F
        beq     LC170                                          ; C166 F0 08
        sta     $05E0,x                                        ; C168 9D E0 05
        dec     $05E0,x                                        ; C16B DE E0 05
        bne     LC153                                          ; C16E D0 E3
LC170:
        lda     #$02                                           ; C170 A9 02
        jmp     LC031                                          ; C172 4C 31 C0

; ----------------------------------------------------------------------------
LC175:
        ldy     #$01                                           ; C175 A0 01
        lda     ($5F),y                                        ; C177 B1 5F
        asl     a                                              ; C179 0A
        asl     a                                              ; C17A 0A
        sta     $05D7,x                                        ; C17B 9D D7 05
        lda     #$02                                           ; C17E A9 02
        jmp     LC031                                          ; C180 4C 31 C0

; ----------------------------------------------------------------------------
LC183:
        ldy     #$01                                           ; C183 A0 01
        lda     ($5F),y                                        ; C185 B1 5F
        asl     a                                              ; C187 0A
        asl     a                                              ; C188 0A
        tay                                                    ; C189 A8
        lda     unknownTable07,y                               ; C18A B9 A7 C1
        sta     $05D8,x                                        ; C18D 9D D8 05
        lda     unknownTable07+1,y                             ; C190 B9 A8 C1
        sta     $05D9,x                                        ; C193 9D D9 05
        lda     unknownTable07+2,y                             ; C196 B9 A9 C1
        sta     $05E7,x                                        ; C199 9D E7 05
        lda     unknownTable07+3,y                             ; C19C B9 AA C1
        sta     $05E4,x                                        ; C19F 9D E4 05
        lda     #$02                                           ; C1A2 A9 02
        jmp     LC031                                          ; C1A4 4C 31 C0

; ----------------------------------------------------------------------------
unknownTable07:
        .byte   $1F,$FE,$B0,$FF,$0F,$FF,$70,$00                ; C1A7 1F FE B0 FF 0F FF 70 00
        .byte   $0F,$FF,$70,$FF,$07,$FF,$30,$00                ; C1AF 0F FF 70 FF 07 FF 30 00
        .byte   $0F,$FF,$0F,$00,$0A,$FF,$B0,$00                ; C1B7 0F FF 0F 00 0A FF B0 00
        .byte   $05,$FF,$30,$00,$0F,$FF,$82,$00                ; C1BF 05 FF 30 00 0F FF 82 00
; ----------------------------------------------------------------------------
LC1C7:
        ldy     #$01                                           ; C1C7 A0 01
        lda     ($5F),y                                        ; C1C9 B1 5F
        sta     $05E4,x                                        ; C1CB 9D E4 05
        lda     #$02                                           ; C1CE A9 02
        jmp     LC031                                          ; C1D0 4C 31 C0

; ----------------------------------------------------------------------------
LC1D3:
        ldy     #$01                                           ; C1D3 A0 01
        lda     ($5F),y                                        ; C1D5 B1 5F
        pha                                                    ; C1D7 48
        iny                                                    ; C1D8 C8
        lda     ($5F),y                                        ; C1D9 B1 5F
        sta     $60                                            ; C1DB 85 60
        pla                                                    ; C1DD 68
        sta     $5F                                            ; C1DE 85 5F
        lda     #$00                                           ; C1E0 A9 00
        jmp     LC031                                          ; C1E2 4C 31 C0

; ----------------------------------------------------------------------------
LC1E5:
        lda     #$00                                           ; C1E5 A9 00
        sta     $0612                                          ; C1E7 8D 12 06
        sta     $0613                                          ; C1EA 8D 13 06
        dec     $0613                                          ; C1ED CE 13 06
        sta     SND_CHN                                        ; C1F0 8D 15 40
        ldy     #$0C                                           ; C1F3 A0 0C
LC1F5:
        sta     SQ1_VOL,y                                      ; C1F5 99 00 40
        dey                                                    ; C1F8 88
        dey                                                    ; C1F9 88
        dey                                                    ; C1FA 88
        dey                                                    ; C1FB 88
        bpl     LC1F5                                          ; C1FC 10 F7
        rts                                                    ; C1FE 60

; ----------------------------------------------------------------------------
LC1FF:
        lda     $0610                                          ; C1FF AD 10 06
        tay                                                    ; C202 A8
        lda     LC217,y                                        ; C203 B9 17 C2
        sta     $0611                                          ; C206 8D 11 06
        iny                                                    ; C209 C8
        cpy     #$06                                           ; C20A C0 06
        bcc     LC210                                          ; C20C 90 02
        ldy     #$00                                           ; C20E A0 00
LC210:
        tya                                                    ; C210 98
        and     #$0F                                           ; C211 29 0F
        sta     $0610                                          ; C213 8D 10 06
        rts                                                    ; C216 60

; ----------------------------------------------------------------------------
LC217:
        .byte   $10,$0C,$08,$00,$08,$0C                        ; C217 10 0C 08 00 08 0C
; ----------------------------------------------------------------------------
LC21D:
        ldx     #$00                                           ; C21D A2 00
        jsr     LC229                                          ; C21F 20 29 C2
        ldx     #$14                                           ; C222 A2 14
        jsr     LC229                                          ; C224 20 29 C2
        ldx     #$28                                           ; C227 A2 28
LC229:
        lda     $05E5,x                                        ; C229 BD E5 05
        beq     LC22F                                          ; C22C F0 01
        rts                                                    ; C22E 60

; ----------------------------------------------------------------------------
LC22F:
        lda     $05E4,x                                        ; C22F BD E4 05
        bne     LC235                                          ; C232 D0 01
        rts                                                    ; C234 60

; ----------------------------------------------------------------------------
LC235:
        lda     $05E3,x                                        ; C235 BD E3 05
        pha                                                    ; C238 48
        lda     $05E6,x                                        ; C239 BD E6 05
        tay                                                    ; C23C A8
        pla                                                    ; C23D 68
        pha                                                    ; C23E 48
        and     #$0F                                           ; C23F 29 0F
        asl     a                                              ; C241 0A
        tax                                                    ; C242 AA
        lda     unknownTable06,x                               ; C243 BD D5 C2
        sta     L0061                                          ; C246 85 61
        lda     unknownTable06+1,x                             ; C248 BD D6 C2
        sta     $62                                            ; C24B 85 62
        lda     $05E4,x                                        ; C24D BD E4 05
        beq     LC260                                          ; C250 F0 0E
        lda     $0610                                          ; C252 AD 10 06
        clc                                                    ; C255 18
        adc     L0061                                          ; C256 65 61
        sta     L0061                                          ; C258 85 61
        lda     #$00                                           ; C25A A9 00
        adc     $62                                            ; C25C 65 62
        sta     $62                                            ; C25E 85 62
LC260:
        pla                                                    ; C260 68
        and     #$F0                                           ; C261 29 F0
        lsr     a                                              ; C263 4A
        lsr     a                                              ; C264 4A
        lsr     a                                              ; C265 4A
        lsr     a                                              ; C266 4A
        tax                                                    ; C267 AA
LC268:
        dex                                                    ; C268 CA
        bmi     LC272                                          ; C269 30 07
        lsr     $62                                            ; C26B 46 62
        ror     L0061                                          ; C26D 66 61
        jmp     LC268                                          ; C26F 4C 68 C2

; ----------------------------------------------------------------------------
LC272:
        lda     L0061                                          ; C272 A5 61
        sta     SQ1_LO,y                                       ; C274 99 02 40
        rts                                                    ; C277 60

; ----------------------------------------------------------------------------
LC278:
        lda     $05D4,x                                        ; C278 BD D4 05
        pha                                                    ; C27B 48
        lda     $05E7,x                                        ; C27C BD E7 05
        sta     $05D3                                          ; C27F 8D D3 05
        lda     $05E5,x                                        ; C282 BD E5 05
        beq     LC289                                          ; C285 F0 02
        pla                                                    ; C287 68
        rts                                                    ; C288 60

; ----------------------------------------------------------------------------
LC289:
        lda     $05E3,x                                        ; C289 BD E3 05
        ldy     $05E6,x                                        ; C28C BC E6 05
        pha                                                    ; C28F 48
        and     #$0F                                           ; C290 29 0F
        asl     a                                              ; C292 0A
        tax                                                    ; C293 AA
        clc                                                    ; C294 18
        tya                                                    ; C295 98
        adc     unknownTable06,x                               ; C296 7D D5 C2
        sta     L0061                                          ; C299 85 61
        lda     unknownTable06+1,x                             ; C29B BD D6 C2
        adc     #$00                                           ; C29E 69 00
        sta     $62                                            ; C2A0 85 62
        pla                                                    ; C2A2 68
        and     #$F0                                           ; C2A3 29 F0
        lsr     a                                              ; C2A5 4A
        lsr     a                                              ; C2A6 4A
        lsr     a                                              ; C2A7 4A
        lsr     a                                              ; C2A8 4A
        tax                                                    ; C2A9 AA
LC2AA:
        dex                                                    ; C2AA CA
        bmi     LC2B4                                          ; C2AB 30 07
        lsr     $62                                            ; C2AD 46 62
        ror     L0061                                          ; C2AF 66 61
        jmp     LC2AA                                          ; C2B1 4C AA C2

; ----------------------------------------------------------------------------
LC2B4:
        pla                                                    ; C2B4 68
        lda     $05D3                                          ; C2B5 AD D3 05
        sta     SQ1_VOL,y                                      ; C2B8 99 00 40
        tya                                                    ; C2BB 98
        lsr     a                                              ; C2BC 4A
        lsr     a                                              ; C2BD 4A
        and     #$01                                           ; C2BE 29 01
        clc                                                    ; C2C0 18
        adc     L0061                                          ; C2C1 65 61
        sta     SQ1_LO,y                                       ; C2C3 99 02 40
        lda     #$00                                           ; C2C6 A9 00
        adc     $62                                            ; C2C8 65 62
        ora     #$08                                           ; C2CA 09 08
        sta     SQ1_HI,y                                       ; C2CC 99 03 40
        lda     #$00                                           ; C2CF A9 00
        sta     SQ1_SWEEP,y                                    ; C2D1 99 01 40
        rts                                                    ; C2D4 60

; ----------------------------------------------------------------------------
unknownTable06:
        .byte   $AE,$06,$4E,$06,$F3,$05,$9E,$05                ; C2D5 AE 06 4E 06 F3 05 9E 05
        .byte   $4D,$05,$01,$05,$B9,$04,$75,$04                ; C2DD 4D 05 01 05 B9 04 75 04
        .byte   $35,$04,$F8,$03,$BF,$03,$89,$03                ; C2E5 35 04 F8 03 BF 03 89 03
; ----------------------------------------------------------------------------
LC2ED:
        dec     $05CA                                          ; C2ED CE CA 05
        beq     LC2F3                                          ; C2F0 F0 01
        rts                                                    ; C2F2 60

; ----------------------------------------------------------------------------
LC2F3:
        lda     $05CD                                          ; C2F3 AD CD 05
        sta     $5F                                            ; C2F6 85 5F
        lda     $05CE                                          ; C2F8 AD CE 05
        sta     $60                                            ; C2FB 85 60
        ldy     $05CF                                          ; C2FD AC CF 05
        lda     ($5F),y                                        ; C300 B1 5F
        and     #$0F                                           ; C302 29 0F
        sta     $05CA                                          ; C304 8D CA 05
        lda     ($5F),y                                        ; C307 B1 5F
        and     #$F0                                           ; C309 29 F0
        and     $05D0                                          ; C30B 2D D0 05
        beq     LC32B                                          ; C30E F0 1B
        lsr     a                                              ; C310 4A
        lsr     a                                              ; C311 4A
        tax                                                    ; C312 AA
        lda     LC39B,x                                        ; C313 BD 9B C3
        sta     NOISE_VOL                                      ; C316 8D 0C 40
        lda     LC39C,x                                        ; C319 BD 9C C3
        sta     $400D                                          ; C31C 8D 0D 40
        lda     LC39D,x                                        ; C31F BD 9D C3
        sta     NOISE_LO                                       ; C322 8D 0E 40
        lda     LC39E,x                                        ; C325 BD 9E C3
        sta     NOISE_HI                                       ; C328 8D 0F 40
LC32B:
        iny                                                    ; C32B C8
        cpy     #$10                                           ; C32C C0 10
        beq     LC334                                          ; C32E F0 04
        sty     $05CF                                          ; C330 8C CF 05
        rts                                                    ; C333 60

; ----------------------------------------------------------------------------
LC334:
        lda     $05CB                                          ; C334 AD CB 05
        sta     $5F                                            ; C337 85 5F
        lda     $05CC                                          ; C339 AD CC 05
        sta     $60                                            ; C33C 85 60
        ldy     #$00                                           ; C33E A0 00
        lda     ($5F),y                                        ; C340 B1 5F
        bpl     LC35A                                          ; C342 10 16
        cmp     #$FE                                           ; C344 C9 FE
        beq     LC359                                          ; C346 F0 11
        iny                                                    ; C348 C8
        lda     ($5F),y                                        ; C349 B1 5F
        pha                                                    ; C34B 48
        iny                                                    ; C34C C8
        lda     ($5F),y                                        ; C34D B1 5F
        sta     $05CC                                          ; C34F 8D CC 05
        pla                                                    ; C352 68
        sta     $05CB                                          ; C353 8D CB 05
        jmp     LC334                                          ; C356 4C 34 C3

; ----------------------------------------------------------------------------
LC359:
        rts                                                    ; C359 60

; ----------------------------------------------------------------------------
LC35A:
        sec                                                    ; C35A 38
        sbc     #$01                                           ; C35B E9 01
        pha                                                    ; C35D 48
        clc                                                    ; C35E 18
        lda     $5F                                            ; C35F A5 5F
        adc     #$01                                           ; C361 69 01
        sta     $05CB                                          ; C363 8D CB 05
        lda     $60                                            ; C366 A5 60
        adc     #$00                                           ; C368 69 00
        sta     $05CC                                          ; C36A 8D CC 05
        pla                                                    ; C36D 68
        sta     $5F                                            ; C36E 85 5F
        lda     #$00                                           ; C370 A9 00
        sta     $60                                            ; C372 85 60
        asl     $5F                                            ; C374 06 5F
        rol     $60                                            ; C376 26 60
        asl     $5F                                            ; C378 06 5F
        rol     $60                                            ; C37A 26 60
        asl     $5F                                            ; C37C 06 5F
        rol     $60                                            ; C37E 26 60
        asl     $5F                                            ; C380 06 5F
        rol     $60                                            ; C382 26 60
        clc                                                    ; C384 18
        lda     $5F                                            ; C385 A5 5F
        adc     $05D1                                          ; C387 6D D1 05
        sta     $05CD                                          ; C38A 8D CD 05
        lda     $60                                            ; C38D A5 60
        adc     $05D2                                          ; C38F 6D D2 05
        sta     $05CE                                          ; C392 8D CE 05
        lda     #$00                                           ; C395 A9 00
        sta     $05CF                                          ; C397 8D CF 05
        rts                                                    ; C39A 60

; ----------------------------------------------------------------------------
LC39B:
        .byte   $07                                            ; C39B 07
LC39C:
        .byte   $00                                            ; C39C 00
LC39D:
        .byte   $03                                            ; C39D 03
LC39E:
        .byte   $02,$03,$00,$07,$02,$06,$00,$05                ; C39E 02 03 00 07 02 06 00 05
        .byte   $02,$01,$00,$04,$FF,$00,$00,$01                ; C3A6 02 01 00 04 FF 00 00 01
        .byte   $FF,$02,$00,$0D,$FF,$02,$00,$0E                ; C3AE FF 02 00 0D FF 02 00 0E
        .byte   $FF,$01,$00,$0D,$FF,$01,$00,$0E                ; C3B6 FF 01 00 0D FF 01 00 0E
        .byte   $FF,$01,$00,$0E,$FF,$00,$00,$0C                ; C3BE FF 01 00 0E FF 00 00 0C
        .byte   $FF,$00,$00,$0F,$FF                            ; C3C6 FF 00 00 0F FF
; ----------------------------------------------------------------------------
LC3CB:
        lda     #$04                                           ; C3CB A9 04
LC3CD:
        sta     $0616                                          ; C3CD 8D 16 06
        sta     $0617                                          ; C3D0 8D 17 06
        rts                                                    ; C3D3 60

; ----------------------------------------------------------------------------
        lda     $05D5,x                                        ; C3D4 BD D5 05
        ldy     $05E6,x                                        ; C3D7 BC E6 05
        sta     SQ1_VOL,y                                      ; C3DA 99 00 40
        jsr     LC278                                          ; C3DD 20 78 C2
        rts                                                    ; C3E0 60

; ----------------------------------------------------------------------------
unknownTable0A:
        .addr   LCBE6                                          ; C3E1 E6 CB
        .addr   LD136                                          ; C3E3 36 D1
        .addr   LCC26                                          ; C3E5 26 CC
        .addr   LCE09                                          ; C3E7 09 CE
        .addr   LD054                                          ; C3E9 54 D0
        .addr   LC427                                          ; C3EB 27 C4
        .addr   LC7AA                                          ; C3ED AA C7
        .addr   LC467                                          ; C3EF 67 C4
        .addr   LC54C                                          ; C3F1 4C C5
        .addr   LC6BC                                          ; C3F3 BC C6
        .addr   LC7E1                                          ; C3F5 E1 C7
        .addr   LCBB7                                          ; C3F7 B7 CB
        .addr   LC831                                          ; C3F9 31 C8
        .addr   LC955                                          ; C3FB 55 C9
        .addr   LCA4F                                          ; C3FD 4F CA
        .addr   LD15D                                          ; C3FF 5D D1
        .addr   LD4EF                                          ; C401 EF D4
        .addr   LD1AD                                          ; C403 AD D1
        .addr   LD36C                                          ; C405 6C D3
        .addr   LD41A                                          ; C407 1A D4
        .addr   LD518                                          ; C409 18 D5
        .addr   LD8F5                                          ; C40B F5 D8
        .addr   LD608                                          ; C40D 08 D6
        .addr   LD702                                          ; C40F 02 D7
        .addr   LD834                                          ; C411 34 D8
        .addr   LD910                                          ; C413 10 D9
        .addr   LDC34                                          ; C415 34 DC
        .addr   LD950                                          ; C417 50 D9
        .addr   LDA28                                          ; C419 28 DA
        .addr   LDB50                                          ; C41B 50 DB
        .addr   LDC4B                                          ; C41D 4B DC
        .addr   LDF71                                          ; C41F 71 DF
        .addr   LDC8B                                          ; C421 8B DC
        .addr   LDD67                                          ; C423 67 DD
        .addr   LDE90                                          ; C425 90 DE
; ----------------------------------------------------------------------------
LC427:
        .byte   $06,$06,$A6,$06,$06,$06,$A3,$01                ; C427 06 06 A6 06 06 06 A3 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; C42F 01 01 01 01 01 01 01 01
        .byte   $A6,$06,$06,$06,$06,$06,$03,$01                ; C437 A6 06 06 06 06 06 03 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; C43F 01 01 01 01 01 01 01 01
        .byte   $06,$06,$06,$06,$06,$06,$03,$01                ; C447 06 06 06 06 06 06 03 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; C44F 01 01 01 01 01 01 01 01
        .byte   $06,$06,$A6,$06,$06,$06,$06,$06                ; C457 06 06 A6 06 06 06 06 06
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; C45F 00 00 00 00 00 00 00 00
LC467:
        .byte   $F9,$08,$F8,$00,$99,$27,$96,$24                ; C467 F9 08 F8 00 99 27 96 24
        .byte   $25,$99,$27,$96,$24,$25,$99,$27                ; C46F 25 99 27 96 24 25 99 27
        .byte   $96,$25,$24,$98,$22,$93,$00,$96                ; C477 96 25 24 98 22 93 00 96
        .byte   $29,$29,$98,$27,$93,$25,$96,$24                ; C47F 29 29 98 27 93 25 96 24
        .byte   $25,$99,$27,$96,$24,$25,$99,$27                ; C487 25 99 27 96 24 25 99 27
        .byte   $96,$25,$24,$22,$00,$99,$32,$9C                ; C48F 96 25 24 22 00 99 32 9C
        .byte   $30,$96,$29,$30,$2A,$93,$29,$27                ; C497 30 96 29 30 2A 93 29 27
        .byte   $99,$25,$20,$96,$29,$30,$27,$29                ; C49F 99 25 20 96 29 30 27 29
        .byte   $99,$25,$20,$22,$96,$22,$24,$27                ; C4A7 99 25 20 22 96 22 24 27
        .byte   $25,$24,$22,$99,$20,$20,$20,$30                ; C4AF 25 24 22 99 20 20 20 30
        .byte   $96,$29,$30,$2A,$93,$29,$27,$99                ; C4B7 96 29 30 2A 93 29 27 99
        .byte   $25,$20,$96,$29,$30,$27,$29,$99                ; C4BF 25 20 96 29 30 27 29 99
        .byte   $25,$20,$22,$96,$22,$24,$27,$25                ; C4C7 25 20 22 96 22 24 27 25
        .byte   $24,$22,$99,$30,$2A,$F7,$30,$29                ; C4CF 24 22 99 30 2A F7 30 29
        .byte   $9B,$29,$96,$29,$99,$27,$96,$24                ; C4D7 9B 29 96 29 99 27 96 24
        .byte   $25,$99,$27,$96,$24,$25,$99,$27                ; C4DF 25 99 27 96 24 25 99 27
        .byte   $96,$25,$24,$99,$22,$96,$29,$29                ; C4E7 96 25 24 99 22 96 29 29
        .byte   $98,$27,$93,$25,$96,$24,$25,$99                ; C4EF 98 27 93 25 96 24 25 99
        .byte   $27,$96,$24,$25,$99,$27,$96,$25                ; C4F7 27 96 24 25 99 27 96 25
        .byte   $24,$22,$00,$99,$32,$9C,$30,$96                ; C4FF 24 22 00 99 32 9C 30 96
        .byte   $29,$30,$2A,$93,$29,$27,$99,$25                ; C507 29 30 2A 93 29 27 99 25
        .byte   $20,$96,$29,$30,$27,$29,$99,$25                ; C50F 20 96 29 30 27 29 99 25
        .byte   $20,$22,$96,$22,$24,$27,$25,$24                ; C517 20 22 96 22 24 27 25 24
        .byte   $22,$99,$20,$20,$20,$30,$96,$29                ; C51F 22 99 20 20 20 30 96 29
        .byte   $30,$2A,$93,$29,$27,$99,$25,$20                ; C527 30 2A 93 29 27 99 25 20
        .byte   $96,$29,$30,$27,$29,$99,$25,$20                ; C52F 96 29 30 27 29 99 25 20
        .byte   $22,$96,$22,$24,$27,$25,$24,$22                ; C537 22 96 22 24 27 25 24 22
        .byte   $99,$30,$2A,$F7,$30,$29,$9B,$29                ; C53F 99 30 2A F7 30 29 9B 29
        .byte   $96,$29,$FF,$67,$C4                            ; C547 96 29 FF 67 C4
LC54C:
        .byte   $F9,$06,$F8,$00,$99,$2A,$96,$27                ; C54C F9 06 F8 00 99 2A 96 27
        .byte   $29,$99,$2A,$96,$27,$29,$99,$2A                ; C554 29 99 2A 96 27 29 99 2A
        .byte   $96,$29,$27,$99,$25,$93,$30,$00                ; C55C 96 29 27 99 25 93 30 00
        .byte   $30,$00,$98,$2A,$93,$29,$96,$27                ; C564 30 00 98 2A 93 29 96 27
        .byte   $29,$99,$2A,$96,$27,$29,$99,$2A                ; C56C 29 99 2A 96 27 29 99 2A
        .byte   $96,$29,$27,$25,$9B,$00,$9C,$00                ; C574 96 29 27 25 9B 00 9C 00
        .byte   $96,$00,$93,$29,$98,$00,$93,$2A                ; C57C 96 00 93 29 98 00 93 2A
        .byte   $00,$96,$00,$93,$29,$98,$00,$93                ; C584 00 96 00 93 29 98 00 93
        .byte   $29,$00,$96,$00,$93,$29,$98,$00                ; C58C 29 00 96 00 93 29 98 00
        .byte   $93,$2A,$00,$96,$00,$93,$29,$98                ; C594 93 2A 00 96 00 93 29 98
        .byte   $00,$93,$29,$00,$96,$00,$93,$25                ; C59C 00 93 29 00 96 00 93 25
        .byte   $98,$00,$93,$25,$00,$96,$00,$93                ; C5A4 98 00 93 25 00 96 00 93
        .byte   $25,$98,$00,$93,$25,$00,$96,$00                ; C5AC 25 98 00 93 25 00 96 00
        .byte   $93,$27,$98,$00,$93,$29,$00,$99                ; C5B4 93 27 98 00 93 29 00 99
        .byte   $27,$00,$96,$00,$93,$29,$98,$00                ; C5BC 27 00 96 00 93 29 98 00
        .byte   $93,$2A,$00,$96,$00,$93,$29,$98                ; C5C4 93 2A 00 96 00 93 29 98
        .byte   $00,$93,$29,$00,$96,$00,$93,$29                ; C5CC 00 93 29 00 96 00 93 29
        .byte   $98,$00,$93,$2A,$00,$96,$00,$93                ; C5D4 98 00 93 2A 00 96 00 93
        .byte   $29,$98,$00,$93,$29,$00,$96,$00                ; C5DC 29 98 00 93 29 00 96 00
        .byte   $93,$25,$98,$00,$93,$25,$00,$96                ; C5E4 93 25 98 00 93 25 00 96
        .byte   $00,$93,$25,$98,$00,$93,$25,$00                ; C5EC 00 93 25 98 00 93 25 00
        .byte   $96,$00,$93,$27,$98,$00,$93,$27                ; C5F4 96 00 93 27 98 00 93 27
        .byte   $00,$F7,$30,$24,$98,$24,$F7,$1E                ; C5FC 00 F7 30 24 98 24 F7 1E
        .byte   $00,$99,$2A,$96,$27,$29,$99,$2A                ; C604 00 99 2A 96 27 29 99 2A
        .byte   $96,$27,$29,$99,$2A,$96,$29,$27                ; C60C 96 27 29 99 2A 96 29 27
        .byte   $99,$25,$93,$30,$00,$30,$00,$98                ; C614 99 25 93 30 00 30 00 98
        .byte   $2A,$93,$29,$96,$27,$29,$99,$2A                ; C61C 2A 93 29 96 27 29 99 2A
        .byte   $96,$27,$29,$99,$2A,$96,$29,$27                ; C624 96 27 29 99 2A 96 29 27
        .byte   $25,$9B,$00,$9C,$00,$96,$00,$93                ; C62C 25 9B 00 9C 00 96 00 93
        .byte   $29,$98,$00,$93,$2A,$00,$96,$00                ; C634 29 98 00 93 2A 00 96 00
        .byte   $93,$29,$98,$00,$93,$29,$00,$96                ; C63C 93 29 98 00 93 29 00 96
        .byte   $00,$93,$29,$98,$00,$93,$2A,$00                ; C644 00 93 29 98 00 93 2A 00
        .byte   $96,$00,$93,$29,$98,$00,$93,$29                ; C64C 96 00 93 29 98 00 93 29
        .byte   $00,$96,$00,$93,$25,$98,$00,$93                ; C654 00 96 00 93 25 98 00 93
        .byte   $25,$00,$96,$00,$93,$25,$98,$00                ; C65C 25 00 96 00 93 25 98 00
        .byte   $93,$25,$00,$96,$00,$93,$27,$98                ; C664 93 25 00 96 00 93 27 98
        .byte   $00,$93,$29,$00,$9C,$27,$96,$00                ; C66C 00 93 29 00 9C 27 96 00
        .byte   $93,$29,$98,$00,$93,$2A,$00,$96                ; C674 93 29 98 00 93 2A 00 96
        .byte   $00,$93,$29,$98,$00,$93,$29,$00                ; C67C 00 93 29 98 00 93 29 00
        .byte   $96,$00,$93,$29,$98,$00,$93,$2A                ; C684 96 00 93 29 98 00 93 2A
        .byte   $00,$96,$00,$93,$29,$98,$00,$93                ; C68C 00 96 00 93 29 98 00 93
        .byte   $29,$00,$96,$00,$93,$25,$98,$00                ; C694 29 00 96 00 93 25 98 00
        .byte   $93,$25,$00,$96,$00,$93,$25,$98                ; C69C 93 25 00 96 00 93 25 98
        .byte   $00,$93,$25,$00,$96,$00,$93,$27                ; C6A4 00 93 25 00 96 00 93 27
        .byte   $98,$00,$93,$27,$00,$F7,$30,$24                ; C6AC 98 00 93 27 00 F7 30 24
        .byte   $98,$24,$F7,$1E,$00,$FF,$4C,$C5                ; C6B4 98 24 F7 1E 00 FF 4C C5
LC6BC:
        .byte   $99,$19,$96,$19,$00,$19,$00,$19                ; C6BC 99 19 96 19 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$22,$00,$22                ; C6C4 00 19 00 19 00 22 00 22
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; C6CC 00 19 00 19 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$22,$9B,$00                ; C6D4 00 19 00 19 00 22 9B 00
        .byte   $9C,$00,$99,$25,$96,$20,$00,$99                ; C6DC 9C 00 99 25 96 20 00 99
        .byte   $25,$96,$25,$00,$99,$25,$96,$20                ; C6E4 25 96 25 00 99 25 96 20
        .byte   $00,$99,$15,$96,$19,$00,$99,$1A                ; C6EC 00 99 15 96 19 00 99 1A
        .byte   $96,$1A,$00,$99,$17,$96,$17,$00                ; C6F4 96 1A 00 99 17 96 17 00
        .byte   $98,$20,$93,$00,$98,$20,$93,$00                ; C6FC 98 20 93 00 98 20 93 00
        .byte   $99,$20,$00,$25,$96,$20,$00,$99                ; C704 99 20 00 25 96 20 00 99
        .byte   $25,$96,$25,$00,$25,$00,$20,$00                ; C70C 25 96 25 00 25 00 20 00
        .byte   $99,$15,$96,$19,$00,$99,$1A,$96                ; C714 99 15 96 19 00 99 1A 96
        .byte   $1A,$00,$1B,$00,$1B,$00,$99,$20                ; C71C 1A 00 1B 00 1B 00 99 20
        .byte   $98,$20,$93,$00,$F7,$30,$19,$98                ; C724 98 20 93 00 F7 30 19 98
        .byte   $19,$F7,$1E,$00,$99,$19,$96,$19                ; C72C 19 F7 1E 00 99 19 96 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; C734 00 19 00 19 00 19 00 19
        .byte   $00,$22,$00,$22,$00,$19,$00,$19                ; C73C 00 22 00 22 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; C744 00 19 00 19 00 19 00 19
        .byte   $00,$22,$9B,$00,$9C,$00,$99,$25                ; C74C 00 22 9B 00 9C 00 99 25
        .byte   $96,$20,$00,$99,$25,$96,$25,$00                ; C754 96 20 00 99 25 96 25 00
        .byte   $99,$25,$96,$20,$00,$99,$15,$96                ; C75C 99 25 96 20 00 99 15 96
        .byte   $19,$00,$99,$1A,$96,$1A,$00,$99                ; C764 19 00 99 1A 96 1A 00 99
        .byte   $17,$96,$17,$00,$98,$20,$93,$00                ; C76C 17 96 17 00 98 20 93 00
        .byte   $98,$20,$93,$00,$9C,$20,$99,$25                ; C774 98 20 93 00 9C 20 99 25
        .byte   $96,$20,$00,$99,$25,$96,$25,$00                ; C77C 96 20 00 99 25 96 25 00
        .byte   $25,$00,$20,$00,$99,$15,$96,$19                ; C784 25 00 20 00 99 15 96 19
        .byte   $00,$99,$1A,$96,$1A,$00,$1B,$00                ; C78C 00 99 1A 96 1A 00 1B 00
        .byte   $1B,$00,$99,$20,$98,$20,$93,$00                ; C794 1B 00 99 20 98 20 93 00
        .byte   $F7,$30,$19,$98,$19,$F7,$1E,$00                ; C79C F7 30 19 98 19 F7 1E 00
        .byte   $FF,$BC,$C6,$FF,$A7,$C7                        ; C7A4 FF BC C6 FF A7 C7
LC7AA:
        .byte   $01,$01,$01,$01,$01,$01,$01,$02                ; C7AA 01 01 01 01 01 01 01 02
        .byte   $03,$01,$01,$01,$01,$01,$01,$01                ; C7B2 03 01 01 01 01 01 01 01
        .byte   $02,$01,$01,$01,$01,$01,$01,$01                ; C7BA 02 01 01 01 01 01 01 01
        .byte   $02,$03,$01,$01,$01,$01,$01,$01                ; C7C2 02 03 01 01 01 01 01 01
        .byte   $01,$02,$03,$01,$01,$01,$01,$01                ; C7CA 01 02 03 01 01 01 01 01
        .byte   $01,$01,$02,$01,$01,$01,$01,$01                ; C7D2 01 01 02 01 01 01 01 01
        .byte   $01,$01,$02,$03,$FF,$AA,$C7                    ; C7DA 01 01 02 03 FF AA C7
LC7E1:
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C7E1 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C7E9 06 06 06 06 06 06 06 06
        .byte   $06,$06,$A6,$06,$06,$06,$A6,$06                ; C7F1 06 06 A6 06 06 06 A6 06
        .byte   $06,$06,$A6,$06,$06,$06,$A6,$06                ; C7F9 06 06 A6 06 06 06 A6 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C801 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C809 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C811 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C819 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C821 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; C829 06 06 06 06 06 06 06 06
LC831:
        .byte   $F9,$08,$9F,$00,$00,$00,$00,$00                ; C831 F9 08 9F 00 00 00 00 00
        .byte   $00,$00,$00,$F8,$05,$9C,$34,$30                ; C839 00 00 00 F8 05 9C 34 30
        .byte   $32,$2B,$96,$30,$28,$29,$2B,$30                ; C841 32 2B 96 30 28 29 2B 30
        .byte   $29,$2B,$30,$9C,$32,$28,$F7,$3C                ; C849 29 2B 30 9C 32 28 F7 3C
        .byte   $34,$96,$29,$2B,$30,$F7,$3C,$32                ; C851 34 96 29 2B 30 F7 3C 32
        .byte   $32,$30,$2B,$9C,$29,$28,$29,$96                ; C859 32 30 2B 9C 29 28 29 96
        .byte   $26,$28,$29,$2B,$9C,$34,$30,$32                ; C861 26 28 29 2B 9C 34 30 32
        .byte   $2B,$96,$30,$28,$29,$2B,$30,$29                ; C869 2B 96 30 28 29 2B 30 29
        .byte   $2B,$30,$9C,$32,$28,$F7,$3C,$34                ; C871 2B 30 9C 32 28 F7 3C 34
        .byte   $96,$29,$2B,$30,$F7,$3C,$32,$32                ; C879 96 29 2B 30 F7 3C 32 32
        .byte   $30,$2B,$9C,$29,$28,$29,$96,$26                ; C881 30 2B 9C 29 28 29 96 26
        .byte   $28,$29,$2B,$F8,$01,$9B,$39,$93                ; C889 28 29 2B F8 01 9B 39 93
        .byte   $39,$00,$39,$00,$39,$00,$38,$00                ; C891 39 00 39 00 39 00 38 00
        .byte   $39,$00,$9B,$3B,$93,$38,$00,$9B                ; C899 39 00 9B 3B 93 38 00 9B
        .byte   $34,$93,$34,$00,$99,$40,$39,$30                ; C8A1 34 93 34 00 99 40 39 30
        .byte   $32,$F7,$54,$34,$93,$34,$00,$9B                ; C8A9 32 F7 54 34 93 34 00 9B
        .byte   $39,$93,$3B,$00,$40,$00,$3B,$00                ; C8B1 39 93 3B 00 40 00 3B 00
        .byte   $39,$00,$34,$00,$9B,$32,$96,$35                ; C8B9 39 00 34 00 9B 32 96 35
        .byte   $99,$39,$93,$3B,$00,$39,$00,$9B                ; C8C1 99 39 93 3B 00 39 00 9B
        .byte   $34,$93,$35,$00,$34,$00,$32,$00                ; C8C9 34 93 35 00 34 00 32 00
        .byte   $2B,$00,$30,$00,$F7,$54,$29,$34                ; C8D1 2B 00 30 00 F7 54 29 34
        .byte   $00,$9B,$39,$93,$39,$00,$39,$00                ; C8D9 00 9B 39 93 39 00 39 00
        .byte   $39,$00,$38,$00,$39,$00,$9B,$3B                ; C8E1 39 00 38 00 39 00 9B 3B
        .byte   $93,$38,$00,$9B,$34,$93,$34,$00                ; C8E9 93 38 00 9B 34 93 34 00
        .byte   $99,$40,$39,$30,$32,$F7,$54,$34                ; C8F1 99 40 39 30 32 F7 54 34
        .byte   $93,$34,$00,$9B,$39,$93,$3B,$00                ; C8F9 93 34 00 9B 39 93 3B 00
        .byte   $40,$00,$3B,$00,$39,$00,$34,$00                ; C901 40 00 3B 00 39 00 34 00
        .byte   $9B,$32,$96,$35,$99,$39,$93,$3B                ; C909 9B 32 96 35 99 39 93 3B
        .byte   $00,$39,$00,$9B,$34,$93,$35,$00                ; C911 00 39 00 9B 34 93 35 00
        .byte   $34,$00,$32,$00,$2B,$00,$30,$00                ; C919 34 00 32 00 2B 00 30 00
        .byte   $F7,$54,$29,$34,$00,$9B,$39,$93                ; C921 F7 54 29 34 00 9B 39 93
        .byte   $3B,$00,$40,$00,$3B,$00,$39,$00                ; C929 3B 00 40 00 3B 00 39 00
        .byte   $34,$00,$9B,$32,$96,$35,$99,$39                ; C931 34 00 9B 32 96 35 99 39
        .byte   $93,$3B,$00,$39,$00,$9B,$34,$93                ; C939 93 3B 00 39 00 9B 34 93
        .byte   $35,$00,$34,$00,$32,$00,$2B,$00                ; C941 35 00 34 00 32 00 2B 00
        .byte   $30,$00,$F7,$54,$29,$96,$00,$F8                ; C949 30 00 F7 54 29 96 00 F8
        .byte   $05,$FF,$3C,$C8                                ; C951 05 FF 3C C8
LC955:
        .byte   $F9,$08,$9F,$00,$00,$00,$00,$00                ; C955 F9 08 9F 00 00 00 00 00
        .byte   $00,$00,$00,$F8,$03,$9F,$00,$00                ; C95D 00 00 00 F8 03 9F 00 00
        .byte   $00,$00,$00,$00,$00,$00,$96,$19                ; C965 00 00 00 00 00 00 96 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$14                ; C96D 00 19 00 19 00 19 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C975 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$15,$00,$15,$00,$14                ; C97D 00 19 00 15 00 15 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C985 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$12                ; C98D 00 19 00 19 00 19 00 12
        .byte   $00,$12,$00,$12,$00,$12,$00,$14                ; C995 00 12 00 12 00 12 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C99D 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; C9A5 00 19 00 19 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$14                ; C9AD 00 19 00 19 00 19 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C9B5 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$15,$00,$15,$00,$14                ; C9BD 00 19 00 15 00 15 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C9C5 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$12                ; C9CD 00 19 00 19 00 19 00 12
        .byte   $00,$12,$00,$12,$00,$12,$00,$14                ; C9D5 00 12 00 12 00 12 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C9DD 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; C9E5 00 19 00 19 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$14                ; C9ED 00 19 00 19 00 19 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; C9F5 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$15,$00,$15,$00,$14                ; C9FD 00 19 00 15 00 15 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; CA05 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$12                ; CA0D 00 19 00 19 00 19 00 12
        .byte   $00,$12,$00,$12,$00,$12,$00,$14                ; CA15 00 12 00 12 00 12 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; CA1D 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$19                ; CA25 00 19 00 19 00 19 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$12                ; CA2D 00 19 00 19 00 19 00 12
        .byte   $00,$12,$00,$12,$00,$12,$00,$14                ; CA35 00 12 00 12 00 12 00 14
        .byte   $00,$14,$00,$14,$00,$14,$00,$19                ; CA3D 00 14 00 14 00 14 00 19
        .byte   $00,$19,$00,$19,$00,$19,$00,$FF                ; CA45 00 19 00 19 00 19 00 FF
        .byte   $60,$C9                                        ; CA4D 60 C9
LCA4F:
        .byte   $96,$29,$34,$30,$34,$29,$34,$30                ; CA4F 96 29 34 30 34 29 34 30
        .byte   $34,$28,$34,$32,$34,$28,$34,$32                ; CA57 34 28 34 32 34 28 34 32
        .byte   $34,$29,$34,$30,$34,$29,$35,$30                ; CA5F 34 29 34 30 34 29 35 30
        .byte   $35,$28,$34,$32,$34,$28,$34,$32                ; CA67 35 28 34 32 34 28 34 32
        .byte   $34,$29,$34,$30,$34,$29,$34,$30                ; CA6F 34 29 34 30 34 29 34 30
        .byte   $34,$29,$35,$32,$35,$29,$35,$32                ; CA77 34 29 35 32 35 29 35 32
        .byte   $35,$29,$34,$30,$34,$28,$34,$32                ; CA7F 35 29 34 30 34 28 34 32
        .byte   $34,$29,$34,$30,$34,$29,$34,$30                ; CA87 34 29 34 30 34 29 34 30
        .byte   $34,$96,$29,$34,$30,$34,$29,$34                ; CA8F 34 96 29 34 30 34 29 34
        .byte   $30,$34,$28,$34,$32,$34,$28,$34                ; CA97 30 34 28 34 32 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$35                ; CA9F 32 34 29 34 30 34 29 35
        .byte   $30,$35,$28,$34,$32,$34,$28,$34                ; CAA7 30 35 28 34 32 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$34                ; CAAF 32 34 29 34 30 34 29 34
        .byte   $30,$34,$29,$35,$32,$35,$29,$35                ; CAB7 30 34 29 35 32 35 29 35
        .byte   $32,$35,$29,$34,$30,$34,$28,$34                ; CABF 32 35 29 34 30 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$34                ; CAC7 32 34 29 34 30 34 29 34
        .byte   $30,$34,$29,$34,$30,$34,$29,$34                ; CACF 30 34 29 34 30 34 29 34
        .byte   $30,$34,$28,$34,$32,$34,$28,$34                ; CAD7 30 34 28 34 32 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$35                ; CADF 32 34 29 34 30 34 29 35
        .byte   $30,$35,$28,$34,$32,$34,$28,$34                ; CAE7 30 35 28 34 32 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$34                ; CAEF 32 34 29 34 30 34 29 34
        .byte   $30,$34,$29,$35,$32,$35,$29,$35                ; CAF7 30 34 29 35 32 35 29 35
        .byte   $32,$35,$29,$34,$30,$34,$28,$34                ; CAFF 32 35 29 34 30 34 28 34
        .byte   $32,$34,$29,$34,$30,$34,$29,$34                ; CB07 32 34 29 34 30 34 29 34
        .byte   $30,$34,$00,$34,$00,$34,$00,$34                ; CB0F 30 34 00 34 00 34 00 34
        .byte   $00,$34,$00,$32,$00,$32,$00,$32                ; CB17 00 34 00 32 00 32 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$30                ; CB1F 00 32 00 34 00 34 00 30
        .byte   $00,$30,$00,$32,$00,$32,$00,$32                ; CB27 00 30 00 32 00 32 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$34                ; CB2F 00 32 00 34 00 34 00 34
        .byte   $00,$34,$00,$35,$00,$35,$00,$35                ; CB37 00 34 00 35 00 35 00 35
        .byte   $00,$35,$00,$34,$00,$34,$00,$32                ; CB3F 00 35 00 34 00 34 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$34                ; CB47 00 32 00 34 00 34 00 34
        .byte   $00,$34,$00,$34,$00,$34,$00,$34                ; CB4F 00 34 00 34 00 34 00 34
        .byte   $00,$34,$00,$32,$00,$32,$00,$32                ; CB57 00 34 00 32 00 32 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$30                ; CB5F 00 32 00 34 00 34 00 30
        .byte   $00,$30,$00,$32,$00,$32,$00,$32                ; CB67 00 30 00 32 00 32 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$34                ; CB6F 00 32 00 34 00 34 00 34
        .byte   $00,$34,$00,$35,$00,$35,$00,$35                ; CB77 00 34 00 35 00 35 00 35
        .byte   $00,$35,$00,$34,$00,$34,$00,$32                ; CB7F 00 35 00 34 00 34 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$34                ; CB87 00 32 00 34 00 34 00 34
        .byte   $00,$34,$00,$34,$00,$34,$00,$34                ; CB8F 00 34 00 34 00 34 00 34
        .byte   $00,$34,$00,$35,$00,$35,$00,$35                ; CB97 00 34 00 35 00 35 00 35
        .byte   $00,$35,$00,$34,$00,$34,$00,$32                ; CB9F 00 35 00 34 00 34 00 32
        .byte   $00,$32,$00,$34,$00,$34,$00,$34                ; CBA7 00 32 00 34 00 34 00 34
        .byte   $00,$34,$FF,$90,$CA,$FF,$B4,$CB                ; CBAF 00 34 FF 90 CA FF B4 CB
LCBB7:
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; CBB7 01 01 01 01 01 01 01 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; CBBF 01 01 01 01 01 01 01 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; CBC7 01 01 01 01 01 01 01 01
        .byte   $02,$02,$02,$02,$02,$02,$02,$02                ; CBCF 02 02 02 02 02 02 02 02
        .byte   $02,$02,$02,$02,$02,$02,$02,$02                ; CBD7 02 02 02 02 02 02 02 02
        .byte   $02,$02,$02,$02,$FF,$B7,$CB                    ; CBDF 02 02 02 02 FF B7 CB
LCBE6:
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; CBE6 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; CBEE 06 06 06 06 06 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; CBF6 B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$46,$46,$46                ; CBFE B6 06 06 06 A6 46 46 46
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; CC06 B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$A6,$A6,$A6                ; CC0E B6 06 06 06 A6 A6 A6 A6
        .byte   $B6,$06,$46,$46,$A6,$06,$46,$46                ; CC16 B6 06 46 46 A6 06 46 46
        .byte   $B6,$06,$46,$46,$A6,$06,$46,$46                ; CC1E B6 06 46 46 A6 06 46 46
LCC26:
        .byte   $F9,$08,$F8,$01,$9F,$00,$00,$00                ; CC26 F9 08 F8 01 9F 00 00 00
        .byte   $F7,$3C,$00,$93,$29,$00,$32,$00                ; CC2E F7 3C 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CC36 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CC3E 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$32,$00                ; CC46 29 00 34 00 29 00 32 00
        .byte   $96,$29,$00,$93,$29,$00,$32,$00                ; CC4E 96 29 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CC56 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CC5E 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$35,$00                ; CC66 29 00 34 00 29 00 35 00
        .byte   $96,$37,$00,$93,$29,$00,$32,$00                ; CC6E 96 37 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CC76 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CC7E 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$32,$00                ; CC86 29 00 34 00 29 00 32 00
        .byte   $96,$29,$00,$93,$29,$00,$32,$00                ; CC8E 96 29 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CC96 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CC9E 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$35,$00                ; CCA6 29 00 34 00 29 00 35 00
        .byte   $96,$37,$00,$93,$29,$00,$32,$00                ; CCAE 96 37 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CCB6 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CCBE 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$32,$00                ; CCC6 29 00 34 00 29 00 32 00
        .byte   $96,$29,$00,$93,$29,$00,$32,$00                ; CCCE 96 29 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CCD6 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CCDE 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$35,$00                ; CCE6 29 00 34 00 29 00 35 00
        .byte   $96,$37,$00,$93,$29,$00,$32,$00                ; CCEE 96 37 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CCF6 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CCFE 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$32,$00                ; CD06 29 00 34 00 29 00 32 00
        .byte   $96,$29,$00,$93,$29,$00,$32,$00                ; CD0E 96 29 00 93 29 00 32 00
        .byte   $35,$00,$34,$00,$29,$00,$32,$00                ; CD16 35 00 34 00 29 00 32 00
        .byte   $29,$00,$30,$00,$29,$00,$32,$00                ; CD1E 29 00 30 00 29 00 32 00
        .byte   $29,$00,$34,$00,$29,$00,$35,$00                ; CD26 29 00 34 00 29 00 35 00
        .byte   $96,$37,$00,$93,$29,$00,$32,$00                ; CD2E 96 37 00 93 29 00 32 00
        .byte   $35,$00,$F7,$60,$35,$9F,$35,$93                ; CD36 35 00 F7 60 35 9F 35 93
        .byte   $35,$00,$30,$98,$00,$93,$33,$98                ; CD3E 35 00 30 98 00 93 33 98
        .byte   $00,$93,$2A,$98,$00,$93,$30,$00                ; CD46 00 93 2A 98 00 93 30 00
        .byte   $30,$00,$28,$00,$2A,$00,$30,$00                ; CD4E 30 00 28 00 2A 00 30 00
        .byte   $33,$00,$99,$35,$93,$33,$00,$35                ; CD56 33 00 99 35 93 33 00 35
        .byte   $00,$30,$98,$00,$93,$33,$98,$00                ; CD5E 00 30 98 00 93 33 98 00
        .byte   $93,$2A,$98,$00,$93,$30,$00,$30                ; CD66 93 2A 98 00 93 30 00 30
        .byte   $00,$28,$98,$00,$93,$2A,$00,$99                ; CD6E 00 28 98 00 93 2A 00 99
        .byte   $23,$96,$25,$00,$93,$35,$00,$30                ; CD76 23 96 25 00 93 35 00 30
        .byte   $98,$00,$93,$33,$98,$00,$93,$2A                ; CD7E 98 00 93 33 98 00 93 2A
        .byte   $98,$00,$93,$30,$00,$96,$30,$93                ; CD86 98 00 93 30 00 96 30 93
        .byte   $28,$00,$2A,$00,$30,$00,$33,$00                ; CD8E 28 00 2A 00 30 00 33 00
        .byte   $99,$35,$93,$33,$00,$35,$00,$30                ; CD96 99 35 93 33 00 35 00 30
        .byte   $98,$00,$93,$33,$98,$00,$93,$2A                ; CD9E 98 00 93 33 98 00 93 2A
        .byte   $98,$00,$93,$30,$00,$96,$30,$93                ; CDA6 98 00 93 30 00 96 30 93
        .byte   $28,$98,$00,$93,$2A,$00,$99,$23                ; CDAE 28 98 00 93 2A 00 99 23
        .byte   $93,$25,$98,$00,$93,$35,$00,$30                ; CDB6 93 25 98 00 93 35 00 30
        .byte   $98,$00,$93,$33,$98,$00,$93,$2A                ; CDBE 98 00 93 33 98 00 93 2A
        .byte   $98,$00,$F7,$0C,$30,$96,$30,$31                ; CDC6 98 00 F7 0C 30 96 30 31
        .byte   $93,$33,$00,$36,$00,$30,$00,$31                ; CDCE 93 33 00 36 00 30 00 31
        .byte   $00,$32,$00,$F7,$0C,$34,$F7,$3C                ; CDD6 00 32 00 F7 0C 34 F7 3C
        .byte   $34,$32,$00,$31,$00,$F7,$0C,$2B                ; CDDE 34 32 00 31 00 F7 0C 2B
        .byte   $9C,$2B,$93,$34,$00,$35,$00,$36                ; CDE6 9C 2B 93 34 00 35 00 36
        .byte   $00,$F7,$0C,$37,$F7,$3C,$37,$36                ; CDEE 00 F7 0C 37 F7 3C 37 36
        .byte   $00,$37,$00,$F7,$0C,$39,$96,$39                ; CDF6 00 37 00 F7 0C 39 96 39
        .byte   $93,$37,$00,$39,$00,$F7,$3C,$3B                ; CDFE 93 37 00 39 00 F7 3C 3B
        .byte   $FF,$26,$CC                                    ; CE06 FF 26 CC
LCE09:
        .byte   $F9,$08,$F8,$03,$93,$12,$00,$22                ; CE09 F9 08 F8 03 93 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CE11 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CE19 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CE21 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CE29 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CE31 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CE39 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CE41 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CE49 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CE51 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CE59 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CE61 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CE69 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CE71 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CE79 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CE81 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CE89 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CE91 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CE99 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CEA1 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CEA9 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CEB1 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CEB9 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CEC1 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CEC9 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CED1 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CED9 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CEE1 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CEE9 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CEF1 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CEF9 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CF01 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CF09 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CF11 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CF19 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CF21 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$12,$00,$22                ; CF29 00 10 00 20 00 12 00 22
        .byte   $00,$12,$00,$22,$00,$15,$00,$25                ; CF31 00 12 00 22 00 15 00 25
        .byte   $00,$15,$00,$25,$00,$0A,$00,$1A                ; CF39 00 15 00 25 00 0A 00 1A
        .byte   $00,$0A,$00,$1A,$00,$10,$00,$20                ; CF41 00 0A 00 1A 00 10 00 20
        .byte   $00,$10,$00,$20,$00,$15,$00,$15                ; CF49 00 10 00 20 00 15 00 15
        .byte   $13,$10,$00,$13,$00,$15,$00,$15                ; CF51 13 10 00 13 00 15 00 15
        .byte   $13,$10,$00,$13,$00,$15,$00,$15                ; CF59 13 10 00 13 00 15 00 15
        .byte   $13,$10,$00,$13,$00,$15,$00,$16                ; CF61 13 10 00 13 00 15 00 16
        .byte   $00,$17,$00,$96,$18,$93,$18,$00                ; CF69 00 17 00 96 18 93 18 00
        .byte   $18,$16,$13,$00,$16,$00,$18,$00                ; CF71 18 16 13 00 16 00 18 00
        .byte   $18,$16,$13,$00,$16,$00,$18,$00                ; CF79 18 16 13 00 16 00 18 00
        .byte   $18,$16,$13,$00,$16,$00,$18,$00                ; CF81 18 16 13 00 16 00 18 00
        .byte   $17,$00,$16,$00,$96,$15,$93,$15                ; CF89 17 00 16 00 96 15 93 15
        .byte   $00,$15,$13,$10,$00,$13,$00,$15                ; CF91 00 15 13 10 00 13 00 15
        .byte   $00,$15,$13,$10,$00,$13,$00,$15                ; CF99 00 15 13 10 00 13 00 15
        .byte   $00,$15,$13,$10,$00,$13,$00,$15                ; CFA1 00 15 13 10 00 13 00 15
        .byte   $00,$16,$00,$17,$00,$96,$18,$93                ; CFA9 00 16 00 17 00 96 18 93
        .byte   $18,$00,$18,$16,$13,$00,$16,$00                ; CFB1 18 00 18 16 13 00 16 00
        .byte   $18,$00,$18,$16,$13,$00,$16,$00                ; CFB9 18 00 18 16 13 00 16 00
        .byte   $18,$00,$18,$16,$13,$00,$16,$00                ; CFC1 18 00 18 16 13 00 16 00
        .byte   $18,$00,$17,$00,$16,$00,$96,$15                ; CFC9 18 00 17 00 16 00 96 15
        .byte   $93,$15,$00,$15,$13,$10,$00,$13                ; CFD1 93 15 00 15 13 10 00 13
        .byte   $00,$15,$00,$15,$13,$10,$00,$13                ; CFD9 00 15 00 15 13 10 00 13
        .byte   $00,$15,$00,$15,$13,$10,$00,$13                ; CFE1 00 15 00 15 13 10 00 13
        .byte   $00,$15,$00,$16,$00,$17,$00,$96                ; CFE9 00 15 00 16 00 17 00 96
        .byte   $18,$93,$18,$00,$18,$16,$13,$00                ; CFF1 18 93 18 00 18 16 13 00
        .byte   $16,$00,$18,$00,$18,$16,$13,$00                ; CFF9 16 00 18 00 18 16 13 00
        .byte   $16,$00,$18,$00,$18,$16,$13,$00                ; D001 16 00 18 00 18 16 13 00
        .byte   $16,$00,$18,$00,$19,$00,$1A,$00                ; D009 16 00 18 00 19 00 1A 00
        .byte   $96,$1B,$93,$1B,$00,$1B,$19,$96                ; D011 96 1B 93 1B 00 1B 19 96
        .byte   $16,$19,$1B,$93,$1B,$19,$96,$16                ; D019 16 19 1B 93 1B 19 96 16
        .byte   $19,$93,$1B,$00,$1B,$19,$96,$16                ; D021 19 93 1B 00 1B 19 96 16
        .byte   $19,$93,$1B,$00,$20,$00,$21,$00                ; D029 19 93 1B 00 20 00 21 00
        .byte   $96,$12,$12,$93,$12,$10,$96,$09                ; D031 96 12 12 93 12 10 96 09
        .byte   $10,$93,$12,$00,$12,$10,$96,$09                ; D039 10 93 12 00 12 10 96 09
        .byte   $10,$93,$14,$00,$14,$12,$96,$0B                ; D041 10 93 14 00 14 12 96 0B
        .byte   $12,$93,$16,$00,$16,$14,$99,$11                ; D049 12 93 16 00 16 14 99 11
        .byte   $FF,$09,$CE                                    ; D051 FF 09 CE
LD054:
        .byte   $9F,$00,$00,$00,$00,$00,$00,$00                ; D054 9F 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$9E,$29,$93                ; D05C 00 00 00 00 00 9E 29 93
        .byte   $27,$29,$2A,$30,$9C,$32,$99,$30                ; D064 27 29 2A 30 9C 32 99 30
        .byte   $2A,$96,$30,$29,$9B,$25,$93,$25                ; D06C 2A 96 30 29 9B 25 93 25
        .byte   $00,$27,$00,$29,$00,$9B,$2A,$27                ; D074 00 27 00 29 00 9B 2A 27
        .byte   $99,$24,$9E,$29,$93,$34,$35,$37                ; D07C 99 24 9E 29 93 34 35 37
        .byte   $39,$9C,$3A,$99,$39,$37,$96,$39                ; D084 39 9C 3A 99 39 37 96 39
        .byte   $35,$9B,$40,$96,$40,$44,$45,$9B                ; D08C 35 9B 40 96 40 44 45 9B
        .byte   $47,$44,$99,$40,$F7,$60,$2A,$9F                ; D094 47 44 99 40 F7 60 2A 9F
        .byte   $2A,$00,$00,$93,$25,$27,$28,$27                ; D09C 2A 00 00 93 25 27 28 27
        .byte   $25,$98,$00,$93,$25,$27,$28,$2A                ; D0A4 25 98 00 93 25 27 28 2A
        .byte   $30,$98,$00,$93,$2A,$30,$31,$33                ; D0AC 30 98 00 93 2A 30 31 33
        .byte   $35,$98,$00,$93,$35,$37,$38,$3A                ; D0B4 35 98 00 93 35 37 38 3A
        .byte   $96,$40,$00,$40,$93,$40,$00,$40                ; D0BC 96 40 00 40 93 40 00 40
        .byte   $00,$41,$00,$99,$3A,$F7,$18,$3A                ; D0C4 00 41 00 99 3A F7 18 3A
        .byte   $96,$3A,$43,$3A,$40,$99,$38,$40                ; D0CC 96 3A 43 3A 40 99 38 40
        .byte   $93,$25,$27,$28,$27,$25,$98,$00                ; D0D4 93 25 27 28 27 25 98 00
        .byte   $93,$25,$27,$28,$2A,$30,$98,$00                ; D0DC 93 25 27 28 2A 30 98 00
        .byte   $93,$2A,$30,$31,$33,$96,$35,$00                ; D0E4 93 2A 30 31 33 96 35 00
        .byte   $93,$35,$37,$38,$3A,$F7,$18,$40                ; D0EC 93 35 37 38 3A F7 18 40
        .byte   $96,$40,$93,$40,$00,$96,$40,$41                ; D0F4 96 40 93 40 00 96 40 41
        .byte   $99,$3A,$F7,$18,$40,$93,$40,$00                ; D0FC 99 3A F7 18 40 93 40 00
        .byte   $96,$31,$33,$36,$38,$39,$3A,$F7                ; D104 96 31 33 36 38 39 3A F7
        .byte   $0C,$3B,$F7,$3C,$3B,$39,$38,$F7                ; D10C 0C 3B F7 3C 3B 39 38 F7
        .byte   $0C,$36,$9C,$36,$96,$3B,$40,$41                ; D114 0C 36 9C 36 96 3B 40 41
        .byte   $F7,$0C,$42,$F7,$3C,$42,$40,$42                ; D11C F7 0C 42 F7 3C 42 40 42
        .byte   $F7,$0C,$44,$44,$93,$42,$00,$44                ; D124 F7 0C 44 44 93 42 00 44
        .byte   $00,$F7,$3C,$46,$FF,$54,$D0,$FF                ; D12C 00 F7 3C 46 FF 54 D0 FF
        .byte   $33,$D1                                        ; D134 33 D1
LD136:
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; D136 01 01 01 01 01 01 01 01
        .byte   $02,$02,$02,$02,$02,$02,$02,$02                ; D13E 02 02 02 02 02 02 02 02
        .byte   $02,$02,$02,$03,$04,$04,$04,$04                ; D146 02 02 02 03 04 04 04 04
        .byte   $04,$04,$04,$04,$04,$04,$04,$04                ; D14E 04 04 04 04 04 04 04 04
        .byte   $04,$04,$04,$04,$FF,$36,$D1                    ; D156 04 04 04 04 FF 36 D1
LD15D:
        .byte   $06,$06,$06,$06,$A6,$06,$06,$06                ; D15D 06 06 06 06 A6 06 06 06
        .byte   $06,$06,$06,$06,$A6,$06,$06,$06                ; D165 06 06 06 06 A6 06 06 06
        .byte   $B6,$06,$06,$06,$06,$06,$06,$06                ; D16D B6 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D175 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D17D 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D185 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D18D 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D195 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D19D 06 06 06 06 06 06 06 06
        .byte   $06,$06,$06,$06,$06,$06,$06,$06                ; D1A5 06 06 06 06 06 06 06 06
LD1AD:
        .byte   $F9,$08,$F8,$05,$99,$34,$96,$2B                ; D1AD F9 08 F8 05 99 34 96 2B
        .byte   $30,$99,$32,$96,$30,$2B,$99,$29                ; D1B5 30 99 32 96 30 2B 99 29
        .byte   $96,$29,$30,$99,$34,$96,$32,$30                ; D1BD 96 29 30 99 34 96 32 30
        .byte   $99,$2B,$96,$2B,$30,$98,$32,$93                ; D1C5 99 2B 96 2B 30 98 32 93
        .byte   $00,$98,$34,$93,$00,$99,$30,$98                ; D1CD 00 98 34 93 00 99 30 98
        .byte   $29,$93,$00,$9C,$29,$96,$32,$98                ; D1D5 29 93 00 9C 29 96 32 98
        .byte   $32,$93,$00,$96,$35,$98,$39,$93                ; D1DD 32 93 00 96 35 98 39 93
        .byte   $00,$96,$37,$35,$98,$34,$93,$00                ; D1E5 00 96 37 35 98 34 93 00
        .byte   $96,$34,$30,$98,$34,$93,$00,$96                ; D1ED 96 34 30 98 34 93 00 96
        .byte   $32,$30,$98,$2B,$93,$00,$96,$2B                ; D1F5 32 30 98 2B 93 00 96 2B
        .byte   $30,$98,$32,$93,$00,$98,$34,$93                ; D1FD 30 98 32 93 00 98 34 93
        .byte   $00,$98,$30,$93,$00,$98,$29,$93                ; D205 00 98 30 93 00 98 29 93
        .byte   $00,$9C,$29,$F7,$1B,$34,$95,$00                ; D20D 00 9C 29 F7 1B 34 95 00
        .byte   $96,$33,$F7,$1B,$34,$95,$00,$96                ; D215 96 33 F7 1B 34 95 00 96
        .byte   $32,$F7,$1B,$34,$95,$00,$96,$39                ; D21D 32 F7 1B 34 95 00 96 39
        .byte   $98,$34,$93,$00,$96,$32,$30,$98                ; D225 98 34 93 00 96 32 30 98
        .byte   $2B,$93,$00,$96,$2B,$30,$98,$32                ; D22D 2B 93 00 96 2B 30 98 32
        .byte   $93,$00,$98,$34,$93,$00,$F7,$60                ; D235 93 00 98 34 93 00 F7 60
        .byte   $39,$F7,$4E,$39,$98,$00,$99,$34                ; D23D 39 F7 4E 39 98 00 99 34
        .byte   $96,$2B,$30,$99,$32,$96,$30,$2B                ; D245 96 2B 30 99 32 96 30 2B
        .byte   $99,$29,$96,$29,$30,$99,$34,$96                ; D24D 99 29 96 29 30 99 34 96
        .byte   $32,$30,$99,$2B,$96,$2B,$30,$98                ; D255 32 30 99 2B 96 2B 30 98
        .byte   $32,$93,$00,$98,$34,$93,$00,$99                ; D25D 32 93 00 98 34 93 00 99
        .byte   $30,$98,$29,$93,$00,$9C,$29,$96                ; D265 30 98 29 93 00 9C 29 96
        .byte   $32,$98,$32,$93,$00,$96,$35,$98                ; D26D 32 98 32 93 00 96 35 98
        .byte   $39,$93,$00,$96,$37,$35,$98,$34                ; D275 39 93 00 96 37 35 98 34
        .byte   $93,$00,$96,$34,$30,$98,$34,$93                ; D27D 93 00 96 34 30 98 34 93
        .byte   $00,$96,$32,$30,$98,$2B,$93,$00                ; D285 00 96 32 30 98 2B 93 00
        .byte   $96,$2B,$30,$98,$32,$93,$00,$98                ; D28D 96 2B 30 98 32 93 00 98
        .byte   $34,$93,$00,$98,$30,$93,$00,$98                ; D295 34 93 00 98 30 93 00 98
        .byte   $29,$93,$00,$9C,$29,$99,$34,$96                ; D29D 29 93 00 9C 29 99 34 96
        .byte   $2B,$30,$99,$32,$96,$30,$2B,$99                ; D2A5 2B 30 99 32 96 30 2B 99
        .byte   $29,$96,$29,$30,$99,$34,$96,$32                ; D2AD 29 96 29 30 99 34 96 32
        .byte   $30,$99,$2B,$96,$2B,$30,$98,$32                ; D2B5 30 99 2B 96 2B 30 98 32
        .byte   $93,$00,$98,$34,$93,$00,$99,$30                ; D2BD 93 00 98 34 93 00 99 30
        .byte   $98,$29,$93,$00,$9C,$29,$96,$32                ; D2C5 98 29 93 00 9C 29 96 32
        .byte   $98,$32,$93,$00,$96,$35,$98,$39                ; D2CD 98 32 93 00 96 35 98 39
        .byte   $93,$00,$96,$37,$35,$98,$34,$93                ; D2D5 93 00 96 37 35 98 34 93
        .byte   $00,$96,$34,$30,$98,$34,$93,$00                ; D2DD 00 96 34 30 98 34 93 00
        .byte   $96,$32,$30,$98,$2B,$93,$00,$96                ; D2E5 96 32 30 98 2B 93 00 96
        .byte   $2B,$30,$98,$32,$93,$00,$98,$34                ; D2ED 2B 30 98 32 93 00 98 34
        .byte   $93,$00,$98,$30,$93,$00,$98,$29                ; D2F5 93 00 98 30 93 00 98 29
        .byte   $93,$00,$9C,$29,$F7,$1B,$34,$95                ; D2FD 93 00 9C 29 F7 1B 34 95
        .byte   $00,$96,$33,$F7,$1B,$34,$95,$00                ; D305 00 96 33 F7 1B 34 95 00
        .byte   $96,$33,$F7,$1B,$34,$95,$00,$96                ; D30D 96 33 F7 1B 34 95 00 96
        .byte   $39,$98,$34,$93,$00,$96,$32,$30                ; D315 39 98 34 93 00 96 32 30
        .byte   $98,$2B,$93,$00,$96,$2B,$30,$98                ; D31D 98 2B 93 00 96 2B 30 98
        .byte   $32,$93,$00,$98,$34,$93,$00,$98                ; D325 32 93 00 98 34 93 00 98
        .byte   $30,$93,$00,$98,$29,$93,$00,$9C                ; D32D 30 93 00 98 29 93 00 9C
        .byte   $29,$F7,$1B,$34,$95,$00,$96,$33                ; D335 29 F7 1B 34 95 00 96 33
        .byte   $F7,$1B,$34,$95,$00,$96,$32,$F7                ; D33D F7 1B 34 95 00 96 32 F7
        .byte   $1B,$34,$95,$00,$96,$39,$98,$34                ; D345 1B 34 95 00 96 39 98 34
        .byte   $93,$00,$96,$32,$30,$98,$2B,$93                ; D34D 93 00 96 32 30 98 2B 93
        .byte   $00,$96,$2B,$30,$98,$32,$93,$00                ; D355 00 96 2B 30 98 32 93 00
        .byte   $98,$34,$93,$00,$F7,$60,$39,$F7                ; D35D 98 34 93 00 F7 60 39 F7
        .byte   $4E,$39,$98,$00,$FE,$AD,$D1                    ; D365 4E 39 98 00 FE AD D1
LD36C:
        .byte   $F9,$08,$F8,$05,$F7,$60,$28,$9E                ; D36C F9 08 F8 05 F7 60 28 9E
        .byte   $29,$96,$29,$28,$9E,$24,$99,$24                ; D374 29 96 29 28 9E 24 99 24
        .byte   $F7,$4E,$29,$98,$00,$9E,$32,$96                ; D37C F7 4E 29 98 00 9E 32 96
        .byte   $30,$2B,$9E,$29,$96,$2B,$29,$9C                ; D384 30 2B 9E 29 96 2B 29 9C
        .byte   $28,$96,$28,$93,$29,$28,$96,$24                ; D38C 28 96 28 93 29 28 96 24
        .byte   $28,$9F,$29,$00,$9E,$29,$96,$2B                ; D394 28 9F 29 00 9E 29 96 2B
        .byte   $29,$9C,$28,$96,$28,$93,$29,$28                ; D39C 29 9C 28 96 28 93 29 28
        .byte   $96,$24,$28,$F7,$60,$29,$F7,$54                ; D3A4 96 24 28 F7 60 29 F7 54
        .byte   $29,$00,$F7,$60,$28,$9E,$29,$96                ; D3AC 29 00 F7 60 28 9E 29 96
        .byte   $29,$28,$9E,$24,$99,$24,$F7,$4E                ; D3B4 29 28 9E 24 99 24 F7 4E
        .byte   $29,$98,$00,$9E,$32,$96,$30,$2B                ; D3BC 29 98 00 9E 32 96 30 2B
        .byte   $9E,$29,$96,$2B,$29,$9C,$28,$96                ; D3C4 9E 29 96 2B 29 9C 28 96
        .byte   $28,$93,$29,$28,$96,$24,$28,$9F                ; D3CC 28 93 29 28 96 24 28 9F
        .byte   $29,$F7,$60,$28,$9E,$29,$96,$29                ; D3D4 29 F7 60 28 9E 29 96 29
        .byte   $28,$9E,$24,$99,$24,$F7,$4E,$29                ; D3DC 28 9E 24 99 24 F7 4E 29
        .byte   $98,$00,$9E,$32,$96,$30,$2B,$9E                ; D3E4 98 00 9E 32 96 30 2B 9E
        .byte   $29,$96,$2B,$29,$9C,$28,$96,$28                ; D3EC 29 96 2B 29 9C 28 96 28
        .byte   $93,$29,$28,$96,$24,$28,$9F,$29                ; D3F4 93 29 28 96 24 28 9F 29
        .byte   $00,$00,$00,$00,$00,$9E,$29,$96                ; D3FC 00 00 00 00 00 9E 29 96
        .byte   $2B,$29,$9C,$28,$96,$28,$93,$29                ; D404 2B 29 9C 28 96 28 93 29
        .byte   $28,$96,$24,$28,$F7,$60,$29,$F7                ; D40C 28 96 24 28 F7 60 29 F7
        .byte   $54,$29,$00,$FE,$6C,$D3                        ; D414 54 29 00 FE 6C D3
LD41A:
        .byte   $9F,$00,$00,$00,$00,$00,$00,$00                ; D41A 9F 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$96,$24                ; D422 00 00 00 00 00 00 96 24
        .byte   $2B,$32,$38,$32,$2B,$24,$2B,$24                ; D42A 2B 32 38 32 2B 24 2B 24
        .byte   $29,$30,$29,$34,$29,$30,$29,$24                ; D432 29 30 29 34 29 30 29 24
        .byte   $2B,$32,$38,$32,$2B,$24,$2B,$24                ; D43A 2B 32 38 32 2B 24 2B 24
        .byte   $29,$30,$34,$99,$30,$29,$96,$35                ; D442 29 30 34 99 30 29 96 35
        .byte   $29,$32,$35,$93,$35,$37,$96,$35                ; D44A 29 32 35 93 35 37 96 35
        .byte   $32,$29,$34,$24,$29,$34,$30,$29                ; D452 32 29 34 24 29 34 30 29
        .byte   $24,$29,$2B,$1B,$22,$29,$2B,$29                ; D45A 24 29 2B 1B 22 29 2B 29
        .byte   $22,$1B,$19,$24,$29,$30,$9C,$39                ; D462 22 1B 19 24 29 30 9C 39
        .byte   $96,$24,$2B,$32,$2B,$38,$2B,$32                ; D46A 96 24 2B 32 2B 38 2B 32
        .byte   $2B,$24,$29,$30,$29,$34,$29,$30                ; D472 2B 24 29 30 29 34 29 30
        .byte   $29,$24,$2B,$32,$38,$32,$2B,$24                ; D47A 29 24 2B 32 38 32 2B 24
        .byte   $2B,$24,$29,$30,$34,$99,$30,$29                ; D482 2B 24 29 30 34 99 30 29
        .byte   $96,$35,$29,$32,$35,$93,$35,$37                ; D48A 96 35 29 32 35 93 35 37
        .byte   $96,$35,$32,$29,$34,$24,$29,$34                ; D492 96 35 32 29 34 24 29 34
        .byte   $30,$29,$24,$29,$2B,$1B,$22,$29                ; D49A 30 29 24 29 2B 1B 22 29
        .byte   $2B,$29,$22,$1B,$19,$24,$29,$30                ; D4A2 2B 29 22 1B 19 24 29 30
        .byte   $9C,$39,$96,$24,$29,$30,$29,$34                ; D4AA 9C 39 96 24 29 30 29 34
        .byte   $29,$30,$29,$24,$29,$30,$24,$34                ; D4B2 29 30 29 24 29 30 24 34
        .byte   $30,$29,$24,$24,$2B,$32,$2B,$38                ; D4BA 30 29 24 24 2B 32 2B 38
        .byte   $32,$2B,$32,$24,$29,$30,$34,$9C                ; D4C2 32 2B 32 24 29 30 34 9C
        .byte   $30,$96,$24,$29,$30,$29,$34,$29                ; D4CA 30 96 24 29 30 29 34 29
        .byte   $30,$29,$34,$29,$30,$24,$34,$30                ; D4D2 30 29 34 29 30 24 34 30
        .byte   $29,$24,$24,$2B,$32,$2B,$38,$32                ; D4DA 29 24 24 2B 32 2B 38 32
        .byte   $2B,$32,$F7,$60,$29,$9F,$29,$FE                ; D4E2 2B 32 F7 60 29 9F 29 FE
        .byte   $1A,$D4,$FF,$EC,$D4                            ; D4EA 1A D4 FF EC D4
LD4EF:
        .byte   $03,$03,$03,$03,$03,$03,$03,$03                ; D4EF 03 03 03 03 03 03 03 03
        .byte   $03,$03,$03,$03,$03,$01,$01,$01                ; D4F7 03 03 03 03 03 01 01 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; D4FF 01 01 01 01 01 01 01 01
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; D507 01 01 01 01 01 01 01 01
        .byte   $01,$01,$01,$01,$01,$02,$FF,$EF                ; D50F 01 01 01 01 01 02 FF EF
        .byte   $D4                                            ; D517 D4
LD518:
        .byte   $A3,$A3,$A3,$A3,$A3,$A3,$A3,$A3                ; D518 A3 A3 A3 A3 A3 A3 A3 A3
        .byte   $A3,$A3,$A1,$01,$01,$A1,$01,$01                ; D520 A3 A3 A1 01 01 A1 01 01
        .byte   $A3,$A3,$A3,$A3,$A3,$A3,$A3,$A3                ; D528 A3 A3 A3 A3 A3 A3 A3 A3
        .byte   $A3,$A3,$A1,$01,$01,$A1,$01,$01                ; D530 A3 A3 A1 01 01 A1 01 01
        .byte   $A6,$06,$06,$06,$06,$06,$A6,$06                ; D538 A6 06 06 06 06 06 A6 06
        .byte   $A6,$06,$A6,$01,$02,$01,$01,$01                ; D540 A6 06 A6 01 02 01 01 01
        .byte   $AC,$0C,$0C,$AC,$AC,$AC,$AC,$0C                ; D548 AC 0C 0C AC AC AC AC 0C
        .byte   $02,$02,$02,$02,$01,$01,$01,$01                ; D550 02 02 02 02 01 01 01 01
        .byte   $AC,$AC,$AC,$AC,$06,$AC,$06,$AC                ; D558 AC AC AC AC 06 AC 06 AC
        .byte   $06,$AC,$01,$01,$01,$01,$01,$01                ; D560 06 AC 01 01 01 01 01 01
        .byte   $AC,$AC,$AC,$AC,$0C,$0C,$AC,$AC                ; D568 AC AC AC AC 0C 0C AC AC
        .byte   $A5,$01,$01,$01,$01,$01,$01,$01                ; D570 A5 01 01 01 01 01 01 01
        .byte   $AC,$06,$AC,$06,$AC,$06,$AC,$06                ; D578 AC 06 AC 06 AC 06 AC 06
        .byte   $AC,$0C,$06,$02,$01,$01,$01,$01                ; D580 AC 0C 06 02 01 01 01 01
        .byte   $AC,$AC,$AC,$AC,$0C,$0C,$AC,$AC                ; D588 AC AC AC AC 0C 0C AC AC
        .byte   $A5,$01,$01,$01,$01,$01,$01,$01                ; D590 A5 01 01 01 01 01 01 01
        .byte   $AC,$0C,$0C,$AC,$AC,$AC,$AC,$06                ; D598 AC 0C 0C AC AC AC AC 06
        .byte   $AB,$01,$01,$01,$01,$01,$01,$01                ; D5A0 AB 01 01 01 01 01 01 01
        .byte   $AC,$06,$AC,$06,$AC,$0C,$0C,$AC                ; D5A8 AC 06 AC 06 AC 0C 0C AC
        .byte   $AC,$A6,$01,$01,$01,$01,$01,$01                ; D5B0 AC A6 01 01 01 01 01 01
        .byte   $AC,$0C,$0C,$AC,$AC,$AC,$AC,$0C                ; D5B8 AC 0C 0C AC AC AC AC 0C
        .byte   $05,$01,$01,$01,$01,$01,$01,$01                ; D5C0 05 01 01 01 01 01 01 01
        .byte   $AC,$AC,$AC,$AC,$06,$AC,$06,$AC                ; D5C8 AC AC AC AC 06 AC 06 AC
        .byte   $06,$AC,$01,$01,$01,$01,$01,$01                ; D5D0 06 AC 01 01 01 01 01 01
        .byte   $AC,$06,$AC,$06,$AC,$0C,$0C,$0C                ; D5D8 AC 06 AC 06 AC 0C 0C 0C
        .byte   $0C,$06,$01,$01,$01,$01,$01,$01                ; D5E0 0C 06 01 01 01 01 01 01
        .byte   $08,$08,$08,$08,$08,$08,$08,$08                ; D5E8 08 08 08 08 08 08 08 08
        .byte   $08,$06,$05,$05,$05,$05,$05,$05                ; D5F0 08 06 05 05 05 05 05 05
        .byte   $A6,$A6,$A6,$A6,$A6,$A6,$A6,$A3                ; D5F8 A6 A6 A6 A6 A6 A6 A6 A3
        .byte   $02,$01,$A1,$01,$01,$01,$01,$01                ; D600 02 01 A1 01 01 01 01 01
LD608:
        .byte   $F9,$08,$F8,$03,$93,$21,$F7,$1E                ; D608 F9 08 F8 03 93 21 F7 1E
        .byte   $00,$21,$00,$20,$00,$21,$00,$20                ; D610 00 21 00 20 00 21 00 20
        .byte   $F7,$1E,$00,$21,$00,$20,$00,$21                ; D618 F7 1E 00 21 00 20 00 21
        .byte   $00,$20,$F7,$1E,$00,$21,$00,$20                ; D620 00 20 F7 1E 00 21 00 20
        .byte   $00,$21,$00,$20,$00,$21,$00,$21                ; D628 00 21 00 20 00 21 00 21
        .byte   $00,$21,$00,$1B,$00,$21,$00,$21                ; D630 00 21 00 1B 00 21 00 21
        .byte   $F7,$1E,$00,$21,$00,$20,$00,$21                ; D638 F7 1E 00 21 00 20 00 21
        .byte   $00,$20,$F7,$1E,$00,$21,$00,$20                ; D640 00 20 F7 1E 00 21 00 20
        .byte   $00,$21,$00,$20,$F7,$1E,$00,$21                ; D648 00 21 00 20 F7 1E 00 21
        .byte   $00,$20,$00,$21,$00,$20,$00,$21                ; D650 00 20 00 21 00 20 00 21
        .byte   $00,$21,$00,$21,$00,$1B,$00,$21                ; D658 00 21 00 21 00 1B 00 21
        .byte   $00,$21,$F7,$1E,$00,$21,$00,$20                ; D660 00 21 F7 1E 00 21 00 20
        .byte   $00,$21,$00,$20,$F7,$1E,$00,$21                ; D668 00 21 00 20 F7 1E 00 21
        .byte   $00,$20,$00,$21,$00,$20,$F7,$1E                ; D670 00 20 00 21 00 20 F7 1E
        .byte   $00,$21,$00,$20,$00,$21,$00,$20                ; D678 00 21 00 20 00 21 00 20
        .byte   $00,$21,$00,$21,$00,$21,$00,$1B                ; D680 00 21 00 21 00 21 00 1B
        .byte   $00,$21,$00,$21,$F7,$1E,$00,$21                ; D688 00 21 00 21 F7 1E 00 21
        .byte   $00,$20,$00,$21,$00,$20,$F7,$1E                ; D690 00 20 00 21 00 20 F7 1E
        .byte   $00,$21,$00,$20,$00,$21,$F8,$05                ; D698 00 21 00 20 00 21 F8 05
        .byte   $00,$F7,$24,$31,$9B,$31,$99,$33                ; D6A0 00 F7 24 31 9B 31 99 33
        .byte   $96,$00,$99,$34,$96,$00,$99,$38                ; D6A8 96 00 99 34 96 00 99 38
        .byte   $96,$00,$36,$93,$00,$96,$34,$93                ; D6B0 96 00 36 93 00 96 34 93
        .byte   $00,$96,$32,$93,$00,$96,$31,$93                ; D6B8 00 96 32 93 00 96 31 93
        .byte   $00,$96,$32,$93,$00,$96,$34,$93                ; D6C0 00 96 32 93 00 96 34 93
        .byte   $00,$9C,$35,$99,$00,$34,$96,$00                ; D6C8 00 9C 35 99 00 34 96 00
        .byte   $99,$30,$96,$00,$99,$33,$96,$00                ; D6D0 99 30 96 00 99 33 96 00
        .byte   $98,$32,$30,$96,$2A,$33,$35,$33                ; D6D8 98 32 30 96 2A 33 35 33
        .byte   $35,$40,$F7,$6C,$3B,$9B,$3B,$F7                ; D6E0 35 40 F7 6C 3B 9B 3B F7
        .byte   $48,$2B,$9E,$2B,$F7,$24,$2A,$F7                ; D6E8 48 2B 9E 2B F7 24 2A F7
        .byte   $6C,$2A,$F7,$6C,$28,$9B,$28,$F7                ; D6F0 6C 2A F7 6C 28 9B 28 F7
        .byte   $48,$31,$F7,$6C,$31,$F8,$03,$FE                ; D6F8 48 31 F7 6C 31 F8 03 FE
        .byte   $08,$D6                                        ; D700 08 D6
LD702:
        .byte   $F9,$08,$F8,$03,$93,$13,$F7,$1E                ; D702 F9 08 F8 03 93 13 F7 1E
        .byte   $00,$13,$00,$13,$00,$13,$00,$13                ; D70A 00 13 00 13 00 13 00 13
        .byte   $F7,$1E,$00,$13,$00,$13,$00,$13                ; D712 F7 1E 00 13 00 13 00 13
        .byte   $00,$14,$F7,$1E,$00,$14,$00,$14                ; D71A 00 14 F7 1E 00 14 00 14
        .byte   $00,$14,$00,$14,$96,$00,$93,$14                ; D722 00 14 00 14 96 00 93 14
        .byte   $96,$00,$93,$14,$96,$00,$93,$14                ; D72A 96 00 93 14 96 00 93 14
        .byte   $96,$00,$93,$13,$F7,$1E,$00,$13                ; D732 96 00 93 13 F7 1E 00 13
        .byte   $00,$13,$00,$13,$00,$13,$F7,$1E                ; D73A 00 13 00 13 00 13 F7 1E
        .byte   $00,$13,$00,$13,$00,$13,$00,$14                ; D742 00 13 00 13 00 13 00 14
        .byte   $F7,$1E,$00,$14,$00,$14,$00,$14                ; D74A F7 1E 00 14 00 14 00 14
        .byte   $00,$14,$96,$00,$93,$14,$96,$00                ; D752 00 14 96 00 93 14 96 00
        .byte   $93,$14,$96,$00,$93,$14,$96,$00                ; D75A 93 14 96 00 93 14 96 00
        .byte   $93,$13,$F7,$1E,$00,$13,$00,$13                ; D762 93 13 F7 1E 00 13 00 13
        .byte   $00,$13,$00,$13,$F7,$1E,$00,$13                ; D76A 00 13 00 13 F7 1E 00 13
        .byte   $00,$13,$00,$13,$00,$14,$F7,$1E                ; D772 00 13 00 13 00 14 F7 1E
        .byte   $00,$14,$00,$14,$00,$14,$00,$14                ; D77A 00 14 00 14 00 14 00 14
        .byte   $96,$00,$93,$14,$96,$00,$93,$14                ; D782 96 00 93 14 96 00 93 14
        .byte   $96,$00,$93,$14,$96,$00,$93,$13                ; D78A 96 00 93 14 96 00 93 13
        .byte   $F7,$1E,$00,$13,$00,$13,$00,$13                ; D792 F7 1E 00 13 00 13 00 13
        .byte   $00,$13,$F7,$1E,$00,$13,$00,$13                ; D79A 00 13 F7 1E 00 13 00 13
        .byte   $00,$13,$00,$14,$F7,$1E,$00,$14                ; D7A2 00 13 00 14 F7 1E 00 14
        .byte   $00,$14,$00,$14,$00,$14,$96,$00                ; D7AA 00 14 00 14 00 14 96 00
        .byte   $93,$14,$96,$00,$93,$14,$96,$00                ; D7B2 93 14 96 00 93 14 96 00
        .byte   $93,$14,$96,$00,$93,$12,$F7,$1E                ; D7BA 93 14 96 00 93 12 F7 1E
        .byte   $00,$12,$00,$12,$00,$12,$00,$12                ; D7C2 00 12 00 12 00 12 00 12
        .byte   $F7,$1E,$00,$12,$00,$12,$00,$12                ; D7CA F7 1E 00 12 00 12 00 12
        .byte   $00,$20,$F7,$1E,$00,$20,$00,$20                ; D7D2 00 20 F7 1E 00 20 00 20
        .byte   $00,$20,$00,$20,$96,$00,$93,$20                ; D7DA 00 20 00 20 96 00 93 20
        .byte   $96,$00,$93,$20,$96,$00,$93,$20                ; D7E2 96 00 93 20 96 00 93 20
        .byte   $96,$00,$93,$1A,$F7,$1E,$00,$1A                ; D7EA 96 00 93 1A F7 1E 00 1A
        .byte   $00,$1A,$00,$1A,$00,$1A,$F7,$1E                ; D7F2 00 1A 00 1A 00 1A F7 1E
        .byte   $00,$1A,$00,$1A,$00,$1A,$00,$19                ; D7FA 00 1A 00 1A 00 1A 00 19
        .byte   $F7,$1E,$00,$19,$00,$19,$00,$19                ; D802 F7 1E 00 19 00 19 00 19
        .byte   $00,$19,$96,$00,$93,$19,$96,$00                ; D80A 00 19 96 00 93 19 96 00
        .byte   $93,$19,$96,$00,$93,$19,$96,$00                ; D812 93 19 96 00 93 19 96 00
        .byte   $F7,$48,$22,$9E,$22,$F7,$24,$20                ; D81A F7 48 22 9E 22 F7 24 20
        .byte   $9B,$20,$9E,$17,$F7,$6C,$1A,$9B                ; D822 9B 20 9E 17 F7 6C 1A 9B
        .byte   $1A,$F7,$48,$19,$F7,$6C,$19,$FE                ; D82A 1A F7 48 19 F7 6C 19 FE
        .byte   $02,$D7                                        ; D832 02 D7
LD834:
        .byte   $F7,$3C,$28,$96,$23,$9E,$30,$9B                ; D834 F7 3C 28 96 23 9E 30 9B
        .byte   $2B,$28,$98,$24,$26,$24,$26,$F7                ; D83C 2B 28 98 24 26 24 26 F7
        .byte   $3C,$28,$96,$23,$9B,$30,$30,$24                ; D844 3C 28 96 23 9B 30 30 24
        .byte   $26,$98,$28,$2A,$2B,$31,$F7,$24                ; D84C 26 98 28 2A 2B 31 F7 24
        .byte   $28,$99,$28,$96,$23,$9E,$30,$9B                ; D854 28 99 28 96 23 9E 30 9B
        .byte   $2B,$28,$98,$24,$26,$24,$26,$F7                ; D85C 2B 28 98 24 26 24 26 F7
        .byte   $3C,$28,$96,$23,$9E,$30,$9B,$24                ; D864 3C 28 96 23 9E 30 9B 24
        .byte   $26,$98,$28,$2A,$2B,$31,$93,$2B                ; D86C 26 98 28 2A 2B 31 93 2B
        .byte   $F7,$1E,$00,$2B,$00,$2B,$00,$24                ; D874 F7 1E 00 2B 00 2B 00 24
        .byte   $00,$2B,$F7,$1E,$00,$24,$00,$24                ; D87C 00 2B F7 1E 00 24 00 24
        .byte   $00,$24,$00,$2A,$F7,$1E,$00,$2A                ; D884 00 24 00 2A F7 1E 00 2A
        .byte   $00,$25,$00,$25,$00,$2A,$96,$00                ; D88C 00 25 00 25 00 2A 96 00
        .byte   $93,$2A,$96,$00,$93,$2A,$96,$00                ; D894 93 2A 96 00 93 2A 96 00
        .byte   $93,$2A,$96,$00,$93,$28,$F7,$1E                ; D89C 93 2A 96 00 93 28 F7 1E
        .byte   $00,$23,$00,$23,$00,$23,$00,$28                ; D8A4 00 23 00 23 00 23 00 28
        .byte   $F7,$1E,$00,$23,$00,$23,$00,$23                ; D8AC F7 1E 00 23 00 23 00 23
        .byte   $00,$26,$F7,$1E,$00,$31,$00,$26                ; D8B4 00 26 F7 1E 00 31 00 26
        .byte   $00,$31,$00,$31,$96,$00,$93,$31                ; D8BC 00 31 00 31 96 00 93 31
        .byte   $96,$00,$93,$31,$96,$00,$93,$31                ; D8C4 96 00 93 31 96 00 93 31
        .byte   $96,$00,$9B,$38,$98,$36,$34,$32                ; D8CC 96 00 9B 38 98 36 34 32
        .byte   $31,$32,$34,$F7,$24,$35,$9B,$35                ; D8D4 31 32 34 F7 24 35 9B 35
        .byte   $34,$30,$33,$98,$32,$30,$96,$2A                ; D8DC 34 30 33 98 32 30 96 2A
        .byte   $33,$35,$33,$35,$40,$F7,$48,$3B                ; D8E4 33 35 33 35 40 F7 48 3B
        .byte   $F7,$6C,$3B,$FE,$34,$D8,$FF,$F2                ; D8EC F7 6C 3B FE 34 D8 FF F2
        .byte   $D8                                            ; D8F4 D8
LD8F5:
        .byte   $03,$04,$05,$04,$06,$07,$08,$09                ; D8F5 03 04 05 04 06 07 08 09
        .byte   $0A,$0B,$0C,$04,$06,$07,$08,$09                ; D8FD 0A 0B 0C 04 06 07 08 09
        .byte   $0D,$0E,$0E,$0E,$0F,$0F,$0F,$0F                ; D905 0D 0E 0E 0E 0F 0F 0F 0F
        .byte   $FF,$F5,$D8                                    ; D90D FF F5 D8
LD910:
        .byte   $B6,$06,$A6,$06,$B6,$06,$A6,$06                ; D910 B6 06 A6 06 B6 06 A6 06
        .byte   $B6,$06,$A6,$A6,$B6,$06,$A6,$06                ; D918 B6 06 A6 A6 B6 06 A6 06
        .byte   $B6,$06,$06,$06,$B6,$06,$06,$06                ; D920 B6 06 06 06 B6 06 06 06
        .byte   $B6,$06,$06,$06,$06,$06,$06,$06                ; D928 B6 06 06 06 06 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; D930 B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; D938 B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$A6,$06,$B6,$06,$A6,$06                ; D940 B6 06 A6 06 B6 06 A6 06
        .byte   $B6,$06,$06,$06,$B6,$06,$06,$06                ; D948 B6 06 06 06 B6 06 06 06
LD950:
        .byte   $F9,$08,$F8,$03,$9B,$20,$93,$22                ; D950 F9 08 F8 03 9B 20 93 22
        .byte   $00,$9B,$24,$93,$20,$00,$99,$24                ; D958 00 9B 24 93 20 00 99 24
        .byte   $93,$22,$00,$20,$00,$99,$22,$17                ; D960 93 22 00 20 00 99 22 17
        .byte   $9B,$22,$93,$24,$00,$9B,$25,$93                ; D968 9B 22 93 24 00 9B 25 93
        .byte   $22,$00,$99,$25,$93,$24,$00,$22                ; D970 22 00 99 25 93 24 00 22
        .byte   $00,$9C,$20,$99,$27,$30,$2B,$93                ; D978 00 9C 20 99 27 30 2B 93
        .byte   $30,$00,$2B,$00,$99,$29,$93,$27                ; D980 30 00 2B 00 99 29 93 27
        .byte   $00,$25,$00,$99,$10,$20,$93,$20                ; D988 00 25 00 99 10 20 93 20
        .byte   $00,$99,$29,$93,$25,$00,$9B,$27                ; D990 00 99 29 93 25 00 9B 27
        .byte   $93,$24,$00,$22,$00,$17,$00,$25                ; D998 93 24 00 22 00 17 00 25
        .byte   $00,$22,$00,$96,$20,$9B,$00,$99                ; D9A0 00 22 00 96 20 9B 00 99
        .byte   $2B,$2B,$93,$2B,$00,$30,$00,$2B                ; D9A8 2B 2B 93 2B 00 30 00 2B
        .byte   $00,$29,$00,$9C,$27,$96,$00,$93                ; D9B0 00 29 00 9C 27 96 00 93
        .byte   $24,$00,$25,$00,$27,$00,$99,$29                ; D9B8 24 00 25 00 27 00 99 29
        .byte   $29,$93,$29,$00,$27,$00,$25,$00                ; D9C0 29 93 29 00 27 00 25 00
        .byte   $24,$00,$F7,$3C,$20,$25,$00,$27                ; D9C8 24 00 F7 3C 20 25 00 27
        .byte   $00,$29,$00,$99,$2B,$2B,$93,$2B                ; D9D0 00 29 00 99 2B 2B 93 2B
        .byte   $00,$30,$00,$32,$00,$34,$00,$F7                ; D9D8 00 30 00 32 00 34 00 F7
        .byte   $3C,$30,$30,$00,$32,$00,$34,$00                ; D9E0 3C 30 30 00 32 00 34 00
        .byte   $99,$35,$35,$93,$35,$00,$39,$00                ; D9E8 99 35 35 93 35 00 39 00
        .byte   $37,$00,$35,$00,$9C,$37,$96,$3B                ; D9F0 37 00 35 00 9C 37 96 3B
        .byte   $00,$42,$00,$99,$27,$30,$2B,$93                ; D9F8 00 42 00 99 27 30 2B 93
        .byte   $30,$00,$2B,$00,$99,$29,$93,$27                ; DA00 30 00 2B 00 99 29 93 27
        .byte   $00,$25,$00,$99,$27,$20,$93,$20                ; DA08 00 25 00 99 27 20 93 20
        .byte   $00,$99,$29,$93,$25,$00,$9B,$27                ; DA10 00 99 29 93 25 00 9B 27
        .byte   $93,$24,$00,$22,$00,$17,$00,$24                ; DA18 93 24 00 22 00 17 00 24
        .byte   $00,$22,$00,$9C,$20,$FE,$50,$D9                ; DA20 00 22 00 9C 20 FE 50 D9
LDA28:
        .byte   $F9,$08,$F8,$03,$93,$20,$00,$27                ; DA28 F9 08 F8 03 93 20 00 27
        .byte   $00,$17,$00,$30,$00,$20,$00,$27                ; DA30 00 17 00 30 00 20 00 27
        .byte   $00,$17,$00,$30,$00,$96,$20,$93                ; DA38 00 17 00 30 00 96 20 93
        .byte   $27,$00,$96,$17,$93,$34,$00,$22                ; DA40 27 00 96 17 93 34 00 22
        .byte   $00,$2B,$00,$17,$00,$32,$00,$22                ; DA48 00 2B 00 17 00 32 00 22
        .byte   $00,$2B,$00,$96,$27,$93,$32,$00                ; DA50 00 2B 00 96 27 93 32 00
        .byte   $22,$00,$2B,$00,$96,$17,$93,$32                ; DA58 22 00 2B 00 96 17 93 32
        .byte   $00,$22,$00,$2B,$00,$17,$00,$32                ; DA60 00 22 00 2B 00 17 00 32
        .byte   $00,$20,$00,$30,$00,$96,$17,$93                ; DA68 00 20 00 30 00 96 17 93
        .byte   $27,$00,$20,$00,$30,$00,$96,$17                ; DA70 27 00 20 00 30 00 96 17
        .byte   $93,$27,$00,$20,$00,$2B,$00,$96                ; DA78 93 27 00 20 00 2B 00 96
        .byte   $17,$93,$27,$00,$96,$19,$93,$30                ; DA80 17 93 27 00 96 19 93 30
        .byte   $00,$96,$14,$93,$29,$00,$20,$00                ; DA88 00 96 14 93 29 00 20 00
        .byte   $30,$00,$96,$17,$93,$27,$00,$96                ; DA90 30 00 96 17 93 27 00 96
        .byte   $19,$93,$20,$00,$96,$14,$93,$29                ; DA98 19 93 20 00 96 14 93 29
        .byte   $00,$20,$00,$30,$00,$96,$17,$93                ; DAA0 00 20 00 30 00 96 17 93
        .byte   $27,$00,$99,$2B,$93,$27,$00,$25                ; DAA8 27 00 99 2B 93 27 00 25
        .byte   $00,$99,$24,$20,$93,$17,$98,$00                ; DAB0 00 99 24 20 93 17 98 00
        .byte   $99,$22,$17,$00,$24,$27,$20,$30                ; DAB8 99 22 17 00 24 27 20 30
        .byte   $25,$20,$25,$00,$20,$27,$19,$17                ; DAC0 25 20 25 00 20 27 19 17
        .byte   $93,$17,$00,$27,$00,$1B,$00,$2B                ; DAC8 93 17 00 27 00 1B 00 2B
        .byte   $00,$22,$00,$27,$00,$17,$00,$2B                ; DAD0 00 22 00 27 00 17 00 2B
        .byte   $00,$24,$00,$30,$00,$20,$00,$27                ; DAD8 00 24 00 30 00 20 00 27
        .byte   $00,$17,$00,$30,$00,$14,$00,$27                ; DAE0 00 17 00 30 00 14 00 27
        .byte   $00,$19,$00,$29,$00,$20,$00,$30                ; DAE8 00 19 00 29 00 20 00 30
        .byte   $00,$24,$00,$29,$00,$25,$00,$30                ; DAF0 00 24 00 29 00 25 00 30
        .byte   $00,$27,$00,$32,$00,$22,$00,$2B                ; DAF8 00 27 00 32 00 22 00 2B
        .byte   $00,$96,$1B,$00,$27,$00,$93,$20                ; DB00 00 96 1B 00 27 00 93 20
        .byte   $00,$30,$00,$96,$17,$93,$27,$00                ; DB08 00 30 00 96 17 93 27 00
        .byte   $20,$00,$2B,$00,$96,$17,$93,$27                ; DB10 20 00 2B 00 96 17 93 27
        .byte   $00,$96,$19,$93,$29,$00,$96,$14                ; DB18 00 96 19 93 29 00 96 14
        .byte   $93,$30,$00,$20,$00,$27,$00,$96                ; DB20 93 30 00 20 00 27 00 96
        .byte   $17,$93,$30,$00,$96,$19,$93,$29                ; DB28 17 93 30 00 96 19 93 29
        .byte   $00,$96,$14,$93,$30,$00,$20,$00                ; DB30 00 96 14 93 30 00 20 00
        .byte   $27,$00,$96,$17,$93,$30,$00,$99                ; DB38 27 00 96 17 93 30 00 99
        .byte   $2B,$93,$27,$00,$25,$00,$24,$98                ; DB40 2B 93 27 00 25 00 24 98
        .byte   $00,$93,$20,$98,$00,$FE,$28,$DA                ; DB48 00 93 20 98 00 FE 28 DA
LDB50:
        .byte   $9B,$34,$93,$35,$00,$9B,$37,$93                ; DB50 9B 34 93 35 00 9B 37 93
        .byte   $34,$00,$99,$37,$93,$35,$00,$34                ; DB58 34 00 99 37 93 35 00 34
        .byte   $00,$99,$35,$2B,$9B,$35,$93,$37                ; DB60 00 99 35 2B 9B 35 93 37
        .byte   $00,$9B,$39,$93,$35,$00,$99,$39                ; DB68 00 9B 39 93 35 00 99 39
        .byte   $93,$37,$00,$35,$00,$9C,$34,$99                ; DB70 93 37 00 35 00 9C 34 99
        .byte   $40,$44,$42,$93,$44,$00,$42,$00                ; DB78 40 44 42 93 44 00 42 00
        .byte   $99,$40,$93,$44,$00,$42,$00,$99                ; DB80 99 40 93 44 00 42 00 99
        .byte   $44,$F7,$18,$37,$93,$37,$00,$99                ; DB88 44 F7 18 37 93 37 00 99
        .byte   $45,$93,$42,$00,$9B,$44,$93,$47                ; DB90 45 93 42 00 9B 44 93 47
        .byte   $00,$45,$00,$3B,$00,$47,$00,$45                ; DB98 00 45 00 3B 00 47 00 45
        .byte   $00,$96,$44,$9B,$00,$9F,$34,$96                ; DBA0 00 96 44 9B 00 9F 34 96
        .byte   $37,$00,$37,$00,$93,$37,$00,$34                ; DBA8 37 00 37 00 93 37 00 34
        .byte   $00,$32,$00,$30,$00,$9F,$34,$96                ; DBB0 00 32 00 30 00 9F 34 96
        .byte   $30,$00,$99,$30,$93,$30,$00,$2B                ; DBB8 30 00 99 30 93 30 00 2B
        .byte   $00,$29,$00,$27,$00,$99,$1B,$1B                ; DBC0 00 29 00 27 00 99 1B 1B
        .byte   $93,$1B,$00,$20,$00,$22,$00,$96                ; DBC8 93 1B 00 20 00 22 00 96
        .byte   $24,$F7,$3C,$20,$93,$20,$00,$22                ; DBD0 24 F7 3C 20 93 20 00 22
        .byte   $00,$24,$00,$99,$25,$25,$93,$25                ; DBD8 00 24 00 99 25 25 93 25
        .byte   $00,$29,$00,$27,$00,$25,$00,$9C                ; DBE0 00 29 00 27 00 25 00 9C
        .byte   $27,$96,$2B,$00,$37,$00,$93,$57                ; DBE8 27 96 2B 00 37 00 93 57
        .byte   $00,$55,$00,$54,$00,$52,$00,$50                ; DBF0 00 55 00 54 00 52 00 50
        .byte   $00,$4B,$00,$49,$00,$47,$00,$57                ; DBF8 00 4B 00 49 00 47 00 57
        .byte   $00,$55,$00,$54,$00,$52,$00,$54                ; DC00 00 55 00 54 00 52 00 54
        .byte   $00,$55,$00,$57,$00,$59,$00,$5B                ; DC08 00 55 00 57 00 59 00 5B
        .byte   $00,$59,$00,$57,$00,$55,$00,$54                ; DC10 00 59 00 57 00 55 00 54
        .byte   $00,$52,$00,$50,$00,$4B,$00,$57                ; DC18 00 52 00 50 00 4B 00 57
        .byte   $57,$59,$00,$5A,$00,$5B,$00,$60                ; DC20 57 59 00 5A 00 5B 00 60
        .byte   $98,$00,$93,$30,$98,$00,$FE,$50                ; DC28 98 00 93 30 98 00 FE 50
        .byte   $DB,$FF,$31,$DC                                ; DC30 DB FF 31 DC
LDC34:
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; DC34 01 01 01 01 01 01 01 01
        .byte   $02,$03,$02,$03,$01,$01,$01,$01                ; DC3C 02 03 02 03 01 01 01 01
        .byte   $01,$01,$01,$04,$FF,$34,$DC                    ; DC44 01 01 01 04 FF 34 DC
LDC4B:
        .byte   $B6,$06,$A6,$06,$B6,$06,$A6,$06                ; DC4B B6 06 A6 06 B6 06 A6 06
        .byte   $B6,$06,$A6,$A6,$B6,$06,$A6,$06                ; DC53 B6 06 A6 A6 B6 06 A6 06
        .byte   $B6,$06,$06,$06,$B6,$06,$06,$06                ; DC5B B6 06 06 06 B6 06 06 06
        .byte   $B6,$06,$06,$06,$06,$06,$06,$06                ; DC63 B6 06 06 06 06 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; DC6B B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$06,$06,$A6,$06,$06,$06                ; DC73 B6 06 06 06 A6 06 06 06
        .byte   $B6,$06,$A6,$06,$B6,$06,$A6,$06                ; DC7B B6 06 A6 06 B6 06 A6 06
        .byte   $B6,$06,$06,$06,$B6,$06,$06,$06                ; DC83 B6 06 06 06 B6 06 06 06
LDC8B:
        .byte   $F9,$08,$F8,$01,$9B,$20,$93,$22                ; DC8B F9 08 F8 01 9B 20 93 22
        .byte   $00,$9B,$23,$93,$20,$00,$99,$23                ; DC93 00 9B 23 93 20 00 99 23
        .byte   $93,$22,$00,$20,$00,$99,$22,$17                ; DC9B 93 22 00 20 00 99 22 17
        .byte   $9B,$22,$93,$23,$00,$9B,$25,$93                ; DCA3 9B 22 93 23 00 9B 25 93
        .byte   $22,$00,$99,$25,$93,$23,$00,$22                ; DCAB 22 00 99 25 93 23 00 22
        .byte   $00,$9C,$20,$99,$27,$30,$2A,$93                ; DCB3 00 9C 20 99 27 30 2A 93
        .byte   $30,$00,$2A,$00,$99,$28,$93,$27                ; DCBB 30 00 2A 00 99 28 93 27
        .byte   $00,$25,$00,$99,$27,$20,$93,$20                ; DCC3 00 25 00 99 27 20 93 20
        .byte   $00,$99,$28,$93,$25,$00,$9B,$27                ; DCCB 00 99 28 93 25 00 9B 27
        .byte   $93,$23,$00,$22,$00,$17,$00,$23                ; DCD3 93 23 00 22 00 17 00 23
        .byte   $00,$22,$00,$20,$F7,$2A,$00,$99                ; DCDB 00 22 00 20 F7 2A 00 99
        .byte   $2A,$96,$2A,$00,$93,$2A,$00,$30                ; DCE3 2A 96 2A 00 93 2A 00 30
        .byte   $00,$2A,$00,$28,$00,$9C,$27,$96                ; DCEB 00 2A 00 28 00 9C 27 96
        .byte   $00,$93,$23,$00,$25,$00,$27,$00                ; DCF3 00 93 23 00 25 00 27 00
        .byte   $99,$28,$28,$93,$28,$00,$27,$00                ; DCFB 99 28 28 93 28 00 27 00
        .byte   $25,$00,$23,$00,$F7,$3C,$20,$25                ; DD03 25 00 23 00 F7 3C 20 25
        .byte   $00,$27,$00,$29,$00,$99,$2B,$2B                ; DD0B 00 27 00 29 00 99 2B 2B
        .byte   $93,$2B,$00,$30,$00,$32,$00,$35                ; DD13 93 2B 00 30 00 32 00 35
        .byte   $00,$F7,$3C,$33,$30,$00,$32,$00                ; DD1B 00 F7 3C 33 30 00 32 00
        .byte   $33,$00,$99,$35,$35,$93,$35,$00                ; DD23 33 00 99 35 35 93 35 00
        .byte   $38,$00,$37,$00,$35,$00,$9C,$37                ; DD2B 38 00 37 00 35 00 9C 37
        .byte   $96,$3B,$00,$42,$00,$99,$27,$40                ; DD33 96 3B 00 42 00 99 27 40
        .byte   $2A,$93,$30,$00,$2A,$00,$99,$28                ; DD3B 2A 93 30 00 2A 00 99 28
        .byte   $93,$27,$00,$25,$00,$99,$27,$20                ; DD43 93 27 00 25 00 99 27 20
        .byte   $93,$20,$00,$99,$28,$93,$25,$00                ; DD4B 93 20 00 99 28 93 25 00
        .byte   $9B,$27,$93,$23,$00,$22,$00,$17                ; DD53 9B 27 93 23 00 22 00 17
        .byte   $00,$23,$00,$22,$00,$20,$F7,$2A                ; DD5B 00 23 00 22 00 20 F7 2A
        .byte   $00,$FE,$8B,$DC                                ; DD63 00 FE 8B DC
LDD67:
        .byte   $F9,$08,$F8,$01,$93,$23,$00,$27                ; DD67 F9 08 F8 01 93 23 00 27
        .byte   $00,$17,$00,$23,$00,$20,$00,$30                ; DD6F 00 17 00 23 00 20 00 30
        .byte   $00,$17,$00,$27,$00,$20,$00,$23                ; DD77 00 17 00 27 00 20 00 23
        .byte   $00,$96,$30,$93,$20,$00,$22,$00                ; DD7F 00 96 30 93 20 00 22 00
        .byte   $2B,$00,$17,$00,$27,$00,$22,$00                ; DD87 2B 00 17 00 27 00 22 00
        .byte   $32,$00,$96,$17,$93,$27,$00,$22                ; DD8F 32 00 96 17 93 27 00 22
        .byte   $00,$2B,$00,$96,$17,$93,$32,$00                ; DD97 00 2B 00 96 17 93 32 00
        .byte   $22,$00,$32,$00,$17,$00,$32,$00                ; DD9F 22 00 32 00 17 00 32 00
        .byte   $20,$00,$23,$00,$96,$17,$93,$27                ; DDA7 20 00 23 00 96 17 93 27
        .byte   $00,$20,$00,$30,$00,$96,$17,$93                ; DDAF 00 20 00 30 00 96 17 93
        .byte   $27,$00,$20,$00,$2A,$00,$96,$17                ; DDB7 27 00 20 00 2A 00 96 17
        .byte   $93,$23,$00,$96,$18,$93,$28,$00                ; DDBF 93 23 00 96 18 93 28 00
        .byte   $96,$13,$93,$30,$00,$20,$00,$23                ; DDC7 96 13 93 30 00 20 00 23
        .byte   $00,$96,$17,$93,$30,$00,$96,$18                ; DDCF 00 96 17 93 30 00 96 18
        .byte   $93,$28,$00,$96,$13,$93,$30,$00                ; DDD7 93 28 00 96 13 93 30 00
        .byte   $20,$00,$27,$00,$96,$17,$93,$23                ; DDDF 20 00 27 00 96 17 93 23
        .byte   $00,$99,$2B,$93,$27,$00,$25,$00                ; DDE7 00 99 2B 93 27 00 25 00
        .byte   $99,$23,$20,$93,$1A,$98,$00,$99                ; DDEF 99 23 20 93 1A 98 00 99
        .byte   $15,$98,$1A,$F7,$1E,$00,$99,$20                ; DDF7 15 98 1A F7 1E 00 99 20
        .byte   $23,$17,$20,$18,$13,$18,$00,$20                ; DDFF 23 17 20 18 13 18 00 20
        .byte   $27,$18,$15,$93,$17,$00,$2B,$00                ; DE07 27 18 15 93 17 00 2B 00
        .byte   $1B,$00,$32,$00,$22,$00,$27,$00                ; DE0F 1B 00 32 00 22 00 27 00
        .byte   $17,$00,$2B,$00,$23,$00,$30,$00                ; DE17 17 00 2B 00 23 00 30 00
        .byte   $20,$00,$23,$00,$17,$00,$27,$00                ; DE1F 20 00 23 00 17 00 27 00
        .byte   $13,$00,$30,$00,$18,$00,$28,$00                ; DE27 13 00 30 00 18 00 28 00
        .byte   $20,$00,$35,$00,$23,$00,$30,$00                ; DE2F 20 00 35 00 23 00 30 00
        .byte   $25,$00,$28,$00,$27,$00,$2B,$00                ; DE37 25 00 28 00 27 00 2B 00
        .byte   $22,$00,$27,$00,$1B,$98,$00,$93                ; DE3F 22 00 27 00 1B 98 00 93
        .byte   $27,$98,$00,$93,$20,$00,$30,$00                ; DE47 27 98 00 93 20 00 30 00
        .byte   $96,$17,$93,$27,$00,$20,$00,$2A                ; DE4F 96 17 93 27 00 20 00 2A
        .byte   $00,$96,$17,$93,$27,$00,$96,$18                ; DE57 00 96 17 93 27 00 96 18
        .byte   $93,$28,$00,$96,$13,$93,$30,$00                ; DE5F 93 28 00 96 13 93 30 00
        .byte   $20,$00,$27,$00,$96,$17,$93,$30                ; DE67 20 00 27 00 96 17 93 30
        .byte   $00,$18,$00,$28,$00,$13,$00,$30                ; DE6F 00 18 00 28 00 13 00 30
        .byte   $00,$20,$00,$27,$00,$96,$17,$30                ; DE77 00 20 00 27 00 96 17 30
        .byte   $99,$2B,$93,$27,$00,$25,$00,$23                ; DE7F 99 2B 93 27 00 25 00 23
        .byte   $98,$00,$93,$20,$98,$00,$FE,$67                ; DE87 98 00 93 20 98 00 FE 67
        .byte   $DD                                            ; DE8F DD
LDE90:
        .byte   $9B,$33,$93,$35,$00,$9B,$37,$93                ; DE90 9B 33 93 35 00 9B 37 93
        .byte   $33,$00,$99,$37,$93,$35,$00,$33                ; DE98 33 00 99 37 93 35 00 33
        .byte   $00,$99,$35,$2B,$9B,$35,$93,$37                ; DEA0 00 99 35 2B 9B 35 93 37
        .byte   $00,$9B,$38,$93,$35,$00,$99,$38                ; DEA8 00 9B 38 93 35 00 99 38
        .byte   $93,$37,$00,$35,$00,$9C,$33,$99                ; DEB0 93 37 00 35 00 9C 33 99
        .byte   $3A,$43,$42,$93,$43,$00,$42,$00                ; DEB8 3A 43 42 93 43 00 42 00
        .byte   $99,$40,$93,$3A,$00,$38,$00,$99                ; DEC0 99 40 93 3A 00 38 00 99
        .byte   $3A,$33,$93,$33,$00,$99,$40,$93                ; DEC8 3A 33 93 33 00 99 40 93
        .byte   $38,$00,$9B,$3A,$93,$37,$00,$35                ; DED0 38 00 9B 3A 93 37 00 35
        .byte   $00,$2B,$00,$37,$00,$35,$00,$33                ; DED8 00 2B 00 37 00 35 00 33
        .byte   $F7,$2A,$00,$9F,$33,$96,$37,$00                ; DEE0 F7 2A 00 9F 33 96 37 00
        .byte   $37,$00,$93,$37,$00,$33,$00,$32                ; DEE8 37 00 93 37 00 33 00 32
        .byte   $00,$30,$00,$9F,$33,$96,$30,$00                ; DEF0 00 30 00 9F 33 96 30 00
        .byte   $99,$30,$93,$30,$00,$2A,$00,$28                ; DEF8 99 30 93 30 00 2A 00 28
        .byte   $00,$27,$00,$99,$1B,$1B,$93,$1B                ; DF00 00 27 00 99 1B 1B 93 1B
        .byte   $00,$20,$00,$22,$00,$25,$00,$F7                ; DF08 00 20 00 22 00 25 00 F7
        .byte   $3C,$23,$20,$00,$22,$00,$23,$00                ; DF10 3C 23 20 00 22 00 23 00
        .byte   $99,$25,$25,$93,$25,$00,$28,$00                ; DF18 99 25 25 93 25 00 28 00
        .byte   $27,$00,$25,$00,$9C,$27,$96,$32                ; DF20 27 00 25 00 9C 27 96 32
        .byte   $00,$47,$00,$93,$57,$00,$55,$00                ; DF28 00 47 00 93 57 00 55 00
        .byte   $53,$00,$52,$00,$50,$00,$4A,$00                ; DF30 53 00 52 00 50 00 4A 00
        .byte   $48,$00,$47,$00,$57,$00,$55,$00                ; DF38 48 00 47 00 57 00 55 00
        .byte   $53,$00,$52,$00,$53,$00,$55,$00                ; DF40 53 00 52 00 53 00 55 00
        .byte   $57,$00,$58,$00,$5A,$00,$58,$00                ; DF48 57 00 58 00 5A 00 58 00
        .byte   $57,$00,$55,$00,$53,$00,$52,$00                ; DF50 57 00 55 00 53 00 52 00
        .byte   $50,$00,$4A,$00,$57,$00,$58,$00                ; DF58 50 00 4A 00 57 00 58 00
        .byte   $59,$00,$5B,$00,$60,$98,$00,$93                ; DF60 59 00 5B 00 60 98 00 93
        .byte   $30,$98,$00,$FE,$90,$DE,$FF,$6E                ; DF68 30 98 00 FE 90 DE FF 6E
        .byte   $DF                                            ; DF70 DF
LDF71:
        .byte   $01,$01,$01,$01,$01,$01,$01,$01                ; DF71 01 01 01 01 01 01 01 01
        .byte   $02,$03,$02,$03,$01,$01,$01,$01                ; DF79 02 03 02 03 01 01 01 01
        .byte   $01,$01,$01,$04,$FF,$71,$DF,$00                ; DF81 01 01 01 04 FF 71 DF 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DF89 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$04,$00,$00,$00,$00                ; DF91 00 00 00 04 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DF99 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFA1 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$02,$00,$00,$00,$00                ; DFA9 00 00 00 02 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFB1 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFB9 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFC1 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFC9 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFD1 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$01,$00,$00                ; DFD9 00 00 00 00 00 01 00 00
        .byte   $00,$00,$00,$10,$00,$00,$00,$00                ; DFE1 00 00 00 10 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFE9 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; DFF1 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$20,$03,$A4,$01                    ; DFF9 00 00 00 20 03 A4 01
; ----------------------------------------------------------------------------
LE000:
        jmp     LE2AA                                          ; E000 4C AA E2

; ----------------------------------------------------------------------------
LE003:
        .addr   LE00D                                          ; E003 0D E0
        .addr   LE021                                          ; E005 21 E0
        .addr   LE035                                          ; E007 35 E0
        .addr   LE049                                          ; E009 49 E0
        .addr   LE05D                                          ; E00B 5D E0
LE00D:
        .addr   LE07B                                          ; E00D 7B E0
        .addr   LE083                                          ; E00F 83 E0
        .addr   LE08B                                          ; E011 8B E0
        .addr   LE096                                          ; E013 96 E0
        .addr   LE09D                                          ; E015 9D E0
        .addr   LE0A0                                          ; E017 A0 E0
        .addr   LE0AE                                          ; E019 AE E0
        .addr   LE0A3                                          ; E01B A3 E0
        .addr   LE071                                          ; E01D 71 E0
        .addr   LE076                                          ; E01F 76 E0
LE021:
        .addr   LE0C2                                          ; E021 C2 E0
        .addr   LE0C2                                          ; E023 C2 E0
        .addr   LE0C2                                          ; E025 C2 E0
        .addr   LE0C2                                          ; E027 C2 E0
        .addr   LE0C9                                          ; E029 C9 E0
        .addr   LE0C9                                          ; E02B C9 E0
        .addr   LE0C9                                          ; E02D C9 E0
        .addr   LE0C9                                          ; E02F C9 E0
        .addr   LE0B8                                          ; E031 B8 E0
        .addr   LE0BD                                          ; E033 BD E0
LE035:
        .addr   LE0E3                                          ; E035 E3 E0
        .addr   LE0E7                                          ; E037 E7 E0
        .addr   LE0EB                                          ; E039 EB E0
        .addr   LE0EF                                          ; E03B EF E0
        .addr   LE0E3                                          ; E03D E3 E0
        .addr   LE0E7                                          ; E03F E7 E0
        .addr   LE0EB                                          ; E041 EB E0
        .addr   LE0EF                                          ; E043 EF E0
        .addr   LE0D9                                          ; E045 D9 E0
        .addr   LE0D4                                          ; E047 D4 E0
LE049:
        .addr   LE0F3                                          ; E049 F3 E0
        .addr   LE0F6                                          ; E04B F6 E0
        .addr   LE0F9                                          ; E04D F9 E0
        .addr   LE0FC                                          ; E04F FC E0
        .addr   LE0FF                                          ; E051 FF E0
        .addr   LE102                                          ; E053 02 E1
        .addr   LE0F9                                          ; E055 F9 E0
        .addr   LE0FC                                          ; E057 FC E0
        .addr   LE0DE                                          ; E059 DE E0
        .addr   LE0D4                                          ; E05B D4 E0
LE05D:
        .addr   LE105                                          ; E05D 05 E1
        .addr   LE109                                          ; E05F 09 E1
        .addr   LE10D                                          ; E061 0D E1
        .addr   LE111                                          ; E063 11 E1
        .addr   LE105                                          ; E065 05 E1
        .addr   LE109                                          ; E067 09 E1
        .addr   LE10D                                          ; E069 0D E1
        .addr   LE111                                          ; E06B 11 E1
        .addr   LE0DE                                          ; E06D DE E0
        .addr   LE0D4                                          ; E06F D4 E0
; ----------------------------------------------------------------------------
LE071:
        .byte   $00,$01,$00,$02,$FF                            ; E071 00 01 00 02 FF
LE076:
        .byte   $16,$03,$03,$16,$FF                            ; E076 16 03 03 16 FF
LE07B:
        .byte   $16,$08,$0B,$0C,$0D,$16,$0B,$FF                ; E07B 16 08 0B 0C 0D 16 0B FF
LE083:
        .byte   $16,$0F,$10,$11,$12,$13,$14,$FF                ; E083 16 0F 10 11 12 13 14 FF
LE08B:
        .byte   $16,$08,$09,$0A,$09,$08,$17,$18                ; E08B 16 08 09 0A 09 08 17 18
        .byte   $17,$08,$FF                                    ; E093 17 08 FF
LE096:
        .byte   $16,$08,$0E,$08,$19,$08,$FF                    ; E096 16 08 0E 08 19 08 FF
LE09D:
        .byte   $16,$15,$FF                                    ; E09D 16 15 FF
LE0A0:
        .byte   $16,$1A,$FF                                    ; E0A0 16 1A FF
LE0A3:
        .byte   $16,$05,$06,$07,$06,$05,$06,$07                ; E0A3 16 05 06 07 06 05 06 07
        .byte   $06,$00,$FF                                    ; E0AB 06 00 FF
LE0AE:
        .byte   $16,$1B,$1C,$1D,$1C,$1B,$1C,$1D                ; E0AE 16 1B 1C 1D 1C 1B 1C 1D
        .byte   $1E,$FF                                        ; E0B6 1E FF
LE0B8:
        .byte   $04,$05,$06,$05,$FF                            ; E0B8 04 05 06 05 FF
LE0BD:
        .byte   $00,$10,$10,$00,$FF                            ; E0BD 00 10 10 00 FF
LE0C2:
        .byte   $00,$01,$02,$03,$12,$11,$FF                    ; E0C2 00 01 02 03 12 11 FF
LE0C9:
        .byte   $00,$07,$08,$09,$0A,$0B,$0C,$0D                ; E0C9 00 07 08 09 0A 0B 0C 0D
        .byte   $0E,$0F,$FF                                    ; E0D1 0E 0F FF
LE0D4:
        .byte   $04,$03,$03,$04,$FF                            ; E0D4 04 03 03 04 FF
LE0D9:
        .byte   $00,$01,$00,$02,$FF                            ; E0D9 00 01 00 02 FF
LE0DE:
        .byte   $00,$01,$02,$01,$FF                            ; E0DE 00 01 02 01 FF
LE0E3:
        .byte   $08,$06,$05,$FF                                ; E0E3 08 06 05 FF
LE0E7:
        .byte   $07,$08,$06,$FF                                ; E0E7 07 08 06 FF
LE0EB:
        .byte   $05,$07,$08,$FF                                ; E0EB 05 07 08 FF
LE0EF:
        .byte   $06,$05,$07,$FF                                ; E0EF 06 05 07 FF
LE0F3:
        .byte   $05,$06,$FF                                    ; E0F3 05 06 FF
LE0F6:
        .byte   $05,$07,$FF                                    ; E0F6 05 07 FF
LE0F9:
        .byte   $05,$08,$FF                                    ; E0F9 05 08 FF
LE0FC:
        .byte   $05,$09,$FF                                    ; E0FC 05 09 FF
LE0FF:
        .byte   $05,$0A,$FF                                    ; E0FF 05 0A FF
LE102:
        .byte   $05,$0B,$FF                                    ; E102 05 0B FF
LE105:
        .byte   $05,$06,$07,$FF                                ; E105 05 06 07 FF
LE109:
        .byte   $06,$05,$07,$FF                                ; E109 06 05 07 FF
LE10D:
        .byte   $07,$05,$06,$FF                                ; E10D 07 05 06 FF
LE111:
        .byte   $06,$07,$05,$FF                                ; E111 06 07 05 FF
; ----------------------------------------------------------------------------
LE115:
        .addr   LE11F                                          ; E115 1F E1
        .addr   LE1BA                                          ; E117 BA E1
        .addr   LE219                                          ; E119 19 E2
        .addr   LE246                                          ; E11B 46 E2
        .addr   LE282                                          ; E11D 82 E2
; ----------------------------------------------------------------------------
LE11F:
        .byte   $00,$35,$36,$3F,$40,$00,$37,$38                ; E11F 00 35 36 3F 40 00 37 38
        .byte   $41,$42,$00,$39,$3A,$43,$44,$00                ; E127 41 42 00 39 3A 43 44 00
        .byte   $3B,$3C,$45,$46,$00,$39,$3A,$4F                ; E12F 3B 3C 45 46 00 39 3A 4F
        .byte   $50,$00,$49,$4A,$51,$40,$00,$4B                ; E137 50 00 49 4A 51 40 00 4B
        .byte   $4C,$52,$53,$00,$4D,$4E,$54,$55                ; E13F 4C 52 53 00 4D 4E 54 55
        .byte   $00,$57,$58,$5D,$5E,$00,$59,$5A                ; E147 00 57 58 5D 5E 00 59 5A
        .byte   $5F,$60,$00,$5B,$5C,$61,$62,$00                ; E14F 5F 60 00 5B 5C 61 62 00
        .byte   $63,$64,$69,$6A,$00,$65,$66,$6B                ; E157 63 64 69 6A 00 65 66 6B
        .byte   $6C,$00,$67,$68,$6D,$6E,$00,$6F                ; E15F 6C 00 67 68 6D 6E 00 6F
        .byte   $70,$71,$72,$00,$73,$74,$7D,$7E                ; E167 70 71 72 00 73 74 7D 7E
        .byte   $00,$75,$76,$7F,$80,$00,$77,$78                ; E16F 00 75 76 7F 80 00 77 78
        .byte   $81,$82,$00,$79,$7A,$83,$84,$00                ; E177 81 82 00 79 7A 83 84 00
        .byte   $7B,$E6,$85,$86,$00,$E6,$7C,$87                ; E17F 7B E6 85 86 00 E6 7C 87
        .byte   $88,$00,$89,$8A,$8B,$8C,$00,$3D                ; E187 88 00 89 8A 8B 8C 00 3D
        .byte   $3E,$47,$48,$40,$5A,$59,$60,$5F                ; E18F 3E 47 48 40 5A 59 60 5F
        .byte   $40,$5C,$5B,$62,$61,$40,$70,$6F                ; E197 40 5C 5B 62 61 40 70 6F
        .byte   $72,$71,$40,$8A,$89,$8C,$8B,$40                ; E19F 72 71 40 8A 89 8C 8B 40
        .byte   $4A,$49,$40,$51,$40,$4C,$4B,$53                ; E1A7 4A 49 40 51 40 4C 4B 53
        .byte   $52,$40,$4E,$4D,$55,$54,$40,$36                ; E1AF 52 40 4E 4D 55 54 40 36
        .byte   $35,$40,$3F                                    ; E1B7 35 40 3F
LE1BA:
        .byte   $00,$01,$02,$1B,$1C,$00,$03,$04                ; E1BA 00 01 02 1B 1C 00 03 04
        .byte   $1D,$1C,$00,$05,$06,$1E,$1F,$00                ; E1C2 1D 1C 00 05 06 1E 1F 00
        .byte   $07,$08,$20,$21,$00,$26,$27,$2D                ; E1CA 07 08 20 21 00 26 27 2D
        .byte   $2E,$00,$03,$28,$2F,$30,$00,$29                ; E1D2 2E 00 03 28 2F 30 00 29
        .byte   $2A,$31,$32,$00,$09,$0A,$22,$1C                ; E1DA 2A 31 32 00 09 0A 22 1C
        .byte   $00,$0B,$0C,$23,$1C,$00,$0D,$0E                ; E1E2 00 0B 0C 23 1C 00 0D 0E
        .byte   $23,$1C,$00,$0F,$10,$23,$1C,$00                ; E1EA 23 1C 00 0F 10 23 1C 00
        .byte   $11,$12,$24,$25,$00,$13,$14,$23                ; E1F2 11 12 24 25 00 13 14 23
        .byte   $1C,$00,$15,$16,$23,$1C,$00,$17                ; E1FA 1C 00 15 16 23 1C 00 17
        .byte   $18,$23,$1C,$00,$19,$1A,$23,$1C                ; E202 18 23 1C 00 19 1A 23 1C
        .byte   $00,$2B,$2C,$33,$34,$40,$04,$03                ; E20A 00 2B 2C 33 34 40 04 03
        .byte   $1C,$1D,$40,$06,$05,$1F,$1E                    ; E212 1C 1D 40 06 05 1F 1E
LE219:
        .byte   $00,$8D,$8E,$9C,$9D,$00,$8F,$90                ; E219 00 8D 8E 9C 9D 00 8F 90
        .byte   $9E,$9F,$00,$8F,$90,$A0,$A1,$00                ; E221 9E 9F 00 8F 90 A0 A1 00
        .byte   $91,$92,$A2,$46,$00,$93,$94,$A2                ; E229 91 92 A2 46 00 93 94 A2
        .byte   $48,$00,$95,$96,$A3,$A4,$00,$97                ; E231 48 00 95 96 A3 A4 00 97
        .byte   $98,$A5,$A4,$00,$99,$96,$A6,$A7                ; E239 98 A5 A4 00 99 96 A6 A7
        .byte   $00,$9A,$9B,$A8,$A9                            ; E241 00 9A 9B A8 A9
LE246:
        .byte   $00,$AA,$AB,$3F,$BA,$00,$AC,$AD                ; E246 00 AA AB 3F BA 00 AC AD
        .byte   $41,$BB,$00,$AE,$AD,$BC,$BD,$00                ; E24E 41 BB 00 AE AD BC BD 00
        .byte   $AF,$B0,$BE,$BF,$00,$B1,$B2,$C0                ; E256 AF B0 BE BF 00 B1 B2 C0
        .byte   $C1,$00,$B3,$B4,$C2,$C3,$00,$B5                ; E25E C1 00 B3 B4 C2 C3 00 B5
        .byte   $B6,$C4,$C5,$00,$B3,$B7,$C2,$C6                ; E266 B6 C4 C5 00 B3 B7 C2 C6
        .byte   $00,$B3,$B8,$C2,$C7,$00,$B5,$B7                ; E26E 00 B3 B8 C2 C7 00 B5 B7
        .byte   $C4,$C6,$00,$B9,$B7,$C8,$C6,$00                ; E276 C4 C6 00 B9 B7 C8 C6 00
        .byte   $B9,$B4,$C8,$C3                                ; E27E B9 B4 C8 C3
LE282:
        .byte   $00,$C9,$CA,$D9,$DA,$00,$CB,$CC                ; E282 00 C9 CA D9 DA 00 CB CC
        .byte   $DB,$DC,$00,$CD,$CE,$DD,$DE,$00                ; E28A DB DC 00 CD CE DD DE 00
        .byte   $CF,$D0,$DF,$E0,$00,$D1,$D2,$E1                ; E292 CF D0 DF E0 00 D1 D2 E1
        .byte   $E2,$00,$D3,$D4,$E3,$E4,$00,$D5                ; E29A E2 00 D3 D4 E3 E4 00 D5
        .byte   $D6,$E5,$E4,$00,$D7,$D8,$E5,$E4                ; E2A2 D6 E5 E4 00 D7 D8 E5 E4
; ----------------------------------------------------------------------------
LE2AA:
        lda     #$08                                           ; E2AA A9 08
        sta     ppuPatternTables                               ; E2AC 85 3D
        lda     #$00                                           ; E2AE A9 00
        clc                                                    ; E2B0 18
        ldy     #$05                                           ; E2B1 A0 05
LE2B3:
        adc     $0596                                          ; E2B3 6D 96 05
        dey                                                    ; E2B6 88
        bne     LE2B3                                          ; E2B7 D0 FA
        tax                                                    ; E2B9 AA
        lda     #$00                                           ; E2BA A9 00
        tay                                                    ; E2BC A8
        clc                                                    ; E2BD 18
LE2BE:
        adc     LE349,x                                        ; E2BE 7D 49 E3
        sta     $A2,y                                          ; E2C1 99 A2 00
        inx                                                    ; E2C4 E8
        iny                                                    ; E2C5 C8
        cpy     #$05                                           ; E2C6 C0 05
        bcc     LE2BE                                          ; E2C8 90 F4
        sta     $A7                                            ; E2CA 85 A7
        jsr     LE4AA                                          ; E2CC 20 AA E4
        jsr     LFF21                                          ; E2CF 20 21 FF
        ldx     $0596                                          ; E2D2 AE 96 05
        lda     LE343,x                                        ; E2D5 BD 43 E3
        sta     $A0                                            ; E2D8 85 A0
LE2DA:
        ldx     #$00                                           ; E2DA A2 00
        stx     $AA                                            ; E2DC 86 AA
        stx     $A1                                            ; E2DE 86 A1
        stx     $A8                                            ; E2E0 86 A8
LE2E2:
        ldx     $A1                                            ; E2E2 A6 A1
        dec     $C1,x                                          ; E2E4 D6 C1
        bne     LE2F1                                          ; E2E6 D0 09
        jsr     LE60C                                          ; E2E8 20 0C E6
        jsr     LE5AB                                          ; E2EB 20 AB E5
        jsr     LE5C6                                          ; E2EE 20 C6 E5
LE2F1:
        ldx     $AA                                            ; E2F1 A6 AA
        inc     $A1                                            ; E2F3 E6 A1
        inc     $A8                                            ; E2F5 E6 A8
LE2F7:
        lda     $A1                                            ; E2F7 A5 A1
        cmp     $A2,x                                          ; E2F9 D5 A2
        bcc     LE2E2                                          ; E2FB 90 E5
        inx                                                    ; E2FD E8
        stx     $AA                                            ; E2FE 86 AA
        lda     #$00                                           ; E300 A9 00
        sta     $A8                                            ; E302 85 A8
        cpx     #$05                                           ; E304 E0 05
        bcc     LE2F7                                          ; E306 90 EF
        inc     $42                                            ; E308 E6 42
        jsr     LFF03                                          ; E30A 20 03 FF
        lda     $0612                                          ; E30D AD 12 06
        bne     LE31C                                          ; E310 D0 0A
        dec     $A0                                            ; E312 C6 A0
        beq     LE323                                          ; E314 F0 0D
        jsr     LFF21                                          ; E316 20 21 FF
        jmp     LE2DA                                          ; E319 4C DA E2

; ----------------------------------------------------------------------------
LE31C:
        lda     nmiWaitVar                                     ; E31C A5 3C
        bne     LE2DA                                          ; E31E D0 BA
        jsr     LFF1E                                          ; E320 20 1E FF
LE323:
        jsr     LE38B                                          ; E323 20 8B E3
        jsr     LE401                                          ; E326 20 01 E4
        lda     $0596                                          ; E329 AD 96 05
        cmp     #$05                                           ; E32C C9 05
        bcc     LE33D                                          ; E32E 90 0D
        lda     #$06                                           ; E330 A9 06
        jsr     LFF27                                          ; E332 20 27 FF
        jsr     LE79E                                          ; E335 20 9E E7
        lda     #$04                                           ; E338 A9 04
        jsr     LFF27                                          ; E33A 20 27 FF
LE33D:
        lda     #$02                                           ; E33D A9 02
        sta     SND_CHN                                        ; E33F 8D 15 40
        rts                                                    ; E342 60

; ----------------------------------------------------------------------------
LE343:
        .byte   $01,$01,$01,$01,$01,$02                        ; E343 01 01 01 01 01 02
LE349:
        .byte   $01,$01,$00,$01,$00,$01,$01,$01                ; E349 01 01 00 01 00 01 01 01
        .byte   $01,$00,$02,$01,$01,$01,$01,$03                ; E351 01 00 02 01 01 01 01 03
        .byte   $02,$01,$01,$01,$03,$03,$02,$01                ; E359 02 01 01 01 03 03 02 01
        .byte   $01,$04,$03,$02,$01,$01                        ; E361 01 04 03 02 01 01
LE367:
        .byte   $C0,$80,$D0,$D0,$D0                            ; E367 C0 80 D0 D0 D0
LE36C:
        .byte   $58,$00,$08,$08,$08                            ; E36C 58 00 08 08 08
LE371:
        .byte   $A8,$48,$48,$48,$48                            ; E371 A8 48 48 48 48
; ----------------------------------------------------------------------------
LE376:
        .addr   LE380                                          ; E376 80 E3
        .addr   LE384                                          ; E378 84 E3
        .addr   LE387                                          ; E37A 87 E3
        .addr   LE389                                          ; E37C 89 E3
        .addr   LE38A                                          ; E37E 8A E3
; ----------------------------------------------------------------------------
LE380:
        .byte   $72,$96,$84,$60                                ; E380 72 96 84 60
LE384:
        .byte   $23,$36,$10                                    ; E384 23 36 10
LE387:
        .byte   $20,$40                                        ; E387 20 40
LE389:
        .byte   $30                                            ; E389 30
LE38A:
        .byte   $10                                            ; E38A 10
; ----------------------------------------------------------------------------
LE38B:
        ldx     #$00                                           ; E38B A2 00
        stx     $AA                                            ; E38D 86 AA
        stx     $A8                                            ; E38F 86 A8
        stx     $A7                                            ; E391 86 A7
LE393:
        stx     $A1                                            ; E393 86 A1
        lda     #$12                                           ; E395 A9 12
        sta     $AB,x                                          ; E397 95 AB
        lda     #$00                                           ; E399 A9 00
        sta     $B6,x                                          ; E39B 95 B6
        jsr     LE60C                                          ; E39D 20 0C E6
        jsr     LE5C6                                          ; E3A0 20 C6 E5
        ldy     $AA                                            ; E3A3 A4 AA
        ldx     $A1                                            ; E3A5 A6 A1
        inx                                                    ; E3A7 E8
        inc     $A8                                            ; E3A8 E6 A8
LE3AA:
        txa                                                    ; E3AA 8A
        cmp     $A2,y                                          ; E3AB D9 A2 00
        bcc     LE393                                          ; E3AE 90 E3
        lda     #$00                                           ; E3B0 A9 00
        sta     $A8                                            ; E3B2 85 A8
        iny                                                    ; E3B4 C8
        sty     $AA                                            ; E3B5 84 AA
        cpy     #$05                                           ; E3B7 C0 05
        bcc     LE3AA                                          ; E3B9 90 EF
LE3BB:
        ldy     #$14                                           ; E3BB A0 14
        jsr     LFF09                                          ; E3BD 20 09 FF
        ldx     #$00                                           ; E3C0 A2 00
        stx     $AA                                            ; E3C2 86 AA
        stx     $A1                                            ; E3C4 86 A1
        stx     $A8                                            ; E3C6 86 A8
LE3C8:
        ldx     $A1                                            ; E3C8 A6 A1
        lda     $AB,x                                          ; E3CA B5 AB
        cmp     #$12                                           ; E3CC C9 12
        bcc     LE3E3                                          ; E3CE 90 13
        jsr     LE60C                                          ; E3D0 20 0C E6
        jsr     LE5AB                                          ; E3D3 20 AB E5
        jsr     LE5C6                                          ; E3D6 20 C6 E5
        ldx     $A1                                            ; E3D9 A6 A1
        lda     $AB,x                                          ; E3DB B5 AB
        cmp     #$12                                           ; E3DD C9 12
        bcs     LE3E3                                          ; E3DF B0 02
        inc     $A7                                            ; E3E1 E6 A7
LE3E3:
        ldx     $AA                                            ; E3E3 A6 AA
        inc     $A1                                            ; E3E5 E6 A1
        inc     $A8                                            ; E3E7 E6 A8
LE3E9:
        lda     $A1                                            ; E3E9 A5 A1
        cmp     $A2,x                                          ; E3EB D5 A2
        bcc     LE3C8                                          ; E3ED 90 D9
        inx                                                    ; E3EF E8
        stx     $AA                                            ; E3F0 86 AA
        lda     #$00                                           ; E3F2 A9 00
        sta     $A8                                            ; E3F4 85 A8
        cpx     #$05                                           ; E3F6 E0 05
        bcc     LE3E9                                          ; E3F8 90 EF
        lda     $A7                                            ; E3FA A5 A7
        cmp     $A6                                            ; E3FC C5 A6
        bcc     LE3BB                                          ; E3FE 90 BB
        rts                                                    ; E400 60

; ----------------------------------------------------------------------------
LE401:
        ldx     #$00                                           ; E401 A2 00
        stx     $AA                                            ; E403 86 AA
        stx     $A8                                            ; E405 86 A8
        stx     $A7                                            ; E407 86 A7
LE409:
        stx     $A1                                            ; E409 86 A1
        lda     #$10                                           ; E40B A9 10
        sta     $AB,x                                          ; E40D 95 AB
        lda     #$00                                           ; E40F A9 00
        sta     $B6,x                                          ; E411 95 B6
        jsr     LE60C                                          ; E413 20 0C E6
        jsr     LE5C6                                          ; E416 20 C6 E5
        ldy     $AA                                            ; E419 A4 AA
        ldx     $A1                                            ; E41B A6 A1
        inx                                                    ; E41D E8
        inc     $A8                                            ; E41E E6 A8
LE420:
        txa                                                    ; E420 8A
        cmp     $A2,y                                          ; E421 D9 A2 00
        bcc     LE409                                          ; E424 90 E3
        lda     #$00                                           ; E426 A9 00
        sta     $A8                                            ; E428 85 A8
        iny                                                    ; E42A C8
        sty     $AA                                            ; E42B 84 AA
        cpy     #$05                                           ; E42D C0 05
        bcc     LE420                                          ; E42F 90 EF
LE431:
        ldy     #$0A                                           ; E431 A0 0A
        jsr     LFF09                                          ; E433 20 09 FF
        ldx     #$00                                           ; E436 A2 00
        stx     $AA                                            ; E438 86 AA
        stx     $A1                                            ; E43A 86 A1
        stx     $A8                                            ; E43C 86 A8
LE43E:
        lda     $A1                                            ; E43E A5 A1
        asl     a                                              ; E440 0A
        asl     a                                              ; E441 0A
        asl     a                                              ; E442 0A
        asl     a                                              ; E443 0A
        tax                                                    ; E444 AA
        lda     oamStaging+83,x                                ; E445 BD 53 02
        ldy     $AA                                            ; E448 A4 AA
        cmp     #$F0                                           ; E44A C9 F0
        bcs     LE489                                          ; E44C B0 3B
        adc     #$04                                           ; E44E 69 04
        cmp     LE371,y                                        ; E450 D9 71 E3
        bcc     LE465                                          ; E453 90 10
        inc     $A7                                            ; E455 E6 A7
        lda     #$F0                                           ; E457 A9 F0
        sta     oamStaging+80,x                                ; E459 9D 50 02
        sta     oamStaging+84,x                                ; E45C 9D 54 02
        sta     oamStaging+88,x                                ; E45F 9D 58 02
        sta     oamStaging+92,x                                ; E462 9D 5C 02
LE465:
        sta     oamStaging+83,x                                ; E465 9D 53 02
        sta     oamStaging+91,x                                ; E468 9D 5B 02
        adc     #$08                                           ; E46B 69 08
        sta     oamStaging+87,x                                ; E46D 9D 57 02
        sta     oamStaging+95,x                                ; E470 9D 5F 02
        jsr     LE60C                                          ; E473 20 0C E6
        ldx     $A1                                            ; E476 A6 A1
        ldy     $B6,x                                          ; E478 B4 B6
        iny                                                    ; E47A C8
        lda     ($D9),y                                        ; E47B B1 D9
        bpl     LE481                                          ; E47D 10 02
        ldy     #$00                                           ; E47F A0 00
LE481:
        sty     $B6,x                                          ; E481 94 B6
        jsr     LE60C                                          ; E483 20 0C E6
        jsr     LE5C6                                          ; E486 20 C6 E5
LE489:
        ldx     $AA                                            ; E489 A6 AA
        inc     $A1                                            ; E48B E6 A1
        inc     $A8                                            ; E48D E6 A8
LE48F:
        lda     $A1                                            ; E48F A5 A1
        cmp     $A2,x                                          ; E491 D5 A2
        bcc     LE43E                                          ; E493 90 A9
        inx                                                    ; E495 E8
        stx     $AA                                            ; E496 86 AA
        lda     #$00                                           ; E498 A9 00
        sta     $A8                                            ; E49A 85 A8
        cpx     #$05                                           ; E49C E0 05
        bcc     LE48F                                          ; E49E 90 EF
        lda     $A7                                            ; E4A0 A5 A7
        cmp     $A6                                            ; E4A2 C5 A6
        bcc     LE4A7                                          ; E4A4 90 01
        rts                                                    ; E4A6 60

; ----------------------------------------------------------------------------
LE4A7:
        jmp     LE431                                          ; E4A7 4C 31 E4

; ----------------------------------------------------------------------------
LE4AA:
        ldx     #$00                                           ; E4AA A2 00
        stx     $A8                                            ; E4AC 86 A8
        stx     $AA                                            ; E4AE 86 AA
        stx     $A1                                            ; E4B0 86 A1
LE4B2:
        ldx     $A1                                            ; E4B2 A6 A1
        lda     #$10                                           ; E4B4 A9 10
        sta     $AB,x                                          ; E4B6 95 AB
        lda     #$00                                           ; E4B8 A9 00
        sta     $B6,x                                          ; E4BA 95 B6
        lda     $A1                                            ; E4BC A5 A1
        asl     a                                              ; E4BE 0A
        asl     a                                              ; E4BF 0A
        asl     a                                              ; E4C0 0A
        asl     a                                              ; E4C1 0A
        tax                                                    ; E4C2 AA
        ldy     $AA                                            ; E4C3 A4 AA
        lda     LE367,y                                        ; E4C5 B9 67 E3
        sta     oamStaging+80,x                                ; E4C8 9D 50 02
        sta     oamStaging+84,x                                ; E4CB 9D 54 02
        clc                                                    ; E4CE 18
        adc     #$08                                           ; E4CF 69 08
        sta     oamStaging+88,x                                ; E4D1 9D 58 02
        sta     oamStaging+92,x                                ; E4D4 9D 5C 02
        ldy     $AA                                            ; E4D7 A4 AA
        lda     LE36C,y                                        ; E4D9 B9 6C E3
        sta     oamStaging+83,x                                ; E4DC 9D 53 02
        sta     oamStaging+91,x                                ; E4DF 9D 5B 02
        clc                                                    ; E4E2 18
        adc     #$08                                           ; E4E3 69 08
        sta     oamStaging+87,x                                ; E4E5 9D 57 02
        sta     oamStaging+95,x                                ; E4E8 9D 5F 02
        jsr     LFF00                                          ; E4EB 20 00 FF
        lda     rngSeed                                        ; E4EE A5 56
        and     #$03                                           ; E4F0 29 03
        ora     #$20                                           ; E4F2 09 20
        sta     oamStaging+82,x                                ; E4F4 9D 52 02
        sta     oamStaging+86,x                                ; E4F7 9D 56 02
        sta     oamStaging+90,x                                ; E4FA 9D 5A 02
        sta     oamStaging+94,x                                ; E4FD 9D 5E 02
        jsr     LE60C                                          ; E500 20 0C E6
        jsr     LE5C6                                          ; E503 20 C6 E5
        ldx     $AA                                            ; E506 A6 AA
        inc     $A1                                            ; E508 E6 A1
        inc     $A8                                            ; E50A E6 A8
LE50C:
        lda     $A1                                            ; E50C A5 A1
        cmp     $A2,x                                          ; E50E D5 A2
        bcc     LE4B2                                          ; E510 90 A0
        inx                                                    ; E512 E8
        stx     $AA                                            ; E513 86 AA
        lda     #$00                                           ; E515 A9 00
        sta     $A8                                            ; E517 85 A8
        cpx     #$05                                           ; E519 E0 05
        bcc     LE50C                                          ; E51B 90 EF
LE51D:
        ldy     #$0A                                           ; E51D A0 0A
        jsr     LFF09                                          ; E51F 20 09 FF
        ldx     #$00                                           ; E522 A2 00
        stx     $AA                                            ; E524 86 AA
        stx     $A1                                            ; E526 86 A1
        stx     $A8                                            ; E528 86 A8
LE52A:
        ldx     $A1                                            ; E52A A6 A1
        lda     $AB,x                                          ; E52C B5 AB
        cmp     #$10                                           ; E52E C9 10
        bcc     LE57F                                          ; E530 90 4D
        jsr     LE60C                                          ; E532 20 0C E6
        ldx     $A1                                            ; E535 A6 A1
        ldy     $B6,x                                          ; E537 B4 B6
        iny                                                    ; E539 C8
        lda     ($D9),y                                        ; E53A B1 D9
        bpl     LE540                                          ; E53C 10 02
        ldy     #$00                                           ; E53E A0 00
LE540:
        tya                                                    ; E540 98
        sta     $B6,x                                          ; E541 95 B6
        txa                                                    ; E543 8A
        asl     a                                              ; E544 0A
        asl     a                                              ; E545 0A
        asl     a                                              ; E546 0A
        asl     a                                              ; E547 0A
        tax                                                    ; E548 AA
        lda     $AA                                            ; E549 A5 AA
        asl     a                                              ; E54B 0A
        tay                                                    ; E54C A8
        lda     LE376,y                                        ; E54D B9 76 E3
        sta     $18                                            ; E550 85 18
        lda     LE376+1,y                                      ; E552 B9 77 E3
        sta     $19                                            ; E555 85 19
        ldy     $A8                                            ; E557 A4 A8
        lda     oamStaging+83,x                                ; E559 BD 53 02
        cmp     ($18),y                                        ; E55C D1 18
        bcc     LE568                                          ; E55E 90 08
        jsr     LE59B                                          ; E560 20 9B E5
        dec     $A7                                            ; E563 C6 A7
        jmp     LE579                                          ; E565 4C 79 E5

; ----------------------------------------------------------------------------
LE568:
        clc                                                    ; E568 18
        adc     #$04                                           ; E569 69 04
        sta     oamStaging+83,x                                ; E56B 9D 53 02
        sta     oamStaging+91,x                                ; E56E 9D 5B 02
        adc     #$08                                           ; E571 69 08
        sta     oamStaging+87,x                                ; E573 9D 57 02
        sta     oamStaging+95,x                                ; E576 9D 5F 02
LE579:
        jsr     LE60C                                          ; E579 20 0C E6
        jsr     LE5C6                                          ; E57C 20 C6 E5
LE57F:
        ldx     $AA                                            ; E57F A6 AA
        inc     $A1                                            ; E581 E6 A1
        inc     $A8                                            ; E583 E6 A8
LE585:
        lda     $A1                                            ; E585 A5 A1
        cmp     $A2,x                                          ; E587 D5 A2
        bcc     LE52A                                          ; E589 90 9F
        inx                                                    ; E58B E8
        stx     $AA                                            ; E58C 86 AA
        lda     #$00                                           ; E58E A9 00
        sta     $A8                                            ; E590 85 A8
        cpx     #$05                                           ; E592 E0 05
        bcc     LE585                                          ; E594 90 EF
        lda     $A7                                            ; E596 A5 A7
        bne     LE51D                                          ; E598 D0 83
        rts                                                    ; E59A 60

; ----------------------------------------------------------------------------
LE59B:
        ldx     $A1                                            ; E59B A6 A1
        jsr     LFF00                                          ; E59D 20 00 FF
        lda     rngSeed+5                                      ; E5A0 A5 5B
        and     #$0E                                           ; E5A2 29 0E
        sta     $AB,x                                          ; E5A4 95 AB
        lda     #$00                                           ; E5A6 A9 00
        sta     $B6,x                                          ; E5A8 95 B6
        rts                                                    ; E5AA 60

; ----------------------------------------------------------------------------
LE5AB:
        ldx     $A1                                            ; E5AB A6 A1
        inc     $B6,x                                          ; E5AD F6 B6
        ldy     $B6,x                                          ; E5AF B4 B6
        lda     ($D9),y                                        ; E5B1 B1 D9
        bpl     LE5C2                                          ; E5B3 10 0D
        jsr     LFF00                                          ; E5B5 20 00 FF
        lda     rngSeed+6                                      ; E5B8 A5 5C
        and     #$0E                                           ; E5BA 29 0E
        sta     $AB,x                                          ; E5BC 95 AB
        lda     #$00                                           ; E5BE A9 00
        sta     $B6,x                                          ; E5C0 95 B6
LE5C2:
        jsr     LE60C                                          ; E5C2 20 0C E6
        rts                                                    ; E5C5 60

; ----------------------------------------------------------------------------
LE5C6:
        ldx     $A1                                            ; E5C6 A6 A1
        lda     #$0C                                           ; E5C8 A9 0C
        sta     $C1,x                                          ; E5CA 95 C1
        txa                                                    ; E5CC 8A
        asl     a                                              ; E5CD 0A
        asl     a                                              ; E5CE 0A
        asl     a                                              ; E5CF 0A
        asl     a                                              ; E5D0 0A
        tax                                                    ; E5D1 AA
        ldy     #$00                                           ; E5D2 A0 00
        lda     oamStaging+82,x                                ; E5D4 BD 52 02
        and     #$23                                           ; E5D7 29 23
        ora     ($DB),y                                        ; E5D9 11 DB
        sta     oamStaging+82,x                                ; E5DB 9D 52 02
        sta     oamStaging+86,x                                ; E5DE 9D 56 02
        sta     oamStaging+90,x                                ; E5E1 9D 5A 02
        sta     oamStaging+94,x                                ; E5E4 9D 5E 02
        iny                                                    ; E5E7 C8
        lda     ($DB),y                                        ; E5E8 B1 DB
        clc                                                    ; E5EA 18
        adc     #$1A                                           ; E5EB 69 1A
        sta     oamStaging+81,x                                ; E5ED 9D 51 02
        iny                                                    ; E5F0 C8
        lda     ($DB),y                                        ; E5F1 B1 DB
        clc                                                    ; E5F3 18
        adc     #$1A                                           ; E5F4 69 1A
        sta     oamStaging+85,x                                ; E5F6 9D 55 02
        iny                                                    ; E5F9 C8
        lda     ($DB),y                                        ; E5FA B1 DB
        clc                                                    ; E5FC 18
        adc     #$1A                                           ; E5FD 69 1A
        sta     oamStaging+89,x                                ; E5FF 9D 59 02
        iny                                                    ; E602 C8
        lda     ($DB),y                                        ; E603 B1 DB
        clc                                                    ; E605 18
        adc     #$1A                                           ; E606 69 1A
        sta     oamStaging+93,x                                ; E608 9D 5D 02
        rts                                                    ; E60B 60

; ----------------------------------------------------------------------------
LE60C:
        lda     $AA                                            ; E60C A5 AA
        asl     a                                              ; E60E 0A
        tax                                                    ; E60F AA
        lda     LE003,x                                        ; E610 BD 03 E0
        sta     $D7                                            ; E613 85 D7
        lda     LE003+1,x                                      ; E615 BD 04 E0
        sta     $D8                                            ; E618 85 D8
        ldx     $A1                                            ; E61A A6 A1
        ldy     $AB,x                                          ; E61C B4 AB
        lda     ($D7),y                                        ; E61E B1 D7
        sta     $D9                                            ; E620 85 D9
        iny                                                    ; E622 C8
        lda     ($D7),y                                        ; E623 B1 D7
        sta     $DA                                            ; E625 85 DA
        ldy     $B6,x                                          ; E627 B4 B6
        lda     $AA                                            ; E629 A5 AA
        asl     a                                              ; E62B 0A
        tax                                                    ; E62C AA
        lda     ($D9),y                                        ; E62D B1 D9
        asl     a                                              ; E62F 0A
        asl     a                                              ; E630 0A
        adc     ($D9),y                                        ; E631 71 D9
        adc     LE115,x                                        ; E633 7D 15 E1
        sta     $DB                                            ; E636 85 DB
        lda     #$00                                           ; E638 A9 00
        adc     LE115+1,x                                      ; E63A 7D 16 E1
        sta     $DC                                            ; E63D 85 DC
        rts                                                    ; E63F 60

; ----------------------------------------------------------------------------
LE640:
        .byte   $05,$05,$05,$05,$05,$05,$05,$05                ; E640 05 05 05 05 05 05 05 05
        .byte   $05,$05,$05,$05,$05,$05,$05,$05                ; E648 05 05 05 05 05 05 05 05
        .byte   $04,$04,$04,$04,$04,$04,$04,$04                ; E650 04 04 04 04 04 04 04 04
        .byte   $04,$04,$03,$03,$03,$03,$03,$03                ; E658 04 04 03 03 03 03 03 03
        .byte   $03,$03,$03,$03,$02,$02,$02,$02                ; E660 03 03 03 03 02 02 02 02
        .byte   $02,$02,$02,$02,$01,$01,$01,$01                ; E668 02 02 02 02 01 01 01 01
        .byte   $01,$01,$00,$00,$00,$00,$00,$80                ; E670 01 01 00 00 00 00 00 80
        .byte   $00,$00,$00,$00,$00,$FF,$FF,$FF                ; E678 00 00 00 00 00 FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE                ; E680 FF FF FF FF FF FF FF FE
        .byte   $FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE                ; E688 FE FE FE FE FE FE FE FE
        .byte   $FE,$81                                        ; E690 FE 81
LE692:
        .byte   $D7,$02,$21,$F8,$D7,$00,$20,$F0                ; E692 D7 02 21 F8 D7 00 20 F0
        .byte   $D7,$00,$20,$E8,$D7,$00,$20,$E0                ; E69A D7 00 20 E8 D7 00 20 E0
        .byte   $CF,$00,$20,$F8,$CF,$00,$20,$F0                ; E6A2 CF 00 20 F8 CF 00 20 F0
        .byte   $CF,$00,$20,$E8,$CF,$00,$20,$E0                ; E6AA CF 00 20 E8 CF 00 20 E0
        .byte   $C7,$00,$20,$F8,$C7,$00,$20,$F0                ; E6B2 C7 00 20 F8 C7 00 20 F0
        .byte   $C7,$00,$20,$E8,$C7,$00,$20,$E0                ; E6BA C7 00 20 E8 C7 00 20 E0
        .byte   $BF,$00,$20,$F8,$BF,$00,$20,$F0                ; E6C2 BF 00 20 F8 BF 00 20 F0
        .byte   $BF,$00,$20,$E8,$BF,$00,$20,$E0                ; E6CA BF 00 20 E8 BF 00 20 E0
        .byte   $D7,$00,$60,$00,$D7,$00,$60,$08                ; E6D2 D7 00 60 00 D7 00 60 08
        .byte   $D7,$00,$60,$10,$D7,$00,$60,$18                ; E6DA D7 00 60 10 D7 00 60 18
        .byte   $CF,$00,$60,$00,$CF,$00,$60,$08                ; E6E2 CF 00 60 00 CF 00 60 08
        .byte   $CF,$00,$60,$10,$CF,$00,$60,$18                ; E6EA CF 00 60 10 CF 00 60 18
        .byte   $C7,$00,$60,$00,$C7,$00,$60,$08                ; E6F2 C7 00 60 00 C7 00 60 08
        .byte   $C7,$00,$60,$10,$C7,$00,$60,$18                ; E6FA C7 00 60 10 C7 00 60 18
        .byte   $BF,$00,$60,$00,$BF,$00,$60,$08                ; E702 BF 00 60 00 BF 00 60 08
        .byte   $BF,$00,$60,$10,$BF,$00,$60,$18                ; E70A BF 00 60 10 BF 00 60 18
        .byte   $DF,$00,$E0,$00,$DF,$00,$E0,$08                ; E712 DF 00 E0 00 DF 00 E0 08
        .byte   $DF,$00,$E0,$10,$DF,$00,$E0,$18                ; E71A DF 00 E0 10 DF 00 E0 18
        .byte   $E7,$00,$E0,$00,$E7,$00,$E0,$08                ; E722 E7 00 E0 00 E7 00 E0 08
        .byte   $E7,$00,$E0,$10,$E7,$00,$E0,$18                ; E72A E7 00 E0 10 E7 00 E0 18
        .byte   $EF,$00,$E0,$00,$EF,$00,$E0,$08                ; E732 EF 00 E0 00 EF 00 E0 08
        .byte   $EF,$00,$E0,$10,$EF,$00,$E0,$18                ; E73A EF 00 E0 10 EF 00 E0 18
        .byte   $F7,$00,$E0,$00,$F7,$00,$E0,$08                ; E742 F7 00 E0 00 F7 00 E0 08
        .byte   $F7,$00,$E0,$10,$F7,$00,$E0,$18                ; E74A F7 00 E0 10 F7 00 E0 18
        .byte   $DF,$00,$A0,$F8,$DF,$00,$A0,$F0                ; E752 DF 00 A0 F8 DF 00 A0 F0
        .byte   $DF,$00,$A0,$E8,$DF,$00,$A0,$E0                ; E75A DF 00 A0 E8 DF 00 A0 E0
        .byte   $E7,$00,$A0,$F8,$E7,$00,$A0,$F0                ; E762 E7 00 A0 F8 E7 00 A0 F0
        .byte   $E7,$00,$A0,$E8,$E7,$00,$A0,$E0                ; E76A E7 00 A0 E8 E7 00 A0 E0
        .byte   $EF,$00,$A0,$F8,$EF,$00,$A0,$F0                ; E772 EF 00 A0 F8 EF 00 A0 F0
        .byte   $EF,$00,$A0,$E8,$EF,$00,$A0,$E0                ; E77A EF 00 A0 E8 EF 00 A0 E0
        .byte   $F7,$00,$A0,$F8,$F7,$00,$A0,$F0                ; E782 F7 00 A0 F8 F7 00 A0 F0
        .byte   $F7,$00,$A0,$E8,$F7,$00,$A0,$E0                ; E78A F7 00 A0 E8 F7 00 A0 E0
LE792:
        .byte   $96,$B6,$41,$C0                                ; E792 96 B6 41 C0
LE796:
        .byte   $0F,$00,$0E,$08                                ; E796 0F 00 0E 08
LE79A:
        .byte   $1F,$00,$0C,$28                                ; E79A 1F 00 0C 28
; ----------------------------------------------------------------------------
LE79E:
        lda     #$01                                           ; E79E A9 01
        sta     $A7                                            ; E7A0 85 A7
LE7A2:
        ldx     #$00                                           ; E7A2 A2 00
LE7A4:
        lda     LE692,x                                        ; E7A4 BD 92 E6
        sta     oamStaging,x                                   ; E7A7 9D 00 02
        inx                                                    ; E7AA E8
        bne     LE7A4                                          ; E7AB D0 F7
        lda     rngSeed+2                                      ; E7AD A5 58
        ora     #$80                                           ; E7AF 09 80
        sta     tmp14                                          ; E7B1 85 14
LE7B3:
        inx                                                    ; E7B3 E8
        inx                                                    ; E7B4 E8
        inx                                                    ; E7B5 E8
        lda     oamStaging,x                                   ; E7B6 BD 00 02
        clc                                                    ; E7B9 18
        adc     tmp14                                          ; E7BA 65 14
        sta     oamStaging,x                                   ; E7BC 9D 00 02
        inx                                                    ; E7BF E8
        bne     LE7B3                                          ; E7C0 D0 F1
        lda     rngSeed                                        ; E7C2 A5 56
        and     #$7F                                           ; E7C4 29 7F
        sta     $3F                                            ; E7C6 85 3F
LE7C8:
        jsr     LFF12                                          ; E7C8 20 12 FF
        txa                                                    ; E7CB 8A
        bne     LE84D                                          ; E7CC D0 7F
        lda     $3F                                            ; E7CE A5 3F
        bne     LE7C8                                          ; E7D0 D0 F6
        lda     #$01                                           ; E7D2 A9 01
        sta     SND_CHN                                        ; E7D4 8D 15 40
        ldx     #$03                                           ; E7D7 A2 03
LE7D9:
        lda     LE792,x                                        ; E7D9 BD 92 E7
        sta     SQ1_VOL,x                                      ; E7DC 9D 00 40
        dex                                                    ; E7DF CA
        bpl     LE7D9                                          ; E7E0 10 F7
        lda     #$01                                           ; E7E2 A9 01
        sta     SND_CHN                                        ; E7E4 8D 15 40
        ldx     #$00                                           ; E7E7 A2 00
        stx     $A5                                            ; E7E9 86 A5
        stx     $A4                                            ; E7EB 86 A4
        inx                                                    ; E7ED E8
        stx     $A0                                            ; E7EE 86 A0
LE7F0:
        ldx     $A4                                            ; E7F0 A6 A4
        lda     LE640,x                                        ; E7F2 BD 40 E6
        bmi     LE806                                          ; E7F5 30 0F
        jsr     LE997                                          ; E7F7 20 97 E9
        inc     $42                                            ; E7FA E6 42
        jsr     LFF03                                          ; E7FC 20 03 FF
        lda     nmiWaitVar                                     ; E7FF A5 3C
        beq     LE84D                                          ; E801 F0 4A
        jmp     LE7F0                                          ; E803 4C F0 E7

; ----------------------------------------------------------------------------
LE806:
        lda     #$08                                           ; E806 A9 08
        sta     SND_CHN                                        ; E808 8D 15 40
        ldx     #$03                                           ; E80B A2 03
LE80D:
        lda     LE796,x                                        ; E80D BD 96 E7
        sta     NOISE_VOL,x                                    ; E810 9D 0C 40
        dex                                                    ; E813 CA
        bpl     LE80D                                          ; E814 10 F7
        lda     #$08                                           ; E816 A9 08
        sta     SND_CHN                                        ; E818 8D 15 40
        lda     #$20                                           ; E81B A9 20
        ldx     #$0F                                           ; E81D A2 0F
LE81F:
        sta     $04AA,x                                        ; E81F 9D AA 04
        dex                                                    ; E822 CA
        bpl     LE81F                                          ; E823 10 FA
        lda     #$2A                                           ; E825 A9 2A
        jsr     LFF0C                                          ; E827 20 0C FF
        lda     #$24                                           ; E82A A9 24
        jsr     LFF0C                                          ; E82C 20 0C FF
        lda     #$0F                                           ; E82F A9 0F
        tax                                                    ; E831 AA
LE832:
        sta     $04AA,x                                        ; E832 9D AA 04
        dex                                                    ; E835 CA
        bpl     LE832                                          ; E836 10 FA
        jsr     LE964                                          ; E838 20 64 E9
        lda     #$2A                                           ; E83B A9 2A
        jsr     LFF0C                                          ; E83D 20 0C FF
        ldy     #$03                                           ; E840 A0 03
        jsr     LFF09                                          ; E842 20 09 FF
        ldy     #$00                                           ; E845 A0 00
        inc     $A4                                            ; E847 E6 A4
LE849:
        lda     nmiWaitVar                                     ; E849 A5 3C
        bne     LE850                                          ; E84B D0 03
LE84D:
        jmp     LE8F7                                          ; E84D 4C F7 E8

; ----------------------------------------------------------------------------
LE850:
        ldx     #$00                                           ; E850 A2 00
        lda     LE9C3,y                                        ; E852 B9 C3 E9
        bmi     LE896                                          ; E855 30 3F
LE857:
        beq     LE85C                                          ; E857 F0 03
        clc                                                    ; E859 18
        adc     #$00                                           ; E85A 69 00
LE85C:
        sta     oamStaging+1,x                                 ; E85C 9D 01 02
        sta     oamStaging+65,x                                ; E85F 9D 41 02
        sta     oamStaging+129,x                               ; E862 9D 81 02
        sta     oamStaging+193,x                               ; E865 9D C1 02
        inx                                                    ; E868 E8
        inx                                                    ; E869 E8
        inx                                                    ; E86A E8
        inx                                                    ; E86B E8
        iny                                                    ; E86C C8
        lda     LE9C3,y                                        ; E86D B9 C3 E9
        bpl     LE857                                          ; E870 10 E5
        lda     #$00                                           ; E872 A9 00
        dey                                                    ; E874 88
        cpx     #$40                                           ; E875 E0 40
        bcc     LE85C                                          ; E877 90 E3
        sty     $CC                                            ; E879 84 CC
        jsr     LE997                                          ; E87B 20 97 E9
        ldy     #$07                                           ; E87E A0 07
        sty     $3F                                            ; E880 84 3F
LE882:
        inc     $42                                            ; E882 E6 42
        jsr     LFF03                                          ; E884 20 03 FF
        lda     nmiWaitVar                                     ; E887 A5 3C
        beq     LE84D                                          ; E889 F0 C2
        lda     $3F                                            ; E88B A5 3F
        bne     LE882                                          ; E88D D0 F3
        ldy     $CC                                            ; E88F A4 CC
        iny                                                    ; E891 C8
        iny                                                    ; E892 C8
        jmp     LE849                                          ; E893 4C 49 E8

; ----------------------------------------------------------------------------
LE896:
        cmp     #$FF                                           ; E896 C9 FF
        beq     LE8E3                                          ; E898 F0 49
        iny                                                    ; E89A C8
        sty     $CC                                            ; E89B 84 CC
        cmp     #$FE                                           ; E89D C9 FE
        beq     LE8BC                                          ; E89F F0 1B
        lda     $A5                                            ; E8A1 A5 A5
        beq     LE849                                          ; E8A3 F0 A4
        and     #$0F                                           ; E8A5 29 0F
        eor     #$04                                           ; E8A7 49 04
        cmp     #$0D                                           ; E8A9 C9 0D
        bcc     LE8AF                                          ; E8AB 90 02
        eor     #$0C                                           ; E8AD 49 0C
LE8AF:
        jsr     LE96F                                          ; E8AF 20 6F E9
        lda     #$30                                           ; E8B2 A9 30
        jsr     LFF0C                                          ; E8B4 20 0C FF
        ldy     $CC                                            ; E8B7 A4 CC
        jmp     LE849                                          ; E8B9 4C 49 E8

; ----------------------------------------------------------------------------
LE8BC:
        lda     rngSeed+3                                      ; E8BC A5 59
        and     #$18                                           ; E8BE 29 18
        bne     LE849                                          ; E8C0 D0 87
        lda     $04AD                                          ; E8C2 AD AD 04
        sta     $A5                                            ; E8C5 85 A5
        ldx     #$10                                           ; E8C7 A2 10
        lda     #$0F                                           ; E8C9 A9 0F
LE8CB:
        sta     $04A9,x                                        ; E8CB 9D A9 04
        dex                                                    ; E8CE CA
        bne     LE8CB                                          ; E8CF D0 FA
        sta     $04A8                                          ; E8D1 8D A8 04
        lda     #$30                                           ; E8D4 A9 30
        jsr     LFF0C                                          ; E8D6 20 0C FF
        ldy     #$01                                           ; E8D9 A0 01
        jsr     LFF09                                          ; E8DB 20 09 FF
        ldy     $CC                                            ; E8DE A4 CC
        jmp     LE849                                          ; E8E0 4C 49 E8

; ----------------------------------------------------------------------------
LE8E3:
        dec     $A0                                            ; E8E3 C6 A0
        lda     nmiWaitVar                                     ; E8E5 A5 3C
        beq     LE8F7                                          ; E8E7 F0 0E
        jsr     LE902                                          ; E8E9 20 02 E9
        jsr     LEB1F                                          ; E8EC 20 1F EB
        lda     $0598                                          ; E8EF AD 98 05
        bne     LE8F7                                          ; E8F2 D0 03
        jmp     LE7A2                                          ; E8F4 4C A2 E7

; ----------------------------------------------------------------------------
LE8F7:
        lda     #$F0                                           ; E8F7 A9 F0
        ldx     #$00                                           ; E8F9 A2 00
LE8FB:
        sta     oamStaging,x                                   ; E8FB 9D 00 02
        inx                                                    ; E8FE E8
        bne     LE8FB                                          ; E8FF D0 FA
        rts                                                    ; E901 60

; ----------------------------------------------------------------------------
LE902:
        lda     #$30                                           ; E902 A9 30
        sta     $A2                                            ; E904 85 A2
        lda     #$20                                           ; E906 A9 20
        sta     $A3                                            ; E908 85 A3
LE90A:
        ldy     #$14                                           ; E90A A0 14
        sty     $3F                                            ; E90C 84 3F
LE90E:
        jsr     LFF00                                          ; E90E 20 00 FF
        lda     rngSeed+5                                      ; E911 A5 5B
        and     #$01                                           ; E913 29 01
        tay                                                    ; E915 A8
        lda     $04AD                                          ; E916 AD AD 04
        and     #$0F                                           ; E919 29 0F
        ora     $A2,y                                          ; E91B 19 A2 00
        sta     $04AD                                          ; E91E 8D AD 04
        sta     $04B1                                          ; E921 8D B1 04
        sta     $04B5                                          ; E924 8D B5 04
        sta     $04B8                                          ; E927 8D B8 04
        lda     $3F                                            ; E92A A5 3F
        and     #$07                                           ; E92C 29 07
        bne     LE933                                          ; E92E D0 03
        jsr     LE997                                          ; E930 20 97 E9
LE933:
        lda     $04AD                                          ; E933 AD AD 04
        and     #$0F                                           ; E936 29 0F
        ldy     $A3                                            ; E938 A4 A3
        cpy     #$20                                           ; E93A C0 20
        bcc     LE940                                          ; E93C 90 02
        ora     #$10                                           ; E93E 09 10
LE940:
        sta     $04A8                                          ; E940 8D A8 04
        lda     #$30                                           ; E943 A9 30
        jsr     LFF0C                                          ; E945 20 0C FF
        lda     $3F                                            ; E948 A5 3F
        bne     LE90E                                          ; E94A D0 C2
        lda     $A3                                            ; E94C A5 A3
        cmp     #$0F                                           ; E94E C9 0F
        beq     LE963                                          ; E950 F0 11
        sta     $A2                                            ; E952 85 A2
        sec                                                    ; E954 38
        sbc     #$10                                           ; E955 E9 10
        bpl     LE95F                                          ; E957 10 06
        lda     $A7                                            ; E959 A5 A7
        bne     LE963                                          ; E95B D0 06
        lda     #$0F                                           ; E95D A9 0F
LE95F:
        sta     $A3                                            ; E95F 85 A3
        bpl     LE90A                                          ; E961 10 A7
LE963:
        rts                                                    ; E963 60

; ----------------------------------------------------------------------------
LE964:
        jsr     LFF00                                          ; E964 20 00 FF
        lda     rngSeed+4                                      ; E967 A5 5A
        and     #$0F                                           ; E969 29 0F
        cmp     #$0D                                           ; E96B C9 0D
        bcs     LE964                                          ; E96D B0 F5
LE96F:
        ora     #$40                                           ; E96F 09 40
        sta     tmp15                                          ; E971 85 15
        ldx     #$03                                           ; E973 A2 03
LE975:
        lda     tmp15                                          ; E975 A5 15
        sec                                                    ; E977 38
        sbc     #$10                                           ; E978 E9 10
        sta     tmp15                                          ; E97A 85 15
        sta     $04AA,x                                        ; E97C 9D AA 04
        sta     $04AE,x                                        ; E97F 9D AE 04
        sta     $04B2,x                                        ; E982 9D B2 04
        sta     $04B6,x                                        ; E985 9D B6 04
        dex                                                    ; E988 CA
        bne     LE975                                          ; E989 D0 EA
        and     #$0F                                           ; E98B 29 0F
        ldx     rngSeed+3                                      ; E98D A6 59
        bmi     LE993                                          ; E98F 30 02
        ora     #$10                                           ; E991 09 10
LE993:
        sta     $04A8                                          ; E993 8D A8 04
        rts                                                    ; E996 60

; ----------------------------------------------------------------------------
LE997:
        ldy     $A4                                            ; E997 A4 A4
        lda     LE640,y                                        ; E999 B9 40 E6
        cmp     #$81                                           ; E99C C9 81
        beq     LE9BE                                          ; E99E F0 1E
        ldx     #$00                                           ; E9A0 A2 00
LE9A2:
        lda     oamStaging,x                                   ; E9A2 BD 00 02
        sec                                                    ; E9A5 38
        sbc     LE640,y                                        ; E9A6 F9 40 E6
        sta     oamStaging,x                                   ; E9A9 9D 00 02
        inx                                                    ; E9AC E8
        inx                                                    ; E9AD E8
        inx                                                    ; E9AE E8
        lda     oamStaging,x                                   ; E9AF BD 00 02
        sec                                                    ; E9B2 38
        sbc     $A0                                            ; E9B3 E5 A0
        sta     oamStaging,x                                   ; E9B5 9D 00 02
        inx                                                    ; E9B8 E8
        bne     LE9A2                                          ; E9B9 D0 E7
        inc     $A4                                            ; E9BB E6 A4
        txa                                                    ; E9BD 8A
LE9BE:
        rts                                                    ; E9BE 60

; ----------------------------------------------------------------------------
        .byte   $02,$FF,$03,$FF                                ; E9BF 02 FF 03 FF
LE9C3:
        .byte   $04,$FF,$06,$05,$00,$00,$01,$FF                ; E9C3 04 FF 06 05 00 00 01 FF
        .byte   $FE,$1C,$1B,$00,$00,$11,$10,$FF                ; E9CB FE 1C 1B 00 00 11 10 FF
        .byte   $FD,$1F,$1E,$1D,$00,$14,$13,$12                ; E9D3 FD 1F 1E 1D 00 14 13 12
        .byte   $00,$0A,$09,$FF,$23,$22,$21,$20                ; E9DB 00 0A 09 FF 23 22 21 20
        .byte   $17,$16,$15,$00,$0D,$0C,$0B,$00                ; E9E3 17 16 15 00 0D 0C 0B 00
        .byte   $07,$FF,$27,$26,$25,$24,$1A,$19                ; E9EB 07 FF 27 26 25 24 1A 19
        .byte   $18,$00,$0F,$0E,$0B,$00,$08,$FF                ; E9F3 18 00 0F 0E 0B 00 08 FF
        .byte   $32,$31,$30,$2F,$2E,$2D,$2C,$00                ; E9FB 32 31 30 2F 2E 2D 2C 00
        .byte   $2B,$2A,$29,$00,$28,$FF,$FF                    ; EA03 2B 2A 29 00 28 FF FF
LEA0A:
        .byte   $1B,$18,$04,$0F,$0D,$FE,$FC,$F2                ; EA0A 1B 18 04 0F 0D FE FC F2
        .byte   $EB,$F8,$ED,$F9,$06,$16,$12,$08                ; EA12 EB F8 ED F9 06 16 12 08
        .byte   $0F,$FC,$E8,$FC,$F3,$FE,$EF,$05                ; EA1A 0F FC E8 FC F3 FE EF 05
        .byte   $09,$0F,$0F,$18,$06,$02,$F4,$F4                ; EA22 09 0F 0F 18 06 02 F4 F4
        .byte   $EF,$E9                                        ; EA2A EF E9
LEA2C:
        .byte   $FE,$F4,$FD,$FD,$E9,$E6,$F2,$ED                ; EA2C FE F4 FD FD E9 E6 F2 ED
        .byte   $FE,$02,$0F,$16,$0A,$07,$15,$1A                ; EA34 FE 02 0F 16 0A 07 15 1A
        .byte   $F2,$0F,$08,$04,$0A,$1B,$15,$14                ; EA3C F2 0F 08 04 0A 1B 15 14
        .byte   $02,$04,$0F,$0D,$F7,$ED,$E9,$F7                ; EA44 02 04 0F 0D F7 ED E9 F7
        .byte   $00,$F4                                        ; EA4C 00 F4
LEA4E:
        .byte   $33,$37,$3A,$3E,$56,$5A,$5E,$37                ; EA4E 33 37 3A 3E 56 5A 5E 37
LEA56:
        .byte   $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0                ; EA56 C0 C0 C0 C0 C0 C0 C0 C0
LEA5E:
        .byte   $12,$12,$22,$22,$22,$12,$22,$22                ; EA5E 12 12 22 22 22 12 22 22
; ----------------------------------------------------------------------------
LEA66:
        lda     oamStaging                                     ; EA66 AD 00 02
        sta     $A1                                            ; EA69 85 A1
        lda     oamStaging+3                                   ; EA6B AD 03 02
        sta     $A0                                            ; EA6E 85 A0
        lda     rngSeed+4                                      ; EA70 A5 5A
        and     #$07                                           ; EA72 29 07
        tax                                                    ; EA74 AA
        lda     LEA4E,x                                        ; EA75 BD 4E EA
        sta     $A6                                            ; EA78 85 A6
        lda     LEA56,x                                        ; EA7A BD 56 EA
        sta     $A9                                            ; EA7D 85 A9
        lda     LEA5E,x                                        ; EA7F BD 5E EA
        sta     $A8                                            ; EA82 85 A8
        ldy     #$00                                           ; EA84 A0 00
        lda     #$F0                                           ; EA86 A9 F0
LEA88:
        sta     oamStaging,y                                   ; EA88 99 00 02
        iny                                                    ; EA8B C8
        bne     LEA88                                          ; EA8C D0 FA
LEA8E:
        jsr     LFF00                                          ; EA8E 20 00 FF
        tya                                                    ; EA91 98
        asl     a                                              ; EA92 0A
        asl     a                                              ; EA93 0A
        tax                                                    ; EA94 AA
        lda     LEA0A,y                                        ; EA95 B9 0A EA
        bmi     LEA9C                                          ; EA98 30 02
        eor     #$FF                                           ; EA9A 49 FF
LEA9C:
        adc     #$28                                           ; EA9C 69 28
        sta     $AA,y                                          ; EA9E 99 AA 00
        lda     LEA2C,y                                        ; EAA1 B9 2C EA
        clc                                                    ; EAA4 18
        adc     $A1                                            ; EAA5 65 A1
        adc     #$03                                           ; EAA7 69 03
        sta     oamStaging,x                                   ; EAA9 9D 00 02
        lda     #$32                                           ; EAAC A9 32
        sta     oamStaging+1,x                                 ; EAAE 9D 01 02
        lda     #$23                                           ; EAB1 A9 23
        sta     oamStaging+2,x                                 ; EAB3 9D 02 02
        lda     LEA0A,y                                        ; EAB6 B9 0A EA
        clc                                                    ; EAB9 18
        adc     $A0                                            ; EABA 65 A0
        adc     #$03                                           ; EABC 69 03
        sta     oamStaging+3,x                                 ; EABE 9D 03 02
        iny                                                    ; EAC1 C8
        cpy     #$22                                           ; EAC2 C0 22
        bcc     LEA8E                                          ; EAC4 90 C8
        lda     $04AD                                          ; EAC6 AD AD 04
        and     #$0F                                           ; EAC9 29 0F
        sta     tmp14                                          ; EACB 85 14
        sta     $04A8                                          ; EACD 8D A8 04
        ldy     #$00                                           ; EAD0 A0 00
LEAD2:
        lda     LEAE5,y                                        ; EAD2 B9 E5 EA
        ora     tmp14                                          ; EAD5 05 14
        sta     $04AA,y                                        ; EAD7 99 AA 04
        iny                                                    ; EADA C8
        cpy     #$10                                           ; EADB C0 10
        bcc     LEAD2                                          ; EADD 90 F3
        lda     #$30                                           ; EADF A9 30
        jsr     LFF0C                                          ; EAE1 20 0C FF
        rts                                                    ; EAE4 60

; ----------------------------------------------------------------------------
LEAE5:
        .byte   $0F,$10,$20,$30,$0F,$00,$10,$20                ; EAE5 0F 10 20 30 0F 00 10 20
        .byte   $0F,$0F,$00,$10,$0F,$0F,$0F,$00                ; EAED 0F 0F 00 10 0F 0F 0F 00
; ----------------------------------------------------------------------------
LEAF5:
        jsr     LFF00                                          ; EAF5 20 00 FF
        lda     rngSeed+4                                      ; EAF8 A5 5A
        and     $A9                                            ; EAFA 25 A9
        sta     tmp14                                          ; EAFC 85 14
        lda     oamStaging+2,x                                 ; EAFE BD 02 02
        and     #$3F                                           ; EB01 29 3F
        ora     tmp14                                          ; EB03 05 14
        sta     oamStaging+2,x                                 ; EB05 9D 02 02
        rts                                                    ; EB08 60

; ----------------------------------------------------------------------------
LEB09:
        inc     oamStaging+1,x                                 ; EB09 FE 01 02
        lda     oamStaging+1,x                                 ; EB0C BD 01 02
        sec                                                    ; EB0F 38
        sbc     #$04                                           ; EB10 E9 04
        cmp     $A6                                            ; EB12 C5 A6
        bcc     LEB1E                                          ; EB14 90 08
        jsr     LEAF5                                          ; EB16 20 F5 EA
        lda     $A6                                            ; EB19 A5 A6
        sta     oamStaging+1,x                                 ; EB1B 9D 01 02
LEB1E:
        rts                                                    ; EB1E 60

; ----------------------------------------------------------------------------
LEB1F:
        jsr     LEA66                                          ; EB1F 20 66 EA
        jsr     LEC24                                          ; EB22 20 24 EC
        lda     $0598                                          ; EB25 AD 98 05
        bne     LEB35                                          ; EB28 D0 0B
        jsr     LEB36                                          ; EB2A 20 36 EB
        lda     $0598                                          ; EB2D AD 98 05
        bne     LEB35                                          ; EB30 D0 03
        jsr     LEC94                                          ; EB32 20 94 EC
LEB35:
        rts                                                    ; EB35 60

; ----------------------------------------------------------------------------
LEB36:
        ldy     #$00                                           ; EB36 A0 00
        sty     $0598                                          ; EB38 8C 98 05
LEB3B:
        jsr     LEB9C                                          ; EB3B 20 9C EB
        jsr     LEB09                                          ; EB3E 20 09 EB
        iny                                                    ; EB41 C8
        cpy     $A8                                            ; EB42 C4 A8
        bcc     LEB3B                                          ; EB44 90 F5
        lda     $3F                                            ; EB46 A5 3F
        bne     LEB4E                                          ; EB48 D0 04
        lda     #$20                                           ; EB4A A9 20
        sta     $3F                                            ; EB4C 85 3F
LEB4E:
        jsr     LEBDE                                          ; EB4E 20 DE EB
        lda     oamStaging                                     ; EB51 AD 00 02
        cmp     #$50                                           ; EB54 C9 50
        bcs     LEB5F                                          ; EB56 B0 07
        lda     nmiWaitVar                                     ; EB58 A5 3C
        bne     LEB36                                          ; EB5A D0 DA
        inc     $0598                                          ; EB5C EE 98 05
LEB5F:
        rts                                                    ; EB5F 60

; ----------------------------------------------------------------------------
LEB60:
        ldx     #$03                                           ; EB60 A2 03
LEB62:
        lda     LE79A,x                                        ; EB62 BD 9A E7
        sta     NOISE_VOL,x                                    ; EB65 9D 0C 40
        dex                                                    ; EB68 CA
        bne     LEB62                                          ; EB69 D0 F7
        stx     tmp14                                          ; EB6B 86 14
LEB6D:
        lda     #$04                                           ; EB6D A9 04
        ldy     oamStaging,x                                   ; EB6F BC 00 02
        cpy     #$F0                                           ; EB72 C0 F0
        bcs     LEB7B                                          ; EB74 B0 05
        lda     oamStaging+2,x                                 ; EB76 BD 02 02
        and     #$03                                           ; EB79 29 03
LEB7B:
        eor     #$FF                                           ; EB7B 49 FF
        sec                                                    ; EB7D 38
        adc     tmp14                                          ; EB7E 65 14
        clc                                                    ; EB80 18
        adc     #$04                                           ; EB81 69 04
        sta     tmp14                                          ; EB83 85 14
        inx                                                    ; EB85 E8
        inx                                                    ; EB86 E8
        inx                                                    ; EB87 E8
        inx                                                    ; EB88 E8
        bne     LEB6D                                          ; EB89 D0 E2
        lda     tmp14                                          ; EB8B A5 14
        sta     $CD                                            ; EB8D 85 CD
        lsr     a                                              ; EB8F 4A
        cmp     #$0F                                           ; EB90 C9 0F
        bcc     LEB96                                          ; EB92 90 02
        lda     #$0F                                           ; EB94 A9 0F
LEB96:
        ora     #$10                                           ; EB96 09 10
        sta     NOISE_VOL                                      ; EB98 8D 0C 40
        rts                                                    ; EB9B 60

; ----------------------------------------------------------------------------
LEB9C:
        tya                                                    ; EB9C 98
        asl     a                                              ; EB9D 0A
        asl     a                                              ; EB9E 0A
        tax                                                    ; EB9F AA
        lda     $AA,y                                          ; EBA0 B9 AA 00
        beq     LEBCD                                          ; EBA3 F0 28
        sec                                                    ; EBA5 38
        sbc     #$01                                           ; EBA6 E9 01
        sta     $AA,y                                          ; EBA8 99 AA 00
        bne     LEBCD                                          ; EBAB D0 20
        lda     LEA0A,y                                        ; EBAD B9 0A EA
        bmi     LEBBC                                          ; EBB0 30 0A
        inc     oamStaging+3,x                                 ; EBB2 FE 03 02
        lsr     a                                              ; EBB5 4A
        lsr     a                                              ; EBB6 4A
        eor     #$FF                                           ; EBB7 49 FF
        jmp     LEBC3                                          ; EBB9 4C C3 EB

; ----------------------------------------------------------------------------
LEBBC:
        lsr     a                                              ; EBBC 4A
        lsr     a                                              ; EBBD 4A
        ora     #$C0                                           ; EBBE 09 C0
        dec     oamStaging+3,x                                 ; EBC0 DE 03 02
LEBC3:
        clc                                                    ; EBC3 18
        adc     #$01                                           ; EBC4 69 01
        beq     LEBCA                                          ; EBC6 F0 02
        adc     #$0A                                           ; EBC8 69 0A
LEBCA:
        sta     $AA,y                                          ; EBCA 99 AA 00
LEBCD:
        lda     $3F                                            ; EBCD A5 3F
        and     #$03                                           ; EBCF 29 03
        bne     LEBDD                                          ; EBD1 D0 0A
        lda     oamStaging,x                                   ; EBD3 BD 00 02
        cmp     #$F0                                           ; EBD6 C9 F0
        bcs     LEBDD                                          ; EBD8 B0 03
        inc     oamStaging,x                                   ; EBDA FE 00 02
LEBDD:
        rts                                                    ; EBDD 60

; ----------------------------------------------------------------------------
LEBDE:
        jsr     LFF00                                          ; EBDE 20 00 FF
        lda     rngSeed+5                                      ; EBE1 A5 5B
        bmi     LEC1E                                          ; EBE3 30 39
        jsr     LEB60                                          ; EBE5 20 60 EB
        lda     #$F0                                           ; EBE8 A9 F0
        ldy     $04AD                                          ; EBEA AC AD 04
        cpy     #$30                                           ; EBED C0 30
        bcs     LEBF3                                          ; EBEF B0 02
        lda     #$10                                           ; EBF1 A9 10
LEBF3:
        sta     tmp14                                          ; EBF3 85 14
        ldy     #$0F                                           ; EBF5 A0 0F
LEBF7:
        ldx     #$03                                           ; EBF7 A2 03
LEBF9:
        lda     $04AA,y                                        ; EBF9 B9 AA 04
        clc                                                    ; EBFC 18
        adc     tmp14                                          ; EBFD 65 14
        cmp     #$F0                                           ; EBFF C9 F0
        bcs     LEC06                                          ; EC01 B0 03
        sta     $04AA,y                                        ; EC03 99 AA 04
LEC06:
        dey                                                    ; EC06 88
        dex                                                    ; EC07 CA
        bne     LEBF9                                          ; EC08 D0 EF
        dey                                                    ; EC0A 88
        bpl     LEBF7                                          ; EC0B 10 EA
        lda     $04AD                                          ; EC0D AD AD 04
        and     #$0F                                           ; EC10 29 0F
        sta     tmp14                                          ; EC12 85 14
        lda     $CD                                            ; EC14 A5 CD
        lsr     a                                              ; EC16 4A
        and     #$10                                           ; EC17 29 10
        ora     tmp14                                          ; EC19 05 14
        sta     $04A8                                          ; EC1B 8D A8 04
LEC1E:
        lda     #$30                                           ; EC1E A9 30
        jsr     LFF0C                                          ; EC20 20 0C FF
        rts                                                    ; EC23 60

; ----------------------------------------------------------------------------
LEC24:
        lda     #$22                                           ; EC24 A9 22
        sta     $0598                                          ; EC26 8D 98 05
LEC29:
        ldy     #$00                                           ; EC29 A0 00
LEC2B:
        jsr     LEB9C                                          ; EC2B 20 9C EB
        lda     oamStaging+1,x                                 ; EC2E BD 01 02
        cmp     $A6                                            ; EC31 C5 A6
        bcc     LEC38                                          ; EC33 90 03
        jsr     LEB09                                          ; EC35 20 09 EB
LEC38:
        lda     oamStaging+2,x                                 ; EC38 BD 02 02
        and     #$03                                           ; EC3B 29 03
        beq     LEC7A                                          ; EC3D F0 3B
        lda     oamStaging,x                                   ; EC3F BD 00 02
        cmp     #$F0                                           ; EC42 C9 F0
        bcs     LEC7A                                          ; EC44 B0 34
        cmp     #$4C                                           ; EC46 C9 4C
        bcs     LEC53                                          ; EC48 B0 09
        jsr     LFF00                                          ; EC4A 20 00 FF
        lda     rngSeed+3                                      ; EC4D A5 59
        and     #$28                                           ; EC4F 29 28
        bne     LEC7A                                          ; EC51 D0 27
LEC53:
        cpy     $A8                                            ; EC53 C4 A8
        bcs     LEC72                                          ; EC55 B0 1B
        lda     $A6                                            ; EC57 A5 A6
        cmp     oamStaging+1,x                                 ; EC59 DD 01 02
        beq     LEC60                                          ; EC5C F0 02
        bcs     LEC6C                                          ; EC5E B0 0C
LEC60:
        dec     oamStaging+2,x                                 ; EC60 DE 02 02
        lda     oamStaging+2,x                                 ; EC63 BD 02 02
        and     #$03                                           ; EC66 29 03
        beq     LEC77                                          ; EC68 F0 0D
        bne     LEC7A                                          ; EC6A D0 0E
LEC6C:
        sta     oamStaging+1,x                                 ; EC6C 9D 01 02
        jmp     LEC7A                                          ; EC6F 4C 7A EC

; ----------------------------------------------------------------------------
LEC72:
        lda     #$F0                                           ; EC72 A9 F0
        sta     oamStaging,x                                   ; EC74 9D 00 02
LEC77:
        dec     $0598                                          ; EC77 CE 98 05
LEC7A:
        iny                                                    ; EC7A C8
        cpy     #$22                                           ; EC7B C0 22
        bcc     LEC2B                                          ; EC7D 90 AC
        lda     $3F                                            ; EC7F A5 3F
        bne     LEC87                                          ; EC81 D0 04
        lda     #$20                                           ; EC83 A9 20
        sta     $3F                                            ; EC85 85 3F
LEC87:
        jsr     LEBDE                                          ; EC87 20 DE EB
        lda     $0598                                          ; EC8A AD 98 05
        beq     LEC93                                          ; EC8D F0 04
        lda     nmiWaitVar                                     ; EC8F A5 3C
        bne     LEC29                                          ; EC91 D0 96
LEC93:
        rts                                                    ; EC93 60

; ----------------------------------------------------------------------------
LEC94:
        lda     $A8                                            ; EC94 A5 A8
        sta     $0598                                          ; EC96 8D 98 05
LEC99:
        ldy     #$00                                           ; EC99 A0 00
LEC9B:
        jsr     LEB9C                                          ; EC9B 20 9C EB
        lda     oamStaging+1,x                                 ; EC9E BD 01 02
        cmp     $A6                                            ; ECA1 C5 A6
        bcc     LECA8                                          ; ECA3 90 03
        jsr     LEB09                                          ; ECA5 20 09 EB
LECA8:
        lda     oamStaging,x                                   ; ECA8 BD 00 02
        cmp     #$60                                           ; ECAB C9 60
        bcs     LECC7                                          ; ECAD B0 18
        jsr     LFF00                                          ; ECAF 20 00 FF
        lda     rngSeed+3                                      ; ECB2 A5 59
        and     #$30                                           ; ECB4 29 30
        bne     LECDC                                          ; ECB6 D0 24
        lda     oamStaging+2,x                                 ; ECB8 BD 02 02
        and     #$03                                           ; ECBB 29 03
        cmp     #$03                                           ; ECBD C9 03
        beq     LECC7                                          ; ECBF F0 06
        inc     oamStaging+2,x                                 ; ECC1 FE 02 02
        jmp     LECDC                                          ; ECC4 4C DC EC

; ----------------------------------------------------------------------------
LECC7:
        lda     #$32                                           ; ECC7 A9 32
        cmp     oamStaging+1,x                                 ; ECC9 DD 01 02
        bne     LECD6                                          ; ECCC D0 08
        lda     #$F0                                           ; ECCE A9 F0
        sta     oamStaging,x                                   ; ECD0 9D 00 02
        jmp     LECDC                                          ; ECD3 4C DC EC

; ----------------------------------------------------------------------------
LECD6:
        sta     oamStaging+1,x                                 ; ECD6 9D 01 02
        dec     $0598                                          ; ECD9 CE 98 05
LECDC:
        iny                                                    ; ECDC C8
        cpy     $A8                                            ; ECDD C4 A8
        bcc     LEC9B                                          ; ECDF 90 BA
        lda     $3F                                            ; ECE1 A5 3F
        bne     LECE9                                          ; ECE3 D0 04
        lda     #$20                                           ; ECE5 A9 20
        sta     $3F                                            ; ECE7 85 3F
LECE9:
        jsr     LEBDE                                          ; ECE9 20 DE EB
        lda     $0598                                          ; ECEC AD 98 05
        beq     LECF7                                          ; ECEF F0 06
        lda     nmiWaitVar                                     ; ECF1 A5 3C
        bne     LEC99                                          ; ECF3 D0 A4
        beq     LED01                                          ; ECF5 F0 0A
LECF7:
        lda     #$0F                                           ; ECF7 A9 0F
        sta     $04A8                                          ; ECF9 8D A8 04
        lda     #$30                                           ; ECFC A9 30
        jsr     LFF0C                                          ; ECFE 20 0C FF
LED01:
        rts                                                    ; ED01 60

; ----------------------------------------------------------------------------
        .byte   $00,$00,$00,$00,$00,$04,$00,$00                ; ED02 00 00 00 00 00 04 00 00
        .byte   $00,$00,$80,$00,$00,$00,$00,$00                ; ED0A 00 00 80 00 00 00 00 00
        .byte   $00,$00,$20,$00,$80,$00,$00,$00                ; ED12 00 00 20 00 80 00 00 00
        .byte   $00,$00,$20,$05,$00,$00,$00,$00                ; ED1A 00 00 20 05 00 00 00 00
        .byte   $00,$00,$00,$00,$40,$00,$00,$00                ; ED22 00 00 00 00 40 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED2A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED32 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED3A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED42 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED4A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED52 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED5A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED62 00 00 00 00 00 00 00 00
        .byte   $00,$00,$08,$02,$00,$10,$00,$00                ; ED6A 00 00 08 02 00 10 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED72 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED7A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$80,$00,$00,$00,$00,$00                ; ED82 00 00 80 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; ED8A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$10,$00,$00,$00,$00,$00                ; ED92 00 00 10 00 00 00 00 00
        .byte   $00,$00,$00,$01,$00,$00,$00,$00                ; ED9A 00 00 00 01 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDA2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDAA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDB2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$20,$00,$00,$00,$00                ; EDBA 00 00 00 20 00 00 00 00
        .byte   $00,$00,$00,$00,$10,$00,$00,$00                ; EDC2 00 00 00 00 10 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDCA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$20,$00,$00,$00,$00                ; EDD2 00 00 00 20 00 00 00 00
        .byte   $00,$00,$08,$00,$00,$00,$00,$00                ; EDDA 00 00 08 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDE2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDEA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EDF2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$61,$B8                ; EDFA 00 00 00 00 00 00 61 B8
        .byte   $FB,$EE,$FF,$FF,$FF,$FF,$1D,$CD                ; EE02 FB EE FF FF FF FF 1D CD
        .byte   $B4,$F7,$F7,$FF,$FF,$FF,$A5,$31                ; EE0A B4 F7 F7 FF FF FF A5 31
        .byte   $A4,$EF,$FF,$FF,$FF,$FF,$0D,$45                ; EE12 A4 EF FF FF FF FF 0D 45
        .byte   $A6,$FF,$FF,$FF,$FF,$FF,$4A,$09                ; EE1A A6 FF FF FF FF FF 4A 09
        .byte   $FF,$FF,$FD,$FE,$FF,$FF,$A0,$E9                ; EE22 FF FF FD FE FF FF A0 E9
        .byte   $ED,$F3,$FF,$DF,$FF,$FF,$53,$05                ; EE2A ED F3 FF DF FF FF 53 05
        .byte   $EB,$EE,$FF,$FF,$FF,$F6,$4E,$6B                ; EE32 EB EE FF FF FF F6 4E 6B
        .byte   $BD,$F6,$FF,$FF,$FF,$FF,$7B,$0A                ; EE3A BD F6 FF FF FF FF 7B 0A
        .byte   $AA,$BB,$FF,$FF,$FF,$BF,$E7,$59                ; EE42 AA BB FF FF FF BF E7 59
        .byte   $FD,$FE,$FF,$FF,$FF,$FF,$53,$6C                ; EE4A FD FE FF FF FF FF 53 6C
        .byte   $FF,$37,$FF,$FF,$FF,$FF,$6F,$32                ; EE52 FF 37 FF FF FF FF 6F 32
        .byte   $E9,$F9,$7F,$FF,$FF,$FF,$2E,$54                ; EE5A E9 F9 7F FF FF FF 2E 54
        .byte   $FD,$BB,$FF,$FF,$FF,$FF,$38,$B3                ; EE62 FD BB FF FF FF FF 38 B3
        .byte   $BA,$F2,$FF,$FE,$EF,$FF,$25,$83                ; EE6A BA F2 FF FE EF FF 25 83
        .byte   $E1,$8F,$FF,$FF,$DF,$FF,$CA,$19                ; EE72 E1 8F FF FF DF FF CA 19
        .byte   $FF,$FF,$FF,$F7,$FF,$FF,$38,$FD                ; EE7A FF FF FF F7 FF FF 38 FD
        .byte   $F2,$99,$FF,$FF,$6F,$FF,$66,$B5                ; EE82 F2 99 FF FF 6F FF 66 B5
        .byte   $5F,$BF,$FF,$FF,$FF,$FE,$CA,$E2                ; EE8A 5F BF FF FF FF FE CA E2
        .byte   $FE,$DF,$FF,$FF,$FF,$FF,$48,$A7                ; EE92 FE DF FF FF FF FF 48 A7
        .byte   $EF,$DF,$FF,$FF,$FF,$FF,$82,$74                ; EE9A EF DF FF FF FF FF 82 74
        .byte   $F5,$D7,$FF,$FF,$FF,$DB,$A1,$4E                ; EEA2 F5 D7 FF FF FF DB A1 4E
        .byte   $F3,$C5,$FF,$FF,$FF,$BF,$3E,$D0                ; EEAA F3 C5 FF FF FF BF 3E D0
        .byte   $FE,$3F,$FF,$FF,$FF,$FF,$BE,$6E                ; EEB2 FE 3F FF FF FF FF BE 6E
        .byte   $F7,$FE,$FF,$FF,$FF,$FF,$11,$A3                ; EEBA F7 FE FF FF FF FF 11 A3
        .byte   $E3,$EB,$FF,$FF,$F7,$FF,$36,$C8                ; EEC2 E3 EB FF FF F7 FF 36 C8
        .byte   $DE,$B9,$FF,$FF,$FF,$FF,$85,$DB                ; EECA DE B9 FF FF FF FF 85 DB
        .byte   $EB,$F9,$FF,$FF,$FF,$FF,$18,$8F                ; EED2 EB F9 FF FF FF FF 18 8F
        .byte   $EB,$FE,$FF,$FF,$BF,$FF,$46,$2C                ; EEDA EB FE FF FF BF FF 46 2C
        .byte   $FD,$ED,$FF,$FF,$FF,$FF,$BB,$88                ; EEE2 FD ED FF FF FF FF BB 88
        .byte   $F9,$FF,$FF,$FF,$FF,$FF,$1E,$AA                ; EEEA F9 FF FF FF FF FF 1E AA
        .byte   $F7,$B3,$FF,$FF,$F7,$BF,$FF,$EF                ; EEF2 F7 B3 FF FF F7 BF FF EF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; EEFA FF FF FF FF FF FF 00 00
        .byte   $00,$00,$20,$00,$10,$08,$00,$00                ; EF02 00 00 20 00 10 08 00 00
        .byte   $00,$00,$02,$00,$00,$10,$00,$00                ; EF0A 00 00 02 00 00 10 00 00
        .byte   $00,$00,$44,$00,$00,$00,$00,$00                ; EF12 00 00 44 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF1A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$01,$00,$00,$00,$00,$00                ; EF22 00 00 01 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF2A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF32 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF3A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$08,$00,$00,$00,$00,$00                ; EF42 00 00 08 00 00 00 00 00
        .byte   $00,$00,$00,$20,$00,$00,$00,$00                ; EF4A 00 00 00 20 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF52 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$10,$00,$00,$00,$00                ; EF5A 00 00 00 10 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF62 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF6A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF72 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF7A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF82 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$10,$00,$00,$00,$00                ; EF8A 00 00 00 10 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF92 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EF9A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFA2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFAA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFB2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$20,$00,$00,$00,$00                ; EFBA 00 00 00 20 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFC2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFCA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$10,$04,$00,$00,$00,$00                ; EFD2 00 00 10 04 00 00 00 00
        .byte   $00,$00,$00,$10,$00,$00,$00,$00                ; EFDA 00 00 00 10 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; EFE2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$80,$00,$00,$00,$00,$00                ; EFEA 00 00 80 00 00 00 00 00
        .byte   $00,$00,$04,$00,$01,$00,$00,$00                ; EFF2 00 00 04 00 01 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$20,$00                ; EFFA 00 00 00 00 00 00 20 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F002 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F00A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F012 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F01A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F022 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F02A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F032 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F03A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F042 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F04A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F052 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F05A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F062 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F06A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F072 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F07A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F082 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F08A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F092 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F09A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F0A2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F0AA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F0B2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F0BA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$03                ; F0C2 00 00 00 00 00 00 00 03
        .byte   $CC,$8C,$AC,$AA,$BC,$02,$AC,$AC                ; F0CA CC 8C AC AA BC 02 AC AC
        .byte   $CC,$CC,$CC,$CC,$CC,$CC,$CC,$AC                ; F0D2 CC CC CC CC CC CC CC AC
        .byte   $2D,$C6,$CC,$98,$9C,$B9,$21,$8C                ; F0DA 2D C6 CC 98 9C B9 21 8C
        .byte   $C8,$C8,$5B,$C6,$CC,$8C,$9C,$C9                ; F0E2 C8 C8 5B C6 CC 8C 9C C9
        .byte   $BC,$40,$99,$C9,$9C,$AC,$CC,$BC                ; F0EA BC 40 99 C9 9C AC CC BC
        .byte   $60,$99,$C9,$3B,$C0,$8C,$AC,$9A                ; F0F2 60 99 C9 3B C0 8C AC 9A
        .byte   $CC,$1B,$C0,$4B,$C2,$CC,$CC,$C8                ; F0FA CC 1B C0 4B C2 CC CC C8
        .byte   $AC,$CA,$CC,$6B,$C2,$CC,$CC,$CC                ; F102 AC CA CC 6B C2 CC CC CC
        .byte   $CC,$88,$8C,$1B,$A4,$AA,$C8,$88                ; F10A CC 88 8C 1B A4 AA C8 88
        .byte   $AC,$BA,$44,$AC,$CC,$C9,$0B,$A0                ; F112 AC BA 44 AC CC C9 0B A0
        .byte   $AA,$CA,$C9,$BC,$61,$8C,$A8,$CA                ; F11A AA CA C9 BC 61 8C A8 CA
        .byte   $AA,$CA,$6B,$C0,$CC,$8C,$8C,$A8                ; F122 AA CA 6B C0 CC 8C 8C A8
        .byte   $AC,$5B,$C0,$8C,$9C,$CC,$5B,$90                ; F12A AC 5B C0 8C 9C CC 5B 90
        .byte   $99,$C8,$C9,$BC,$22,$CC,$C9,$C9                ; F132 99 C8 C9 BC 22 CC C9 C9
        .byte   $CC,$CC,$AA,$AC,$AA,$CA,$C8,$88                ; F13A CC CC AA AC AA CA C8 88
        .byte   $BC,$23,$CC,$CC,$C8,$99,$C9,$BC                ; F142 BC 23 CC CC C8 99 C9 BC
        .byte   $05,$CC,$98,$9C,$C9,$6B,$C2,$8C                ; F14A 05 CC 98 9C C9 6B C2 8C
        .byte   $C8,$0B,$A6,$AA,$AC,$1B,$C6,$8C                ; F152 C8 0B A6 AA AC 1B C6 8C
        .byte   $88,$9C,$BC,$03,$8C,$CC,$3B,$C2                ; F15A 88 9C BC 03 8C CC 3B C2
        .byte   $CC,$C8,$AA,$CC,$4B,$C4,$C9,$99                ; F162 CC C8 AA CC 4B C4 C9 99
        .byte   $BC,$61,$8C,$C8,$C8,$CA,$3B,$A6                ; F16A BC 61 8C C8 C8 CA 3B A6
        .byte   $AA,$CC,$2B,$80,$8C,$C9,$C9,$0B                ; F172 AA CC 2B 80 8C C9 C9 0B
        .byte   $A0,$CA,$CC,$0B,$C6,$3B,$C0,$C8                ; F17A A0 CA CC 0B C6 3B C0 C8
        .byte   $AA,$CA,$9C,$99,$99,$CC,$C8,$BC                ; F182 AA CA 9C 99 99 CC C8 BC
        .byte   $60,$CA,$BC,$46,$CC,$8C,$98,$C9                ; F18A 60 CA BC 46 CC 8C 98 C9
        .byte   $C9,$6B,$C4,$88,$C8,$C9,$CC,$CC                ; F192 C9 6B C4 88 C8 C9 CC CC
        .byte   $BC,$64,$8C,$9C,$CC,$CC,$3B,$C4                ; F19A BC 64 8C 9C CC CC 3B C4
        .byte   $A8,$AA,$CC,$4B,$C2,$CC,$C9,$99                ; F1A2 A8 AA CC 4B C2 CC C9 99
        .byte   $C9,$CC,$6D,$A2,$CA,$CC,$8C,$CC                ; F1AA C9 CC 6D A2 CA CC 8C CC
        .byte   $5D,$84,$9C,$99,$C9,$3B,$A2,$AC                ; F1B2 5D 84 9C 99 C9 3B A2 AC
        .byte   $CA,$BC,$05,$8C,$99,$99,$BC,$03                ; F1BA CA BC 05 8C 99 99 BC 03
        .byte   $CC,$BC,$03,$CC,$CC,$C8,$AA,$CA                ; F1C2 CC BC 03 CC CC C8 AA CA
        .byte   $CC,$5B,$A6,$AC,$CA,$CC,$BC,$41                ; F1CA CC 5B A6 AC CA CC BC 41
        .byte   $CC,$8C,$88,$AC,$AA,$BC,$63,$AA                ; F1D2 CC 8C 88 AC AA BC 63 AA
        .byte   $CA,$CC,$3B,$C4,$CC,$CC,$A8,$CA                ; F1DA CA CC 3B C4 CC CC A8 CA
        .byte   $CA,$1B,$C6,$8C,$C8,$A8,$CA,$CC                ; F1E2 CA 1B C6 8C C8 A8 CA CC
        .byte   $3B,$C2,$AA,$AC,$BC,$43,$AA,$C8                ; F1EA 3B C2 AA AC BC 43 AA C8
        .byte   $CA,$CC,$0B,$A0,$CA,$BC,$20,$AA                ; F1F2 CA CC 0B A0 CA BC 20 AA
        .byte   $CC,$CC,$2B,$C6,$99,$9C,$C9,$CC                ; F1FA CC CC 2B C6 99 9C C9 CC
        .byte   $BC,$44,$8C,$C9,$C9,$BC,$06,$CC                ; F202 BC 44 8C C9 C9 BC 06 CC
        .byte   $C8,$98,$C9,$CC,$4B,$96,$99,$9C                ; F20A C8 98 C9 CC 4B 96 99 9C
        .byte   $BC,$02,$CC,$A8,$AC,$CA,$CC,$DC                ; F212 BC 02 CC A8 AC CA CC DC
        .byte   $21,$CC,$CC,$AA,$AA,$CA,$BC,$22                ; F21A 21 CC CC AA AA CA BC 22
        .byte   $8C,$C8,$AA,$CC,$6B,$C6,$C8,$C9                ; F222 8C C8 AA CC 6B C6 C8 C9
        .byte   $BC,$65,$99,$99,$CC,$2B,$C0,$C8                ; F22A BC 65 99 99 CC 2B C0 C8
        .byte   $CC,$CA,$CC,$CC,$9C,$C9,$BC,$03                ; F232 CC CA CC CC 9C C9 BC 03
        .byte   $CC,$8C,$AC,$AA,$CC,$2B,$A2,$CC                ; F23A CC 8C AC AA CC 2B A2 CC
        .byte   $CC,$CC,$CC,$CC,$4B,$C4,$CC,$8C                ; F242 CC CC CC CC 4B C4 CC 8C
        .byte   $99,$9C,$99,$BC,$05,$CC,$8C,$9C                ; F24A 99 9C 99 BC 05 CC 8C 9C
        .byte   $99,$CC,$CC,$CC,$CC,$AC,$AA,$CC                ; F252 99 CC CC CC CC AC AA CC
        .byte   $BC,$65,$CA,$CC,$0B,$94,$99,$CC                ; F25A BC 65 CA CC 0B 94 99 CC
        .byte   $BC,$45,$CC,$CC,$CC,$C8,$99,$9C                ; F262 BC 45 CC CC CC C8 99 9C
        .byte   $BC,$21,$8C,$C8,$CC,$9C,$C9,$CC                ; F26A BC 21 8C C8 CC 9C C9 CC
        .byte   $AA,$CA,$AA,$3D,$94,$C9,$3B,$C6                ; F272 AA CA AA 3D 94 C9 3B C6
        .byte   $CC,$AC,$AA,$CC,$4B,$C4,$C8,$99                ; F27A CC AC AA CC 4B C4 C8 99
        .byte   $C9,$4B,$C4,$C8,$C9,$6B,$C2,$C8                ; F282 C9 4B C4 C8 C9 6B C2 C8
        .byte   $98,$C9,$BC,$46,$CA,$CA,$CC,$BC                ; F28A 98 C9 BC 46 CA CA CC BC
        .byte   $62,$C8,$88,$C9,$BC,$64,$99,$99                ; F292 62 C8 88 C9 BC 64 99 99
        .byte   $CC,$CC,$5B,$80,$9C,$99,$C9,$FB                ; F29A CC CC 5B 80 9C 99 C9 FB
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2A2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2AA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2B2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$80,$FF,$FF                ; F2BA 00 00 00 00 00 80 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F2C2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F2CA FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F2D2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F2DA FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2E2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2EA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F2F2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F2FA 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F302 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F30A FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F312 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F31A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$01                ; F322 00 00 00 00 00 00 00 01
        .byte   $00,$00,$00,$00,$00,$40,$00,$00                ; F32A 00 00 00 00 00 40 00 00
        .byte   $00,$00,$00,$40,$00,$00,$00,$00                ; F332 00 00 00 40 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F33A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F342 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F34A FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F352 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F35A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$80,$00,$00                ; F362 00 00 00 00 00 80 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F36A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$01,$00,$00                ; F372 00 00 00 00 00 01 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F37A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F382 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F38A FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F392 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F39A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F3A2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F3AA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F3B2 00 00 00 00 00 00 00 00
        .byte   $10,$00,$00,$00,$00,$00,$FF,$FF                ; F3BA 10 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F3C2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F3CA FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F3D2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F3DA FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F3E2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F3EA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$01,$00                ; F3F2 00 00 00 00 00 00 01 00
        .byte   $20,$00,$00,$00,$00,$00,$03,$00                ; F3FA 20 00 00 00 00 00 03 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F402 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F40A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F412 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F41A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F422 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F42A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F432 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F43A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F442 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F44A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F452 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F45A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F462 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F46A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$33                ; F472 00 00 00 00 00 00 00 33
        .byte   $00,$34,$00,$00,$35,$36,$00,$00                ; F47A 00 34 00 00 35 36 00 00
        .byte   $00,$37,$38,$38,$34,$00,$00,$00                ; F482 00 37 38 38 34 00 00 00
        .byte   $00,$00,$00,$00,$00,$33,$33,$00                ; F48A 00 00 00 00 00 33 33 00
        .byte   $36,$35,$00,$00,$00,$33,$37,$38                ; F492 36 35 00 00 00 33 37 38
        .byte   $00,$00,$38,$38,$34,$00,$00,$00                ; F49A 00 00 38 38 34 00 00 00
        .byte   $00,$35,$00,$00,$00,$36,$00,$00                ; F4A2 00 35 00 00 00 36 00 00
        .byte   $00,$00,$35,$33,$37,$37,$00,$00                ; F4AA 00 00 35 33 37 37 00 00
        .byte   $38,$35,$33,$36,$00,$34,$34,$35                ; F4B2 38 35 33 36 00 34 34 35
        .byte   $00,$00,$00,$37,$37,$00,$35,$35                ; F4BA 00 00 00 37 37 00 35 35
        .byte   $34,$00,$00,$00,$00,$00,$00,$46                ; F4C2 34 00 00 00 00 00 00 46
        .byte   $CC,$8C,$99,$C9,$BC,$62,$88,$AC                ; F4CA CC 8C 99 C9 BC 62 88 AC
        .byte   $AA,$AA,$CC,$CC,$CC,$CC,$CC,$CC                ; F4D2 AA AA CC CC CC CC CC CC
        .byte   $D9,$24,$AA,$BC,$03,$CC,$8C,$99                ; F4DA D9 24 AA BC 03 CC 8C 99
        .byte   $CC,$BC,$00,$BC,$22,$8C,$8C,$98                ; F4E2 CC BC 00 BC 22 8C 8C 98
        .byte   $9C,$C9,$6B,$82,$8C,$AA,$CA,$0B                ; F4EA 9C C9 6B 82 8C AA CA 0B
        .byte   $A4,$CA,$BC,$60,$99,$C9,$5B,$80                ; F4F2 A4 CA BC 60 99 C9 5B 80
        .byte   $AA,$AA,$AC,$1B,$C4,$88,$A8,$AA                ; F4FA AA AA AC 1B C4 88 A8 AA
        .byte   $CA,$BA,$41,$BC,$23,$CC,$99,$C9                ; F502 CA BA 41 BC 23 CC 99 C9
        .byte   $0B,$C0,$AA,$CA,$CA,$3B,$82,$CA                ; F50A 0B C0 AA CA CA 3B 82 CA
        .byte   $0B,$A6,$AA,$CA,$2B,$C4,$C8,$99                ; F512 0B A6 AA CA 2B C4 C8 99
        .byte   $99,$BC,$26,$CC,$CC,$88,$C8,$3B                ; F51A 99 BC 26 CC CC 88 C8 3B
        .byte   $C6,$8C,$99,$99,$BC,$43,$CC,$8C                ; F522 C6 8C 99 99 BC 43 CC 8C
        .byte   $C9,$1B,$80,$C9,$3B,$C0,$C8,$B9                ; F52A C9 1B 80 C9 3B C0 C8 B9
        .byte   $42,$CC,$88,$A8,$AA,$CC,$6B,$90                ; F532 42 CC 88 A8 AA CC 6B 90
        .byte   $99,$C9,$BC,$62,$AA,$BC,$04,$9C                ; F53A 99 C9 BC 62 AA BC 04 9C
        .byte   $99,$9C,$BC,$26,$CC,$AA,$BC,$24                ; F542 99 9C BC 26 CC AA BC 24
        .byte   $99,$BC,$43,$CC,$C8,$99,$9C,$C9                ; F54A 99 BC 43 CC C8 99 9C C9
        .byte   $5B,$C6,$9C,$99,$C9,$2B,$A0,$AC                ; F552 5B C6 9C 99 C9 2B A0 AC
        .byte   $CA,$A8,$BA,$62,$AA,$AA,$5B,$A2                ; F55A CA A8 BA 62 AA AA 5B A2
        .byte   $CC,$AA,$CA,$BA,$24,$AA,$CA,$C9                ; F562 CC AA CA BA 24 AA CA C9
        .byte   $BC,$02,$CC,$88,$A8,$AC,$AA,$4B                ; F56A BC 02 CC 88 A8 AC AA 4B
        .byte   $80,$BC,$45,$8C,$9C,$CC,$4B,$C0                ; F572 80 BC 45 8C 9C CC 4B C0
        .byte   $CC,$C8,$CC,$BC,$06,$88,$9C,$C9                ; F57A CC C8 CC BC 06 88 9C C9
        .byte   $3B,$92,$99,$99,$CC,$3B,$92,$99                ; F582 3B 92 99 99 CC 3B 92 99
        .byte   $B9,$02,$8C,$88,$BC,$61,$8C,$CC                ; F58A B9 02 8C 88 BC 61 8C CC
        .byte   $A8,$AC,$BA,$42,$8C,$88,$88,$8C                ; F592 A8 AC BA 42 8C 88 88 8C
        .byte   $6B,$86,$88,$AC,$AA,$6B,$C4,$88                ; F59A 6B 86 88 AC AA 6B C4 88
        .byte   $9C,$99,$B9,$00,$AA,$AA,$3B,$82                ; F5A2 9C 99 B9 00 AA AA 3B 82
        .byte   $BC,$03,$C9,$3B,$C4,$C8,$99,$99                ; F5AA BC 03 C9 3B C4 C8 99 99
        .byte   $C9,$CA,$AA,$AA,$1B,$C0,$98,$C9                ; F5B2 C9 CA AA AA 1B C0 98 C9
        .byte   $3B,$C4,$C8,$3B,$B6,$66,$98,$CC                ; F5BA 3B C4 C8 3B B6 66 98 CC
        .byte   $BC,$00,$AA,$AC,$CC,$8C,$3B,$92                ; F5C2 BC 00 AA AC CC 8C 3B 92
        .byte   $C9,$5B,$A6,$AA,$AA,$BC,$62,$AC                ; F5CA C9 5B A6 AA AA BC 62 AC
        .byte   $AC,$AA,$8C,$C8,$CC,$4B,$84,$99                ; F5D2 AC AA 8C C8 CC 4B 84 99
        .byte   $C9,$B9,$42,$8C,$AC,$AA,$4B,$80                ; F5DA C9 B9 42 8C AC AA 4B 80
        .byte   $9C,$99,$99,$BC,$41,$8C,$88,$CA                ; F5E2 9C 99 99 BC 41 8C 88 CA
        .byte   $AA,$AA,$4B,$C4,$98,$99,$99,$BC                ; F5EA AA AA 4B C4 98 99 99 BC
        .byte   $26,$88,$8C,$99,$BC,$23,$A8,$AC                ; F5F2 26 88 8C 99 BC 23 A8 AC
        .byte   $6B,$90,$C9,$99,$0B,$A6,$CC,$0B                ; F5FA 6B 90 C9 99 0B A6 CC 0B
        .byte   $A6,$CC,$BC,$61,$88,$BC,$FF,$FF                ; F602 A6 CC BC 61 88 BC FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FD                ; F60A FF FF FF FF FF FF FF FD
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F612 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F61A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F622 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F62A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F632 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F63A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$7F,$FF,$FF,$FF,$FF                ; F642 FF FF FF 7F FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$F7,$FF                ; F64A FF FF FF FF FF FF F7 FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F652 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F65A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F662 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F66A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F672 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F67A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F682 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F68A FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F692 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$EF,$FF,$00,$00                ; F69A FF FF FF FF EF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6A2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6AA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6B2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F6BA 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F6C2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F6CA FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$DF                ; F6D2 FF FF FF FF FF FF FF DF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F6DA FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6E2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6EA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F6F2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F6FA 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$F7,$FF                ; F702 FF FF FF FF FF FF F7 FF
        .byte   $FF,$DF,$FF,$FF,$FF,$FF,$FE,$FF                ; F70A FF DF FF FF FF FF FE FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F712 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F71A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F722 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F72A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F732 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F73A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F742 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F74A FF FF FF FF FF FF FF FF
        .byte   $DF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F752 DF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F75A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F762 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F76A 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F772 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F77A 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F782 FF FF FF FF FF FF FF FF
        .byte   $FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F78A FE FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F792 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F79A FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7A2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7AA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7B2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$FF,$FF                ; F7BA 00 00 00 00 00 00 FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F7C2 FF FF FF FF FF FF FF FF
        .byte   $F7,$FF,$FF,$F7,$FF,$FF,$FF,$FF                ; F7CA F7 FF FF F7 FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF                ; F7D2 FF FF FF FF FF FF FF FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$00,$00                ; F7DA FF FF FF FF FF FF 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7E2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7EA 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; F7F2 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00                        ; F7FA 00 00 00 00 00 00
; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
renderPlayfieldColumns01:
        lda     ppuNametableSelect                             ; F800 A5 29
        asl     a                                              ; F802 0A
        asl     a                                              ; F803 0A
        adc     #$20                                           ; F804 69 20
        sta     PPUADDR                                        ; F806 8D 06 20
        lda     #$CC                                           ; F809 A9 CC
        sta     PPUADDR                                        ; F80B 8D 06 20
        lda     playfield                                      ; F80E AD 0A 03
        sta     PPUDATA                                        ; F811 8D 07 20
        lda     playfield+10                                   ; F814 AD 14 03
        sta     PPUDATA                                        ; F817 8D 07 20
        lda     playfield+20                                   ; F81A AD 1E 03
        sta     PPUDATA                                        ; F81D 8D 07 20
        lda     playfield+30                                   ; F820 AD 28 03
        sta     PPUDATA                                        ; F823 8D 07 20
        lda     playfield+40                                   ; F826 AD 32 03
        sta     PPUDATA                                        ; F829 8D 07 20
        lda     playfield+50                                   ; F82C AD 3C 03
        sta     PPUDATA                                        ; F82F 8D 07 20
        lda     playfield+60                                   ; F832 AD 46 03
        sta     PPUDATA                                        ; F835 8D 07 20
        lda     playfield+70                                   ; F838 AD 50 03
        sta     PPUDATA                                        ; F83B 8D 07 20
        lda     playfield+80                                   ; F83E AD 5A 03
        sta     PPUDATA                                        ; F841 8D 07 20
        lda     playfield+90                                   ; F844 AD 64 03
        sta     PPUDATA                                        ; F847 8D 07 20
        lda     playfield+100                                  ; F84A AD 6E 03
        sta     PPUDATA                                        ; F84D 8D 07 20
        lda     playfield+110                                  ; F850 AD 78 03
        sta     PPUDATA                                        ; F853 8D 07 20
        lda     playfield+120                                  ; F856 AD 82 03
        sta     PPUDATA                                        ; F859 8D 07 20
        lda     playfield+130                                  ; F85C AD 8C 03
        sta     PPUDATA                                        ; F85F 8D 07 20
        lda     playfield+140                                  ; F862 AD 96 03
        sta     PPUDATA                                        ; F865 8D 07 20
        lda     playfield+150                                  ; F868 AD A0 03
        sta     PPUDATA                                        ; F86B 8D 07 20
        lda     playfield+160                                  ; F86E AD AA 03
        sta     PPUDATA                                        ; F871 8D 07 20
        lda     playfield+170                                  ; F874 AD B4 03
        sta     PPUDATA                                        ; F877 8D 07 20
        lda     playfield+180                                  ; F87A AD BE 03
        sta     PPUDATA                                        ; F87D 8D 07 20
        lda     playfield+190                                  ; F880 AD C8 03
        sta     PPUDATA                                        ; F883 8D 07 20
        lda     ppuNametableSelect                             ; F886 A5 29
        asl     a                                              ; F888 0A
        asl     a                                              ; F889 0A
        adc     #$20                                           ; F88A 69 20
        sta     PPUADDR                                        ; F88C 8D 06 20
        lda     #$CD                                           ; F88F A9 CD
        sta     PPUADDR                                        ; F891 8D 06 20
        lda     playfield+1                                    ; F894 AD 0B 03
        sta     PPUDATA                                        ; F897 8D 07 20
        lda     playfield+11                                   ; F89A AD 15 03
        sta     PPUDATA                                        ; F89D 8D 07 20
        lda     playfield+21                                   ; F8A0 AD 1F 03
        sta     PPUDATA                                        ; F8A3 8D 07 20
        lda     playfield+31                                   ; F8A6 AD 29 03
        sta     PPUDATA                                        ; F8A9 8D 07 20
        lda     playfield+41                                   ; F8AC AD 33 03
        sta     PPUDATA                                        ; F8AF 8D 07 20
        lda     playfield+51                                   ; F8B2 AD 3D 03
        sta     PPUDATA                                        ; F8B5 8D 07 20
        lda     playfield+61                                   ; F8B8 AD 47 03
        sta     PPUDATA                                        ; F8BB 8D 07 20
        lda     playfield+71                                   ; F8BE AD 51 03
        sta     PPUDATA                                        ; F8C1 8D 07 20
        lda     playfield+81                                   ; F8C4 AD 5B 03
        sta     PPUDATA                                        ; F8C7 8D 07 20
        lda     playfield+91                                   ; F8CA AD 65 03
        sta     PPUDATA                                        ; F8CD 8D 07 20
        lda     playfield+101                                  ; F8D0 AD 6F 03
        sta     PPUDATA                                        ; F8D3 8D 07 20
        lda     playfield+111                                  ; F8D6 AD 79 03
        sta     PPUDATA                                        ; F8D9 8D 07 20
        lda     playfield+121                                  ; F8DC AD 83 03
        sta     PPUDATA                                        ; F8DF 8D 07 20
        lda     playfield+131                                  ; F8E2 AD 8D 03
        sta     PPUDATA                                        ; F8E5 8D 07 20
        lda     playfield+141                                  ; F8E8 AD 97 03
        sta     PPUDATA                                        ; F8EB 8D 07 20
        lda     playfield+151                                  ; F8EE AD A1 03
        sta     PPUDATA                                        ; F8F1 8D 07 20
        lda     playfield+161                                  ; F8F4 AD AB 03
        sta     PPUDATA                                        ; F8F7 8D 07 20
        lda     playfield+171                                  ; F8FA AD B5 03
        sta     PPUDATA                                        ; F8FD 8D 07 20
        lda     playfield+181                                  ; F900 AD BF 03
        sta     PPUDATA                                        ; F903 8D 07 20
        lda     playfield+191                                  ; F906 AD C9 03
        sta     PPUDATA                                        ; F909 8D 07 20
        lda     #<renderPlayfieldColumns23                     ; F90C A9 1A
        sta     jmp1E                                          ; F90E 85 1E
        lda     #>renderPlayfieldColumns23                     ; F910 A9 F9
        sta     jmp1E+1                                        ; F912 85 1F
        jsr     LFF2A                                          ; F914 20 2A FF
        jmp     jumpToFinishNmi                                ; F917 4C 2D FF

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
renderPlayfieldColumns23:
        lda     ppuNametableSelect                             ; F91A A5 29
        asl     a                                              ; F91C 0A
        asl     a                                              ; F91D 0A
        adc     #$20                                           ; F91E 69 20
        sta     PPUADDR                                        ; F920 8D 06 20
        lda     #$CE                                           ; F923 A9 CE
        sta     PPUADDR                                        ; F925 8D 06 20
        lda     playfield+2                                    ; F928 AD 0C 03
        sta     PPUDATA                                        ; F92B 8D 07 20
        lda     playfield+12                                   ; F92E AD 16 03
        sta     PPUDATA                                        ; F931 8D 07 20
        lda     playfield+22                                   ; F934 AD 20 03
        sta     PPUDATA                                        ; F937 8D 07 20
        lda     playfield+32                                   ; F93A AD 2A 03
        sta     PPUDATA                                        ; F93D 8D 07 20
        lda     playfield+42                                   ; F940 AD 34 03
        sta     PPUDATA                                        ; F943 8D 07 20
        lda     playfield+52                                   ; F946 AD 3E 03
        sta     PPUDATA                                        ; F949 8D 07 20
        lda     playfield+62                                   ; F94C AD 48 03
        sta     PPUDATA                                        ; F94F 8D 07 20
        lda     playfield+72                                   ; F952 AD 52 03
        sta     PPUDATA                                        ; F955 8D 07 20
        lda     playfield+82                                   ; F958 AD 5C 03
        sta     PPUDATA                                        ; F95B 8D 07 20
        lda     playfield+92                                   ; F95E AD 66 03
        sta     PPUDATA                                        ; F961 8D 07 20
        lda     playfield+102                                  ; F964 AD 70 03
        sta     PPUDATA                                        ; F967 8D 07 20
        lda     playfield+112                                  ; F96A AD 7A 03
        sta     PPUDATA                                        ; F96D 8D 07 20
        lda     playfield+122                                  ; F970 AD 84 03
        sta     PPUDATA                                        ; F973 8D 07 20
        lda     playfield+132                                  ; F976 AD 8E 03
        sta     PPUDATA                                        ; F979 8D 07 20
        lda     playfield+142                                  ; F97C AD 98 03
        sta     PPUDATA                                        ; F97F 8D 07 20
        lda     playfield+152                                  ; F982 AD A2 03
        sta     PPUDATA                                        ; F985 8D 07 20
        lda     playfield+162                                  ; F988 AD AC 03
        sta     PPUDATA                                        ; F98B 8D 07 20
        lda     playfield+172                                  ; F98E AD B6 03
        sta     PPUDATA                                        ; F991 8D 07 20
        lda     playfield+182                                  ; F994 AD C0 03
        sta     PPUDATA                                        ; F997 8D 07 20
        lda     playfield+192                                  ; F99A AD CA 03
        sta     PPUDATA                                        ; F99D 8D 07 20
        lda     ppuNametableSelect                             ; F9A0 A5 29
        asl     a                                              ; F9A2 0A
        asl     a                                              ; F9A3 0A
        adc     #$20                                           ; F9A4 69 20
        sta     PPUADDR                                        ; F9A6 8D 06 20
        lda     #$CF                                           ; F9A9 A9 CF
        sta     PPUADDR                                        ; F9AB 8D 06 20
        lda     playfield+3                                    ; F9AE AD 0D 03
        sta     PPUDATA                                        ; F9B1 8D 07 20
        lda     playfield+13                                   ; F9B4 AD 17 03
        sta     PPUDATA                                        ; F9B7 8D 07 20
        lda     playfield+23                                   ; F9BA AD 21 03
        sta     PPUDATA                                        ; F9BD 8D 07 20
        lda     playfield+33                                   ; F9C0 AD 2B 03
        sta     PPUDATA                                        ; F9C3 8D 07 20
        lda     playfield+43                                   ; F9C6 AD 35 03
        sta     PPUDATA                                        ; F9C9 8D 07 20
        lda     playfield+53                                   ; F9CC AD 3F 03
        sta     PPUDATA                                        ; F9CF 8D 07 20
        lda     playfield+63                                   ; F9D2 AD 49 03
        sta     PPUDATA                                        ; F9D5 8D 07 20
        lda     playfield+73                                   ; F9D8 AD 53 03
        sta     PPUDATA                                        ; F9DB 8D 07 20
        lda     playfield+83                                   ; F9DE AD 5D 03
        sta     PPUDATA                                        ; F9E1 8D 07 20
        lda     playfield+93                                   ; F9E4 AD 67 03
        sta     PPUDATA                                        ; F9E7 8D 07 20
        lda     playfield+103                                  ; F9EA AD 71 03
        sta     PPUDATA                                        ; F9ED 8D 07 20
        lda     playfield+113                                  ; F9F0 AD 7B 03
        sta     PPUDATA                                        ; F9F3 8D 07 20
        lda     playfield+123                                  ; F9F6 AD 85 03
        sta     PPUDATA                                        ; F9F9 8D 07 20
        lda     playfield+133                                  ; F9FC AD 8F 03
        sta     PPUDATA                                        ; F9FF 8D 07 20
        lda     playfield+143                                  ; FA02 AD 99 03
        sta     PPUDATA                                        ; FA05 8D 07 20
        lda     playfield+153                                  ; FA08 AD A3 03
        sta     PPUDATA                                        ; FA0B 8D 07 20
        lda     playfield+163                                  ; FA0E AD AD 03
        sta     PPUDATA                                        ; FA11 8D 07 20
        lda     playfield+173                                  ; FA14 AD B7 03
        sta     PPUDATA                                        ; FA17 8D 07 20
        lda     playfield+183                                  ; FA1A AD C1 03
        sta     PPUDATA                                        ; FA1D 8D 07 20
        lda     playfield+193                                  ; FA20 AD CB 03
        sta     PPUDATA                                        ; FA23 8D 07 20
        lda     #<renderPlayfieldColumns45                     ; FA26 A9 34
        sta     jmp1E                                          ; FA28 85 1E
        lda     #>renderPlayfieldColumns45                     ; FA2A A9 FA
        sta     jmp1E+1                                        ; FA2C 85 1F
        jsr     LFF2A                                          ; FA2E 20 2A FF
        jmp     jumpToFinishNmi                                ; FA31 4C 2D FF

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
renderPlayfieldColumns45:
        lda     ppuNametableSelect                             ; FA34 A5 29
        asl     a                                              ; FA36 0A
        asl     a                                              ; FA37 0A
        adc     #$20                                           ; FA38 69 20
        sta     PPUADDR                                        ; FA3A 8D 06 20
        lda     #$D0                                           ; FA3D A9 D0
        sta     PPUADDR                                        ; FA3F 8D 06 20
        lda     playfield+4                                    ; FA42 AD 0E 03
        sta     PPUDATA                                        ; FA45 8D 07 20
        lda     playfield+14                                   ; FA48 AD 18 03
        sta     PPUDATA                                        ; FA4B 8D 07 20
        lda     playfield+24                                   ; FA4E AD 22 03
        sta     PPUDATA                                        ; FA51 8D 07 20
        lda     playfield+34                                   ; FA54 AD 2C 03
        sta     PPUDATA                                        ; FA57 8D 07 20
        lda     playfield+44                                   ; FA5A AD 36 03
        sta     PPUDATA                                        ; FA5D 8D 07 20
        lda     playfield+54                                   ; FA60 AD 40 03
        sta     PPUDATA                                        ; FA63 8D 07 20
        lda     playfield+64                                   ; FA66 AD 4A 03
        sta     PPUDATA                                        ; FA69 8D 07 20
        lda     playfield+74                                   ; FA6C AD 54 03
        sta     PPUDATA                                        ; FA6F 8D 07 20
        lda     playfield+84                                   ; FA72 AD 5E 03
        sta     PPUDATA                                        ; FA75 8D 07 20
        lda     playfield+94                                   ; FA78 AD 68 03
        sta     PPUDATA                                        ; FA7B 8D 07 20
        lda     playfield+104                                  ; FA7E AD 72 03
        sta     PPUDATA                                        ; FA81 8D 07 20
        lda     playfield+114                                  ; FA84 AD 7C 03
        sta     PPUDATA                                        ; FA87 8D 07 20
        lda     playfield+124                                  ; FA8A AD 86 03
        sta     PPUDATA                                        ; FA8D 8D 07 20
        lda     playfield+134                                  ; FA90 AD 90 03
        sta     PPUDATA                                        ; FA93 8D 07 20
        lda     playfield+144                                  ; FA96 AD 9A 03
        sta     PPUDATA                                        ; FA99 8D 07 20
        lda     playfield+154                                  ; FA9C AD A4 03
        sta     PPUDATA                                        ; FA9F 8D 07 20
        lda     playfield+164                                  ; FAA2 AD AE 03
        sta     PPUDATA                                        ; FAA5 8D 07 20
        lda     playfield+174                                  ; FAA8 AD B8 03
        sta     PPUDATA                                        ; FAAB 8D 07 20
        lda     playfield+184                                  ; FAAE AD C2 03
        sta     PPUDATA                                        ; FAB1 8D 07 20
        lda     playfield+194                                  ; FAB4 AD CC 03
        sta     PPUDATA                                        ; FAB7 8D 07 20
        lda     ppuNametableSelect                             ; FABA A5 29
        asl     a                                              ; FABC 0A
        asl     a                                              ; FABD 0A
        adc     #$20                                           ; FABE 69 20
        sta     PPUADDR                                        ; FAC0 8D 06 20
        lda     #$D1                                           ; FAC3 A9 D1
        sta     PPUADDR                                        ; FAC5 8D 06 20
        lda     playfield+5                                    ; FAC8 AD 0F 03
        sta     PPUDATA                                        ; FACB 8D 07 20
        lda     playfield+15                                   ; FACE AD 19 03
        sta     PPUDATA                                        ; FAD1 8D 07 20
        lda     playfield+25                                   ; FAD4 AD 23 03
        sta     PPUDATA                                        ; FAD7 8D 07 20
        lda     playfield+35                                   ; FADA AD 2D 03
        sta     PPUDATA                                        ; FADD 8D 07 20
        lda     playfield+45                                   ; FAE0 AD 37 03
        sta     PPUDATA                                        ; FAE3 8D 07 20
        lda     playfield+55                                   ; FAE6 AD 41 03
        sta     PPUDATA                                        ; FAE9 8D 07 20
        lda     playfield+65                                   ; FAEC AD 4B 03
        sta     PPUDATA                                        ; FAEF 8D 07 20
        lda     playfield+75                                   ; FAF2 AD 55 03
        sta     PPUDATA                                        ; FAF5 8D 07 20
        lda     playfield+85                                   ; FAF8 AD 5F 03
        sta     PPUDATA                                        ; FAFB 8D 07 20
        lda     playfield+95                                   ; FAFE AD 69 03
        sta     PPUDATA                                        ; FB01 8D 07 20
        lda     playfield+105                                  ; FB04 AD 73 03
        sta     PPUDATA                                        ; FB07 8D 07 20
        lda     playfield+115                                  ; FB0A AD 7D 03
        sta     PPUDATA                                        ; FB0D 8D 07 20
        lda     playfield+125                                  ; FB10 AD 87 03
        sta     PPUDATA                                        ; FB13 8D 07 20
        lda     playfield+135                                  ; FB16 AD 91 03
        sta     PPUDATA                                        ; FB19 8D 07 20
        lda     playfield+145                                  ; FB1C AD 9B 03
        sta     PPUDATA                                        ; FB1F 8D 07 20
        lda     playfield+155                                  ; FB22 AD A5 03
        sta     PPUDATA                                        ; FB25 8D 07 20
        lda     playfield+165                                  ; FB28 AD AF 03
        sta     PPUDATA                                        ; FB2B 8D 07 20
        lda     playfield+175                                  ; FB2E AD B9 03
        sta     PPUDATA                                        ; FB31 8D 07 20
        lda     playfield+185                                  ; FB34 AD C3 03
        sta     PPUDATA                                        ; FB37 8D 07 20
        lda     playfield+195                                  ; FB3A AD CD 03
        sta     PPUDATA                                        ; FB3D 8D 07 20
        lda     #<renderPlayfieldColumns67                     ; FB40 A9 4E
        sta     jmp1E                                          ; FB42 85 1E
        lda     #>renderPlayfieldColumns67                     ; FB44 A9 FB
        sta     jmp1E+1                                        ; FB46 85 1F
        jsr     LFF2A                                          ; FB48 20 2A FF
        jmp     jumpToFinishNmi                                ; FB4B 4C 2D FF

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
renderPlayfieldColumns67:
        lda     ppuNametableSelect                             ; FB4E A5 29
        asl     a                                              ; FB50 0A
        asl     a                                              ; FB51 0A
        adc     #$20                                           ; FB52 69 20
        sta     PPUADDR                                        ; FB54 8D 06 20
        lda     #$D2                                           ; FB57 A9 D2
        sta     PPUADDR                                        ; FB59 8D 06 20
        lda     playfield+6                                    ; FB5C AD 10 03
        sta     PPUDATA                                        ; FB5F 8D 07 20
        lda     playfield+16                                   ; FB62 AD 1A 03
        sta     PPUDATA                                        ; FB65 8D 07 20
        lda     playfield+26                                   ; FB68 AD 24 03
        sta     PPUDATA                                        ; FB6B 8D 07 20
        lda     playfield+36                                   ; FB6E AD 2E 03
        sta     PPUDATA                                        ; FB71 8D 07 20
        lda     playfield+46                                   ; FB74 AD 38 03
        sta     PPUDATA                                        ; FB77 8D 07 20
        lda     playfield+56                                   ; FB7A AD 42 03
        sta     PPUDATA                                        ; FB7D 8D 07 20
        lda     playfield+66                                   ; FB80 AD 4C 03
        sta     PPUDATA                                        ; FB83 8D 07 20
        lda     playfield+76                                   ; FB86 AD 56 03
        sta     PPUDATA                                        ; FB89 8D 07 20
        lda     playfield+86                                   ; FB8C AD 60 03
        sta     PPUDATA                                        ; FB8F 8D 07 20
        lda     playfield+96                                   ; FB92 AD 6A 03
        sta     PPUDATA                                        ; FB95 8D 07 20
        lda     playfield+106                                  ; FB98 AD 74 03
        sta     PPUDATA                                        ; FB9B 8D 07 20
        lda     playfield+116                                  ; FB9E AD 7E 03
        sta     PPUDATA                                        ; FBA1 8D 07 20
        lda     playfield+126                                  ; FBA4 AD 88 03
        sta     PPUDATA                                        ; FBA7 8D 07 20
        lda     playfield+136                                  ; FBAA AD 92 03
        sta     PPUDATA                                        ; FBAD 8D 07 20
        lda     playfield+146                                  ; FBB0 AD 9C 03
        sta     PPUDATA                                        ; FBB3 8D 07 20
        lda     playfield+156                                  ; FBB6 AD A6 03
        sta     PPUDATA                                        ; FBB9 8D 07 20
        lda     playfield+166                                  ; FBBC AD B0 03
        sta     PPUDATA                                        ; FBBF 8D 07 20
        lda     playfield+176                                  ; FBC2 AD BA 03
        sta     PPUDATA                                        ; FBC5 8D 07 20
        lda     playfield+186                                  ; FBC8 AD C4 03
        sta     PPUDATA                                        ; FBCB 8D 07 20
        lda     playfield+196                                  ; FBCE AD CE 03
        sta     PPUDATA                                        ; FBD1 8D 07 20
        lda     ppuNametableSelect                             ; FBD4 A5 29
        asl     a                                              ; FBD6 0A
        asl     a                                              ; FBD7 0A
        adc     #$20                                           ; FBD8 69 20
        sta     PPUADDR                                        ; FBDA 8D 06 20
        lda     #$D3                                           ; FBDD A9 D3
        sta     PPUADDR                                        ; FBDF 8D 06 20
        lda     playfield+7                                    ; FBE2 AD 11 03
        sta     PPUDATA                                        ; FBE5 8D 07 20
        lda     playfield+17                                   ; FBE8 AD 1B 03
        sta     PPUDATA                                        ; FBEB 8D 07 20
        lda     playfield+27                                   ; FBEE AD 25 03
        sta     PPUDATA                                        ; FBF1 8D 07 20
        lda     playfield+37                                   ; FBF4 AD 2F 03
        sta     PPUDATA                                        ; FBF7 8D 07 20
        lda     playfield+47                                   ; FBFA AD 39 03
        sta     PPUDATA                                        ; FBFD 8D 07 20
        lda     playfield+57                                   ; FC00 AD 43 03
        sta     PPUDATA                                        ; FC03 8D 07 20
        lda     playfield+67                                   ; FC06 AD 4D 03
        sta     PPUDATA                                        ; FC09 8D 07 20
        lda     playfield+77                                   ; FC0C AD 57 03
        sta     PPUDATA                                        ; FC0F 8D 07 20
        lda     playfield+87                                   ; FC12 AD 61 03
        sta     PPUDATA                                        ; FC15 8D 07 20
        lda     playfield+97                                   ; FC18 AD 6B 03
        sta     PPUDATA                                        ; FC1B 8D 07 20
        lda     playfield+107                                  ; FC1E AD 75 03
        sta     PPUDATA                                        ; FC21 8D 07 20
        lda     playfield+117                                  ; FC24 AD 7F 03
        sta     PPUDATA                                        ; FC27 8D 07 20
        lda     playfield+127                                  ; FC2A AD 89 03
        sta     PPUDATA                                        ; FC2D 8D 07 20
        lda     playfield+137                                  ; FC30 AD 93 03
        sta     PPUDATA                                        ; FC33 8D 07 20
        lda     playfield+147                                  ; FC36 AD 9D 03
        sta     PPUDATA                                        ; FC39 8D 07 20
        lda     playfield+157                                  ; FC3C AD A7 03
        sta     PPUDATA                                        ; FC3F 8D 07 20
        lda     playfield+167                                  ; FC42 AD B1 03
        sta     PPUDATA                                        ; FC45 8D 07 20
        lda     playfield+177                                  ; FC48 AD BB 03
        sta     PPUDATA                                        ; FC4B 8D 07 20
        lda     playfield+187                                  ; FC4E AD C5 03
        sta     PPUDATA                                        ; FC51 8D 07 20
        lda     playfield+197                                  ; FC54 AD CF 03
        sta     PPUDATA                                        ; FC57 8D 07 20
        lda     #<renderPlayfieldColumns89                     ; FC5A A9 68
        sta     jmp1E                                          ; FC5C 85 1E
        lda     #>renderPlayfieldColumns89                     ; FC5E A9 FC
        sta     jmp1E+1                                        ; FC60 85 1F
        jsr     LFF2A                                          ; FC62 20 2A FF
        jmp     jumpToFinishNmi                                ; FC65 4C 2D FF

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
renderPlayfieldColumns89:
        lda     ppuNametableSelect                             ; FC68 A5 29
        asl     a                                              ; FC6A 0A
        asl     a                                              ; FC6B 0A
        adc     #$20                                           ; FC6C 69 20
        sta     PPUADDR                                        ; FC6E 8D 06 20
        lda     #$D4                                           ; FC71 A9 D4
        sta     PPUADDR                                        ; FC73 8D 06 20
        lda     playfield+8                                    ; FC76 AD 12 03
        sta     PPUDATA                                        ; FC79 8D 07 20
        lda     playfield+18                                   ; FC7C AD 1C 03
        sta     PPUDATA                                        ; FC7F 8D 07 20
        lda     playfield+28                                   ; FC82 AD 26 03
        sta     PPUDATA                                        ; FC85 8D 07 20
        lda     playfield+38                                   ; FC88 AD 30 03
        sta     PPUDATA                                        ; FC8B 8D 07 20
        lda     playfield+48                                   ; FC8E AD 3A 03
        sta     PPUDATA                                        ; FC91 8D 07 20
        lda     playfield+58                                   ; FC94 AD 44 03
        sta     PPUDATA                                        ; FC97 8D 07 20
        lda     playfield+68                                   ; FC9A AD 4E 03
        sta     PPUDATA                                        ; FC9D 8D 07 20
        lda     playfield+78                                   ; FCA0 AD 58 03
        sta     PPUDATA                                        ; FCA3 8D 07 20
        lda     playfield+88                                   ; FCA6 AD 62 03
        sta     PPUDATA                                        ; FCA9 8D 07 20
        lda     playfield+98                                   ; FCAC AD 6C 03
        sta     PPUDATA                                        ; FCAF 8D 07 20
        lda     playfield+108                                  ; FCB2 AD 76 03
        sta     PPUDATA                                        ; FCB5 8D 07 20
        lda     playfield+118                                  ; FCB8 AD 80 03
        sta     PPUDATA                                        ; FCBB 8D 07 20
        lda     playfield+128                                  ; FCBE AD 8A 03
        sta     PPUDATA                                        ; FCC1 8D 07 20
        lda     playfield+138                                  ; FCC4 AD 94 03
        sta     PPUDATA                                        ; FCC7 8D 07 20
        lda     playfield+148                                  ; FCCA AD 9E 03
        sta     PPUDATA                                        ; FCCD 8D 07 20
        lda     playfield+158                                  ; FCD0 AD A8 03
        sta     PPUDATA                                        ; FCD3 8D 07 20
        lda     playfield+168                                  ; FCD6 AD B2 03
        sta     PPUDATA                                        ; FCD9 8D 07 20
        lda     playfield+178                                  ; FCDC AD BC 03
        sta     PPUDATA                                        ; FCDF 8D 07 20
        lda     playfield+188                                  ; FCE2 AD C6 03
        sta     PPUDATA                                        ; FCE5 8D 07 20
        lda     playfield+198                                  ; FCE8 AD D0 03
        sta     PPUDATA                                        ; FCEB 8D 07 20
        lda     ppuNametableSelect                             ; FCEE A5 29
        asl     a                                              ; FCF0 0A
        asl     a                                              ; FCF1 0A
        adc     #$20                                           ; FCF2 69 20
        sta     PPUADDR                                        ; FCF4 8D 06 20
        lda     #$D5                                           ; FCF7 A9 D5
        sta     PPUADDR                                        ; FCF9 8D 06 20
        lda     playfield+9                                    ; FCFC AD 13 03
        sta     PPUDATA                                        ; FCFF 8D 07 20
        lda     playfield+19                                   ; FD02 AD 1D 03
        sta     PPUDATA                                        ; FD05 8D 07 20
        lda     playfield+29                                   ; FD08 AD 27 03
        sta     PPUDATA                                        ; FD0B 8D 07 20
        lda     playfield+39                                   ; FD0E AD 31 03
        sta     PPUDATA                                        ; FD11 8D 07 20
        lda     playfield+49                                   ; FD14 AD 3B 03
        sta     PPUDATA                                        ; FD17 8D 07 20
        lda     playfield+59                                   ; FD1A AD 45 03
        sta     PPUDATA                                        ; FD1D 8D 07 20
        lda     playfield+69                                   ; FD20 AD 4F 03
        sta     PPUDATA                                        ; FD23 8D 07 20
        lda     playfield+79                                   ; FD26 AD 59 03
        sta     PPUDATA                                        ; FD29 8D 07 20
        lda     playfield+89                                   ; FD2C AD 63 03
        sta     PPUDATA                                        ; FD2F 8D 07 20
        lda     playfield+99                                   ; FD32 AD 6D 03
        sta     PPUDATA                                        ; FD35 8D 07 20
        lda     playfield+109                                  ; FD38 AD 77 03
        sta     PPUDATA                                        ; FD3B 8D 07 20
        lda     playfield+119                                  ; FD3E AD 81 03
        sta     PPUDATA                                        ; FD41 8D 07 20
        lda     playfield+129                                  ; FD44 AD 8B 03
        sta     PPUDATA                                        ; FD47 8D 07 20
        lda     playfield+139                                  ; FD4A AD 95 03
        sta     PPUDATA                                        ; FD4D 8D 07 20
        lda     playfield+149                                  ; FD50 AD 9F 03
        sta     PPUDATA                                        ; FD53 8D 07 20
        lda     playfield+159                                  ; FD56 AD A9 03
        sta     PPUDATA                                        ; FD59 8D 07 20
        lda     playfield+169                                  ; FD5C AD B3 03
        sta     PPUDATA                                        ; FD5F 8D 07 20
        lda     playfield+179                                  ; FD62 AD BD 03
        sta     PPUDATA                                        ; FD65 8D 07 20
        lda     playfield+189                                  ; FD68 AD C7 03
        sta     PPUDATA                                        ; FD6B 8D 07 20
        lda     playfield+199                                  ; FD6E AD D1 03
        sta     PPUDATA                                        ; FD71 8D 07 20
        lda     #<unknownRoutine07                             ; FD74 A9 30
        sta     jmp1E                                          ; FD76 85 1E
        lda     #>unknownRoutine07                             ; FD78 A9 FF
        sta     jmp1E+1                                        ; FD7A 85 1F
        lda     #$00                                           ; FD7C A9 00
        sta     ppuRenderDirection                             ; FD7E 85 35
        jsr     LFF2A                                          ; FD80 20 2A FF
        jmp     jumpToFinishNmi                                ; FD83 4C 2D FF

; ----------------------------------------------------------------------------
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FD86 00 00 00 00 00 00 00 00
        .byte   $00,$00                                        ; FD8E 00 00
LFD90:
        .byte   $00,$00,$00,$00,$00,$06,$06,$00                ; FD90 00 00 00 00 00 06 06 00
        .byte   $00,$06,$06,$00,$00,$00,$00,$00                ; FD98 00 06 06 00 00 00 00 00
LFDA0:
        .byte   $00,$00,$00,$00,$00,$02,$02,$00                ; FDA0 00 00 00 00 00 02 02 00
        .byte   $00,$00,$02,$02,$00,$00,$00,$00                ; FDA8 00 00 02 02 00 00 00 00
LFDB0:
        .byte   $00,$00,$00,$02,$00,$00,$02,$02                ; FDB0 00 00 00 02 00 00 02 02
        .byte   $00,$00,$02,$00,$00,$00,$00,$00                ; FDB8 00 00 02 00 00 00 00 00
LFDC0:
        .byte   $00,$00,$00,$00,$00,$00,$04,$00                ; FDC0 00 00 00 00 00 00 04 00
        .byte   $04,$04,$04,$00,$00,$00,$00,$00                ; FDC8 04 04 04 00 00 00 00 00
LFDD0:
        .byte   $00,$00,$00,$00,$04,$04,$00,$00                ; FDD0 00 00 00 00 04 04 00 00
        .byte   $00,$04,$00,$00,$00,$04,$00,$00                ; FDD8 00 04 00 00 00 04 00 00
LFDE0:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FDE0 00 00 00 00 00 00 00 00
        .byte   $04,$04,$04,$00,$04,$00,$00,$00                ; FDE8 04 04 04 00 04 00 00 00
LFDF0:
        .byte   $00,$00,$00,$00,$00,$04,$00,$00                ; FDF0 00 00 00 00 00 04 00 00
        .byte   $00,$04,$00,$00,$00,$04,$04,$00                ; FDF8 00 04 00 00 00 04 04 00
LFE00:
        .byte   $00,$00,$00,$00,$00,$00,$01,$01                ; FE00 00 00 00 00 00 00 01 01
        .byte   $00,$01,$01,$00,$00,$00,$00,$00                ; FE08 00 01 01 00 00 00 00 00
LFE10:
        .byte   $00,$00,$01,$00,$00,$00,$01,$01                ; FE10 00 00 01 00 00 00 01 01
        .byte   $00,$00,$00,$01,$00,$00,$00,$00                ; FE18 00 00 00 01 00 00 00 00
LFE20:
        .byte   $00,$00,$00,$00,$03,$00,$00,$00                ; FE20 00 00 00 00 03 00 00 00
        .byte   $03,$03,$03,$00,$00,$00,$00,$00                ; FE28 03 03 03 00 00 00 00 00
LFE30:
        .byte   $00,$00,$00,$00,$00,$03,$00,$00                ; FE30 00 00 00 00 00 03 00 00
        .byte   $00,$03,$00,$00,$03,$03,$00,$00                ; FE38 00 03 00 00 03 03 00 00
LFE40:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FE40 00 00 00 00 00 00 00 00
        .byte   $03,$03,$03,$00,$00,$00,$03,$00                ; FE48 03 03 03 00 00 00 03 00
LFE50:
        .byte   $00,$00,$00,$00,$00,$03,$03,$00                ; FE50 00 00 00 00 00 03 03 00
        .byte   $00,$03,$00,$00,$00,$03,$00,$00                ; FE58 00 03 00 00 00 03 00 00
LFE60:
        .byte   $00,$00,$00,$00,$00,$05,$00,$00                ; FE60 00 00 00 00 00 05 00 00
        .byte   $00,$05,$05,$00,$00,$05,$00,$00                ; FE68 00 05 05 00 00 05 00 00
LFE70:
        .byte   $00,$00,$00,$00,$00,$05,$00,$00                ; FE70 00 00 00 00 00 05 00 00
        .byte   $05,$05,$05,$00,$00,$00,$00,$00                ; FE78 05 05 05 00 00 00 00 00
LFE80:
        .byte   $00,$00,$00,$00,$00,$05,$00,$00                ; FE80 00 00 00 00 00 05 00 00
        .byte   $05,$05,$00,$00,$00,$05,$00,$00                ; FE88 05 05 00 00 00 05 00 00
LFE90:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FE90 00 00 00 00 00 00 00 00
        .byte   $05,$05,$05,$00,$00,$05,$00,$00                ; FE98 05 05 05 00 00 05 00 00
LFEA0:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FEA0 00 00 00 00 00 00 00 00
        .byte   $0A,$0B,$0B,$0C,$00,$00,$00,$00                ; FEA8 0A 0B 0B 0C 00 00 00 00
LFEB0:
        .byte   $00,$07,$00,$00,$00,$08,$00,$00                ; FEB0 00 07 00 00 00 08 00 00
        .byte   $00,$08,$00,$00,$00,$09,$00,$00                ; FEB8 00 08 00 00 00 09 00 00
; ----------------------------------------------------------------------------
LFEC0:
        .addr   LFD90                                          ; FEC0 90 FD
        .addr   LFD90                                          ; FEC2 90 FD
        .addr   LFD90                                          ; FEC4 90 FD
        .addr   LFD90                                          ; FEC6 90 FD
        .addr   LFDC0                                          ; FEC8 C0 FD
        .addr   LFDD0                                          ; FECA D0 FD
        .addr   LFDE0                                          ; FECC E0 FD
        .addr   LFDF0                                          ; FECE F0 FD
        .addr   LFE20                                          ; FED0 20 FE
        .addr   LFE30                                          ; FED2 30 FE
        .addr   LFE40                                          ; FED4 40 FE
        .addr   LFE50                                          ; FED6 50 FE
        .addr   LFE00                                          ; FED8 00 FE
        .addr   LFE10                                          ; FEDA 10 FE
        .addr   LFE00                                          ; FEDC 00 FE
        .addr   LFE10                                          ; FEDE 10 FE
        .addr   LFDA0                                          ; FEE0 A0 FD
        .addr   LFDB0                                          ; FEE2 B0 FD
        .addr   LFDA0                                          ; FEE4 A0 FD
        .addr   LFDB0                                          ; FEE6 B0 FD
        .addr   LFEA0                                          ; FEE8 A0 FE
        .addr   LFEB0                                          ; FEEA B0 FE
        .addr   LFEA0                                          ; FEEC A0 FE
        .addr   LFEB0                                          ; FEEE B0 FE
        .addr   LFE60                                          ; FEF0 60 FE
        .addr   LFE70                                          ; FEF2 70 FE
        .addr   LFE80                                          ; FEF4 80 FE
        .addr   LFE90                                          ; FEF6 90 FE
; ----------------------------------------------------------------------------
        .byte   $BD,$4E,$FF,$FF,$FF,$00,$FF,$F8                ; FEF8 BD 4E FF FF FF 00 FF F8
; ----------------------------------------------------------------------------
LFF00:
        jmp     generateNextPseudoRandomNumber                 ; FF00 4C 92 90

; ----------------------------------------------------------------------------
LFF03:
        jmp     L9059                                          ; FF03 4C 59 90

; ----------------------------------------------------------------------------
        jmp     L9054                                          ; FF06 4C 54 90

; ----------------------------------------------------------------------------
LFF09:
        jmp     L902E                                          ; FF09 4C 2E 90

; ----------------------------------------------------------------------------
LFF0C:
        jmp     L92DD                                          ; FF0C 4C DD 92

; ----------------------------------------------------------------------------
        jmp     L93C6                                          ; FF0F 4C C6 93

; ----------------------------------------------------------------------------
LFF12:
        jmp     pollController                                 ; FF12 4C CE 8F

; ----------------------------------------------------------------------------
        jmp     L9323                                          ; FF15 4C 23 93

; ----------------------------------------------------------------------------
        jmp     resetOamStaging                                ; FF18 4C 53 83

; ----------------------------------------------------------------------------
        jmp     L908C                                          ; FF1B 4C 8C 90

; ----------------------------------------------------------------------------
LFF1E:
        jmp     LC3CB                                          ; FF1E 4C CB C3

; ----------------------------------------------------------------------------
LFF21:
        jmp     L8341                                          ; FF21 4C 41 83

; ----------------------------------------------------------------------------
        jmp     cnromOrMMC1BankSwitch                          ; FF24 4C 97 8F

; ----------------------------------------------------------------------------
LFF27:
        jmp     L90F9                                          ; FF27 4C F9 90

; ----------------------------------------------------------------------------
LFF2A:
        jmp     resetPpuRegistersAndCopyOamStaging             ; FF2A 4C 2C 80

; ----------------------------------------------------------------------------
jumpToFinishNmi:
        jmp     finishNmi                                      ; FF2D 4C 4F 80

; ----------------------------------------------------------------------------
; can be jumped to using 1E/1F
unknownRoutine07:
        jmp     unknownRoutine02                               ; FF30 4C 86 80

; ----------------------------------------------------------------------------
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF33 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$40,$00,$00,$00                ; FF3B 00 00 00 00 40 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF43 00 00 00 00 00 00 00 00
        .byte   $01,$00,$00,$00,$00,$00,$00,$00                ; FF4B 01 00 00 00 00 00 00 00
        .byte   $00,$8C,$20,$81,$61,$00,$00,$00                ; FF53 00 8C 20 81 61 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF5B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF63 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF6B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF73 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF7B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF83 00 00 00 00 00 00 00 00
        .byte   $00,$04,$00,$00,$00,$00,$80,$00                ; FF8B 00 04 00 00 00 00 80 00
        .byte   $00,$20,$F1,$90,$A2,$00,$00,$00                ; FF93 00 20 F1 90 A2 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FF9B 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FFA3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FFAB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$08,$00,$00,$00,$00,$00                ; FFB3 00 00 08 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FFBB 00 00 00 00 00 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FFC3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$04,$00,$00,$00,$00,$00                ; FFCB 00 00 04 00 00 00 00 00
        .byte   $00,$80,$39,$04,$10,$00,$00,$00                ; FFD3 00 80 39 04 10 00 00 00
        .byte   $00,$00,$01,$00,$01,$00,$00,$00                ; FFDB 00 00 01 00 01 00 00 00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00                ; FFE3 00 00 00 00 00 00 00 00
        .byte   $00,$00,$01,$FF,$00,$01,$00,$00                ; FFEB 00 00 01 FF 00 01 00 00
        .byte   $00,$89,$80,$A5,$04,$53,$80                    ; FFF3 00 89 80 A5 04 53 80
; ----------------------------------------------------------------------------

.segment        "VECTORS": absolute

        .addr   nmi                                            ; FFFA 04 80
        .addr   reset                                          ; FFFC 00 80
        .addr   irq                                            ; FFFE 03 80

; End of "VECTORS" segment
; ----------------------------------------------------------------------------
.code

