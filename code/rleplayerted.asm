*=$1001

chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key

src_p=$5E
src_h=$5F
dst_p=$60
dst_h=$61
special=$62
end_src_p=$63
end_src_h=$64
value1=$65
value2=$66
len=$67

; 10 SYS 4110
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 4110", 0, 0
end_basic:
!byte 0

screen_player:
    ldx #$0e
    ldy #$06
    lda color_table,x
    sta $ff19 ; border (TED)
    sta $053B ; foreground (KERNAL)
    lda color_table,y
    sta $ff15 ; background (TED)
    lda #$93
    jsr chrout
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
+   rts
++  clc
    lda src_p
    adc #$02
    sta src_p
    bcc +
    inc src_h
+   lda #$00
    ldx #$08 ; color attributes memory
    sta dst_p
    stx dst_h
    jsr decode_color
    lda #$00
    ldx #$0C ; text screen memory
    sta dst_p
    stx dst_h
    jsr decode_text:
-   jsr getin
    cmp #$00
    beq -
    cmp #3
    beq +
    lda #$93
    jsr chrout
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
    pha
    lsr
    lsr
    lsr
    lsr
    tax
    lda color_table, x
    sta (dst_p),y
    pla
    and #$0f
    tax
    lda color_table, x
    iny
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
    lsr
    lsr
    lsr
    lsr
    tax
    lda color_table, x
    sta value1
    lda (src_p),y
    and #$0F
    tax
    lda color_table, x
    sta value2
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
    ldy #0
    lda value1
    sta (dst_p),y
    lda value2
    iny
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
    bcs +
    jmp color_loop
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
    sta value1
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
    lda value1
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

; C64 color to TED color mappings
color_table:  !byte $00,$71,$42,$63,$54,$55,$26,$77,$58,$38,$6B,$31,$41,$7F,$56,$61

start_data:
