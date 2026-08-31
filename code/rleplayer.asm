*=$801

chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key

src_p=$FB
src_h=$FC
dst_p=$FD
dst_h=$FE
special=$FF
end_src_p=$22
end_src_h=$23
value=$24
len=$25
pages=$26 ; count of pages indexed
page=$27 ; 0 based

screen_index = $33C
max_pages = 96

; 10 SYS 2062
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 2062", 0, 0
end_basic:
!byte 0

screen_player:
    lda #$0e
    ldx #$06
    sta $d020
    stx $d021
    sta 646
    lda #$93
    jsr chrout
    lda #<start_data
    ldx #>start_data
    sta src_p
    stx src_h
    jsr index_data
screen_loop: 
    lda page
    cmp pages
    bcc +
    rts
+   asl
    tay
    lda screen_index,y
    ldx screen_index+1,y
    sta src_p
    stx src_h
    lda #2
    ldx #0
    jsr addto_src_p
    lda #$00
    ldx #$d8
    sta dst_p
    stx dst_h
    jsr decode_color
    lda #$00
    ldx #$04
    sta dst_p
    stx dst_h
    jsr decode_text
-   jsr getin
    cmp #$00
    beq -
    cmp #3
    bne +
    lda #$93
    jmp chrout
+   cmp #20 ; delete
    bne +
--  lda page ; check if can backup a page
    beq -
    dec page
    jmp ++
+   cmp #157 ; left
    beq --
    cmp #145 ; up
    beq --
    cmp #'1'
    bcc +
    cmp #('9'+1)
    bcs +
    sec        ; 1..9
    sbc #'1'   ; because 0 based
--  cmp pages
    bcs -      ; ignore key if out of range
    sta page
    bcc ++
+   cmp #'0'
    bne +
    lda #10    ; try page 10
    bne --   
+   inc page   ; any other key, advance page
++
    lda #$93   ; before switching page, clear screen
    jsr chrout
    jmp screen_loop

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
    lda #3
    ldx #0
    jsr addto_src_p
color_loop: 
    ldy #$00
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
    lda #3
    ldx #0
    jsr addto_src_p
    ldx len
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
    lda #3
    ldx #0
    jsr addto_src_p
text_loop:
    ldy #$00
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

index_data:
    lda #0
    sta pages
    sta page
    
index_loop:
    ; setup index storage offset in .X
    ; .A already has pages
    asl
    tax

    ; set next index to 0000
    lda #0
    sta screen_index, x
    sta screen_index+1, x

    ; do check for start of page (C600 address)
    ldy #0
    lda (src_p),y
    bne index_exit
    iny
    lda (src_p),y
    cmp #$c6
    bne index_exit

    ; store indexed page
    lda src_p
    sta screen_index, x
    lda src_h
    sta screen_index+1, x
    inc pages

    ; skip C600 address
    lda #2
    sta len ; prep upcoming loop at the same time
    ldx #0
    jsr addto_src_p

    ; advance past color and text rle data using their lengths
-   ldy #1
    lda (src_p),y
    tax
    dey
    lda (src_p),y
    jsr addto_src_p
    dec len
    bne -

    ; while pages < max_pages
    lda pages
    cmp #max_pages
    bcc index_loop

index_exit:
    lda #<start_data
    ldx #>start_data
    sta src_p
    stx src_h
    rts

addto_src_p: ; A low, X high, perform 16-bit addition from/to src_p/src_h
    clc
    adc src_p
    sta src_p
    txa
    adc src_h
    sta src_h
    rts

start_data:
