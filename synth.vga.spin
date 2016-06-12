{{
User interface VGA back end

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    colors  = $180
    Height  = 70

VAR
    LONG    Cog_
    LONG    Params_[5]

    WORD    Status_[25]                 ' button of screen status
    WORD    TextPtr_                    ' display offset into text buffer
    WORD    Text_[Height*25]            ' text buffer (as a playfield; TextPtr_ indicates exactly where)

PUB Start(ScopePtr, GraphicsPtr) | _i
{
Start VGA graphics
ScopePtr:    byte pointer to scope data
GraphicsPtr: long pointer to free form graphics area
}
    Stop

    TextPtr_ := @Text_
    Params_[0] := ScopePtr
    Params_[1] := GraphicsPtr
    Params_[2] := @Status_
    Params_[3] := @TextPtr_
    Params_[4] := @ColorTable
    
    wordfill(@Text_, " " | $200, Height*25)
    wordfill(@Status_[0], " " | $200, 25)
    return Cog_ := (cognew(@entry, @Params_) + 1)

PUB Stop
{
Stop VGA graphics, freeing cog
}
    if Cog_
        cogstop(Cog_ - 1)
    Cog_ := 0

PUB Scroll(L)
{
Scroll to where text line L is at top of screen
}
    L <#= Height - 14
    TextPtr_ := @Text_[L * 25]

PUB TextAt(S, X, Y, Color) | ptr, c, p
{
Place 0-terminated text S at X, Y, with color Color
X: 0-24
Y: 0-14
S: 0 terminated string
Color: 0-3
}
    ptr := Y * 25 + X
    p := 0
    Color <<= 12
    repeat while (c := BYTE[S][p++])
        Text_[ptr] := Text_[ptr] & $800 | (((c & 1) << 10) | Color | $200 | (c & $fe))
        ptr++

PUB Highlight(Col, Width, At, On) | ptr
{
Highlight Width characters from Col at line At, according to boolean On
}
    ptr := At * 25 + Col
    repeat while (Width-- > 0)
        if On
            Text_[ptr++] |= $800
        else
            Text_[ptr++] &= !$800

PUB SetColor(Col, Width, At, C) | ptr, cell
{
Set color C of Width characters from Col at line At
}
    ptr := At * 25 + Col
    repeat while (Width-- > 0)
        cell := Text_[ptr] & !($3 << 12)
        Text_[ptr++] := cell | ((C & $3) << 12)
        

PUB SetStatus(Status) | p, c
{
Set the reserved bottom line of status text
}
    p := 0
    repeat while (c := BYTE[Status][p])
        Status_[++p] := ((c & 1) << 10) | (c & $fe) | $200
    repeat while (p < 24)
        Status_[++p] := " " | $200
        
DAT
    org

entry
    mov DIRA, vid_pins                      ' VGA 4 color mode, pins 16-23
    movi CTRA, #%0_00001_101
    mov FRQA, vid_freq                      ' assumes 80Mhz clock
    movi VCFG, #%0_01_1_0_0_000
    movd VCFG, #%010
    movs VCFG, #$ff
    mov VSCL, vid_scl
    
    mov r0, PAR
    rdlong scope_ptr, r0
    add r0, #4
    rdlong graphics_ptr, r0
    add r0, #4
    rdlong status_ptr, r0
    add r0, #4
    rdlong text_ptrptr, r0
    add r0, #4
    rdlong r0, r0
    
    mov cv, #16                             ' copy 16 color (2 sets of 8 for ROM charactes) table
    mov r2, #colors
:getcolors
    rdlong r1, r0
    or r1, c_black
    add r0, #4
    movd :copy, r2
    add r2, #1
:copy
    mov 0-0, r1
    djnz cv, #:getcolors

    '*
    '* Frame
    '*
frame
    mov cv, #0
    mov sptr, scope_ptr                     ' reset scope pointer
    mov gptr, graphics_ptr                  ' reset graphics pointer
    rdword tptr, text_ptrptr                ' read/reset indirect text pointer

    '*
    '* Line
    '*
line
    call #hsync                             ' sync pulse (+back porch)

    '*
    '* Things to do during horizontal retrace
    '*
    mov tl, cv
    and tl, #$1f
    shl tl, #2

    rdbyte stile, sptr                      ' get scope value

    or tl, colors_hi                        ' set up tile offset based on which line we are on

    add sptr, #1                            ' increment scope pointer
    mov spixel, hi
    shr spixel, stile                       ' displayed tile pixel
    shr stile, #5                           ' displayed tile
    add stile, #1                           ' range of ch: 8 <= stile <= 1

    mov VSCL, chr_scl                       ' 20 dots per tile

    '*
    '* Character Tiles
    '*
    mov ch, #25                             ' 25 columns of text
:text
    rdword t, tptr                          ' character tile base address
    shl t, #6                               ' as upper six bits of memory
    or t, tl                                ' offset lines 0-31 per tile

    rdlong r0, t                            ' read tile data
    shr t, #16                              ' now be color table
    movd :out, t

    add tptr, #2                            ' next tile
:out
    waitvid c_black, r0                     ' shift it out
    djnz ch, #:text

    rdlong r0, gptr                         ' prefetch first graphics byte here (because we can't later)

    mov VSCL, brdr_scl                      ' area between text and graphics
    waitvid c_blue, #0                      ' fill it in with pretty blue

    mov VSCL, vid_scl                       ' 16 dots per shift now
    mov ch, #8                              ' 8 * 16 = 128 dots for the scope

    cmp cv, line_416 wc
    if_nc jmp #:graphics                    ' scope or free-form graphics?

:scope
    cmp stile, ch wz
    if_z waitvid c_scope, spixel
    if_nz waitvid c_scope, #0
    djnz ch, #:scope

    jmp #:eol

:graphics
    waitvid c_graphics, r0
    add gptr, #4
    rdlong r0, gptr
    djnz ch, #:graphics

    test cv, #$01 wz
    if_z sub gptr, #(4*8)

:eol
    '*
    '* End Of Line
    '*
    waitvid c_black, #0                     ' back horizontal porch
    add cv, #1                              ' next line counter
    test cv, #$1f wz                        ' check tile row
    if_nz sub tptr, #(2*25)                 ' re-read if still in same row
    
    '*
    '* Display Status Area?
    '*
    cmp cv, line_448 wc                     ' status line?
    if_nc mov tptr, status_ptr
    
    '*
    '* Bottom?
    '*
    cmp cv, line_480 wc                     ' botton of the screen?
    if_c jmp #line
 
    '*
    '* End Of Frame
    '*' 
    mov cv, #10                             ' 10 lines of front veritcal porch
front
    call #hsync                             ' hsync, blank
    call #blank_line
    djnz cv, #front                         ' next vertical line of front porch

    '*
    '* Vertical Sync
    '*    
    mov cv, #2                              ' two lines of vertical sync
vsync
    mov ch, #6                              ' h+v sync
:synchv
    waitvid c_hvsync, #0
    djnz ch, #:synchv
    mov ch, #44                             ' 704 dots of black (hback, blank, hfront)
:syncv
    waitvid c_vsync, #0
    djnz ch, #:syncv
    djnz cv, #vsync                         ' next vertical line of sync

    '*
    '* End Of Vertical Sync
    '*    
    mov cv, #33                             ' 33 lines of certical back porch
back
    call #hsync
    call #blank_line
    djnz cv, #back                          ' next vertical line of back porch
    
    jmp #frame                              ' next frame

'*
'* asynchronously send the hsync and back porch
'*
hsync
    mov VSCL, sync_scl
    waitvid c_hsync, #$0f                   ' 2*3*16, 1*3*16  of sync, back porch
    mov VSCL, vid_scl
hsync_ret
    ret

blank_line
    mov VSCL, blank_scl
    waitvid c_black, #0
    mov VSCL, vid_scl    
blank_line_ret
    ret

vid_pins        long    $00ff0000
vid_freq        long    $1423d70a                   ' 25.175 Mhz dot clock (pll/4)

chr_scl         long    (1 << 12) | (1 * 20)        ' 20 dots per character tile
vid_scl         long    (1 << 12) | (1 * 16)        ' one clock per dot
sync_scl        long    ((16 * 3) << 12) | (16 * 3 * 3) ' 3 groups of 3 character widths
blank_scl       long    (1 << 12) | (1 * 16 * 41)   ' visible line's worth
brdr_scl        long    (1 << 12) | (1 * 12)        ' odd area between text and scope

line_480        long    480
line_448        long    448
line_416        long    416
hi              long    $80000000

c_scope         long    $ffffff13
c_blue          long    $0b0b0b0b
c_black         long    $03030303
c_hsync         long    $01000003
c_vsync         long    $02020202
c_hvsync        long    $00000000

c_graphics      long    %%3333_2223_2023_0023   ' white, gray, bpurple, blue

colors_hi       long    colors << 16

scope_ptr       res     1
graphics_ptr    res     1
status_ptr      res     1
text_ptrptr     res     1

r0              res     1
r1              res     1
r2              res     1
cv              res     1
ch              res     1
tptr            res     1
sptr            res     1
gptr            res     1
spixel          res     1
stile           res     1
tl              res     1
t               res     1

            fit colors

ColorTable  LONG    %%3330_0020_3330_0020, %%3330_3330_0020_0020    ' white on blue
            LONG    %%0020_3330_0020_3330, %%0020_0020_3330_3330    ' blue on white
            LONG    %%2220_0020_2220_0020, %%2220_2220_0020_0020    ' gray on blue
            LONG    %%0020_2220_0020_2220, %%0020_0020_2220_2220    ' blue on gray
            LONG    %%0010_0020_0010_0020, %%0010_0010_0020_0020    ' light blue on blue
            LONG    %%0020_0010_0020_0010, %%0020_0020_0010_0010    ' blue on light blue

{{
                            TERMS OF USE: MIT License                                                           

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
}}
