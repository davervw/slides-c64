*=$801

chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key
plot = $FFF0 ; C clear sets cursor position X=row, Y=col, or if C set gets cursor position

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
save_border=$28
save_background=$29
save_foreground=$2a

screen_index = $33C
max_pages = 96

text_addr=$0400
color_addr=$d800

; 10 SYS 2062
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 2062", 0, 0
end_basic:
!byte 0

screen_player:
    jmp main

set_slide_colors:
    lda #$0e
    ldx #$06
    ldy #$0e
    jmp set_colors

main:
    jsr save_colors
    jsr set_slide_colors
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
    jmp exit_basic
+   asl
    tay
    lda screen_index,y
    ldx screen_index+1,y
    sta src_p
    stx src_h
    lda #2
    ldx #0
    jsr addto_src_p
    lda #<color_addr
    ldx #>color_addr
    sta dst_p
    stx dst_h
    jsr decode_color
    lda #<text_addr
    ldx #>text_addr
    sta dst_p
    stx dst_h
    jsr decode_text
-   jsr getin
    cmp #$00
    beq -
    cmp #'X'
    bne +
    jmp exit_basic_x
+   cmp #3
    bne +
    lda #$93
    jsr chrout
    jmp exit_basic
+   cmp #20 ; delete
    bne +
--  lda page ; check if can backup a page
    beq -
    dec page
    jmp ++
+   cmp #19 ; home
    bne +
    lda #0
    sta page
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

save_colors:
    lda $d020
    ldx $d021
    ldy 646
    sta save_border
    stx save_background
    sty save_foreground
    rts

exit_basic:
    lda #0
    tax
    ldy #1
    jsr set_colors
    ldx #12
    ldy #(20-exit_message_len/2)
    clc
    jsr plot
    lda #<exit_message
    ldx #>exit_message
    jsr string_out
--  jsr getin
    cmp #0
    beq --
    cmp #19
    bne ++
    lda #0
    sta page
-   lda #$93
    jsr chrout
    jsr set_slide_colors
    lda page
    cmp pages
    bcc +
    dec page
+   jmp screen_loop
++  cmp #20 ; del (backspace)
    beq -
    cmp #157 ; left
    beq -
    cmp #145 ; up
    beq -
    cmp #'1'
    bcc +
    cmp #('9'+1)
    bcs +
    sec
    sbc #'1'
    cmp pages
    bcs --
    sta page
    jmp -
+   cmp #'X'
    bne --
exit_basic_x:    
    lda save_border
    ldx save_background
    ldy save_foreground
    jsr set_colors
    lda #$93
    jmp chrout ; and exit to BASIC

set_colors:
    sta $d020
    stx $d021
    sty 646
    rts

string_out:
    sta src_p
    stx src_h
    ldy #0
-   lda (src_p), y
    beq +
    jsr chrout
    iny
    bne -
    inc src_h
    jmp -
+   rts

exit_message:
    !text "(PRESS X TO EXIT)"
exit_message_len = * - exit_message    
    !byte 0

start_data:
