.include "constants.inc"
.include "header.inc"

.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  RTI
.endproc

.import reset_handler

.export main
.proc main
  ; -----------------------------
  ; Set palette at $3F00
  ; -----------------------------
  LDX PPUSTATUS
  LDX #$3F
  STX PPUADDR
  LDX #$00
  STX PPUADDR

  ; Background universal color (color 0)
  LDA #$0F        ; black
  STA PPUDATA

  ; Background palette color 1 (used by our tile pixels = value 1)
  LDA #$29        ; a visible color (same one you used)
  STA PPUDATA

  ; Fill rest of palette entries (optional but nice)
  LDA #$00
  STA PPUDATA
  STA PPUDATA

  ; -----------------------------
  ; Write "HELLO" to nametable
  ; Nametable 0 starts at $2000
  ; We'll put it at row 12, col 10:
  ; addr = $2000 + (12*32) + 10 = $218A
  ; -----------------------------
  BIT PPUSTATUS
  LDA #$21
  STA PPUADDR
  LDA #$8A
  STA PPUADDR

  ; Write tile indices: H E L L O
  LDA #$00  ; H tile
  STA PPUDATA
  LDA #$01  ; E tile
  STA PPUDATA
  LDA #$02  ; L tile
  STA PPUDATA
  LDA #$02  ; L tile
  STA PPUDATA
  LDA #$03  ; O tile
  STA PPUDATA

  ; -----------------------------
  ; Enable background rendering
  ; -----------------------------
  LDA #%00011110
  STA PPUMASK

forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler


; -----------------------------------------
; CHR ROM: define the tiles pixel-by-pixel
; Tile format: 16 bytes per tile:
;   8 bytes plane 0, then 8 bytes plane 1
; We'll use only plane 0 (plane 1 = 0)
; -----------------------------------------
.segment "CHR"

; ----------------
; tile 0 = 'H'
; ----------------
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11111111
  .byte %11111111
  .byte %11000011
  .byte %11000011
  .byte %11000011
  ; plane 1
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

; ----------------
; tile 1 = 'E'
; ----------------
  .byte %11111111
  .byte %11111111
  .byte %11000000
  .byte %11111100
  .byte %11111100
  .byte %11000000
  .byte %11111111
  .byte %11111111
  ; plane 1
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

; ----------------
; tile 2 = 'L'
; ----------------
  .byte %11000000
  .byte %11000000
  .byte %11000000
  .byte %11000000
  .byte %11000000
  .byte %11000000
  .byte %11111111
  .byte %11111111
  ; plane 1
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

; ----------------
; tile 3 = 'O'
; ----------------
  .byte %00111100
  .byte %01100110
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %11000011
  .byte %01100110
  .byte %00111100
  ; plane 1
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000
  .byte %00000000

; Pad remaining CHR ROM to 8KB (1 bank)
.res 8192 - 64, $00
