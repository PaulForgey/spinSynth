{{
Voice (drive allocated oscillator and envelope set according to patch configuration)

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Patch_Feedback          = 0             ' global
    Patch_Algorithm         = 1
    Patch_BendRange         = 2
    Patch_Cutoff            = 3
    Patch_Resonance         = 4

    Patch_Op                = 5             ' offset to first operator

    Patch_Osc               = 0             ' offset inside operator to oscillator
    Patch_OscWords          = 7

    Patch_Level             = 0
    Patch_Velocity          = 1
    Patch_Wheel             = 2
    Patch_Frequency         = 3
    Patch_Multiplier        = 4
    Patch_Detune            = 5
    Patch_Wave              = 6

    Patch_Env               = 7             ' offset inside operator to envelope
    Patch_EnvWords          = 9

    Patch_R1                = 0
    Patch_L1                = 1
    Patch_R2                = 2
    Patch_L2                = 3
    Patch_R3                = 4
    Patch_L3                = 5
    Patch_R4                = 6
    Patch_L4                = 7
    Patch_Loop              = 8

    Patch_OpWords           = Patch_OscWords + Patch_EnvWords

    Patch_Ops               = 4
    Patch_Words             = Patch_Op + (Patch_OpWords * Patch_Ops)

    Freq_C10                = $6132         ' frequency of C10 (midi $78)

OBJ
    env[4]  : "synth.env"

VAR
    LONG    VoicePtr_                       ' long pointer to allocated oscillator parameters
    LONG    PatchPtr_                       ' word pointer to patch data
    LONG    PedalPtr_                       ' byte pointer to pedal state
    LONG    BendPtr_                        ' long pointer to pitch bend state
    LONG    WheelPtr_                       ' byte pointer to modulation wheel state
    
    LONG    Frequency_[Patch_Ops]           ' variable frequecy (in cents) of oscillator if pitch bend applies to it
    LONG    Bend_                           ' last pitch bend state
    BYTE    Wheel_                          ' last modulation wheel state
    BYTE    Key_                            ' note being played
    BYTE    KeyDown_                        ' key down state
    BYTE    Playing_                        ' playing state (depending on pedal, is not simply KeyDown_)
    
PUB Init(VoicePtr, PatchPtr, PedalPtr, BendPtr, WheelPtr) | i
{
Initialize voice instance

VoicePtr:   long pointer to allocated oscillator parameters
PatchPtr:   word pointer to patch data
PedalPtr:   byte pointer to pedal state
BendPtr:    long pointer to pitch bend state
WheelPtr:   byte pointer to modulation wheel state
}
    VoicePtr_ := VoicePtr
    PatchPtr_ := PatchPtr
    PedalPtr_ := PedalPtr
    BendPtr_ := BendPtr
    WheelPtr_ := WheelPtr

    ' each oscillator has an attached envelope
    repeat i from 0 to Patch_Ops - 1
        env[i].Init(@LONG[VoicePtr_][i * 4], @WORD[PatchPtr][Patch_Op + Patch_Env + Patch_OpWords * i])

PUB Advance | c, op, updateBend, updateWheel
{
Idle state update.

Read new state of midi controls
Advance envelopes in time
}
    UpdatePedal
    
    c := PitchBend
    if (c <> Bend_)
        Bend_ := c
        updateBend := TRUE
    else
        updateBend := FALSE
        
    c := Wheel
    if (c <> Wheel_)
        Wheel_ := c
        updateWheel := TRUE
    else
        updateWheel := FALSE
                
    repeat op from 0 to Patch_Ops-1
        if (updateBend AND c := Frequency_[op])
            SetFrequency(op, BentFrequencyForIndex(op, c))
        if (updateWheel)
            env[op].SetWheel((WheelSense(op) * Wheel_) >> 9)
        env[op].Advance

PRI UpdatePedal | op
{
If sustain pedal is down, do not enter key-up envelope state
If sustain pedal is up, key-up envelope states as needed
}
    if (Playing_ AND NOT (KeyDown_ OR Pedal))
        Playing_ := FALSE
        repeat op from 0 to Patch_Ops - 1
            env[op].Up

PUB Down(K, V) | op
{
Key down

Enter envelope key-down states with velocity scale
}
    Key_ := K
    KeyDown_ := TRUE
    Playing_ := TRUE
    
    ' set last known pitch bend state
    Bend_ := PitchBend
    
    ' key down each envelope
    repeat op from 0 to Patch_Ops - 1
        OpDown(op, K, V)

PUB Key
{
Last/current key being played
}
    return Key_

PUB Up
{
Key up

Unless the sustain pedal is down, enter key-up states for each envelope
}
    KeyDown_ := FALSE
    UpdatePedal

PUB Playing
{
In both key-up state and the sustain pedal is up
}
    return Playing_ <> 0

PUB Silence | op
{
Set oscillator levels to 0
}
    repeat op from 0 to Patch_Ops-1
        env[op].Silence

PRI OpDown(Op, K, V) | n, s
{
Key down state per operator

Op: operator (0-3)
K:  MIDI note $00-$7f
V:  Velocity $01-$7f
}
    s := Frequency(Op)              ' frequency configuration

    if (s & $80)
        n := K * 100                ' note as played
    else
        n := s * 100                ' fixed frequency

    n += Detune(Op)                 ' detune as configured

    if (s => $180)
        Frequency_[Op] := 0         ' note a bendable frequency
        SetFrequency(Op, FrequencyForIndex(Op, n)) ' set the actual frequency
    else
        Frequency_[Op] := n         ' bendable frequency
        SetFrequency(Op, BentFrequencyForIndex(Op, n)) ' set the acutal frequency

    ' velocity scale the envelope (todo: this better)
    V := $7F - V
    n := Level(Op)
    s := $200 - ((V * Velocity(Op)) >> 7)
    n := (n * s) >> 9

    env[Op].Down(n)                 ' enter key-down state


PRI BentFrequencyForIndex(Op, n)
{
For a note value in cents, return an actual frequency per configured multiplier and pitch bend state
}
    n += (Bend_ * 1200) ~> 12
    return FrequencyForIndex(Op, n)

' global state accessors
PRI PitchBend
{
Current pitch bend state
}
    return LONG[BendPtr_]

PRI Pedal
{
Current pedal state
}
    return BYTE[PedalPtr_]

PRI Wheel
{
Current modulation wheel state
}
    return BYTE[WheelPtr_]

' oscillator accessors
PRI SetFrequency(Op, F)
{
Set oscillator Op to frequency F (which is actually a 16 bit value)
}
    ' if we're going at or above Nyquist, be silent instead
    if F > $ffff
        F := 0
    LONG[VoicePtr_][Op * 4] := F

' patch accessors
PRI Level(Op)
{
Configured level, 0-$200
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Level]

PRI Velocity(Op)
{
Configured velocity sensitivity, 0-$200
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Velocity]

PRI WheelSense(Op)
{
Modulation wheel sensitivity, 0-$200
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Wheel]

PRI Multiplier(Op)
{
Fixed point 5.8 multiplier, 0-$1fff, unity at $100
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Multiplier]
    
PRI Frequency(Op)
{
Fixed frequency value (as midi note value) or base note if $80
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Frequency]

PRI Detune(Op) | v
{
Detune setting, -256 - +255
}
    v := WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Detune]
    
    if (v & $100)
        v := -($200 - v)
    return v

PRI FrequencyForIndex(Op, N) : f | octave, index
{
Given a note in cents, return frequency with multiplier
N: note 0-13199
}
    N #>= 0
    N <#= 13199
    octave := N / 1200
    index := ((N // 1200) * $800) / 1200
    ' within the octave, find 2^(n/1200)
    f := WORD[$d000][index] | $1_0000
    ' multiply by C (base note per octave)
    f *= Freq_C10
    ' shave down to desired octave
    f := f >> (16 + (10 - octave))
    ' now apply multiplier
    f := (f * Multiplier(Op)) >> 8
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
