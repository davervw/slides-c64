chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key

src_p=$FB
src_h=$FC
dst_p=$FD
dst_h=$FE
special=$FA
end_src_p=$61
end_src_h=$62
value=$63
len=$64

*=$1C01

; 10 SYS 7182
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 7182", 0, 0
end_basic:
!byte 0

screen_player:
    lda #$0e
    ldx #$06
    sta $d020
    stx $d021
    sta 241
    lda #$93
    jsr chrout
    sei
    lda #$06 ; RAM bank 0 0000-CFFF, IO D000-DFFF, KERNAL E000-FFFF
    sta $FF00
    lda #<start_data
    ldx #>start_data
    sta src_p
    stx src_h
screen_loop: 
    ldy #$00
    lda (src_p),y
    bne +
    iny
    lda (src_p),y
    cmp #$c6
    beq ++
+   lda #$00
    sta $FF00
    cli
    rts
++  clc
    lda src_p
    adc #$02
    sta src_p
    bcc +
    inc src_h
+   lda #$00
    ldx #$d8
    sta dst_p
    stx dst_h
    jsr decode_color
    lda #$00
    ldx #$04
    sta dst_p
    stx dst_h
    jsr decode_text:
    lda #$00
    sta $FF00
    cli
-   jsr getin
    cmp #$00
    beq -
    cmp #3
    beq +
    lda #$93
    jsr chrout
    sei
    lda #$06
    sta $FF00
    jmp screen_loop
+   rts

decode_color:
    clc
    ldy #$00
    lda (src_p),y
    adc src_p
    sta end_src_p
    iny
    lda (src_p),y
    adc src_h
    sta end_src_h
    iny
    lda (src_p),y
    sta special
    clc
    lda src_p
    adc #$03
    sta src_p
    bcc +
    inc src_h
color_loop: 
+   ldy #$00
    lda (src_p),y
    cmp special
    beq ++
    iny
    sta (dst_p),y
    dey
    lsr
    lsr
    lsr
    lsr
    sta (dst_p),y
    inc src_p
    bne +
    inc src_h
+   clc
    lda dst_p
    adc #$02
    sta dst_p
    bcc +
    inc dst_h
+   jmp color_while
++  iny
    lda (src_p),y
    sta value
    iny
    lda (src_p),y
    sta len
    lda #$03
    clc
    adc src_p
    sta src_p
    bcc +
    inc src_h
+   ldx len
color_rle_loop: 
    lda value
    ldy #$01
    sta (dst_p),y
    dey
    lsr
    lsr
    lsr
    lsr
    sta (dst_p),y
    clc
    lda dst_p
    adc #$02
    sta dst_p
    bcc +
    inc dst_h
+   dex
    bne color_rle_loop
color_while:
    lda src_p
    ldx src_h
    cpx end_src_h
    bcc color_loop
    bne +
    cmp end_src_p
    bcc color_loop
+   rts

decode_text:
    clc
    ldy #$00
    lda (src_p),y
    adc src_p
    sta end_src_p
    iny
    lda (src_p),y
    adc src_h
    sta end_src_h
    iny
    lda (src_p),y
    sta special
    clc
    lda src_p
    adc #$03
    sta src_p
    bcc +
    inc src_h
text_loop:
+   ldy #$00
    lda (src_p),y
    cmp special
    beq ++
    sta (dst_p),y
    inc src_p
    bne +
    inc src_h
+   inc dst_p
    bne +
    inc dst_h
+   jmp text_while
++  iny
    lda (src_p),y
    sta value
    iny
    lda (src_p),y
    sta len
    lda #$03
    clc
    adc src_p
    sta src_p
    bcc +
    inc src_h
+   ldx len
text_rle_loop: 
    lda value
    ldy #$00
    sta (dst_p),y
    inc dst_p
    bne +
    inc dst_h
+   dex
    bne text_rle_loop
text_while:
    lda src_p
    ldx src_h
    cpx end_src_h
    bcc text_loop
    bne +
    cmp end_src_p
    bcc text_loop
+   rts

start_data:
