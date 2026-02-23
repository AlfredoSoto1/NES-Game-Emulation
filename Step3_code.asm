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
  ; Step 2: draw one full screen (one nametable)
  ; using brick tiles type A (5-8) and type B (9-12)
  ; Bomberman-like layout: borders, hard pillars, soft blocks and paths
  ; ------------------------------------------------------------

  ; Write 30 rows x 32 columns of tiles to $2000-$23BF
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDY #$0F                ; 15 metatile rows (each writes top+bottom tile rows)
draw_meta_rows:
  TYA
  CMP #$0F                ; top border row
  BEQ draw_full_wall_row
  CMP #$01                ; bottom border row
  BEQ draw_full_wall_row

  TYA
  AND #$01
  BNE draw_pillar_row     ; odd interior rows -> hard pillar pattern

draw_soft_row:
  TYA
  AND #$02
  BEQ draw_soft_row_a
  JMP draw_soft_row_b

draw_full_wall_row:
  LDX #$00
full_top_copy:
  LDA full_wall_top, X
  STA PPUDATA
  INX
  CPX #$20                ; 32 tiles per row
  BNE full_top_copy

  LDX #$00
full_bottom_copy:
  LDA full_wall_bottom, X
  STA PPUDATA
  INX
  CPX #$20
  BNE full_bottom_copy
  JMP next_meta_row

draw_pillar_row:
  LDX #$00
pillar_top_copy:
  LDA pillar_row_top, X
  STA PPUDATA
  INX
  CPX #$20
  BNE pillar_top_copy

  LDX #$00
pillar_bottom_copy:
  LDA pillar_row_bottom, X
  STA PPUDATA
  INX
  CPX #$20
  BNE pillar_bottom_copy
  JMP next_meta_row

draw_soft_row_a:
  LDX #$00
soft_a_top_copy:
  LDA soft_row_a_top, X
  STA PPUDATA
  INX
  CPX #$20
  BNE soft_a_top_copy

  LDX #$00
soft_a_bottom_copy:
  LDA soft_row_a_bottom, X
  STA PPUDATA
  INX
  CPX #$20
  BNE soft_a_bottom_copy
  JMP next_meta_row

draw_soft_row_b:
  LDX #$00
soft_b_top_copy:
  LDA soft_row_b_top, X
  STA PPUDATA
  INX
  CPX #$20
  BNE soft_b_top_copy

  LDX #$00
soft_b_bottom_copy:
  LDA soft_row_b_bottom, X
  STA PPUDATA
  INX
  CPX #$20
  BNE soft_b_bottom_copy

next_meta_row:
  DEY
  BEQ meta_rows_done
  JMP draw_meta_rows

meta_rows_done:

  ; ------------------------------------------------------------
  ; Full attribute table ($23C0-$23FF): 64 bytes
  ; Assign palettes 0,1,2,3 in an alternating pattern over the screen
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR

  LDY #$08                ; 8 attribute rows
draw_attr_rows:
  TYA
  AND #$01
  BEQ use_attr_even_row

use_attr_odd_row:
  LDX #$00
attr_odd_copy:
  LDA attr_row_odd, X
  STA PPUDATA
  INX
  CPX #$08                ; 8 bytes per attribute row
  BNE attr_odd_copy
  JMP next_attr_row

use_attr_even_row:
  LDX #$00
attr_even_copy:
  LDA attr_row_even, X
  STA PPUDATA
  INX
  CPX #$08                ; 8 bytes per attribute row
  BNE attr_even_copy

next_attr_row:
  DEY
  BNE draw_attr_rows

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
  ; Background color $1A (green) is shared as color index 0 across all palettes.
  ; Palette 0: brick A = hard stone wall  (white highlight, light gray, dark gray)
  ; $2A = bright green is the universal background color (NES $3F00)
  .byte $2A, $30, $10, $00
  ; Palette 1: brick B = soft destructible block  (yellow, orange, dark brown)
  .byte $2A, $28, $17, $07
  ; Palette 2: (unused - kept for future use)
  .byte $2A, $2A, $1A, $0A
  ; Palette 3: (unused - kept for future use)
  .byte $2A, $21, $11, $01

  ; Sprite palettes (not used)
  .byte $0f, $20, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

full_wall_top:
  .byte $05, $06, $05, $06, $05, $06, $05, $06
  .byte $05, $06, $05, $06, $05, $06, $05, $06
  .byte $05, $06, $05, $06, $05, $06, $05, $06
  .byte $05, $06, $05, $06, $05, $06, $05, $06

full_wall_bottom:
  .byte $07, $08, $07, $08, $07, $08, $07, $08
  .byte $07, $08, $07, $08, $07, $08, $07, $08
  .byte $07, $08, $07, $08, $07, $08, $07, $08
  .byte $07, $08, $07, $08, $07, $08, $07, $08

; Pillar row: brick A at cols 0,2,4,6,8,10,12,14 and col 15 (right border)
; Floor (tile 0) at cols 1,3,5,7,9,11,13  – floor shows green via bg color
pillar_row_top:
  .byte $05, $06, $00, $00, $05, $06, $00, $00
  .byte $05, $06, $00, $00, $05, $06, $00, $00
  .byte $05, $06, $00, $00, $05, $06, $00, $00
  .byte $05, $06, $00, $00, $05, $06, $05, $06

pillar_row_bottom:
  .byte $07, $08, $00, $00, $07, $08, $00, $00
  .byte $07, $08, $00, $00, $07, $08, $00, $00
  .byte $07, $08, $00, $00, $07, $08, $00, $00
  .byte $07, $08, $00, $00, $07, $08, $07, $08

; Soft row A: interior rows with soft B and floor gaps (no spawn-corner safety needed)
; col 0,15 = border A | interior = B blocks with floor gaps every 3rd metatile
soft_row_a_top:
  .byte $05, $06, $09, $0A, $09, $0A, $00, $00
  .byte $09, $0A, $09, $0A, $00, $00, $09, $0A
  .byte $00, $00, $09, $0A, $09, $0A, $00, $00
  .byte $09, $0A, $09, $0A, $00, $00, $05, $06

soft_row_a_bottom:
  .byte $07, $08, $0B, $0C, $0B, $0C, $00, $00
  .byte $0B, $0C, $0B, $0C, $00, $00, $0B, $0C
  .byte $00, $00, $0B, $0C, $0B, $0C, $00, $00
  .byte $0B, $0C, $0B, $0C, $00, $00, $07, $08

; Soft row B: spawn-safe rows (rows 1 and 13, just inside top/bottom border)
; cols 1-2 and cols 13-14 are free floor tiles to protect player spawn zones
soft_row_b_top:
  .byte $05, $06, $00, $00, $00, $00, $09, $0A
  .byte $09, $0A, $09, $0A, $00, $00, $09, $0A
  .byte $09, $0A, $00, $00, $09, $0A, $09, $0A
  .byte $09, $0A, $00, $00, $00, $00, $05, $06

soft_row_b_bottom:
  .byte $07, $08, $00, $00, $00, $00, $0B, $0C
  .byte $0B, $0C, $0B, $0C, $00, $00, $0B, $0C
  .byte $0B, $0C, $00, $00, $0B, $0C, $0B, $0C
  .byte $0B, $0C, $00, $00, $00, $00, $07, $08

; Each attribute byte covers a 4x4 tile block (2 metatile cols x 2 metatile rows)
; Bit layout: [bits 7-6: BR] [bits 5-4: BL] [bits 3-2: TR] [bits 1-0: TL]
;
; The screen pairs one pillar row (top) with one soft row (bottom) per attr block:
;   Top metatile row  = pillar pattern → wall cols use pal 0, floor cols use pal 0
;   Bottom metatile row = soft pattern → border cols use pal 0, interior uses pal 1
;
; Byte 0  covers cols 0-1:  TL=pal0(wall) TR=pal0(floor) BL=pal0(wall) BR=pal1(soft)
; Bytes 1-6 cover interior: TL=pal0(wall) TR=pal0(floor) BL=pal1(soft) BR=pal1(soft)
; Byte 7  covers cols 14-15: TL=pal0       TR=pal0(wall)  BL=pal1(soft) BR=pal0(wall)
attr_row_even:
  .byte %01000000, %01010000, %01010000, %01010000
  .byte %01010000, %01010000, %01010000, %00010000

attr_row_odd:
  .byte %01000000, %01010000, %01010000, %01010000
  .byte %01010000, %01010000, %01010000, %00010000


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
; tile 9 = brick B (top-left 8x8)  (bevel: bright top/left edge)
; color3 = top/left edge, color1 = fill
; ----------------
  ; plane 0
  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
  ; plane 1
  .byte $FF, $80, $80, $80, $80, $80, $80, $80

; ----------------
; tile 10 = brick B (top-right 8x8)
; color3 = top edge, color2 = right edge, color1 = fill
; ----------------
  ; plane 0
  .byte $FF, $FE, $FE, $FE, $FE, $FE, $FE, $FE
  ; plane 1
  .byte $FF, $01, $01, $01, $01, $01, $01, $01

; ----------------
; tile 11 = brick B (bottom-left 8x8)
; color3 = left edge, color2 = bottom edge (entire last row)
; ----------------
  ; plane 0
  .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00
  ; plane 1
  .byte $80, $80, $80, $80, $80, $80, $80, $FF

; ----------------
; tile 12 = brick B (bottom-right 8x8)
; color2 = right edge and bottom edge (entire last row)
; ----------------
  ; plane 0
  .byte $FE, $FE, $FE, $FE, $FE, $FE, $FE, $00
  ; plane 1
  .byte $01, $01, $01, $01, $01, $01, $01, $FF

; Pad remaining CHR ROM to 8KB (1 bank)
.res $2000 - (* - chr_start)
