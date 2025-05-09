; lores.asm
; Copyright (c) 2022 by David R. Van Wagner
; davevw.com
; 
; support for drawing large fonts, plotting points, drawing lines, and positioning the text cursor

start=$C000 ; machine language org

chrout=$ffd2

syntax_error=$af08
chkcom=$aefd ; checks for $2c
frmevl=$ad9e ; evaluate expression
pulstr=$b6a3 ; pull string from descriptor stack
getbytc=$b79b ; parse byte expression from BASIC input

* = start
        jmp sys_lores_plot
        jmp sys_lores_down
        jmp sys_lores_right
        jmp sys_big_text_print
        jmp sys_locate_print
        jmp sys_lores_to
        jmp sys_set_plot

sys_lores_plot
        jsr getbytc
        stx x_coord
        jsr getbytc
        stx y_coord
        jsr lores_plot
        rts

sys_lores_to
        jsr getbytc
        stx x2_coord
        jsr getbytc
        stx y2_coord
        jsr lores_to
        rts

sys_lores_down
        jsr getbytc
        stx x_coord
        jsr getbytc
        stx y_coord
        jsr getbytc
        stx distance
-       jsr lores_plot
        ldx distance
        cpx #0
        beq +
        dec distance
        inc y_coord
        jmp -
+       rts

sys_lores_right
        jsr getbytc
        stx x_coord
        jsr getbytc
        stx y_coord
        jsr getbytc
        stx distance
-       jsr lores_plot
        ldx distance
        cpx #0
        beq +
        dec distance
        inc x_coord
        jmp -
+       rts

sys_big_text_print
        jsr chkcom
	jsr frmevl	; evaluate expression
	bit $d		; string or numeric?
	bmi +
        jmp syntax_error
+       jsr pulstr	; pull string from descriptor stack (a=len, x=lo, y=hi addr of string)        
        cmp #0
        beq +
        stx $fb
        sty $fc
        sta $fd
        jsr buffer_char_bitmaps
        jsr draw_lores_char_bitmaps
+       rts

sys_locate_print
        jsr getbytc
        stx x_coord
        jsr getbytc
        stx y_coord
        lda #19 ; home
        jsr $ffd2
        ldx x_coord
        beq +
-       lda #29 ; right
        jsr $ffd2
        dex
        bne -
+       ldx y_coord
        beq +
-       lda #17 ; down
        jsr $ffd2
        dex
        bne -
        rts

sys_set_plot
        jsr getbytc
        ldy #$80
        txa
        and #1
        beq +
        ldy #$0
+       sty unplot_flag
        rts

buffer_char_bitmaps
        lda 646
        and #$f
        sta curcolor
        lda $fd
        cmp #31 ; check length too big
        bcc +
        lda #30 ; truncate length, so don't overrun buffers
        sta $fd
+       sta buffer_char_bitmaps_counter
        sei
        jsr bank_charrom
        ldy #0
        ldx #0
        stx charrvs
        stx lowercase
-       lda ($fb),y
        jsr check_control_code
        bcc +
        jsr petscii_to_screencode
        jsr buffer_char_bitmap ; .A=char, .X=offset of destination (auto advance)
+       inc $fb
        bne +
        inc $fc
+       dec buffer_char_bitmaps_counter
        bne -
        jsr bank_norm
        cli
        rts

check_control_code
        stx savex
        cmp #$20
        bcc ++
        cmp #$80
        bcc +
        cmp #$a0
        bcc ++
+       sec
        bcs +++
++      dec $fd ; one less printable character
+++     php
        cmp #$12
        bne +
        ldx #$80
        stx charrvs
+       cmp #$92
        bne +
        ldx #0
        stx charrvs
+       cmp #$0e
        bne +
        ldx #$80
        stx lowercase
+       cmp #$8e
        bne +
        ldx #0
        stx lowercase
+       ldx #15
-       cmp color_codes, x
        bne +
        stx curcolor
        bpl ++
+       dex
        bpl -
++      ldx savex
        plp
        rts

petscii_to_screencode 
        cmp #$20
        bcs +++
-       lda #63         ; out of range '?'
        bne +           ; display it
+++     cmp #$ff        ; pi?
        bne +++
        lda #$5e        ; convert to pi screen code
        bne +           ; display it
+++     cmp #$e0
        bcc +++         ; continue on if not e0..fe
        sbc #$80        ; convert to screen code
        bne +           ; display it
+++     cmp #$c0        ; check if in range c0..df
        bcc +++         ; continue on if not c0..df
        sbc #$80        ; convert to screen code
        bne +           ; display it
+++     cmp #$a0
        bcc +++         ; continue on if not a0..bf
        sec
        sbc #$40
        bne +           ; display it
+++     cmp #$80
        bcs -           ; skip if out of range 80..9f
        cmp #$40
        bcc +           ; display if in range 20..3f
        cmp #$60
        bcs +++         ; branch if 60..7f
        sec             ; otherwise in range 40..5f
        sbc #$40        ; convert ASCII to screen code
        jmp +
+++     sbc #$20        ; convert to screen code
+	clc
        adc charrvs
        rts

buffer_char_bitmap ; .A = char, .X = dest offset, .Y = 0
        ; multiply .A * 8
        sty $ff
        asl
        rol $ff
        asl
        rol $ff
        asl
        rol $ff
        sta $fe
        clc
        lda #$D0
        adc $ff
        bit lowercase
        bpl +
        adc #$08
+       sta $ff       
-       lda ($fe),y
        sta charrom_buffer, x
        iny
        inx
        cpy #8
        bne -
        txa
        lsr
        lsr
        lsr
        tay
        dey
        lda curcolor
        sta color_buffer, y
        ldy #0
        rts

draw_lores_char_bitmaps ; input $fd length 1..10, charrom_buffer filled 8..80 bitmaps
        ldx #0 ; source into charrom_buffer
-       jsr draw_lores_char_bitmap_line
        inx
        inx
        cpx #8
        bne -
        rts

draw_lores_char_bitmap_line ; .X=0..6, $fd length 1..10, charrom_buffer bitmaps
        lda $fd
        bne +
        jmp +++
+       sta draw_line_counter
        lda #0
        sta color_column
---     lda #4
        sta draw_char_column
        lda #$c0 ; bitmask
        sta $fe
-       lda draw_char_column
        sta draw_char_counter
        lda $fe
        and charrom_buffer, x
--      dec draw_char_counter
        beq +
        lsr
        lsr
        bpl --
+       lsr ; shift to swap bits around
        bcc +
        ora #2 ; replace high bit with low bit
+       sta $ff
        lda draw_char_column
        sta draw_char_counter
        lda $fe
        and charrom_buffer+1, x
--      dec draw_char_counter
        beq +
        lsr
        lsr
        bpl --
+       lsr ; shift to swap bits around
        bcc +
        ora #2 ; replace high bit with low bit
+       asl
        asl
        ora $ff
        pha
        ldy color_column
        lda color_buffer, y
        sta 646
        pla
        tay
        lda lores_codes, y
        bpl +
        lda #18
        jsr $ffd2
        lda lores_codes, y
        eor #$80
        clc
        adc #$40
        jsr $ffd2
        lda #(18+128)
        jmp ++
+       clc
        adc #$40
++      jsr $ffd2
        dec draw_char_column
        lsr $fe
        lsr $fe
        bne -
        inc color_column
        txa
        clc
        adc #8
        tax
        dec draw_line_counter
        beq +
        jmp ---
+       lda $fd
        asl
        asl
        sta draw_line_counter
-       lda #157 ; left
        jsr $ffd2
        dex
        dex
        dec draw_line_counter
        bne -
        lda #17 ; down
        jsr $ffd2
+++     rts

lores_plot ; input .X (0..79), .Y (0..49)
        ; algorithm:
        ; loc = 1024+int(x/2)+40*int(y/2)
        ; z=peek(loc)
        ; lookup index (i 0..15) of value z in lores_codes
        ; bits=i or 2^((x and 1) + 2*(y and 1))
        ; poke z,lores_codes[bits]
        jsr compute_screen_address
        ldy #0
        lda ($fb),y
        jsr find_in_lores_codes
        pha
        jsr compute_bit
        pla
        ora power2, x
        bit unplot_flag
        bpl +
        eor power2, x
+       tax
        lda lores_codes, x
        ldy #0
        sta ($fb),y
        clc
        lda $fc
        adc #$d4
        sta $fc
        lda 646
        sta ($fb),y
+++     rts

compute_screen_address; 1024+int(x/2)+40*int(y/2)
        lda #0
        sta $fb
        lda #(1024/256)
        sta $fc
        lda y_coord
        asl ; 2*
        asl ; 4*
        and #$F8 ; drop lower 3 bits, result is now 8*int(y/2)
        sta $fd
        ldx #5
-       clc
        lda $fd
        adc $fb
        sta $fb
        bcc +
        inc $fc
+       dex
        bne -
        ; result is now 1024 + 40*int(y/2)
        lda x_coord
        lsr ; /2
        clc
        adc $fb
        sta $fb
        bcc +
        inc $fc
        ; finished
+       rts

find_in_lores_codes
        ldx #0
-       cmp lores_codes, x
        beq +
        inx
        cpx #$10
        bne -
        ldx #0
        beq +
+       txa
        rts

compute_bit ; 2*(y and 1)) + (x and 1)
        lda y_coord
        and #1
        asl
        tax
        lda x_coord
        and #1
        beq +
        inx
+       rts

bank_norm
        lda $01
        ora #$07
        sta $01
        rts

bank_ram
        lda $01
        and #$f8
        sta $01
        rts

bank_charrom ; note caller responsible for disabling/enabling interrupts or equivalent
        lda $01
        and #$F8
        ora #$03
        sta $01
        rts

bank_select
        sta my_bank
        lda $01
        and #$f8
        ora my_bank
        sta $01
        rts

lores_to
        lda #0
        sta distance
        jsr get_slope ; C=1: Y diff is greater, C=0: X diff is greater; results in x_diff, y_diff
        bcs ++

        ; increment/decrement along X axis, Y uses slope, increments ocassionally
        lda x_coord
-       clc
        adc x_sign
        sta x_coord
        lda y_diff
        clc
        adc distance
        sta distance
        sec
        sbc x_diff
        bcc +
        sta distance
        lda y_coord
        clc
        adc y_sign
        sta y_coord
+       jsr lores_plot
        lda x_coord
        cmp x2_coord
        bne -
        beq +++ ; done

++      ; increment/decrement along Y axis, X uses slope
        lda y_diff
        beq +++ ; nothing to do, same points, so done
        lda y_coord
-       clc
        adc y_sign
        sta y_coord
        lda x_diff
        clc
        adc distance
        sta distance
        sec
        sbc y_diff
        bcc +
        sta distance
        lda x_coord
        clc
        adc x_sign
        sta x_coord
+       jsr lores_plot
        lda y_coord
        cmp y2_coord
        bne -
        beq +++ ; done

+++     rts

get_slope
        lda #1
        sta x_sign
        sta y_sign
        lda x2_coord
        sec
        sbc x_coord
        sta x_diff
        bpl +
        dec x_sign ; zero
        dec x_sign ; -1
        lda #0
        sbc x_diff
        sta x_diff ; absolute value
+       lda y2_coord
        sec
        sbc y_coord
        sta y_diff
        bpl +
        dec y_sign ; zero
        dec y_sign ; -1
        lda #0
        sbc y_diff
        sta y_diff ; absolute value
+       cmp x_diff ; compare absolute values, C=1 if y_diff > x_diff
        rts

my_bank !byte 0

x_coord !byte 0
y_coord !byte 0
x2_coord !byte 0
y2_coord !byte 0
x_diff !byte 0 ; 0..79
y_diff !byte 0 ; 0..49
x_sign !byte 0 ; signed 1 or -1
y_sign !byte 0 ; signed 1 or -1
unplot_flag !byte 0 ; 0=off, 128=on

savex !byte 0

distance !byte 0
charrvs !byte 0
lowercase !byte 0
curcolor !byte 0
color_column !byte 0

buffer_char_bitmaps_counter !byte 0
draw_line_counter !byte 0
draw_char_column !byte 0
draw_char_counter !byte 0

power2 !byte 1, 2, 4, 8, 16, 32, 64, 128

lores_codes 
        !byte  96, 126, 124, 226, 123,  97, 255, 236
        !byte 108, 127, 225, 251,  98, 252, 254, 224
        !byte 0

color_codes
        !byte 144, 5, 28, 159, 156, 30, 31, 158
        !byte 129, 149, 150, 151, 152, 153, 154, 155

color_buffer ; 30 bytes to match charrom_buffer
        !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

charrom_buffer ; 8 bytes x 30 characters (note larger than will fit on normal C64 screen)
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
        !byte 0, 0, 0, 0, 0, 0, 0, 0
