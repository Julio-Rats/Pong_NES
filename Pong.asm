  ; iNES header identifier
  .inesprg 1      ; 1x 16KB PRG code
  .ineschr 1      ; 1x  8KB CHR data
  .inesmap 0      ; Mapper 0 = NROM, no bank swapping
  .inesmir 0      ; BCG Horizontal Mirroring

;===================  Constantes   =============================
Speed_ball       = 03
Speed_players 	 = 04
N_Sprites     	 = 96
P0_Xpos       	 = $0207
P1_Xpos       	 = $0213
P0_Ypos       	 = $0204
P1_Ypos       	 = $0210
Ball_Xpos     	 = $021F
Ball_Ypos     	 = $021C
Ball_Limit_Under = $E0
Ball_Limit_Upper = $23

;===================  Variaveis   =============================
; Variaveis (RAM Interna do NES)
; ---> Zero Page used here ! $00--$FF (256 Bytes Free RAM) <---
  .zp
Ball_Control .rs 1
; Bit                    Descrição

;  0                      Alive?          1-true,0-false
;  1                      move_right?     1-true,0-false
;  2                      move_down?      1-true,0-false
;  4                      side_dead?      1-left,0-right

; Memoria reservada para futura implementação de velocidade dinamica
Ball_Speed   .rs 1
; Memoria reservada para futura implementação de velocidade dinamica
Player_Speed .rs 1
P0_Score     .rs 1
P1_Score     .rs 1


  .code


  .bank 1
  .org $FFFA

  .dw nmi
  .dw reset
  .dw nmi


  .bank 0
  .org $8000

nmi:
  lda #$02
  sta $4014
  lda #0
  sta $2006
  sta $2006

  jsr Read_Control
  ; Descomente para mover Players para nivel da bola (semi IA)
  ;ldx #0
  ;jsr IA_Px
  ;ldx #12
  ;jsr IA_Px
  jsr Colision_Ball_Player
  jsr Dead_Ball
  jsr Status_Ball

  lda #%10000000
  sta $2000
  lda #%00011110
  sta $2001
  rti


reset:
  sei
  cld
  ldx #%01000000
  stx $4017
  ldx #$FF
  txs
  inx
  stx $2000
  stx $2001
  stx $4010
vblankWait1:
  bit $2002
  bpl vblankWait1
  lda #$00
clearMemory:
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clearMemory
  ; Inicializando Variaveis
  lda #%000000000
  sta Ball_Control
  lda #0
  sta P0_Score
  sta P1_Score
  lda #Speed_ball
  sta Ball_Speed
  lda #Speed_players
  sta Player_Speed
vblankWait2:
  bit $2002
  bpl vblankWait2
main:
  jsr LoadPalettes
  jsr LoadBG
  jsr LoadSprites
  lda #$02
  sta $4014
  lda #%10000000
  sta $2000
  lda #%00011110
  sta $2001
ForeverLoop:
  jmp ForeverLoop


LoadBG:
  lda #$04
  sta $2000
  jsr Line_Center
  lda #$00
  sta $2000
  jsr Line_Up
  jsr Line_Down
  jsr Attrib_Lines
  rts


LoadPalettes:
  bit $2002
  lda #$3F
  sta $2006
  lda #$00
  sta $2006
  ldx #0
loopPalettes:
  lda palettes, x
  sta $2007
  inx
  cpx #32
  bne loopPalettes
  rts


LoadSprites:
  ldx #0
loopSprites:
  lda sprites, x
  sta $0200, x
  inx
  cpx #N_Sprites
  bne loopSprites
  rts


Line_Up:
  bit $2002
  LDA #$20
  STA $2006
  LDA #$80
  STA $2006
  LDX #$00
  LDA #1           ; Tile 1 (Horizon line)
loopLineUp:
  STA $2007
  INX
  CPX #$20
  BNE loopLineUp
  rts


Line_Down:
  bit $2002
  LDA #$23
  STA $2006
  LDA #$80
  STA $2006
  LDX #$00
  LDA #1           ; Tile 1 (Horizon line)
loopLineDown:
  STA $2007
  INX
  CPX #$20
  BNE loopLineDown
  rts


Line_Center:
  bit $2002
  LDA #$20
  STA $2006
  LDA #$AF         ; Center NameTable
  STA $2006
  LDX #$00
  LDA #2           ; Tile 2 (Vertical line)
loopLineCenter:
  STA $2007
  INX
  EOR #$02         ; Switching between Block 2 and Block 0 (traced Line)
  CPX #24
  BNE loopLineCenter
  rts


Attrib_Lines:
  bit $2002
  LDA #$23
  STA $2006
  LDA #$C0
  STA $2006
  LDX #0
  LDA #0           ; Pallet color 0 for all BCG block
loopAttribLines:
  STA $2007
  INX
  CPX #$40
  BNE loopAttribLines
  RTS


Read_Control:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016 ; tell both the controllers to latch buttons
p0_a:
  LDA $4016 ; player 1 - A
  and #1
  beq p0_b
  lda Ball_Control
  and #1
  bne p0_b
  lda Ball_Control
  ora #$01
  sta Ball_Control
p0_b:
  LDA $4016 ; player 1 - B
  and #1
  beq p0_slct
  lda Ball_Control
  and #$01
  bne p0_slct
  lda Ball_Control
  ora #$01
  sta Ball_Control
p0_slct:
  LDA $4016 ; player 1 - Select
  ;and #1
p0_start:
  LDA $4016 ; player 1 - Start
  ;and #1
p0_up:
  LDA $4016 ; player 1 - Up
  and #1
  beq p0_down
  ldx #0
  lda #0
  sec
  sbc Player_Speed
  tay
  jsr move_players
p0_down:
  LDA $4016 ; player 1 - Down
  and #1
  beq p0_left
  ldx #0
  ldy Player_Speed
  jsr move_players
p0_left:
  LDA $4016 ; player 1 - Left
  and #1
  beq p0_right
  ldx #0
  lda #0
  sec
  sbc Player_Speed
  tay
  jsr move_players
p0_right:
  LDA $4016 ; player 1 - Right
  and #1
  beq p1_a
  ldx #0
  ldy Player_Speed
  jsr move_players
p1_a:
  LDA $4017 ; player 2 - A
  and #1
  beq p1_b
  lda Ball_Control
  and #$01
  bne p1_b
  lda Ball_Control
  ora #$01
  sta Ball_Control
p1_b:
  LDA $4017 ; player 2 - B
  and #1
  beq p1_slct
  lda Ball_Control
  and #$01
  bne p1_slct
  lda Ball_Control
  ora #$01
  sta Ball_Control
p1_slct:
  LDA $4017 ; player 2 - Select
p1_start:
  LDA $4017 ; player 2 - Start
p1_up:
  LDA $4017 ; player 2 - Up
  and #1
  beq p1_down
  ldx #12
  lda #0
  sec
  sbc Player_Speed
  tay
  jsr move_players
p1_down:
  LDA $4017 ; player 2 - Down
  and #1
  beq p1_left
  ldx #12
  ldy Player_Speed
  jsr move_players
p1_left:
  LDA $4017 ; player 2 - Left
  and #1
  beq p1_right
  ldx #12
  lda #0
  sec
  sbc Player_Speed
  tay
  jsr move_players
p1_right:
  LDA $4017 ; player 2 - Right
  and #1
  beq exit_read_control
  ldx #12
  ldy Player_Speed
  jsr move_players
exit_read_control:
  rts


move_players:
  tya
  clc
  adc P0_Ypos,x
  cmp #Ball_Limit_Upper+1
  bcc exit_move_players
  cmp #Ball_Limit_Under-18
  bcs exit_move_players
  sta P0_Ypos,x
  tya
  clc
  adc P0_Ypos+4,x
  sta P0_Ypos+4,x
  tya
  clc
  adc P0_Ypos+8,x
  sta P0_Ypos+8,x
exit_move_players:
  rts


Status_Ball:
  ; Bit                     Descrição       Logica
  ;  0                      Alive?          1-true,0-false
  ;  1                      move_right?     1-true,0-false
  ;  2                      move_down?      1-true,0-false
  ;  4                      side_dead?      1-left,0-right

  lda #%00000001
  bit Ball_Control
  bne ball_alive
  lda #0            	      ; Dead Sprite (translucido)
  sta $021D
  jmp out_alive

ball_alive:
  lda #4                      ; Live Sprite (Title #4)
  sta Ball_Ypos+1
  lda #%00000010
  bit Ball_Control
  beq move_left
  lda Ball_Speed              ; Speed Move Right BALL
  clc
  adc Ball_Xpos
  sta Ball_Xpos
  jmp out_move_lateral
move_left:
  lda #0                      ; Speed Move Letf BALL
  sec
  sbc Ball_Speed
  clc
  adc Ball_Xpos
  sta Ball_Xpos
out_move_lateral:
  lda #%00000100
  bit Ball_Control
  beq move_up
  lda Ball_Speed              ; Speed Move Down BALL
  clc
  adc Ball_Ypos
  cmp #Ball_Limit_Under       ; Limite Inferior
  bcc no_swapUD
  lda Ball_Control
  and #%11111011
  sta Ball_Control
  jmp out_move_vertical
no_swapUD:
  sta Ball_Ypos
  jmp out_move_vertical
move_up:
  lda #0                      ; Speed Move up BALL
  sec
  sbc Ball_Speed
  clc
  adc Ball_Ypos
  cmp #Ball_Limit_Upper       ; Limite Superior
  bcs no_swapDU
  lda Ball_Control
  ora #%000000100
  sta Ball_Control
  jmp out_move_vertical
no_swapDU:
  sta Ball_Ypos
out_move_vertical:
out_alive:
  rts


Colision_Ball_Player:
  lda Ball_Xpos
  sec
  sbc #7                    ; Control Impact distance (plus for most distance detect collision)
  cmp P0_Xpos
  bcs No_Colision_Left
  lda Ball_Ypos
  clc
  adc #4                    ; P0 UP hitbox Control (plus for more hitbox)
  cmp P0_Ypos
  bcc No_Colision_Left
  lda Ball_Ypos
  sec
  sbc #9                    ; P0 DW hitbox Control (plus for more hitbox)
  cmp P0_Ypos+8             ; 3ºSprite Y pos
  bcs No_Colision_Left
  lda Ball_Control
  ora #$02
  sta Ball_Control
  jmp out_colision
No_Colision_Left:
  lda Ball_Xpos
  clc
  adc #3                    ; Control Impact distance (plus for most distance detect collision)
  cmp P1_Xpos
  bcc No_Colision_Right
  lda Ball_Ypos
  clc
  adc #4                    ; P0 UP hitbox Control (plus for more hitbox)
  cmp P1_Ypos
  bcc No_Colision_Right
  lda Ball_Ypos
  sec
  sbc #9                    ; P0 DW hitbox Control (plus for more hitbox)
  cmp P1_Ypos+8             ; 3ºSprite Y pos
  bcs No_Colision_Right
  lda Ball_Control
  and #$FD
  sta Ball_Control
No_Colision_Right:
out_colision:
  rts


Dead_Ball:
  lda Ball_Xpos
  cmp #4
  bcs No_Dead_Left
  lda Ball_Control
  and #$FE
  ora #2
  sta Ball_Control
  lda P0_Xpos
  clc
  adc #4
  sta Ball_Xpos
No_Dead_Left:
  lda Ball_Xpos
  cmp #252
  bcc out_dead
  lda Ball_Control
  and #$FC
  sta Ball_Control
  lda P1_Xpos
  sec
  sbc #4
  sta Ball_Xpos
out_dead:
  rts


IA_Px:
  lda Ball_Ypos
  sec
  sbc #10
  cmp #Ball_Limit_Upper
  bcs no_boud_up
  lda #Ball_Limit_Upper+2
no_boud_up:
  cmp #Ball_Limit_Under-20
  bcc no_boud_dw
  lda #Ball_Limit_Under-20
no_boud_dw:
  sta P0_Ypos,x
  clc
  adc #6
  sta P0_Ypos+4,x
  clc
  adc #6
  sta P0_Ypos+8,x
  rts


palettes:
  .byte $00
  .byte $30, $0F, $0F
  .byte $00
  .byte $01, $02, $03
  .byte $00
  .byte $04, $05, $07
  .byte $00
  .byte $08, $09, $0A

  .byte $0F
  .byte $30, $0F, $0F
  .byte $00
  .byte $0B, $0C, $01
  .byte $00
  .byte $02, $03, $04
  .byte $02
  .byte $05, $06, $07


sprites:
  .byte 0, 0, %00000000, 0

  ;P0
  .byte 105, 3, %01000000, 4
  .byte 111, 3, %01000000, 4
  .byte 117, 3, %01000000, 4

  ;P1
  .byte 105, 3, %00000000, (255-10)
  .byte 111, 3, %00000000, (255-10)
  .byte 117, 3, %00000000, (255-10)

  ;Ball ;byte 28
  .byte 111, 0, 0, 115

  ;P0 Score MS Score
  .byte 11, 5, %00000000, 36
  .byte 11, 5, %01000000, 42
  .byte 19, 5, %10000000, 36
  .byte 19, 5, %11000000, 42

  ;P0 Score LS Score
  .byte 11, 5, %00000000, 52
  .byte 11, 5, %01000000, 58
  .byte 19, 5, %10000000, 52
  .byte 19, 5, %11000000, 58

  ;P1 Score MS Score
  .byte 11, 5, %00000000, 204
  .byte 11, 5, %01000000, 210
  .byte 19, 5, %10000000, 204
  .byte 19, 5, %11000000, 210

  ;P1 Score LS Score
  .byte 11, 5, %00000000, 220
  .byte 11, 5, %01000000, 226
  .byte 19, 5, %10000000, 220
  .byte 19, 5, %11000000, 226



sprites_end:
  .bank 2
  .org $0000

  ; Tile 0: Blank
  .defchr $00000000,\
          $00000000,\
          $00000000,\
          $00000000,\
          $00000000,\
          $00000000,\
          $00000000,\
          $00000000


  ; Tile 1: Line Horizons
  .defchr $00000000,\
          $00000000,\
          $00000000,\
          $11111111,\
          $11111111,\
          $00000000,\
          $00000000,\
          $00000000

  ; Tile 2: Line Vertical
  .defchr $00010000,\
          $00010000,\
          $00010000,\
          $00010000,\
          $00010000,\
          $00010000,\
          $00010000,\
          $00010000

  ; Tile 3: Players
  .defchr $00111000,\
          $00111000,\
          $00111000,\
          $00111000,\
          $00111000,\
          $00111000,\
          $00111000,\
          $00111000

  ; Tile 4: Ball
  .defchr $01110000,\
          $11111000,\
          $11111000,\
          $01110000,\
          $00000000,\
          $00000000,\
          $00000000,\
          $00000000

  ; Tile 5: Zero
  .defchr $00011111,\
          $00111111,\
          $01100000,\
          $01100000,\
          $01100000,\
          $01100000,\
          $01100000,\
          $01100000
