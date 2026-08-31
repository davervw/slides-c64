;; rleplayer.asm - interactive player of multiple run length encoded color/text screens (aka slides)
;; by David R. Van Wagner
;;
;; MIT LICENSE
;;
;; github.com/davervw/slides-c64
;; davevw.com
;;
;; targets: one of TARGET_C64, TARGET_C128, TARGET_TED
;;   (set in build.sh or equivalent)
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MIT License
;;
;; Copyright (c) 2026 David R. Van Wagner
;; davevw.com
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

chrout = $FFD2 ; character out to device (normally screen)
getin = $FFE4 ; read character from keyboard, 0=no key
plot = $FFF0 ; C clear sets cursor position X=row, Y=col, or if C set gets cursor position

!ifdef TARGET_C64 {
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

border=$d020
background=$d021
foreground=646

*=$801

; 10 SYS 2062
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 2062", 0
end_basic:
!byte 0, 0
}

!ifdef TARGET_C128 {
src_p=$FB
src_h=$FC
dst_p=$FD
dst_h=$FE
special=$FA
end_src_p=$61
end_src_h=$62
value=$63
len=$64
pages=$65
page=$66
save_border=$67
save_background=$68
save_foreground=$69

screen_index=$0B00
max_pages=127

text_addr=$0400
color_addr=$d800

border=$d020
background=$d021
foreground=241

*=$1C01

; 10 graphic 5,1:printchr$(15)"graphic 0 !!!":graphic 0
!byte $25,$1c,$0a,$00,$de,$20,$35,$2c,$31,$3a,$99,$c7,$28,$31,$35,$29
!byte $22,$47,$52,$41,$50,$48,$49,$43,$20,$30,$20,$21,$21,$21,$22,$3a
!byte $de,$20,$30,$00

; 20 bank 15:sys 7224
!text $36,$1c,$14,$00,$fe,$02,$20,$31,$35,$3a,$9e," 7224",$00

end_basic:
!byte 0, 0
}

!ifdef TARGET_TED { ; Commodore 16, 116, Plus/4, etc.
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
save_border=$6C
save_background=$6D
save_foreground=$6E

screen_index=$333
max_pages=96

text_addr=$0c00
color_addr=$0800

*=$1001

; 10 SYS 4110
!byte <end_basic, >end_basic
!text 10, 0, $9E, " 4110", 0, 0
end_basic:
!byte 0
}

screen_player:
    jmp main

set_slide_colors:
    lda #$05 ; 0E=C64 foreground
    ldx #$06
    ldy #$0e
!ifdef TARGET_TED {
    jmp xlat_set_colors
} else {
    jmp set_colors
}

main:
    jsr save_colors
    jsr set_slide_colors
    lda #$0E ; 0E=lowercase, otherwise 93=clearscreen
    jsr chrout
!ifdef TARGET_C128 {
    jsr sei_c128_ram_bank
}
!ifdef TARGET_TED {
    jsr sei_ted_ram_bank
}
    lda #<start_data
    ldx #>start_data
    sta src_p
    stx src_h
    jsr index_data
screen_loop: 
!ifdef TARGET_C128 {
    jsr sei_c128_ram_bank
}
!ifdef TARGET_TED {
    jsr sei_ted_ram_bank
}
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
    jsr addbyteto_src_p
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
!ifdef TARGET_C128 {    
    jsr c128_rom_bank_cli
}
!ifdef TARGET_TED {    
    jsr ted_rom_bank_cli
}
-   jsr getin
    cmp #$00
    beq -
    cmp #'X'
    bne +
    jmp exit_basic_x
+   cmp #27 ; ESC
    beq +
    cmp #3
    bne ++
+   lda #$93
    jsr chrout
    jmp exit_basic
++  cmp #20 ; delete
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

!ifdef TARGET_TED {
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
} else { ; TARGET_C64 or TARGET_C128
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
    jsr addbyteto_src_p
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
}

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
!ifdef TARGET_TED {
    sta value1
} else {
    sta value
}
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
!ifdef TARGET_TED {
    lda value1
} else {
    lda value
}
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

exit_basic:
    lda #0
    tax
    ldy #1
!ifdef TARGET_TED {
    jsr xlat_set_colors
} else {
    jsr set_colors
}
!ifdef TARGET_C128 {    
    jsr c128_rom_bank_cli
}
!ifdef TARGET_TED {    
    jsr ted_rom_bank_cli
}
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
!ifdef TARGET_C128 {
    jsr c128_rom_bank_cli
}
    lda save_border
    ldx save_background
    ldy save_foreground
!ifdef TARGET_TED {
    jsr set_ted_colors ; no translation
    ldy #14
-   lda #0
    sta src_p,y
    dey
    bpl -
    jsr ted_rom_bank_cli
} else {
    jsr set_colors
}
    lda #$93
    jmp chrout ; and exit to BASIC

!ifdef TARGET_TED {
xlat_set_colors:
    sta value1
    lda color_table,x
    sta $ff15 ; background
    ldx value1
    lda color_table,x
    sta $ff19 ; border
    lda color_table,y
    sta $053B ; foreground (KERNAL)
    rts

save_colors:
    lda $ff15
    ldx $ff19
    ldy $053B
    sta save_border
    stx save_background
    sty save_foreground
    rts

set_ted_colors:
    sta $ff15
    stx $ff19
    sty $053B
    rts
} else { ; TARGET_C64 OR TARGET_C128
set_colors:
    sta border
    stx background   
    sty foreground
    rts

save_colors:
    lda border
    ldx background
    ldy foreground
    sta save_border
    stx save_background
    sty save_foreground
    rts
}

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

!ifdef TARGET_C128 {
sei_c128_ram_bank:
    sei
    lda #$06 ; RAM bank 0 0000-CFFF, IO D000-DFFF, KERNAL E000-FFFF
    sta $FF00
    rts

c128_rom_bank_cli:
    lda #$00
    sta $FF00
    cli
    rts
}

!ifdef TARGET_TED {
sei_ted_ram_bank:
    sei
    sta $ff3f ; bank in RAM
    rts

ted_rom_bank_cli:
    sta $ff3e ; bank in ROM
    cli
    rts
}

exit_message:
    !text "(PRESS X TO EXIT)"
exit_message_len = * - exit_message    
    !byte 0

!ifdef TARGET_TED {
; C64 color to TED color mappings
color_table:  !byte $00,$71,$42,$63,$54,$55,$26,$77,$58,$38,$6B,$31,$41,$7F,$56,$61
}

start_data:
