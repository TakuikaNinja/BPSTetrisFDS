# BPS Tetris FDS

This is a proof-of-concept port of BPS Tetris from the Famicom to the Famicom Disk System, similar to [TetrisFDS](https://github.com/TakuikaNinja/TetrisFDS).

## Pirate Disk Info

Two pirate disks of this game are known to exist - one has normal pieces and the other has custom pieces. A dump was supposedly catalogued, then removed from no-intro during 2014.

Footage of version with custom pieces: https://youtu.be/Uwv05HCpWKQ

## Build Requirements

* gcc
* make
* cc65
* python (with pillow library)


## Build

`make`

This will ouput a file `tetris.fds`.

## Thanks

Original disassembly: https://github.com/zohassadar/BPSTetrisDisasm
