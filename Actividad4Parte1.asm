.include "constants.inc"
.include "header.inc"

; ===========================================================
; Zero-page variables  (allocated by nes.cfg ZEROPAGE at $10)
; These act as the "per-draw-call uniform parameters" in the
; classic CPU-side rendering pipeline.
; ===========================================================
.segment "ZEROPAGE"
oam_offset: .res 1   ; byte offset into the OAM shadow buffer (0..252)
char_x:     .res 1   ; X  position passed to draw_character
char_y:     .res 1   ; Y  position passed to draw_character
char_frame: .res 1   ; frame index  (0..5)  passed to draw_character
char_attr:  .res 1   ; OAM attribute byte   (palette + flip flags)
tile_base:  .res 1   ; scratch: char_frame * 4

; ===========================================================
; OAM shadow buffer at $0200 (64 entries × 4 bytes = 256 B)
; The PPU's internal OAM is refreshed every frame via OAMDMA.
; ===========================================================
.segment "OAM"
oam_buf:    .res 256

; ===========================================================
; CODE
; ===========================================================
.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  RTI
.endproc

.import reset_handler

; -----------------------------------------------------------
; draw_character
; "Submit a draw call": write 4 OAM entries for a 16×16
; character sprite (2×2 tiles).
;
; Inputs  (zero-page):
;   char_frame  – animation frame index (0..5)
;   char_x      – left edge in pixels
;   char_y      – top  edge in pixels
;   char_attr   – OAM attribute byte (palette, H/V flip)
;
; Tile layout assumed in sprite pattern table ($1000):
;   frame N → TL=$4N  TR=$4N+1  BL=$4N+2  BR=$4N+3
;
; Clobbers: A, X
; -----------------------------------------------------------
.proc draw_character
  ; tile_base = char_frame * 4
  LDA char_frame
  ASL A
  ASL A
  STA tile_base

  LDX oam_offset       ; X = current write position in oam_buf

  ; ---- top-left 8×8 sprite ----
  LDA char_y
  STA oam_buf,X        ; [0] Y
  INX
  LDA tile_base        ; tile TL = base + 0
  STA oam_buf,X        ; [1] tile
  INX
  LDA char_attr
  STA oam_buf,X        ; [2] attributes
  INX
  LDA char_x
  STA oam_buf,X        ; [3] X
  INX

  ; ---- top-right 8×8 sprite ----
  LDA char_y
  STA oam_buf,X        ; [0] Y
  INX
  LDA tile_base
  CLC
  ADC #$01             ; tile TR = base + 1
  STA oam_buf,X        ; [1] tile
  INX
  LDA char_attr
  STA oam_buf,X        ; [2] attributes
  INX
  LDA char_x
  CLC
  ADC #$08             ; X + 8 (right half)
  STA oam_buf,X        ; [3] X
  INX

  ; ---- bottom-left 8×8 sprite ----
  LDA char_y
  CLC
  ADC #$08             ; Y + 8 (bottom half)
  STA oam_buf,X        ; [0] Y
  INX
  LDA tile_base
  CLC
  ADC #$02             ; tile BL = base + 2
  STA oam_buf,X        ; [1] tile
  INX
  LDA char_attr
  STA oam_buf,X        ; [2] attributes
  INX
  LDA char_x
  STA oam_buf,X        ; [3] X
  INX

  ; ---- bottom-right 8×8 sprite ----
  LDA char_y
  CLC
  ADC #$08
  STA oam_buf,X        ; [0] Y
  INX
  LDA tile_base
  CLC
  ADC #$03             ; tile BR = base + 3
  STA oam_buf,X        ; [1] tile
  INX
  LDA char_attr
  STA oam_buf,X        ; [2] attributes
  INX
  LDA char_x
  CLC
  ADC #$08
  STA oam_buf,X        ; [3] X
  INX

  STX oam_offset       ; save updated write position
  RTS
.endproc

; -----------------------------------------------------------
; draw_character_flipped
; Same as draw_character but swaps TL↔TR and BL↔BR tiles so
; that the 16×16 meta-sprite appears horizontally mirrored.
; OAM_FLIP_H must be set in char_attr to flip each 8×8 tile.
; Used for right-facing poses (reuses left-facing tiles).
;
; Inputs  (zero-page): char_frame, char_x, char_y, char_attr
; (char_attr should include OAM_FLIP_H = %01000000)
; Clobbers: A, X
; -----------------------------------------------------------
.proc draw_character_flipped
  LDA char_frame
  ASL A
  ASL A
  STA tile_base

  LDX oam_offset

  ; ---- top-left position → uses TR tile (base+1) + h-flip ----
  LDA char_y
  STA oam_buf,X
  INX
  LDA tile_base
  CLC
  ADC #$01             ; TR tile (visually becomes left-half after flip)
  STA oam_buf,X
  INX
  LDA char_attr
  STA oam_buf,X
  INX
  LDA char_x
  STA oam_buf,X
  INX

  ; ---- top-right position → uses TL tile (base+0) + h-flip ----
  LDA char_y
  STA oam_buf,X
  INX
  LDA tile_base        ; TL tile (visually becomes right-half after flip)
  STA oam_buf,X
  INX
  LDA char_attr
  STA oam_buf,X
  INX
  LDA char_x
  CLC
  ADC #$08
  STA oam_buf,X
  INX

  ; ---- bottom-left position → uses BR tile (base+3) + h-flip ----
  LDA char_y
  CLC
  ADC #$08
  STA oam_buf,X
  INX
  LDA tile_base
  CLC
  ADC #$03
  STA oam_buf,X
  INX
  LDA char_attr
  STA oam_buf,X
  INX
  LDA char_x
  STA oam_buf,X
  INX

  ; ---- bottom-right position → uses BL tile (base+2) + h-flip ----
  LDA char_y
  CLC
  ADC #$08
  STA oam_buf,X
  INX
  LDA tile_base
  CLC
  ADC #$02
  STA oam_buf,X
  INX
  LDA char_attr
  STA oam_buf,X
  INX
  LDA char_x
  CLC
  ADC #$08
  STA oam_buf,X
  INX

  STX oam_offset
  RTS
.endproc

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

  ; ----------------------------------------------------------
  ; PIPELINE STEP 1 – Clear OAM shadow buffer
  ; Set every sprite Y = $FF so all 64 entries are off-screen
  ; before we submit draw calls.
  ; ----------------------------------------------------------
  LDA #$FF
  LDX #$00
clear_oam_buf:
  STA oam_buf,X
  INX
  BNE clear_oam_buf

  ; Reset OAM write pointer
  LDA #$00
  STA oam_offset

  ; ----------------------------------------------------------
  ; PIPELINE STEP 2 – Draw calls
  ; 4 rows x 3 columns, one row per direction, centred on screen.
  ;
  ;   X positions: 64, 120, 176  (56px apart, sprite=16px)
  ;   Y positions: 24, 82, 140, 198  (one row per direction)
  ;
  ;   Row 1 (Y= 24):  Down_Idle   Down_A    Down_B
  ;   Row 2 (Y= 82):  Left_Idle   Left_A    Left_B
  ;   Row 3 (Y=140):  Right_Idle  Right_A   Right_B
  ;   Row 4 (Y=198):  Up_Idle     Up_A      Up_B
  ; ----------------------------------------------------------

  ; ---- Row 1: Down ----
  LDA #FRAME_DOWN_IDLE
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$40             ; X = 64
  STA char_x
  LDA #$18             ; Y = 24
  STA char_y
  JSR draw_character

  LDA #FRAME_DOWN_A
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$78             ; X = 120
  STA char_x
  LDA #$18
  STA char_y
  JSR draw_character

  LDA #FRAME_DOWN_B
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$B0             ; X = 176
  STA char_x
  LDA #$18
  STA char_y
  JSR draw_character

  ; ---- Row 2: Left ----
  LDA #FRAME_LEFT_IDLE
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$40             ; X = 64
  STA char_x
  LDA #$52             ; Y = 82
  STA char_y
  JSR draw_character

  LDA #FRAME_LEFT_A
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$78             ; X = 120
  STA char_x
  LDA #$52
  STA char_y
  JSR draw_character

  LDA #FRAME_LEFT_B
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$B0             ; X = 176
  STA char_x
  LDA #$52
  STA char_y
  JSR draw_character

  ; ---- Row 3: Right ----
  LDA #FRAME_RIGHT_IDLE
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$40             ; X = 64
  STA char_x
  LDA #$8C             ; Y = 140
  STA char_y
  JSR draw_character

  LDA #FRAME_RIGHT_A
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$78             ; X = 120
  STA char_x
  LDA #$8C
  STA char_y
  JSR draw_character

  LDA #FRAME_RIGHT_B
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$B0             ; X = 176
  STA char_x
  LDA #$8C
  STA char_y
  JSR draw_character

  ; ---- Row 4: Up ----
  LDA #FRAME_UP_IDLE
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$40             ; X = 64
  STA char_x
  LDA #$C6             ; Y = 198
  STA char_y
  JSR draw_character

  LDA #FRAME_UP_A
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$78             ; X = 120
  STA char_x
  LDA #$C6
  STA char_y
  JSR draw_character

  LDA #FRAME_UP_B
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$B0             ; X = 176
  STA char_x
  LDA #$C6
  STA char_y
  JSR draw_character

  ; ----------------------------------------------------------
  ; PIPELINE STEP 3 – Wait for VBlank, then submit
  ; ----------------------------------------------------------
vblankwait:
  BIT PPUSTATUS
  BPL vblankwait

  ; Submit OAM: copy shadow buffer $0200-$02FF → PPU OAM
  LDA #$02             ; high byte of OAM_BASE ($0200)
  STA OAMDMA           ; triggers 513-cycle DMA

  ; Enable NMIs | sprites use pattern table at $1000 | BG at $0000
  LDA #%10001000
  STA PPUCTRL

  ; Enable BG rendering + sprite rendering
  LDA #%00011110
  STA PPUMASK

forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
  ; Background palettes – universal black background
  .byte $0F, $0F, $0F, $0F   ; BG pal 0
  .byte $0F, $0F, $0F, $0F   ; BG pal 1
  .byte $0F, $0F, $0F, $0F   ; BG pal 2
  .byte $0F, $0F, $0F, $0F   ; BG pal 3

  ; Sprite palette 0 – skin ($27) and hair/eyes ($16) swapped
  .byte $0F, $18, $16, $27
  .byte $0F, $18, $16, $27
  .byte $0F, $18, $16, $27
  .byte $0F, $18, $16, $27

full_wall_top:
  .byte $04, $05, $04, $05, $04, $05, $04, $05
  .byte $04, $05, $04, $05, $04, $05, $04, $05
  .byte $04, $05, $04, $05, $04, $05, $04, $05
  .byte $04, $05, $04, $05, $04, $05, $04, $05

full_wall_bottom:
  .byte $06, $07, $06, $07, $06, $07, $06, $07
  .byte $06, $07, $06, $07, $06, $07, $06, $07
  .byte $06, $07, $06, $07, $06, $07, $06, $07
  .byte $06, $07, $06, $07, $06, $07, $06, $07

; Pillar row: brick A at cols 0,2,4,6,8,10,12,14 and col 15 (right border)
; Floor (tile 0) at cols 1,3,5,7,9,11,13  – floor shows green via bg color
pillar_row_top:
  .byte $04, $05, $00, $00, $04, $05, $00, $00
  .byte $04, $05, $00, $00, $04, $05, $00, $00
  .byte $04, $05, $00, $00, $04, $05, $00, $00
  .byte $04, $05, $00, $00, $04, $05, $04, $05

pillar_row_bottom:
  .byte $06, $07, $00, $00, $06, $07, $00, $00
  .byte $06, $07, $00, $00, $06, $07, $00, $00
  .byte $06, $07, $00, $00, $06, $07, $00, $00
  .byte $06, $07, $00, $00, $06, $07, $06, $07

; Soft row A: interior rows with soft B and floor gaps (no spawn-corner safety needed)
; col 0,15 = border A | interior = B blocks with floor gaps every 3rd metatile
soft_row_a_top:
  .byte $04, $05, $08, $09, $08, $09, $00, $00
  .byte $08, $09, $08, $09, $00, $00, $08, $09
  .byte $00, $00, $08, $09, $08, $09, $00, $00
  .byte $08, $09, $08, $09, $00, $00, $04, $05

soft_row_a_bottom:
  .byte $06, $07, $0A, $0B, $0A, $0B, $00, $00
  .byte $0A, $0B, $0A, $0B, $00, $00, $0A, $0B
  .byte $00, $00, $0A, $0B, $0A, $0B, $00, $00
  .byte $0A, $0B, $0A, $0B, $00, $00, $06, $07

; Soft row B: spawn-safe rows (rows 1 and 13, just inside top/bottom border)
; cols 1-2 and cols 13-14 are free floor tiles to protect player spawn zones
soft_row_b_top:
  .byte $04, $05, $00, $00, $00, $00, $08, $09
  .byte $08, $09, $08, $09, $00, $00, $08, $09
  .byte $08, $09, $00, $00, $08, $09, $08, $09
  .byte $08, $09, $00, $00, $00, $00, $04, $05

soft_row_b_bottom:
  .byte $06, $07, $00, $00, $00, $00, $0A, $0B
  .byte $0A, $0B, $0A, $0B, $00, $00, $0A, $0B
  .byte $0A, $0B, $00, $00, $0A, $0B, $0A, $0B
  .byte $0A, $0B, $00, $00, $00, $00, $06, $07

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
.incbin "mario.chr", 0, $2000  ; first 8KB only (NEXXT exports duplicate banks)
