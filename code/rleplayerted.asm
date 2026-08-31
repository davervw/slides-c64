*=$1001

chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key

src_p=$60
src_h=$61
dst_p=$62
dst_h=$63
special=$64
end_src_p=$65
end_src_h=$66
value1=$67
value2=$68
len=$69
pages=$6A
page=$6B

screen_index=$333
max_pages=96

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
    sei
    sta $ff3f ; bank in RAM
    jsr index_data
screen_loop: 
    lda page
    cmp pages
    bcc +
    jmp exitbasic
+   asl
    tay
    lda screen_index,y
    ldx screen_index+1,y
    sta src_p
    stx src_h
    lda #2
    jsr addbyteto_src_p
    lda #$00
    ldx #$08 ; color attributes memory
    sta dst_p
    stx dst_h
    jsr decode_color
    lda #$00
    ldx #$0C ; text screen memory
    sta dst_p
    stx dst_h
    jsr decode_text
    sta $ff3e ; bank in ROM
    cli
-   jsr getin
    cmp #$00
    beq -
    cmp #27 ; ESC
    beq do_exit
    cmp #3 ; STOP
    bne +
do_exit:    
    lda #$93 ; clear screen
    jsr chrout
    jmp exitbasic
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
    sei
    sta $ff3f ; bank in RAM
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
    jsr addbyteto_src_p
color_loop: 
    ldy #$00
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
    lda #3
    jsr addbyteto_src_p   
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
    jsr addbyteto_src_p

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
    ; reset start_data
    lda #<start_data
    ldx #>start_data
    sta src_p
    stx src_h
    rts

addbyteto_src_p: ; ; A low, !! Warning: X is set to 0 !! fall through to 16-bit add
    ldx #0
addto_src_p: ; A low, X high, perform 16-bit addition from/to src_p/src_h
    clc
    adc src_p
    sta src_p
    txa
    adc src_h
    sta src_h
    rts

exitbasic:
    ldy #11
-   lda #0
    sta src_p,y
    dey
    bpl -
    sta $ff3e ; bank in ROM
    cli
    rts ; exit to BASIC

; C64 color to TED color mappings
color_table:  !byte $00,$71,$42,$63,$54,$55,$26,$77,$58,$38,$6B,$31,$41,$7F,$56,$61

start_data:
