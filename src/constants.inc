; MMIO register constants (names used commonly in NES docs)
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUADDR   = $2006
PPUDATA   = $2007
PPUSCROLL = $2005
OAMADDR   = $2003
OAMDATA   = $2004
OAMDMA    = $4014    ; write $02 here to DMA copy $0200-$02FF → OAM

; OAM attribute byte flags
OAM_PALETTE_0     = %00000000
OAM_PALETTE_1     = %00000001
OAM_PALETTE_2     = %00000010
OAM_PALETTE_3     = %00000011
OAM_FLIP_H        = %01000000  ; horizontal flip
OAM_FLIP_V        = %10000000  ; vertical flip
OAM_BEHIND_BG     = %00100000  ; draw sprite behind background

; Sprite frame indices (each frame = one 16x16 character pose, 4 tiles)
; Tile layout per frame N: TL=tile(N*4), TR=tile(N*4+1), BL=tile(N*4+2), BR=tile(N*4+3)
; CHR has 12 frames total (3 per direction). Tiles 0-3 are NEXXT calibration tiles.
; Character frames start at tile 4 (frame index 1).
;
; Down  (row 1): idle=1  walk_A=2  walk_B=3   -> tiles  4-15
; Left  (row 2): idle=4  walk_A=5  walk_B=6   -> tiles 16-27
; Right (row 3): idle=7  walk_A=8  walk_B=9   -> tiles 28-39
; Up    (row 4): idle=10 walk_A=11 walk_B=12  -> tiles 40-51
FRAME_DOWN_IDLE   = 1
FRAME_DOWN_A      = 2
FRAME_DOWN_B      = 3
FRAME_LEFT_IDLE   = 4
FRAME_LEFT_A      = 5
FRAME_LEFT_B      = 6
FRAME_RIGHT_IDLE  = 7
FRAME_RIGHT_A     = 8
FRAME_RIGHT_B     = 9
FRAME_UP_IDLE     = 10
FRAME_UP_A        = 11
FRAME_UP_B        = 12

; Legacy alias kept for compatibility
FRAME_IDLE        = FRAME_DOWN_IDLE

; OAM buffer base address
OAM_BASE          = $0200
