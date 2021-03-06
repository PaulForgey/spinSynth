{{
Oscillators and operators

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

OBJ
    tables      : "synth.osc.tables"

CON
    Bus_Zero        = 0                                 ' read only 0 value
    Bus_Nowhere     = 1                                 ' write only discard value
    Bus_Out         = 2                                 ' audio output (add, never mov)
    Bus_0           = 3                                 ' general purpose operator busses
    Bus_1           = 4
    Bus_2           = 5
    Bus_3           = 6
    Bus_4           = 7
    Bus_5           = 8
    Bus_6           = 9
    Bus_7           = 10
    
VAR
    LONG    Cog_
    LONG    Params_[8]

    LONG    Profile_                                    ' updated with -clock count per pass
    BYTE    Trigger_                                    ' set to non-0 to trigger output, non-LSB specifies offset within buffer
    
    LONG    Output_[$20]                                ' two 16 sample windows of output

PUB OutputPtr
{
return long pointer to output sample buffer
output format is in signed longs
}
    return @Output_
    
PUB TriggerPtr
{
return byte pointer to trigger
write a non-0 value to activate, set bit 6 pointing to Output_[0] or Output_[$10]
}
    return @Trigger_

PUB Profile
{
return number of clock cycles per last frame redered
}
    return -Profile_

PUB Start(InputsPtr, AlgoPtr, FeedbackPtr) | o
{
start an oscillator cog
InputsPtr:  long pointer to 32 longs (4 values per 8 oscillators)
AlgoPtr:    byte pointer to alogirthm selection, 0 based
FeedbackPtr:byte pointer to feedback shift value, higher is lower, 16 turns it off completely
}
    Stop

    repeat o from 0 to 7
        LONG[InputsPtr][1+o*4] := $8800 << 15 + $100 ' start silent

    Params_[0] := InputsPtr
    Params_[1] := AlgoPtr
    Params_[2] := FeedbackPtr
    Params_[3] := tables.SinesPtr
    Params_[4] := @Algs
    Params_[5] := @Output_
    Params_[6] := @Trigger_
    Params_[7] := @Profile_

    return (Cog_ := cognew(@entry, @Params_) + 1)
    
PUB Stop
{
stop an oscillator cog, freeing it
}
    if (Cog_)
        cogstop(Cog_ - 1)
    Cog_ := 0

DAT
    org

entry
    mov r0, PAR
    rdlong input_ptr, r0
    add r0, #4
    rdlong alg_ptr, r0
    add r0, #4
    rdlong feedback_ptr, r0
    add r0, #4
    rdlong sine_ptr, r0
    add r0, #4
    rdlong algs_ptr, r0
    add r0, #4
    rdlong output_ptr, r0
    add r0, #4
    rdlong sync_ptr, r0
    add r0, #4
    rdlong profile_ptr, r0

wait
    mov cnt_d, CNT

    rdbyte r0, sync_ptr wz

    if_z jmp #wait
    and r0, #$40                        ' select low or high half

    wrbyte zero, sync_ptr

    mov outp, output_ptr
    add outp, r0

    rdbyte fb, feedback_ptr

    mov c0, #$10                        ' 16 samples of output
    mov r0, alg

    rdbyte alg, alg_ptr

    cmp alg, r0 wz
    if_nz call #change_alg

    mov input, input_ptr                ' reset oscillator bank inputs

    mov r0, #osc_f+0
    mov r1, #osc_rate+0
    mov r2, #osc_env+0
    mov c1, #8

params
    movd f_ind, r0
    movd rate_ind, r1

f_ind
    rdlong osc_f+0, input

    add input, #4
    movs env_ind, r2

    rdlong rate, input

env_ind
    sub rate, osc_env+0
    sar rate, #4

    add r0, #1
    add r1, #1

rate_ind
    mov osc_rate+0, rate
    add r2, #1

    add input, #12
    djnz c1, #params

sample
    mov out, #0                         ' reset current output sample

    '=== pre-initialized to default algorithm 0 (organ mode, feedback operators from self)
    
    ' oscillator 0
osc_0_in
    mov mod, zero

    mov t, osc_t+0
    mov f, osc_f+0
    mov env, osc_env+0

    call #oscillator

    mov osc_t+0, t
    add osc_env+0, osc_rate+0
    
    ' oscillator 0 output
osc_0_out
    add out, r0
    mov nowhere, r0

    '===

    ' oscillator 1
osc_1_in
    mov mod, zero
    
    mov t, osc_t+1    
    mov f, osc_f+1
    mov env, osc_env+1

    call #oscillator

    mov osc_t+1, t
    add osc_env+1, osc_rate+1

    ' oscillator 1 output
osc_1_out
    add out, r0
    mov nowhere, r0
    
    '===
    
    ' oscillator 2
osc_2_in
    mov mod, zero

    mov t, osc_t+2
    mov f, osc_f+2
    mov env, osc_env+2

    call #oscillator

    mov osc_t+2, t
    add osc_env+2, osc_rate+2
    
    ' oscillator 2 output
osc_2_out
    add out, r0
    mov nowhere, r0

    '===

    ' oscillator 3
osc_3_in
    mov mod, bus+3

    ' this is a feedback oscillator
    mov r0, mod
    add mod, fb3
    mov fb3, r0
    sar mod, fb

    mov t, osc_t+3
    mov f, osc_f+3
    mov env, osc_env+3

    call #oscillator

    mov osc_t+3, t
    add osc_env+3, osc_rate+3

    ' oscillator 3 output
osc_3_out
    add out, r0
    mov bus+3, r0

    '===

    ' oscillator 4
osc_4_in
    mov mod, zero

    mov t, osc_t+4
    mov f, osc_f+4
    mov env, osc_env+4

    call #oscillator

    mov osc_t+4, t
    add osc_env+4, osc_rate+4
    
    ' oscillator 4 output
osc_4_out
    add out, r0
    mov nowhere, r0

    '===

    ' oscillator 5
osc_5_in
    mov mod, zero

    mov t, osc_t+5
    mov f, osc_f+5
    mov env, osc_env+5

    call #oscillator

    mov osc_t+5, t
    add osc_env+5, osc_rate+5

    ' oscillator 5 output
osc_5_out
    add out, r0
    mov nowhere, r0
    
    '===
    
    ' oscillator 6
osc_6_in
    mov mod, zero

    mov t, osc_t+6
    mov f, osc_f+6
    mov env, osc_env+6

    call #oscillator

    mov osc_t+6, t
    add osc_env+6, osc_rate+6
    
    ' oscillator 6 output
osc_6_out
    add out, r0
    mov nowhere, r0

    '===

    ' oscillator 7
osc_7_in
    mov mod, bus+7
    
    ' feedback oscillator
    mov r0, mod
    add mod, fb7
    mov fb7, r0
    sar mod, fb

    mov t, osc_t+7
    mov f, osc_f+7
    mov env, osc_env+7

    call #oscillator

    mov osc_t+7, t
    add osc_env+7, osc_rate+7
    
    ' oscillator 7 output
osc_7_out
    add out, r0
    mov bus+7, r0

'*
'* Master Output
'*
    wrlong out, outp                    ' output
    add outp, #4                        ' post increment output pointer

    djnz c0, #sample                    ' next sample
    
    sub cnt_d, CNT                      ' profile info
    wrlong cnt_d, profile_ptr
    
    jmp #wait

'*
'* Oscillator
'*
oscillator
    add t, f                            ' add t
    mov r0, t                           ' t -> r0 (t is left as t+f)
    shl mod, #5                         ' scale input
    add r0, mod                         ' modulate
    shr r0, #8                          ' whole number t
    test r0, half wz                    ' sign into z
    and r0, half_mask
    cmp quarter, r0 wc                  ' odd quarter?
    negc r0, r0
    if_c and r0, quarter_mask
    shr env, #1                         ' scale envelope ($2_2000 -> $1_1000, word offset $8800)
    add r0, sine_ptr                    ' sine table

    rdword r0, r0                       ' r0=log(sin(r0))

    shl r0, #1                          ' word offset
    add env, r0                         ' exp of sine+env

    mov r0, env
    and r0, quarter_mask                ' fractional exponent

    xor r0, quarter_mask                ' which is negative
    add r0, alog_ptr

    rdword r0, r0                       ' r0=alog(r0)

    or r0, bit16                        ' whole part
    shr env, #12                        ' whole exponent
    max env, #31
    shr r0, env                         ' into the right power of 2
    negnz r0, r0                        ' finally, restore sign

oscillator_ret
    ret                                 ' r0 has an 18 bit sample value

'*
'* Switch Algorithm
'*
change_alg
    mov r0, alg
    shl r0, #5                          ' each entry is 4 bytes * 8 oscillators

    add r0, algs_ptr
    
    ' operator 1, voice 1
    call #read_alg_bus
    movs osc_0_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_0_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_0_out+1, r1                ' output mov

    add r0, #1
    ' operator 2, voice 1
    call #read_alg_bus
    movs osc_1_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_1_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_1_out+1, r1                ' output mov

    add r0, #1
    ' operator 3, voice 1
    call #read_alg_bus
    movs osc_2_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_2_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_2_out+1, r1                ' output mov

    add r0, #1
    ' operator 4, voice 1
    call #read_alg_bus
    movs osc_3_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_3_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_3_out+1, r1                ' output mov

    add r0, #1
    ' operator 1, voice 2
    call #read_alg_bus
    movs osc_4_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_4_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_4_out+1, r1                ' output mov

    add r0, #1
    ' operator 2, voice 2
    call #read_alg_bus
    movs osc_5_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_5_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_5_out+1, r1                ' output mov

    add r0, #1
    ' operator 3, voice 2
    call #read_alg_bus
    movs osc_6_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_6_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_6_out+1, r1                ' output mov

    add r0, #1
    ' operator 4, voice 2
    call #read_alg_bus
    movs osc_7_in, r1                   ' modulator source

    call #read_alg_bus
    movd osc_7_out, r1                  ' output add
    
    call #read_alg_bus
    movd osc_7_out+1, r1                ' output mov

change_alg_ret
    ret

read_alg_bus
    rdbyte r1, r0                       ' byte offset + ..
    add r0, #1                          ' advance next pointer
    add r1, #zero                       ' [..byte offset +] zero (e.g. 0 = zero, 1 = nowhere, 2 = out, 3 = bus0, etc)
read_alg_bus_ret
    ret


zero            long    0               ' read only, always 0
nowhere         long    0               ' write only, discard
out             long    0               ' audio bus output
bus             long    0[8]            ' general purpose modulation paths

alog_ptr        long    $d000

quarter         long    $0800 << 1
quarter_mask    long    $07ff << 1
half            long    $1000 << 1
half_mask       long    $0fff << 1
period          long    $2000 << 1
minus_one       long    $ffff_ffff
bit16           long    $0001_0000
alg             long    0
fb3             long    0               ' smoothing buffer for osc3 feedback
fb7             long    0               ' smoothing buffer for osc7 feedback

osc_t           long    0[8]
osc_f           long    0[8]
osc_env         long    0[8]
osc_rate        long    0[8]

input_ptr       res     1               ' frequency, level, 0, envelope (4 longs)
alg_ptr         res     1
feedback_ptr    res     1
sine_ptr        res     1
algs_ptr        res     1
output_ptr      res     1
sync_ptr        res     1
profile_ptr     res     1

r0              res     1
r1              res     1
r2              res     1
env             res     1
rate            res     1
f               res     1
t               res     1
mod             res     1
fb              res     1
c0              res     1
c1              res     1
input           res     1
outp            res     1
cnt_d           res     1

Algs
{{
Algorithm table.
**IMPORTANT! If these change, so must synth.ui.graphics to reflect them

Each algorithm identically configures a pair of four oscillators (two voices occupy one instance of this object)
Each of 8 oscillators uses 4 bytes for input, add output, mov output, reserved
Adding an output adds to that bus, where Moving a value sets it
If a given input is to see the summation of outputs, it is important that:
1- the output has a mov at some point to avoid continuous accumlation
2- read before mov, mov before add, add before read
3- these operations happen in order listed
The output bus is automatically reset, never mov to it
Always discard output to Nowhere, and never read from it
Always read zero input from Zero, and never write to it

Oscillators 3 and 7 are feedback oscillators, so input to them are feedback scaled
}}

{{
 Algorithm 1
1 2 3 4*
}}
'       input       add         mov             mbz
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_3,      Bus_Out,    Bus_3,          0

BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_4,      Bus_Out,    Bus_4,          0
{{
 Algorithm 2
    4*
    |
1 2 3
}}
'       input       add         mov             mbz
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_2,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_2,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_6,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_6,      Bus_Nowhere,Bus_6,          0
{{
 Algorithm 3
    4*
|=|=|
1 2 3
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_0,      Bus_Nowhere,Bus_0,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_4,      Bus_Nowhere,Bus_4,          0
{{
 Algorithm 4
2 4*
| |
1 3
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_0,          0
BYTE    Bus_3,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_3,      Bus_Nowhere,Bus_3,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_4,          0
BYTE    Bus_7,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_7,      Bus_Nowhere,Bus_7,          0

{{
 Algorithm 5
2 4-|
| | |
1 3-|
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_0,          0
BYTE    Bus_2,      Bus_Out,    Bus_3,          0
BYTE    Bus_3,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_4,          0
BYTE    Bus_6,      Bus_Out,    Bus_7,          0
BYTE    Bus_7,      Bus_Nowhere,Bus_6,          0

{{
 Algorithm 6
  4*
  |
  3
  |
1 2
}}
'       input       add         mov             mbz
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_1,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_2,      Bus_Nowhere,Bus_1,          0
BYTE    Bus_2,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_5,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_6,      Bus_Nowhere,Bus_5,          0
BYTE    Bus_6,      Bus_Nowhere,Bus_6,          0
{{
 Algorithm 7
  4-|
  | |
  3 |
  | |
1 2-|
}}
'       input       add         mov             mbz
BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_1,      Bus_Out,    Bus_3,          0
BYTE    Bus_2,      Bus_Nowhere,Bus_1,          0
BYTE    Bus_3,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_Zero,   Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_5,      Bus_Out,    Bus_7,          0
BYTE    Bus_6,      Bus_Nowhere,Bus_5,          0
BYTE    Bus_7,      Bus_Nowhere,Bus_6,          0
{{
 Algorithm 8
  4*
  |
2 3
|=|
  1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_0,          0
BYTE    Bus_2,      Bus_0,      Bus_Nowhere,    0
BYTE    Bus_2,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_4,          0
BYTE    Bus_6,      Bus_4,      Bus_Nowhere,    0
BYTE    Bus_6,      Bus_nowhere,Bus_6,          0
{{
 Algorithm 9
  4=|
  | |
2 3=|
|=|
  1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_0,          0
BYTE    Bus_2,      Bus_0,      Bus_1,          0
BYTE    Bus_1,      Bus_nowhere,Bus_2,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_4,          0
BYTE    Bus_6,      Bus_4,      Bus_5,          0
BYTE    Bus_5,      Bus_nowhere,Bus_6,          0

{{
 Algorithm 10
3
|
2 4*
|=|
  1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_1,      Bus_Nowhere,Bus_0,          0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_1,          0
BYTE    Bus_3,      Bus_0,      Bus_3,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_5,      Bus_Nowhere,Bus_4,          0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_5,          0
BYTE    Bus_7,      Bus_4,      Bus_7,          0

{{
 Algorithm 11

2 3 4*
|=|=|
    1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_0,          0
BYTE    Bus_Zero,   Bus_0,      Bus_Nowhere,    0
BYTE    Bus_3,      Bus_0,      Bus_3,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_4,          0
BYTE    Bus_Zero,   Bus_4,      Bus_Nowhere,    0
BYTE    Bus_7,      Bus_4,      Bus_7,          0

{{
 Algorithm 12
3 4*
|=|
  2
  |
  1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_1,      Bus_Nowhere,Bus_0,          0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_1,          0
BYTE    Bus_3,      Bus_1,      Bus_3,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_5,      Bus_Nowhere,Bus_4,          0
BYTE    Bus_Zero,   Bus_Nowhere,Bus_5,          0
BYTE    Bus_7,      Bus_5,      Bus_7,          0
{{
 Algorithm 13
4*
|
3
|
2
|
1
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_1,      Bus_Nowhere,Bus_0,          0
BYTE    Bus_2,      Bus_Nowhere,Bus_1,          0
BYTE    Bus_2,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_4,      Bus_Out,    Bus_Nowhere,    0
BYTE    Bus_5,      Bus_Nowhere,Bus_4,          0
BYTE    Bus_6,      Bus_Nowhere,Bus_5,          0
BYTE    Bus_6,      Bus_Nowhere,Bus_6,          0
{{
 Algorithm 14
4=|
| |
3 |
| |
2 |
| |
1=|
}}
'       input       add         mov             mbz
BYTE    Bus_0,      Bus_Out,    Bus_3,          0
BYTE    Bus_1,      Bus_Nowhere,Bus_0,          0
BYTE    Bus_2,      Bus_Nowhere,Bus_1,          0
BYTE    Bus_3,      Bus_Nowhere,Bus_2,          0

BYTE    Bus_4,      Bus_Out,    Bus_7,          0
BYTE    Bus_5,      Bus_Nowhere,Bus_4,          0
BYTE    Bus_6,      Bus_Nowhere,Bus_5,          0
BYTE    Bus_7,      Bus_Nowhere,Bus_6,          0

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
