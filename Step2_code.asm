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
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR

load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; reset scroll to (0,0)
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  ; Clear nametable to remove garbage data
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  
  LDA #$00  ; tile 0 (empty)
  LDX #$00
  LDY #$04  ; clear 4 pages (1024 bytes = full nametable)
clear_nametable:
  STA PPUDATA
  INX
  BNE clear_nametable
  DEY
  BNE clear_nametable

; ------------------------------------------------------------
  ; Step 2: draw 6 brick metatiles (2x2 tiles each) from top-left
  ; Each metatile drawn individually for clarity
  ; ------------------------------------------------------------

  ; ========== METATILE 1 at position (0,0) ==========
  ; Uses PALETTE 0, COLOR 1 = YELLOW
  ; Top row of metatile 1 at $2000
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDA #$05  ; tile 5 - top-left
  STA PPUDATA
  LDA #$06  ; tile 6 - top-right
  STA PPUDATA

  ; Bottom row of metatile 1 at $2020
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$20
  STA PPUADDR
  LDA #$07  ; tile 7 - bottom-left
  STA PPUDATA
  LDA #$08  ; tile 8 - bottom-right
  STA PPUDATA

  ; ========== METATILE 2 at position (2,0) ==========
  ; Uses PALETTE 1, COLOR 1 = GREEN
  ; Top row of metatile 2 at $2002
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$02
  STA PPUADDR
  LDA #$05  ; tile 5 - top-left
  STA PPUDATA
  LDA #$06  ; tile 6 - top-right
  STA PPUDATA

  ; Bottom row of metatile 2 at $2022
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$22
  STA PPUADDR
  LDA #$07  ; tile 7 - bottom-left
  STA PPUDATA
  LDA #$08  ; tile 8 - bottom-right
  STA PPUDATA

  ; ========== METATILE 3 at position (4,0) ==========
  ; Uses PALETTE 2, COLOR 1 = RED
  ; Top row of metatile 3 at $2004
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$04
  STA PPUADDR
  LDA #$05  ; tile 5 - top-left
  STA PPUDATA
  LDA #$06  ; tile 6 - top-right
  STA PPUDATA

  ; Bottom row of metatile 3 at $2024
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$24
  STA PPUADDR
  LDA #$07  ; tile 7 - bottom-left
  STA PPUDATA
  LDA #$08  ; tile 8 - bottom-right
  STA PPUDATA

  ; ========== METATILE 4 at position (6,0) ==========
  ; Uses PALETTE 3, COLOR 1 = CYAN
  ; Top row of metatile 4 at $2006
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$06
  STA PPUADDR
  LDA #$05  ; tile 5 - top-left
  STA PPUDATA
  LDA #$06  ; tile 6 - top-right
  STA PPUDATA

  ; Bottom row of metatile 4 at $2026
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$26
  STA PPUADDR
  LDA #$07  ; tile 7 - bottom-left
  STA PPUDATA
  LDA #$08  ; tile 8 - bottom-right
  STA PPUDATA

  ; ========== METATILE 5 at position (8,0) ==========
  ; Uses PALETTE 0, COLOR 2 = WHITE
  ; Top row of metatile 5 at $2008
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$08
  STA PPUADDR
  LDA #$09  ; tile 9 - top-left (color 2)
  STA PPUDATA
  LDA #$0A  ; tile 10 - top-right (color 2)
  STA PPUDATA

  ; Bottom row of metatile 5 at $2028
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$28
  STA PPUADDR
  LDA #$0B  ; tile 11 - bottom-left (color 2)
  STA PPUDATA
  LDA #$0C  ; tile 12 - bottom-right (color 2)
  STA PPUDATA

  ; ========== METATILE 6 at position (10,0) ==========
  ; Uses PALETTE 1, COLOR 2 = LIGHT GREEN  
  ; Top row of metatile 6 at $200A
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$0A
  STA PPUADDR
  LDA #$09  ; tile 9 - top-left (color 2)
  STA PPUDATA
  LDA #$0A  ; tile 10 - top-right (color 2)
  STA PPUDATA

  ; Bottom row of metatile 6 at $202A
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$2A
  STA PPUADDR
  LDA #$0B  ; tile 11 - bottom-left (color 2)
  STA PPUDATA
  LDA #$0C  ; tile 12 - bottom-right (color 2)
  STA PPUDATA


  ; ========== METATILE 7 at position (12,0) ==========
  ; Uses PALETTE 3, COLOR 2 = BLUE
  ; Type B brick (tiles 9-12)
  ; Top row of metatile 7 at $200C
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$0C
  STA PPUADDR
  LDA #$09  ; tile 9 - top-left (type B)
  STA PPUDATA
  LDA #$0A  ; tile 10 - top-right (type B)
  STA PPUDATA

  ; Bottom row of metatile 7 at $202C
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$2C
  STA PPUADDR
  LDA #$0B  ; tile 11 - bottom-left (type B)
  STA PPUDATA
  LDA #$0C  ; tile 12 - bottom-right (type B)
  STA PPUDATA

  ; ============================================================
  ; ATTRIBUTE TABLE - Manual palette assignment per metatile
  ; ============================================================
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR

  ; $23C0: Metatile 1 = Palette 0 (WHITE), Metatile 2 = Palette 1 (GREEN)
  LDA #%00000100  
  STA PPUDATA

  ; $23C1: Metatile 3 = Palette 2 (RED), Metatile 4 = Palette 3 (CYAN)
  LDA #%00001110  
  STA PPUDATA

  ; $23C2: Metatile 5 = Palette 0 (YELLOW), Metatile 6 = Palette 1 (LIGHT GREEN)
  LDA #%00000100  
  STA PPUDATA

  ; $23C3: Metatile 7 = Palette 3 (BLUE)
  LDA #%00000011
  STA PPUDATA

  ; ============================================================
  ; DRAW "HELLO" TEXT
  ; ============================================================
  LDA PPUSTATUS 
  LDA #$21
  STA PPUADDR
  LDA #$89
  STA PPUADDR
  LDX #$01 ; H
  STX PPUDATA
  LDX #$02 ; E
  STX PPUDATA
  LDX #$03 ; L
  STX PPUDATA
  LDX #$03 ; L
  STX PPUDATA
  LDX #$04 ; O
  STX PPUDATA

  ; ============================================================
  ; HELLO TEXT ATTRIBUTES - force HELLO to Palette 0 (WHITE)
  ; HELLO starts at $2189 -> attribute byte $23DA, top-left quadrant bits 1-0
  ; ============================================================
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$DA
  STA PPUADDR
  ; bits 1-0 = 00 -> Palette 0
  LDA #%00000000 
  STA PPUDATA

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10000000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
  ; Background palette 0: color1=WHITE, color2=YELLOW
  .byte $0f, $30, $28, $38
  ; Background palette 1: color1=GREEN, color2=LIGHT GREEN
  .byte $0f, $1A, $2A, $0A
  ; Background palette 2: color1=RED, color2=ORANGE
  .byte $0f, $16, $27, $06
  ; Background palette 3: color1=CYAN, color2=BLUE
  .byte $0f, $2C, $12, $22

  ; Sprite palettes (not used)
  .byte $0f, $20, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00


.segment "CHR"
chr_start:
; ----------------
; tile 0 = empty
; ----------------
.byte $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00

; ----------------
; tile 1 = 'H'
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
; tile 2 = 'E'
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
; tile 3 = 'L'
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
; tile 4 = 'O'
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

; ----------------
; tile 5 = brick A (top-left 8x8)
; ----------------
  .byte $FF, $FF, $40, $3F, $7F, $00, $0F, $FF
  ; plane 1
  .byte $FF, $FF, $80, $00, $00, $7F, $FF, $04

; ----------------
; tile 6 = brick A (top-right 8x8)
; ----------------
  .byte $FF, $FF, $03, $FF, $FD, $01, $00, $FF
  ; plane 1
  .byte $FF, $FF, $01, $01, $03, $FF, $FF, $00

; ----------------
; tile 7 = brick A (bottom-left 8x8)
; ----------------
  .byte $FF, $FB, $04, $00, $00, $FF, $FF, $00
  ; plane 1
  .byte $04, $04, $FF, $FF, $00, $00, $00, $FF

; ----------------
; tile 8 = brick A (bottom-right 8x8)
; ----------------
  .byte $FF, $FF, $00, $60, $E0, $BF, $BF, $60
  ; plane 1
  .byte $00, $00, $FF, $FF, $60, $40, $40, $DF

; ----------------
; tile 9 = brick B (top-left 8x8)  (bisel: borde claro arriba/izq)
; color3 = borde arriba/izq, color1 = relleno
; ----------------
  ; plane 0
  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  ; plane 1
  .byte $FF, $80, $80, $80, $80, $80, $80, $80

; ----------------
; tile 10 = brick B (top-right 8x8)
; color3 = borde arriba, color2 = borde derecha, color1 = relleno
; ----------------
  ; plane 0
  .byte $FF, $FE, $FE, $FE, $FE, $FE, $FE, $FE
  ; plane 1
  .byte $FF, $01, $01, $01, $01, $01, $01, $01

; ----------------
; tile 11 = brick B (bottom-left 8x8)
; color3 = borde izquierda, color2 = borde abajo (toda la última fila)
; ----------------
  ; plane 0
  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00
  ; plane 1
  .byte $80, $80, $80, $80, $80, $80, $80, $FF

; ----------------
; tile 12 = brick B (bottom-right 8x8)
; color2 = borde derecha y borde abajo (última fila completa)
; ----------------
  ; plane 0
  .byte $FE, $FE, $FE, $FE, $FE, $FE, $FE, $00
  ; plane 1
  .byte $01, $01, $01, $01, $01, $01, $01, $FF

; Pad remaining CHR ROM to 8KB (1 bank)
.res $2000 - (* - chr_start)
