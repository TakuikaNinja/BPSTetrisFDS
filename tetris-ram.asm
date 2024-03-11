.zeropage
.res 18
tmp12:	.res 1	; $0012
tmp13:	.res 1	; $0013
tmp14:	.res 1	; $0014
tmp15:	.res 1	; $0015
.res 21
aBackup:	.res 1	; $002B
xBackup:	.res 1	; $002C
yBackup:	.res 1	; $002D
.res 2
controllerInput:	.res 1	; $0030
.res 11
nmiWaitVar:	.res 1	; $003C
.res 25
rngSeed:	.res $7	; $0056
.res 162
lastZPAddress:	.res 1	; $00FF

.bss
stack:	.res $100	; $0100
oamStaging:	.res $100	; $0200
