;
; FDS disk files
;

; This layout is modified from Brad Smith (rainwarrior)'s FDS example for CA65
; https://github.com/bbbradsmith/NES-ca65-example/tree/fds

FILE_COUNT = 5

.segment "SIDE1A"
; block 1
.byte $01
.byte "*NINTENDO-HVC*"
.byte $00 ; manufacturer
.byte "T0D" ; the original ID was "T0", which makes it hard to create a 3-letter name...
.byte ' ' ; normal disk (another example: 'E'=event)
.byte $01 ; game version 1, since this has altered code
.byte $00 ; side
.byte $00 ; disk
.byte $00 ; disk type
.byte $00 ; unknown
.byte FILE_COUNT ; boot file count
.byte $FF,$FF,$FF,$FF,$FF

; manufacturing date will use the rev 2 release date
.byte $63 ; 1988 (showa era)
.byte $12 ; december
.byte $22 ; 22

.byte $49 ; country
.byte $61, $00, $00, $02, $00, $00, $00, $00, $00 ; unknown

; 2025 (port release year) does not fit into the showa era format used by disk writers, 
; so use the same date as manufacturing...
.byte $63 ; 1988 (showa era)
.byte $12 ; december
.byte $22 ; 22

.byte $00, $80 ; unknown
.byte $00, $00 ; disk writer serial number
.byte $07 ; unknown
.byte $00 ; disk write count
.byte $00 ; actual disk side
.byte $00 ; disk type?
.byte $00 ; disk version?

; block 2
.byte $02
.byte FILE_COUNT

.segment "FILE0_HDR"
; block 3
.import __FILE0_DAT_RUN__
.import __FILE0_DAT_SIZE__
.byte $03
.byte 0,0
.byte "FILE0..."
.word __FILE0_DAT_RUN__
.word __FILE0_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
;.segment "FILE0_DAT"
;.incbin "" ; this is code below

.segment "FILE1_HDR"
; block 3
.import __FILE1_DAT_RUN__
.import __FILE1_DAT_SIZE__
.byte $03
.byte 1,1
.byte "FILE1..."
.word __FILE1_DAT_RUN__
.word __FILE1_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
;.segment "FILE1_DAT"
;.incbin "" ; this is code below

.segment "FILE2_HDR"
; block 3
.import __FILE2_DAT_SIZE__
.import __FILE2_DAT_RUN__
.byte $03
.byte 2,2
.byte "FILE2..."
.word __FILE2_DAT_RUN__
.word __FILE2_DAT_SIZE__
.byte 1 ; CHR
; block 4
.byte $04
;.segment "FILE2_DAT"
;.incbin "" ; this is code below

; This block is the last to load, and enables NMI by "loading" the NMI enable value
; directly into the PPU control register at $2000.
; While the disk loader continues searching for one more boot file,
; eventually an NMI fires, allowing us to take control of the CPU before the
; license screen is displayed.
.segment "FILE3_HDR"
; block 3
.import __FILE3_DAT_SIZE__
.import __FILE3_DAT_RUN__
.byte $03
.byte 3,3
.byte "FILE3..."
.word __FILE3_DAT_RUN__
.word __FILE3_DAT_SIZE__
.byte 0 ; PRG (CPU:$2000)
; block 4
.byte $04
.segment "FILE3_DAT"
.byte $90 ; enable NMI byte sent to $2000

; This file is never loaded, but is large enough for an NMI to fire while the BIOS is seeking
; the disk during the boot process.
.segment "FILE4_HDR"
; block 3
.import __FILE4_DAT_SIZE__
.import __FILE4_DAT_RUN__
.byte $03
.byte 4,$FF
.byte "FILE4..."
.word __FILE4_DAT_RUN__
.word __FILE4_DAT_SIZE__
.byte 0 ; PRG
; block 4
.byte $04
.segment "FILE4_DAT"
.res $1000

