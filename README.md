# BPS Famicom Tetris Disassembly

Work in progress


## Build Requirements

* gcc
* make
* cc65
* python (with pillow library)

## Disassemble

Requires a backup of the original game with the filename `clean.nes` in the project root directory.

main.asm is dynamically generated using main.infofile.  To update, add label information to main.infofile and run `make disassembly`.  This will update main.asm with the new labels as well as run `make compare` to validate the new main.asm produces the expected result.

## Build

`make`

This will ouput a file `tetris.nes` with the following:

```
sha1sum: 218dbaa3827650c9ad9917f41f2d886aeb688c58
md5sum: e986b2e5202e16c480241a5c866f4bb2
```

## Validate

`make compare`

## Thanks

[threecreepio](https://github.com/threecreepio/da65ify) getting this started

[CelestialAmber](https://github.com/CelestialAmber/TetrisNESDisasm) disassembly structure

[ejona86](https://github.com/ejona86/taus) info file structure and tetris-ram.awk

[qalle2](https://github.com/qalle2/nes-util) CHR tools

[kirjavascript](https://github.com/kirjavascript/TetrisGYM) borrowed bits
