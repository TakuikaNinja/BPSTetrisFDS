.segment "HEADER"
.include "header.asm"
.include "constants.asm"
.scope bank0 
.segment "FILE0_DAT"
.include "main.asm"

.segment "FILE1_DAT"
; this routine is entered by interrupting the last boot file load
; by forcing an NMI not expected by the BIOS, allowing the license
; screen to be skipped entirely.
;
; The last file writes $90 to $2000, enabling NMI during the file load.
; The "extra" file in the FILE_COUNT causes the disk to keep seeking
; past the last file, giving enough delay for an NMI to fire and interrupt
; the process.
bypass:
        ; disable NMI
        lda     #0
        sta     PPUCTRL
        ; replace NMI 3 "bypass" vector at $DFFA
        lda     #<nmi
        sta     $DFFA
        lda     #>nmi
        sta     $DFFB
        ; tell the FDS reset routine that the BIOS initialized correctly
        lda     #$35
        sta     stack+2
        lda     #$AC
        sta     stack+3
        ; reset the FDS to begin our program properly
        jmp     ($FFFC)
.endscope 

.segment "FILE2_DAT"
.incbin "gfx/tileset_gamemenu_00.chr"
.incbin "gfx/tileset_dancers_01.chr"
;.incbin "gfx/tileset_02.chr"
;.incbin "gfx/tileset_ending_03.chr"
