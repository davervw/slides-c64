# SLIDES for Commodore 64

This project started so I could self-host a presentation from a Commodore 64 emulator about said [emulator](https://github.com/davervw/simple-emu-c64).  

![Presentation](https://github.com/davervw/slides-c64/raw/master/slides.gif)

Example slide definition:

    4000 DATA "!-"
    4050 DATA "!C
    4100 DATA "!F7
    4150 DATA ""
    4200 DATA "HISTORY"
    4250 DATA ""
    4300 DATA "!F15"
    4350 DATA "!L"
    4400 DATA "-   * GOAL: MINIMAL IMPLEMENTATION"
    4450 DATA ""
    4500 DATA "-   * PUZZLE: JUST BASIC?
    4550 DATA "-   * PUZZLE: 6502 EMULATOR
    4600 DATA ""
    4650 DATA "-   * EMULATOR PLAYGROUND"
    4700 DATA "-   * WHAT IFS"
    4750 DATA "!-"

Slides are defined in BASIC DATA statements.

    DATA "!B6" : REM background color 6
    DATA "!D12" : REM border color 12
    DATA "!F3"  : REM foreground color 3
    DATA "!." : REM horizontal line
    DATA "!-" : REM new slide
    DATA "!C" : REM center align text
    DATA "!L" : REM left align text
    DATA "!E" : REM end of slides
    DATA "TEXT" : REM display string TEXT using large 4x4 font
    DATA "-TEXT" : REM use standard size font
    DATA "" : REM blank line

User can use left/right cursor keys to navigate, and number keys to jump to page, advances on other keys

Source code is 6502 assembler and BASIC targeting Commodore 64

Low resolution PETSCII graphics machine language support has five entry points.  

    SYS 49152,X,Y : REM to plot using the quad-character PETSCII graphics 80x50 on 40x25 screen using POKEs
    SYS 49155,X,Y,V-1 : REM plot vertical line V pixels (80x50) high using POKEs
    SYS 49158,X,Y,H-1 : REM plot horizontal line H pixels (80x50) wide using POKEs
    SYS 49161,"Hello" : REM draw big text (4x4 characters) using lores pixels using character out
    SYS 49164,X,Y : REM locate text cursor on 40x25 screen using HOME/LEFT/DOWN characters out
    SYS 49167,X,Y : REM draw line to 80x50 position using quad-character PETSCII graphics PEEK/POKEs
    SYS 49170,C : REM set plot(1), or unplot(0) for subsequent plot operations
    SYS 49173 : REM store text/color to save buffer
    SYS 49176 : REM swap text/color with save buffer

Note that the big text entry supports control characters (18/146, 14/142) for reverse on/off and lowercase on/off and a sample program "BIG EDITOR" is included to demonstrate typing big text on the screen with cursor control, colors, etc.

![Slides directory](https://github.com/davervw/slides-c64/raw/master/slides.png)

![Lores demo](https://github.com/davervw/slides-c64/raw/master/slides2.png)
LORES DEMO program

Building requires bin/win/[acme.exe](https://sourceforge.net/projects/acme-crossass/) and bin/win/c1541.exe from [Vice](http://vice-emu.sourceforge.net/index.html#download)
and revise build.sh to use more Vice executables. 

[Slides.D64](https://github.com/davervw/slides-c64/raw/master/build/slides.d64) disk image
