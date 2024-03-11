.zeropage
.res 18
tmp12:	.res 1	; $0012
tmp13:	.res 1	; $0013
tmp14:	.res 1	; $0014
tmp15:	.res 1	; $0015
.res 8
jmp1E:	.res $2	; $001E
.res 11
aBackup:	.res 1	; $002B
xBackup:	.res 1	; $002C
yBackup:	.res 1	; $002D
.res 1
controllerBeingRead:	.res 1	; $002F
controllerInput:	.res 1	; $0030
.res 11
nmiWaitVar:	.res 1	; $003C
.res 25
rngSeed:	.res $9	; $0056
.res 160
lastZPAddress:	.res 1	; $00FF

.bss
stack:	.res $100	; $0100
oamStaging:	.res $100	; $0200
.res 10
playfield:	.res $C8	; $030A
playfieldStash:	.res $C8	; $03D2
