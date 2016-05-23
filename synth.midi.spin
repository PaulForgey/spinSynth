{{
MIDI hardware interface

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    BufferLength    = 32                                ' most be an even power of 2, no smaller than a long size

VAR
    LONG    Cog_                                        ' running cog +1
    LONG    Params_[3]                                  ' parameters to routine

    BYTE    WPos_                                       ' updated by receiver
    BYTE    RPos_                                       ' updated by consumer; if WPos_==RPos_ then buffer is empty
    LONG    Buffer_[BufferLength]                       ' ring buffer
    
PUB Start(PinNum)
{
Start MIDI receiver reading from PinNum
}
    Stop

    Params_[0] := 1 << PinNum
    Params_[1] := @Buffer_
    Params_[2] := @WPos_
    return (Cog_ := cognew(@entry, @Params_) + 1)

PUB Stop
{
Stop MIDI receiver, freeing a cog
}
    if Cog_
        cogstop(Cog_ - 1)
    Cog_ := 0

PUB Empty
{
returns boolean TRUE if receiver is empty
}
    return RPos_ == WPos_
 
PUB Data
{
returns one long of a received message, blocking if empty
}
    repeat while WPos_ == RPos_
        ' block
    result := Buffer_[RPos_++]
    RPos_ &= (BufferLength-1)
 
DAT
    org
    
entry
    mov r0, PAR
    rdlong pin, r0
    add r0, #4
    rdlong buffer_ptr, r0
    add r0, #4
    rdlong pos_ptr, r0
    
loop
    '
    ' Limit ourselves to 3 byte messages (an assumption that is not generically useful)
    ' for benefit of waking up the slow SPIN code on message boundaries
    call #recv
    if_nc jmp #loop                     ' frame to start of message

message
    shl r0, #16
    mov r1, r0
    
    call #recv                          ' second byte
    if_c jmp #message

    shl r0, #8
    or r1, r0
    
    call #recv                          ' third byte
    if_c jmp #message

    or r1, r0

    rdbyte pos, pos_ptr                 ' where to put it?
    mov r0, pos
    shl r0, #2                          ' long offsets
    add r0, buffer_ptr
    wrlong r1, r0                       ' write message
    add pos, #1
    and pos, #(BufferLength-1)          ' increment and wrap around index
    wrbyte pos, pos_ptr                 ' store it back
    
    jmp #loop                           ' loop again 

recv
    test zero, #0 wc                    ' clear c
    waitpeq zero, pin                   ' start bit 
    mov bclk, baud_clks                 ' prime wait counter
    shr bclk, #1
    add bclk, baud_clks
    add bclk, CNT 
    
    mov c0, #9                          ' 9 bits
    mov r0, #0
msg
    waitcnt bclk, baud_clks             ' pause for data clock rate
    test pin, INA wc                    ' input bit -> C
    rcr r0, #1                          ' shift it in
    djnz c0, #msg                       ' for 9 total

    if_nc jmp #recv                     ' stop bit is 1, so if it isn't assume a framing error
    
    shr r0, #(32-9)                     ' adjust
    and r0, #$ff
    test r0, #$80 wc                    ' C indicates start of message
recv_ret
    ret

baud_clks   long    2560                ' 31250 baud @ 80Mhz
zero        long    0

buffer_ptr  res     1
pos_ptr     res     1
pos         res     1
pin         res     1
r0          res     1
r1          res     1
c0          res     1
bclk        res     1

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
