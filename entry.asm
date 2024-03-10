.segment "HEADER"
.include "header.asm"
.scope bank0 
.segment "PRG0" 
.include "main.asm" 
.endscope 

.segment "CHR" 
.incbin "gfx/tileset_gamemenu_00.chr"
.incbin "gfx/tileset_dancers_01.chr"
.incbin "gfx/tileset_02.chr"
.incbin "gfx/tileset_ending_03.chr"
