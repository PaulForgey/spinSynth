{{
Audio master output

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

OBJ
    exp     : "synth.float"

VAR
    LONG    Cog_
    LONG    Params_[7]

    LONG    Profile_
    LONG    Filter_[3]              ' one stage of Butterworth filter coefficients (gain, b0, b1)
    BYTE    Scope_[480]             ' oscilliscope date
    
PUB Start(PinNum, InputsPtr, TriggersPtr, NumInputs)
{
Start audio output
PinNum:         audio output pin
InputsPtr:      pointer to array of long pointers to audio data
TriggersPtr:    pointer to array of byte pointers to triggers
NumInput:       array size of InputsPtr and TriggersPtr
}
    Stop

    Filter_[0] := 1 << 13               ' gain = 1.0
    Filter_[1] := 2 << 13               ' b0 = 2.0
    Filter_[2] := 1 << 13               ' b1 = 1.0 (cutoff = fs/2; no effective filter)

    Params_[0] := PinNum
    Params_[1] := InputsPtr
    Params_[2] := TriggersPtr
    Params_[3] := NumInputs
    Params_[4] := @Profile_
    Params_[5] := @Filter_
    Params_[6] := @Scope_
    
    return (Cog_ := cognew(@entry, @Params_) + 1)
    
PUB Stop
{
Stop audio output, freeing cog
}
    if Cog_
        cogstop(Cog_ - 1)
    Cog_ := 0
    
PUB ScopePtr
{
Return byte pointer to scope data
}
    return @Scope_

PUB Profile
{
Get clock cycles spent per sample
}
    return Profile_

PUB SetFilter(C, R) | b1, b2, b, gain, cb0, cb1, t, cos
{
Set low pass filter
C: cutoff 1-2048 (2048 = fs/2; no filter)
R: resonance 1-1000
}
    cos := WORD[$e000][$800 - C]                    ' cos(c)
    R #>= 1                                         ' set minimum resonance value
    
    if cos == 0
        gain := exp.FromFixed($1_0000)
        cb0 := exp.FromFixed($2_0000)               ' no filter at fs/2 (regardless of resonance)
        cb1 := exp.FromFixed($1_0000)
    else
        t := exp.FromFixed(WORD[$e000][C])          ' sin(c)
        t := exp.Div(t, exp.FromFixed(cos))         ' t = tan(C)

        b1 := exp.Div(exp.FromFixed($1_6a0a), exp.FromFixed(R << 16))
        b1 := exp.Div(b1, t)                        ' b1 = (sqrt(2) / R) / t

        b2 := exp.Div(exp.FromFixed($1_0000), t)
        b2 := exp.Div(b2, t)                        ' b2 = 1/t^2

                                                    ' b = b1 + b2 + 1
        b := exp.FromFixed(exp.ToFixed(b1) + exp.ToFixed(b2) + $1_0000)
        gain := exp.Div(exp.FromFixed($1_0000), b)  ' gain = 1/b

        cb0 := exp.Mult(exp.FromFixed(-$2_0000), b2)
        cb0 := exp.Plus(cb0, $2_0000)
        cb0 := exp.Div(cb0, b)                      ' cb0 = (-2*b2 + 2) / b

        cb1 := exp.FromFixed($1_0000 + exp.ToFixed(b2) - exp.ToFixed(b1))
        cb1 := exp.Div(cb1, b)                      ' cb1 = (1 + b2 - b1) / b

    Filter_[0] := exp.ToFixed(gain) >> 3
    Filter_[1] := exp.ToFixed(cb0) >> 3
    Filter_[2] := exp.ToFixed(cb1) >> 3

DAT
    org
    
entry
    mov r0, PAR
    rdlong pin, r0
    add r0, #4
    rdlong inputs_ptr, r0
    add r0, #4
    rdlong triggers_ptr, r0
    add r0, #4
    rdlong num_inputs, r0
    add r0, #4
    rdlong profile_ptr, r0
    add r0, #4
    rdlong filter_ptr, r0
    add r0, #4
    rdlong scope_ptr, r0
    
    mov r0, #1                              ' set pin to output
    shl r0, pin
    or DIRA, r0
    
    mov CTRA, pin
    movi CTRA, #%110_000                    ' duty cycle output
    
    mov sptr, #0                            ' initialize scope index

    mov tclk, CNT
    mov cnt_d, tclk
    add tclk, fsclk                         ' prime tclk
    
:window
    mov c1, #$10                            ' 16 samples per window
    
:sample    
    mov c0, num_inputs                      ' for num_input inputs..
    mov iptr, inputs_ptr                    ' reset iptr to first input
    mov r0, #0                              ' starting output value

:input
    rdlong r1, iptr                         ' pointer to samples for this input
    add iptr, #4                            ' next input
    add r1, pos                             ' pos input samples in
    rdlong r1, r1                           ' actual input sample
    add r0, r1                              ' accumulate
    djnz c0, #:input

    maxs r0, high
    mins r0, low

    shl r0, #10                             ' move to high 16
    andn r0, mask16

    mov cptr, filter_ptr
    rdword r1, cptr                         ' gain
    add cptr, #4
    call #smult                             ' output *= gain
    shl r1, #3
    mov out, r1                             ' in high 16

    ' 2 pole single stage filter
    mov r0, history+0
    rdword r1, cptr
    add cptr, #4                            ' b0
    call #smult
    shl r1, #3
    sub out, r1                             ' output -= history[0] * b0
    mov h, out                              ' new_history = output

    mov r0, history+1
    rdword r1, cptr                         ' b1
    add cptr, #4
    call #smult
    shl r1, #3
    sub h, r1                               ' new_history -= history[1] * b1

    mov out, history+0
    shl out, #1
    add out, h                              ' output = new_history + history[0] * 2
    add out, history+1                      ' output += history[1] * 1

    mov history+1, history+0                ' advance history
    andn h, mask16
    mov history+0, h

    ' finally, present the sample out

    sub cnt_d, CNT
    wrlong cnt_d, profile_ptr               ' profile

    xor out, sign                           ' convert signed -x,x to unsigned 0,2x
    mov FRQA, out                           ' set output
    waitcnt tclk, fsclk                     ' wait fs period

    mov cnt_d, CNT                          ' start measuring clock ticks to produce next sample

    shr out, #24                            ' scope uses 8 bit unsigned valuue
    cmp sptr, #0 wz                         ' trigger?
    test out, #$80 wc
    if_z_and_nc jmp #:skip
    
    mov r0, sptr
    add r0, scope_ptr
    wrbyte out, r0                          ' update the oscilliscope
    add sptr, #1
    cmp sptr, s_480 wc
    if_nc mov sptr, #0
:skip
    
    add pos, #4                             ' next set of input samples
    djnz c1, #:sample

    and pos, #$7f                           ' wraparound within two windows
    mov r0, pos                             ' ask for the other window
    or r0, #$01
    and r0, #$41
    xor r0, #$40                            ' set bit 0 for non 0, flip bit 5 for opposite window
    mov tptr, triggers_ptr                  ' for each trigger
    mov c0, num_inputs

:trigger
    rdlong r1, tptr                         ' get trigger byte
    add tptr, #4                            ' next trigger
    wrbyte r0, r1                           ' activate trigger
    djnz c0, #:trigger

    jmp #:window

smult
    ' 336 clocks total call to ret
    ' signed multiply r1 *= r0
    ' r0 must already be << 16 with lower 16 clear
    ' r1 must have upper 16 clear
    test r1, #1 wz                          ' first iteration without C
    if_nz sub r1, r0                        ' add down
    sar r1, #1 wc                           ' shift right, old bit 0 -> C
    mov c0, #15                             ' 15 more iterations (=16)
:loop
    test r1, #1 wz                          ' current bit 0 -> !Z
    if_c_and_z add r1, r0                   ' 01: add up
    if_nc_and_nz sub r1, r0                 ' 10: add down
    sar r1, #1 wc                           ' shift right, old bit 0 -> C
    djnz c0, #:loop

smult_ret
    ret


sign            long    $80000000
fsclk           long    1814
pos             long    0
mask16          long    $ffff
history         long    0[2]
s_480           long    480
cnt_d           long    0

high            long    $000f_ffff
low             long    $fff0_0000

profile_ptr     res     1
scope_ptr       res     1
filter_ptr      res     1
inputs_ptr      res     1
triggers_ptr    res     1
num_inputs      res     1

r0              res     1
r1              res     1
r2              res     1
c0              res     1
c1              res     1
h               res     1
sptr            res     1
iptr            res     1
tptr            res     1
cptr            res     1
ptr             res     1
pin             res     1
out             res     1
tclk            res     1

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
