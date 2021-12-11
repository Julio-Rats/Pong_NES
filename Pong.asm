.segment "HEADER"
  .byte $4E, $45, $53, $1A  ; iNES header identifier
  .byte 2                   ; 2x 16KB PRG-ROM Banks
  .byte 1                   ; 1x  8KB CHR-ROM
  .byte $02, $00            ; mapper 0, vertical mirroring
  .byte 0,0,0,0,0,0,0,0

.segment "VECTORS"
  .addr nmi
  .addr reset
  .addr 0

.segment "STARTUP"

.segment "CODE"

; Variaveis
 
Ball_Control = $00
; Bit                   Descrição
;  0                      Alive?          1-true,0-false
;  1                      move_right?     1-true,0-false
;  2                      move_down?      1-true,0-false
;  4                      side_dead?      1-left,0-right

Ball_Speed   = $01
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
  bit $2002
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
@vblankWait2:
  bit $2002
  bpl @vblankWait2
main:
  lda #%000000000
  sta Ball_Control
  lda #0
  sta P0_Score
  sta P1_Score   
  lda #2
  sta Ball_Speed
  lda #3
  sta Player_Speed

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
  adc $0204,x
  cmp #$26
  bcc exit_move_players
  cmp #$CE
  bcs exit_move_players
  sta $0204,x
  tya
  clc
  adc $0208,x
  sta $0208,x
  tya
  clc
  adc $020C,x
  sta $020C,x
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
  sta $021D
  lda #%00000010
  bit Ball_Control
  beq move_left
  lda Ball_Speed              ; Speed Move Right BALL
  clc 
  adc $021F
  sta $021F
  jmp out_move_lateral
move_left:
  lda #0                      ; Speed Move Letf BALL
  sec
  sbc Ball_Speed 
  clc 
  adc $021F
  sta $021F
out_move_lateral:
  lda #%00000100
  bit Ball_Control
  beq move_up
  lda Ball_Speed              ; Speed Move Down BALL
  clc 
  adc $021C
  cmp #$DF                    ; Limite Inferior
  bcc no_swapUD  
  lda Ball_Control
  and #%11111011
  sta Ball_Control
  jmp out_move_vertical
no_swapUD:  
  sta $021C
  jmp out_move_vertical
move_up:
  lda #0                      ; Speed Move up BALL
  sec
  sbc Ball_Speed
  clc 
  adc $021C
  cmp #$24                    ; Limite Superior
  bcs no_swapDU
  lda Ball_Control
  ora #%000000100
  sta Ball_Control
  jmp out_move_vertical
no_swapDU:
  sta $021C
out_move_vertical:
out_alive:
  rts
.endproc


.proc Colision_Ball_Player
  lda $021F
  sec
  sbc #7
  cmp $0207
  bcs No_Colision_Left
  lda $021C
  cmp $0204
  bcc No_Colision_Left
  lda $021C
  sec
  sbc #8
  cmp $020C
  bcs No_Colision_Left
  lda Ball_Control
  ora #$02
  sta Ball_Control
  jmp out_colision
No_Colision_Left:
  lda $021F
  clc
  adc #2
  cmp $0213
  bcc No_Colision_Right
  lda $021C
  cmp $0210
  bcc No_Colision_Right
  lda $021C
  sec
  sbc #8
  cmp $0218
  bcs No_Colision_Right
  lda Ball_Control
  and #$FD
  sta Ball_Control
No_Colision_Right:
out_colision:
  rts
.endproc


.proc Dead_Ball
  lda $021F
  cmp #4
  bcs No_Dead_Left
  lda Ball_Control
  and #$FE
  ora #2
  sta Ball_Control
  lda $0207
  clc 
  adc #4
  sta $021F
No_Dead_Left:
  lda $021F
  cmp #252
  bcc out_dead
  lda Ball_Control
  and #$FC
  sta Ball_Control
  lda $0213
  sec 
  sbc #4
  sta $021F
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
  .byte 111, 0, 0, 114

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
