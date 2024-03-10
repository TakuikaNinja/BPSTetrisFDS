.segment "INES"
.include "ines.asm"
.scope bank0 
.segment "PRG0" 
.include "bank0.asm" 
.endscope 

.segment "CHR" 
.incbin "clean.nes", $8010, $4000 
