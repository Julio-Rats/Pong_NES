.segment "HEADER"
  .byte $4E, $45            ; iNES header identifier
  .byte $53, $1A     
  .byte $02, $01            ; 2x 16KB PRG-ROM Banks, 1x  8KB CHR-ROM
  .byte $00, $00            ; mapper 0, horizontal mirroring,  no battery, 
  .byte $00, $00            ; NTSC
  .byte $00, $00            ; Reserved (NESv2) (RAM chr)
  .byte $00, $00            ; Reserved (NESv2) (WRAM)
  .byte $00, $00            ; Reserved (NESv2) (Save RAM)

.segment "VECTORS"
  .addr nmi
  .addr reset
  .addr 0

.segment "STARTUP"

.segment "CODE"

;===================  Constante   =============================
Speed_ball    = 03
Speed_players = 04
P0_Xpos       = $0207 ; DW
P1_Xpos       = $0213 ; DW
P0_Ypos       = $0204 ; DW
P1_Ypos       = $0210 ; DW
Ball_Xpos     = $021F ; DW
Ball_Ypos     = $021C ; DW
Ball_Limit_Under = $E0
Ball_Limit_Upper = $23

;===================  Variaveis   =============================
; Variaveis (RAM Interna do NES)
; ---> Zero Page used here ! $00--$FF (256 Bytes Free RAM) <---
Ball_Control = $00
; Bit                    Descrição

;  0                      Alive?          1-true,0-false
;  1                      move_right?     1-true,0-false
;  2                      move_down?      1-true,0-false
;  4                      side_dead?      1-left,0-right

; Memoria reserada para futura implementação de velocidade dinamica
Ball_Speed   = $01  
; Memoria reserada para futura implementação de velocidade dinamica    
Player_Speed = $02
P0_Score     = $03
P1_Score     = $04

.proc nmi
  jsr Read_Control
  jsr Colision_Ball_Player
  jsr Dead_Ball
  jsr Status_Ball

  lda #$02
  sta $4014
  bit $2002
  lda #0
  sta $2006
  sta $2006
  rti
.endproc


.proc reset
  sei
  cld
  ldx #%01000000
  stx $4017
  ldx #$ff
  txs
  inx
  stx $2000
  stx $2001
  stx $4010
@vblankWait1:
  bit $2002
  bpl @vblankWait1
  lda #$00
@clearMemory:
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne @clearMemory 
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

@vblankWait2:
  bit $2002
  bpl @vblankWait2
main:
  lda #$04
  sta $2000
  jsr Line_Center
  lda #$00
  sta $2000
  jsr Line_Up
  jsr Line_Down
  jsr Attrib_Lines
  jsr LoadPalettes
  jsr LoadSprites

  lda #$02
  sta $4014
  lda #%00011000
  sta $2001
  lda #%10000000
  sta $2000
ForeverLoop:
  jmp ForeverLoop
.endproc


.proc LoadPalettes
  bit $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #0
@loop:
  lda palettes, x
  sta $2007
  inx
  cpx #32
  bne @loop
  rts
.endproc


.proc LoadSprites
  ldx #0
@loop:
  lda sprites, x
  sta $0200, x
  inx
  cpx #(N_Sprites*4)
  bne @loop
  rts
.endproc


.proc Line_Up
  bit $2002             
  LDA #$20
  STA $2006             
  LDA #$80
  STA $2006             
  LDX #$00              
  LDA #1
@loop:
  STA $2007              
  INX                   
  CPX #$20            
  BNE @loop  
  rts
.endproc


.proc Line_Down
  bit $2002             
  LDA #$23
  STA $2006             
  LDA #$80
  STA $2006             
  LDX #$00              
  LDA #1
@loop:
  STA $2007              
  INX                   
  CPX #$20            
  BNE @loop  
  rts
.endproc


.proc Line_Center
  bit $2002             
  LDA #$20
  STA $2006             
  LDA #$B0
  STA $2006             
  LDX #$00              
  LDA #2
@loop:
  STA $2007              
  INX                   
  EOR #$02
  CPX #24            
  BNE @loop  
  rts
.endproc


.proc Attrib_Lines
  bit $2002             
  LDA #$23
  STA $2006             
  LDA #$C0
  STA $2006             
  LDX #$00              
  LDA #0
@loop:
  STA $2007              
  INX                   
  CPX #$40            
  BNE @loop  
  RTS
.endproc


.proc Read_Control
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
.endproc


.proc move_players
  tya
  clc
  adc P0_Ypos,x
  cmp #$26
  bcc exit_move_players
  cmp #$CE
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
.endproc

.proc Status_Ball
  ; Bit                     Descrição       Logica
  ;  0                      Alive?          1-true,0-false
  ;  1                      move_right?     1-true,0-false
  ;  2                      move_down?      1-true,0-false
  ;  4                      side_dead?      1-left,0-right
  
  lda #%00000001
  bit Ball_Control
  bne ball_alive
  lda #0            ; Dead Sprite (translucido)
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
  cmp #Ball_Limit_Under        ; Limite Inferior
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
  cmp #Ball_Limit_Upper        ; Limite Superior
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
.endproc


.proc Colision_Ball_Player
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
.endproc


.proc Dead_Ball
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
.endproc


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
  .byte $00
  .byte $05, $06, $07



sprites:
   N_Sprites = 24
  .byte 0, 0, %00000000, 0

  ;P0
  .byte 105, 3, %01000000, 8
  .byte 111, 3, %01000000, 8
  .byte 117, 3, %01000000, 8

  ;P1
  .byte 105, 3, %00000000, (256-8)
  .byte 111, 3, %00000000, (256-8)
  .byte 117, 3, %00000000, (256-8)

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

 
.segment "CHARS"

; Tile 0: Blank
.byte $00, $00, $00, $00, $00, $00, $00, $00
.byte $00, $00, $00, $00, $00, $00, $00, $00

; Tile 1: Line Horizons
.byte %00000000
.byte %00000000
.byte %00000000
.byte %11111111
.byte %11111111
.byte %00000000
.byte %00000000
.byte %00000000


.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile 2: Line Vertical
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000

.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile 3: Players
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000

.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile 4: Ball
.byte %11110000
.byte %11110000
.byte %11110000
.byte %11110000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile 5: Zero
.byte %00011111
.byte %00111111
.byte %01100000
.byte %01100000
.byte %01100000
.byte %01100000
.byte %01100000
.byte %01100000

.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
