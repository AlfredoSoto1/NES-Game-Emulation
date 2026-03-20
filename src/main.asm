.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
map_ptr_lo:   .res 1
map_ptr_hi:   .res 1
packed0:      .res 1
packed1:      .res 1
packed2:      .res 1
packed3:      .res 1
packed_byte:  .res 1
rows_left:    .res 1

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
  ; ------------------------------------------------------------
  ; Write palettes
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDX #$3F
  STX PPUADDR
  LDX #$00
  STX PPUADDR

  LDX #$00
load_palettes:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; reset scroll to (0,0)
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  ; ------------------------------------------------------------
  ; Clear nametable to remove garbage data
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDA #$00 ; tile 0 (empty / floor)
  LDX #$00
  LDY #$04 ; 4 pages = 1024 bytes
clear_nametable:
  STA PPUDATA
  INX
  BNE clear_nametable
  DEY
  BNE clear_nametable

  ; ------------------------------------------------------------
  ; Draw one full screen using 2-bit compressed metatiles
  ; 15 metatile rows x 16 metatile cols
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  JSR draw_compressed_nametable

  ; ------------------------------------------------------------
  ; Full attribute table ($23C0-$23FF): 64 bytes
  ; Same attribute content as the original program
  ; ------------------------------------------------------------
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR

  LDY #$08
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
  CPX #$08
  BNE attr_odd_copy
  JMP next_attr_row

use_attr_even_row:
  LDX #$00
attr_even_copy:
  LDA attr_row_even, X
  STA PPUDATA
  INX
  CPX #$08
  BNE attr_even_copy

next_attr_row:
  DEY
  BNE draw_attr_rows

vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10000000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc


; ============================================================
; Draw compressed nametable
;
; Each metatile is 2x2 tiles:
;   0 = floor      -> tiles 00 00 / 00 00
;   1 = hard wall  -> tiles 04 05 / 06 07
;   2 = soft block -> tiles 08 09 / 0A 0B
;   3 = unused
;
; Map is 15 rows x 16 metatiles = 240 metatiles
; Packed at 2 bits each => 60 bytes total
; 4 metatiles per byte
; ============================================================
.proc draw_compressed_nametable
  LDA #<screen_map_2bit
  STA map_ptr_lo
  LDA #>screen_map_2bit
  STA map_ptr_hi

  LDA #$0F
  STA rows_left

row_loop:
  ; read 4 packed bytes = 16 metatiles for this row
  LDY #$00
  LDA (map_ptr_lo), Y
  STA packed0
  INY
  LDA (map_ptr_lo), Y
  STA packed1
  INY
  LDA (map_ptr_lo), Y
  STA packed2
  INY
  LDA (map_ptr_lo), Y
  STA packed3

  ; advance the pointer by 4 bytes
  CLC
  LDA map_ptr_lo
  ADC #$04
  STA map_ptr_lo
  LDA map_ptr_hi
  ADC #$00
  STA map_ptr_hi

  ; write top tile row for the 16 metatiles (32 tiles)
  LDA packed0
  JSR emit_four_top
  LDA packed1
  JSR emit_four_top
  LDA packed2
  JSR emit_four_top
  LDA packed3
  JSR emit_four_top

  ; write bottom tile row for the same 16 metatiles (32 tiles)
  LDA packed0
  JSR emit_four_bottom
  LDA packed1
  JSR emit_four_bottom
  LDA packed2
  JSR emit_four_bottom
  LDA packed3
  JSR emit_four_bottom

  DEC rows_left
  BNE row_loop

  RTS
.endproc


; ============================================================
; Input:
;   A = one packed byte containing 4 metatiles
; Format:
;   bits 7-6 = metatile 0
;   bits 5-4 = metatile 1
;   bits 3-2 = metatile 2
;   bits 1-0 = metatile 3
;
; Writes the TOP row (2 tiles each metatile => 8 tiles total)
; ============================================================
.proc emit_four_top
  STA packed_byte

  ; metatile 0
  LDA packed_byte
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  JSR emit_top_pair

  ; metatile 1
  LDA packed_byte
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  JSR emit_top_pair

  ; metatile 2
  LDA packed_byte
  AND #%00001100
  LSR A
  LSR A
  JSR emit_top_pair

  ; metatile 3
  LDA packed_byte
  AND #%00000011
  JSR emit_top_pair

  RTS
.endproc


; ============================================================
; Same as emit_four_top, but writes the BOTTOM row
; ============================================================
.proc emit_four_bottom
  STA packed_byte

  ; metatile 0
  LDA packed_byte
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  JSR emit_bottom_pair

  ; metatile 1
  LDA packed_byte
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  JSR emit_bottom_pair

  ; metatile 2
  LDA packed_byte
  AND #%00001100
  LSR A
  LSR A
  JSR emit_bottom_pair

  ; metatile 3
  LDA packed_byte
  AND #%00000011
  JSR emit_bottom_pair

  RTS
.endproc


; ============================================================
; A = metatile ID (0..3)
; Write top-left, top-right
; ============================================================
.proc emit_top_pair
  ASL A
  ASL A
  TAX

  LDA metatile_lut + 0, X
  STA PPUDATA
  LDA metatile_lut + 1, X
  STA PPUDATA

  RTS
.endproc


; ============================================================
; A = metatile ID (0..3)
; Write bottom-left, bottom-right
; ============================================================
.proc emit_bottom_pair
  ASL A
  ASL A
  TAX

  LDA metatile_lut + 2, X
  STA PPUDATA
  LDA metatile_lut + 3, X
  STA PPUDATA

  RTS
.endproc


.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler


.segment "RODATA"

palettes:
  ; Background color $2A shared as universal background
  ; Palette 0: hard wall / border
  .byte $2A, $30, $10, $00
  ; Palette 1: soft block
  .byte $2A, $28, $17, $07
  ; Palette 2: unused
  .byte $2A, $2A, $1A, $0A
  ; Palette 3: unused
  .byte $2A, $21, $11, $01

  ; Sprite palettes (not used)
  .byte $0F, $20, $00, $00
  .byte $0F, $00, $00, $00
  .byte $0F, $00, $00, $00
  .byte $0F, $00, $00, $00


; ============================================================
; Metatile lookup table
; Each entry = 4 tiles:
;   top-left, top-right, bottom-left, bottom-right
; ============================================================
metatile_lut:
  .byte $00, $00, $00, $00   ; 00 = floor
  .byte $04, $05, $06, $07   ; 01 = hard wall
  .byte $08, $09, $0A, $0B   ; 10 = soft block
  .byte $00, $00, $00, $00   ; 11 = unused


; ============================================================
; 2-bit packed map
;
; Row layout is EXACTLY the same as the old uncompressed version.
;
; Encoding:
;   00 = floor
;   01 = hard wall
;   10 = soft block
;   11 = unused
;
; 4 metatiles per byte:
;   [m0 m1 m2 m3] => bits [7:6][5:4][3:2][1:0]
; ============================================================
screen_map_2bit:
  ; row 0  = full hard wall border
  .byte $55, $55, $55, $55

  ; row 1  = soft row B (spawn-safe)
  ; [1,0,0,2] [2,2,0,2] [2,0,2,2] [2,0,0,1]
  .byte $42, $A2, $8A, $81

  ; row 2  = pillar row
  ; [1,0,1,0] [1,0,1,0] [1,0,1,0] [1,0,1,1]
  .byte $44, $44, $44, $45

  ; row 3  = soft row A
  ; [1,2,2,0] [2,2,0,2] [0,2,2,0] [2,2,0,1]
  .byte $68, $A2, $28, $A1

  ; row 4  = pillar row
  .byte $44, $44, $44, $45

  ; row 5  = soft row B
  .byte $42, $A2, $8A, $81

  ; row 6  = pillar row
  .byte $44, $44, $44, $45

  ; row 7  = soft row A
  .byte $68, $A2, $28, $A1

  ; row 8  = pillar row
  .byte $44, $44, $44, $45

  ; row 9  = soft row B
  .byte $42, $A2, $8A, $81

  ; row 10 = pillar row
  .byte $44, $44, $44, $45

  ; row 11 = soft row A
  .byte $68, $A2, $28, $A1

  ; row 12 = pillar row
  .byte $44, $44, $44, $45

  ; row 13 = soft row B (spawn-safe)
  .byte $42, $A2, $8A, $81

  ; row 14 = full hard wall border
  .byte $55, $55, $55, $55


; ============================================================
; Attribute table rows
; Same values as original implementation
; ============================================================
attr_row_even:
  .byte %01000000, %01010000, %01010000, %01010000
  .byte %01010000, %01010000, %01010000, %00010000

attr_row_odd:
  .byte %01000000, %01010000, %01010000, %01010000
  .byte %01010000, %01010000, %01010000, %00010000


.segment "CHR"
.incbin "graphics.chr"