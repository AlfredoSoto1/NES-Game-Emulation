.include "constants.inc"
.include "header.inc"

; ===========================================================
; Zero-page variables  (allocated by nes.cfg ZEROPAGE at $10)
; These act as the "per-draw-call uniform parameters" in the
; classic CPU-side rendering pipeline.
; ===========================================================
.segment "ZEROPAGE"
oam_offset:    .res 1   ; byte offset into the OAM shadow buffer (0..252)
char_x:        .res 1   ; X position passed to draw_character
char_y:        .res 1   ; Y position passed to draw_character
char_frame:    .res 1   ; animation frame index passed to draw_character
char_attr:     .res 1   ; OAM attribute byte (palette + flip flags)
tile_base:     .res 1   ; scratch: char_frame * 4
frame_counter: .res 1   ; counts VBlanks 0..59; resets every second (60 Hz)
anim_frame:    .res 1   ; current animation step: 0=Idle, 1=A, 2=B
nmi_flag:      .res 1   ; set to 1 by NMI handler, cleared by main loop

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

; -----------------------------------------------------------
; nmi_handler  – fires every VBlank (~60 Hz)
;   1. Submits OAM DMA so the PPU sees the latest shadow buffer.
;   2. Ticks frame_counter; every 60 ticks (1 second) it advances
;      anim_frame through 0 → 1 → 2 → 0.
;   3. Sets nmi_flag so the main loop knows to redraw.
; -----------------------------------------------------------
.proc nmi_handler
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Submit OAM DMA
  LDA #$02
  STA OAMDMA

  ; Advance frame counter
  INC frame_counter
  LDA frame_counter
  CMP #60
  BNE :+
  LDA #$00
  STA frame_counter
  ; Advance animation step (0 → 1 → 2 → 0)
  INC anim_frame
  LDA anim_frame
  CMP #3
  BNE :+
  LDA #$00
  STA anim_frame
:
  LDA #$01
  STA nmi_flag

  PLA
  TAY
  PLA
  TAX
  PLA
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
  ; ---- Load palettes ----
  LDX PPUSTATUS
  LDX #$3F
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; ---- Reset scroll ----
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  ; ---- Clear nametable ----
  LDA PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDA #$00
  LDX #$00
  LDY #$04
clear_nametable:
  STA PPUDATA
  INX
  BNE clear_nametable
  DEY
  BNE clear_nametable

  ; ---- Initialize counters ----
  LDA #$00
  STA frame_counter
  STA anim_frame
  STA nmi_flag
  STA oam_offset

  ; ---- Pre-clear OAM shadow buffer ----
  LDA #$FF
  LDX #$00
clear_oam_init:
  STA oam_buf,X
  INX
  BNE clear_oam_init

  ; ---- Wait for VBlank, then enable NMI + rendering ----
vblankwait:
  BIT PPUSTATUS
  BPL vblankwait
  LDA #%10001000       ; NMI on | sprites at $1000 | BG at $0000
  STA PPUCTRL
  LDA #%00011110       ; BG + sprites enabled
  STA PPUMASK

  ; ---- Main loop: redraw 4 characters every VBlank ----
  ; Characters (all at Y=112, 32px apart, centred on 256px screen):
  ;   Left  X= 72 ($48)   Right X=104 ($68)
  ;   Up    X=136 ($88)   Down  X=168 ($A8)
forever:
  LDA nmi_flag
  BEQ forever          ; wait for NMI signal
  LDA #$00
  STA nmi_flag

  ; Clear OAM shadow
  LDA #$FF
  LDX #$00
clear_oam:
  STA oam_buf,X
  INX
  BNE clear_oam
  LDA #$00
  STA oam_offset

  ; -- Left animation --
  LDA #FRAME_LEFT_IDLE ; IDLE/A/B are consecutive, add anim_frame (0/1/2)
  CLC
  ADC anim_frame
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$48             ; X = 72
  STA char_x
  LDA #$70             ; Y = 112
  STA char_y
  JSR draw_character

  ; -- Right animation --
  LDA #FRAME_RIGHT_IDLE
  CLC
  ADC anim_frame
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$68             ; X = 104
  STA char_x
  LDA #$70
  STA char_y
  JSR draw_character

  ; -- Up animation --
  LDA #FRAME_UP_IDLE
  CLC
  ADC anim_frame
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$88             ; X = 136
  STA char_x
  LDA #$70
  STA char_y
  JSR draw_character

  ; -- Down animation --
  LDA #FRAME_DOWN_IDLE
  CLC
  ADC anim_frame
  STA char_frame
  LDA #OAM_PALETTE_0
  STA char_attr
  LDA #$A8             ; X = 168
  STA char_x
  LDA #$70
  STA char_y
  JSR draw_character

  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
  .byte $0F, $0F, $0F, $0F   ; BG pal 0 – black background
  .byte $0F, $0F, $0F, $0F   ; BG pal 1
  .byte $0F, $0F, $0F, $0F   ; BG pal 2
  .byte $0F, $0F, $0F, $0F   ; BG pal 3
  .byte $0F, $18, $16, $27   ; Sprite pal 0 – black / red / skin
  .byte $0F, $18, $16, $27   ; Sprite pal 1
  .byte $0F, $18, $16, $27   ; Sprite pal 2
  .byte $0F, $18, $16, $27   ; Sprite pal 3

.segment "CHR"
.incbin "mario.chr", 0, $2000  ; first 8KB only (NEXXT exports duplicate banks)
