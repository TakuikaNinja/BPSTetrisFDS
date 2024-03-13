.zeropage
.res 16
ppuStageSource:	.res $2	; $0010
ppuStageDest:	.res $2	; $0012
tmp14:	.res 1	; $0014
tmp15:	.res 1	; $0015
.res 8
renderJump:	.res $2	; $001E
.res 4
mmc1RegisterDest:	.res $2	; $0024
.res 3
ppuNametableSelect:	.res 1	; $0029
.res 1
aBackup:	.res 1	; $002B
xBackup:	.res 1	; $002C
yBackup:	.res 1	; $002D
currentPpuMask:	.res 1	; $002E
controllerBeingRead:	.res 1	; $002F
controllerInput:	.res 1	; $0030
.res 2
ppuStageRepeatsUnused:	.res 1	; $0033
ppuStageLength:	.res 1	; $0034
ppuRenderDirection:	.res 1	; $0035
currentScrollX:	.res 1	; $0036
currentScrollY:	.res 1	; $0037
aStorage:	.res 1	; $0038
.res 1
startStorage:	.res 1	; $003A
selectStorage:	.res 1	; $003B
nmiWaitVar:	.res 1	; $003C
ppuPatternTables:	.res 1	; $003D
ppuStageRepeats:	.res 1	; $003E
fallTimer:	.res 1	; $003F
.res 2
unknownCounter:	.res 1	; $0042
.res 19
rngSeed:	.res $9	; $0056
.res 160
lastZPAddress:	.res 1	; $00FF

.bss
stack:	.res $100	; $0100
oamStaging:	.res $100	; $0200
.res 10
playfield:	.res $C8	; $030A
playfieldStash:	.res $C8	; $03D2
paletteStagingRam049A:	.res $10	; $049A
paletteStagingRam04AA:	.res $10	; $04AA
.res 182
tetrominoX_A:	.res 1	; $0570
tetrominoY_A:	.res 1	; $0571
.res 1
tetrominoOrientation_A:	.res 1	; $0573
.res 1
fallTimerReset:	.res 1	; $0575
.res 14
tetrominoX_B:	.res 1	; $0584
tetrominoY_B:	.res 1	; $0585
tetrominoOrientation_B:	.res 1	; $0586
.res 14
levelNumber:	.res 1	; $0595
roundNumber:	.res 1	; $0596
.res 126
maxMusicOptions:	.res 1	; $0615
