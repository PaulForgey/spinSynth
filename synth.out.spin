{{
Audio master output

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Frac    = 13        ' number of fractional bits the coeefficients use

OBJ
    fp      : "synth.float"

VAR
    LONG    Cog_
    LONG    Params_[7]

    LONG    Profile_
    LONG    Filter_[12]              ' two stage of Butterworth filter coefficients (gain, b0, b1, gain, b0, b1) (x2 for atomic swap)
    LONG    FilterPtr_
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

    Filter_[0] := 1 << Frac             ' gain = 1.0
    Filter_[1] := 2 << Frac             ' b0 = 2.0
    Filter_[2] := 1 << Frac             ' b1 = 1.0 (cutoff = fs/2; no effective filter)
    Filter_[3] := 1 << Frac
    Filter_[4] := 2 << Frac
    Filter_[5] := 1 << Frac

    Filter_[6] := Filter_[0]
    Filter_[7] := Filter_[1]
    Filter_[8] := Filter_[2]
    Filter_[9] := Filter_[3]
    Filter_[10] := Filter_[4]
    Filter_[11] := Filter_[5]

    FilterPtr_ := @Filter_[0]

    Params_[0] := PinNum
    Params_[1] := InputsPtr
    Params_[2] := TriggersPtr
    Params_[3] := NumInputs
    Params_[4] := @Profile_
    Params_[5] := @FilterPtr_
    Params_[6] := @Scope_

    return (Cog_ := cognew(@entry, @Params_) + 1)
    
PUB Stop
{
Stop audio output, freeing cog
}
    if Cog_
        cogstop(Cog_ - 1)
    Cog_ := 0

PUB FilterPtr
    return FilterPtr_
    
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

PUB SetFilter(C, R) | b1, b2, b, gain0, cb0, cb1, gain1, cb2, cb3, t, cos
{
Set low pass filter
C: cutoff 1-2048 (2048 = fs/2; no filter)
R: resonance 1-1000
}
    C #>= 1                                         ' do not attempt fs/inf
    R += $10                                        ' set minimum resonance value

    R := fp.FromFixed(R << 12, 16)

    cos := WORD[$e000][$800 - C]                    ' cos(c)
    
    if cos == 0
        gain0 := 1.0
        cb0 := 2.0                                  ' no filter at fs/2 (regardless of resonance)
        cb1 := 1.0
        gain1 := gain0
        cb2 := cb0
        cb3 := cb1
    else
        t := fp.FromFixed(WORD[$e000][C], 16)
        t := fp.F_Div(t, fp.FromFixed(cos, 16))

        ' stage 1
        b1 := fp.F_Div(fp.F_Div(0.765367, R), t)    ' b1 = (0.765367 / R) / t
        b2 := fp.F_Div(1.0, fp.F_Mul(t, t))         ' b2 = 1/t^2

        b := fp.F_Add(fp.F_Add(b1, b2), 1.0)        ' b = b1 + b2 + 1

        gain0 := fp.F_Div(1.0, b)                   ' gain = 1/b

        cb0 := fp.F_Add(fp.F_Mul(-2.0, b2), 2.0)
        cb0 := fp.F_Div(cb0, b)                     ' cb0 = (-2*b2 + 2) / b

        cb1 := fp.F_Sub(fp.F_Add(1.0, b2), b1)
        cb1 := fp.F_Div(cb1, b)                     ' cb1 = (1 + b2 - b1) / b

        ' stage 2
        b1 := fp.F_Div(fp.F_Div(1.847759, R), t)

        b := fp.F_Add(fp.F_Add(b1, b2), 1.0)

        gain1 := fp.F_Div(1.0, b)                   ' gain = 1 / b

        cb2 := fp.F_Add(fp.F_Mul(-2.0, b2), 2.0)
        cb2 := fp.F_Div(cb2, b)                     ' cb2 = (-2*b2 + 2) / b

        cb3 := fp.F_Sub(fp.F_Add(1.0, b2), b1)
        cb3 := fp.F_Div(cb3, b)                     ' cb3 = (1 + b2 - b1) / b

    if FilterPtr_ == @Filter_[0]                    ' swap atomically to other filter
        Filter_[6] := fp.ToFixed(gain0, Frac)
        Filter_[7] := fp.ToFixed(cb0, Frac)
        Filter_[8] := fp.ToFixed(cb1, Frac)
        Filter_[9] := fp.ToFixed(gain1, Frac)
        Filter_[10] := fp.ToFixed(cb2, Frac)
        Filter_[11] := fp.ToFixed(cb3, Frac)
        FilterPtr_ := @Filter_[6]
    else
        Filter_[0] := fp.ToFixed(gain0, Frac)
        Filter_[1] := fp.ToFixed(cb0, Frac)
        Filter_[2] := fp.ToFixed(cb1, Frac)
        Filter_[3] := fp.ToFixed(gain1, Frac)
        Filter_[4] := fp.ToFixed(cb2, Frac)
        Filter_[5] := fp.ToFixed(cb3, Frac)
        FilterPtr_ := @Filter_[0]

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
    rdlong filter_ptr_ptr, r0
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

    mov cptr, filter_ptr_ptr                ' deref filter pointer pointer
    rdword cptr, cptr

    shl r0, #10                             ' move to high 16
    andn r0, mask16

    ' 2 pole 2 stage filter
    ' stage 1
    rdword r1, cptr                         ' gain
    add cptr, #4
    call #smult                             ' output *= gain
    shl r1, #3
    mov out, r1                             ' in high 16

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

    ' stage 2
    andn out, mask16
    mov r0, out
    rdword r1, cptr                         ' gain
    add cptr, #4
    call #smult                             ' output *= gain
    shl r1, #3
    mov out, r1                             ' in high 16

    mov r0, history+2
    rdword r1, cptr
    add cptr, #4                            ' b0
    call #smult
    shl r1, #3
    sub out, r1                             ' output -= history[2] * b0
    mov h, out                              ' new_history = output

    mov r0, history+3
    rdword r1, cptr                         ' b1
    call #smult
    shl r1, #3
    sub h, r1                               ' new_history -= history[3] * b1

    mov out, history+2
    shl out, #1
    add out, h                              ' output = new_history + history[2] * 2
    add out, history+3                      ' output += history[3] * 1

    mov history+3, history+2                ' advance history
    andn h, mask16
    mov history+2, h

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

smult                                       ' r1 *= r0, r0 in 31:16, r1 in 15:0
    test r1, sign16 wc
    muxc r1, sign16_ext
    abs r1, r1 wc                           ' adjust signs after abs (seems to be fastest way to do this)
    muxc r2, #$01
    abs r0, r0 wc
    muxc r2, #$02

    shr r1, #1 wc                           ' prime initial bit

    if_c add r1,r0 wc                       ' c*r1..
    rcr r1, #1 wc                           ' ..ultimately to the right

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1 wc

    if_c add r1, r0 wc
    rcr r1, #1

    max r1, high32s                         ' limit

    test r2, #$03 wc                        ' adjust sign
    negc r1, r1                             ' opposite sign, negative result

smult_ret
    ret


sign            long    $8000_0000
sign16          long    $0000_8000
sign16_ext      long    $ffff_8000
fsclk           long    1814
pos             long    0
mask16          long    $ffff
history         long    $8000_0000[4]
s_480           long    480
cnt_d           long    0

high            long    $000f_ffff
low             long    $fff0_0000
high32s         long    $7fff_ffff

profile_ptr     res     1
scope_ptr       res     1
filter_ptr_ptr  res     1
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
