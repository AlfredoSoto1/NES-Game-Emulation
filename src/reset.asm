.include "constants.inc"

.segment "CODE"

.import main
.export reset_handler

.proc reset_handler
  SEI
  CLD

  LDX #$40
  STX $4017       ; APU frame counter

  LDX #$FF
  TXS             ; set up stack
  INX             ; X = 0

  STX PPUCTRL     ; disable NMI
  STX PPUMASK     ; disable rendering
  STX $4010       ; disable DMC IRQs

  BIT PPUSTATUS   ; clear vblank flag

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2

  JMP main
.endproc
