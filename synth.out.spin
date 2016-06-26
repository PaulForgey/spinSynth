{{
Audio master output

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

VAR
    LONG    Cog_
    LONG    Params_[9]

    LONG    Profile_
    LONG    Counter_
    BYTE    Scope_[480]             ' oscilliscope date

PUB Start(PinNum, InputsPtr, TriggersPtr, NumInputs, EnvelopesPtr, NumEnvelopes)
{
Start audio output
PinNum:         audio output pin
InputsPtr:      pointer to array of long pointers to audio data
TriggersPtr:    pointer to array of byte pointers to triggers
NumInput:       array size of InputsPtr and TriggersPtr
}
    Stop

    Params_[0] := PinNum
    Params_[1] := InputsPtr
    Params_[2] := TriggersPtr
    Params_[3] := NumInputs
    Params_[4] := EnvelopesPtr
    Params_[5] := NumEnvelopes
    Params_[6] := @Profile_
    Params_[7] := @Counter_
    Params_[8] := @Scope_

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
    return -Profile_

PUB CounterPtr
{
Get long pointer to value which increments every time we complete all envelopes
}
    return @Counter_

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
    rdlong envelopes_ptr, r0
    add r0, #4
    rdlong num_envelopes, r0
    add r0, #4
    rdlong profile_ptr, r0
    add r0, #4
    rdlong counter_ptr, r0
    add r0, #4
    rdlong scope_ptr, r0

    mov r0, #1                              ' set pin to output
    shl r0, pin
    or DIRA, r0

    mov CTRA, pin
    movi CTRA, #%110_000                    ' duty cycle output

    mov sptr, #0                            ' initialize scope index

    mov envelope_ptr, envelopes_ptr         ' point to first envelope
    mov envelope_cnt, num_envelopes

    mov tclk, CNT
    mov cnt_d, tclk
    add tclk, fsclk                         ' prime tclk

:window
    mov c1, #$10                            ' 16 samples per window

:sample    
    sub envelope_cnt, #1 wz
    if_z mov envelope_cnt, num_envelopes
    if_z mov envelope_ptr, envelopes_ptr
    if_z add counter, #1
    wrlong counter, counter_ptr

    call #envelope                          ' iterate an envelope (one per sample)

    mov c0, num_inputs                      ' for num_input inputs..
    mov iptr, inputs_ptr                    ' reset iptr to first input
    mov out, #0                             ' starting output value

:input
    rdlong r1, iptr                         ' pointer to samples for this input
    add iptr, #4                            ' next input
    add r1, pos                             ' pos input samples in
    rdlong r1, r1                           ' actual input sample
    add out, r1                             ' accumulate
    djnz c0, #:input

    maxs out, high
    mins out, low

    shl out, #10                            ' move to high 16

    ' present the sample out

    sub cnt_d, CNT
    wrlong cnt_d, profile_ptr               ' profile

    xor out, sign                           ' convert signed -x,x to unsigned 0,2x
    mov FRQA, out                           ' set output
    waitcnt tclk, fsclk                     ' wait fs period

    mov cnt_d, CNT                          ' start measuring clock ticks to produce next sample

    xor out, sign                           ' zoom in a bit and limit for scope, which uses 8 bit unsigned value
    maxs out, scope_high
    mins out, scope_low
    shr out, #21
    xor out, #$80

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

'*
'* iterate an envelope
'*
envelope
    rdlong env, envelope_ptr                    ' current value

    mov r0, envelope_ptr                        ' note where we read it from
    add envelope_ptr, #4

    rdlong goal, envelope_ptr

    add envelope_ptr, #4
    sub goal, env                               ' find goal-env

    rdlong rate, envelope_ptr

    add envelope_ptr, #4
    abs goal, goal wc                           ' consider minimum |goal| or rate

    rdlong mod, envelope_ptr                    ' modulation value

    add envelope_ptr, #4
    max rate, goal

    negc rate, rate                             ' restore sign
    add env, rate                               ' move envelope

    ' [nop]
    ' [nop]

    wrlong env, r0                              ' store moved value before external modulation

    add env, mod
    maxs env, env_max                           ' clamp envelope after modulation

    rdlong eptr, envelope_ptr wz                ' pointer to log output value

    add envelope_ptr, #4
    if_z jmp envelope_ret                       ' we are done if no pointer

    mins env, #0
    mov r0, env_max

    sub r0, env
    ' [nop]

    wrlong r0, eptr

envelope_ret
    ret

sign            long    $8000_0000
sign16          long    $0000_8000
sign16_ext      long    $ffff_8000
fsclk           long    1814
pos             long    0
s_480           long    480
cnt_d           long    0
counter         long    0

high            long    $000f_ffff
low             long    $fff0_0000
high32s         long    $7fff_ffff
scope_high      long    $1fff_ffff
scope_low       long    $e000_0000

env_max         long    $2_2000

profile_ptr     res     1
counter_ptr     res     1
scope_ptr       res     1
inputs_ptr      res     1
triggers_ptr    res     1
num_inputs      res     1
envelopes_ptr   res     1
num_envelopes   res     1
envelope_ptr    res     1
envelope_cnt    res     1

r0              res     1
r1              res     1
r2              res     1
c0              res     1
c1              res     1
sptr            res     1
iptr            res     1
tptr            res     1
ptr             res     1
pin             res     1
out             res     1
tclk            res     1
eptr            res     1
exp             res     1
env             res     1
goal            res     1
rate            res     1
mod             res     1

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
