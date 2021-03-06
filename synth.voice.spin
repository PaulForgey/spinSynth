{{
Voice (drive allocated oscillator and envelope set according to patch configuration)

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Patch_Feedback          = 0             ' global
    Patch_Algorithm         = 1

    Patch_LFO_Wave          = 2
    Patch_LFO_Frequency     = 3
    Patch_LFO_Pitch         = 4
    Patch_LFO_R1            = 5
    Patch_LFO_L1            = 6
    Patch_LFO_R2            = 7
    Patch_LFO_L2            = 8
    Patch_LFO_R3            = 9
    Patch_LFO_L3            = 10
    Patch_LFO_R4            = 11
    Patch_LFO_L4            = 12
    Patch_LFO_Loop          = 13

    Patch_Pitch_R1          = 14
    Patch_Pitch_L1          = 15
    Patch_Pitch_R2          = 16
    Patch_Pitch_L2          = 17
    Patch_Pitch_R3          = 18
    Patch_Pitch_L3          = 19
    Patch_Pitch_R4          = 20
    Patch_Pitch_L4          = 21
    Patch_Pitch_Loop        = 22

    Patch_Op                = 23            ' offset to first operator

    Patch_Osc               = 0             ' offset inside operator to oscillator
    Patch_OscWords          = 7

    Patch_Level             = 0
    Patch_Velocity          = 1
    Patch_Wheel             = 2
    Patch_Mod_LFO           = 3
    Patch_Frequency         = 4
    Patch_Multiplier        = 5
    Patch_Detune            = 6

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

    Freq_C10                = $61322        ' frequency of C10 (midi $78)

OBJ
    env[Patch_Ops]  : "synth.env"
    pitch           : "synth.env"
    lfo             : "synth.lfo"

VAR
    LONG    VoicePtr_                       ' long pointer to allocated oscillators
    LONG    PatchPtr_                       ' word pointer to patch data
    LONG    PedalPtr_                       ' byte pointer to pedal state
    LONG    BendPtr_                        ' long pointer to pitch bend state
    LONG    WheelPtr_                       ' byte pointer to modulation wheel state
    
    LONG    Pitch_                          ' pitch envelope value
    LONG    Rate_                           ' portamento slide rate (0 for none)
    LONG    Clk_                            ' portamento clock sync
    WORD    Frequency_[Patch_Ops]           ' frequency (in units) of oscillator
    WORD    Slide_[Patch_Ops]               ' portamento slide to frequency
    BYTE    Key_                            ' note being played
    BYTE    KeyDown_                        ' key down state
    BYTE    Playing_                        ' playing state (depending on pedal, is not simply KeyDown_)
    
PUB Init(VoicePtr, EnvPtr, PatchPtr, PedalPtr, BendPtr, WheelPtr) | i
{
Initialize voice instance

VoicePtr:   long pointer to allocated oscillators
EnvPtr:     long pointer to allocated envelopes
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

    Key_ := $80

    ' each oscillator has an attached envelope
    repeat i from 0 to Patch_Ops - 1
        env[i].Init(@LONG[VoicePtr_][i * 4 + 1], @LONG[EnvPtr][i*5], @WORD[PatchPtr][Patch_Op + Patch_Env + Patch_OpWords * i])
    lfo.Init(@LONG[EnvPtr][4*5], @WORD[PatchPtr][Patch_LFO_R1])
    pitch.Init(0, @LONG[EnvPtr][5*5], @WORD[PatchPtr][Patch_Pitch_R1])

PUB Advance | op, l, c
{
Idle state update.

Read new state of midi controls
Advance envelopes in time
}
    UpdatePedal

    l := lfo.Value

    pitch.Modulate((LFO_Pitch * l) ~> 8)
    Pitch_ := pitch.Advance

    repeat op from 0 to Patch_Ops-1
        SetFrequency(op, BentFrequency(op))

        c := WheelSense(Op) * Wheel + ((LFOModSense(Op) * l) ~> 8)
        env[op].Modulate(c)
        env[op].Advance

PRI UpdatePedal | op
{
If sustain pedal is down, do not enter key-up envelope state
If sustain pedal is up, key-up envelope states as needed
}
    if (Playing_ AND NOT (KeyDown_ OR Pedal))
        Playing_ := FALSE
        lfo.Up
        pitch.Up
        repeat op from 0 to Patch_Ops - 1
            env[op].Up

PUB Down(K, V, P) | op
{
Key down
K: midi note $00:$7f
V: velocity $00:$7f
P: portamento 0 (none) : $200 (slowest)

Enter envelope key-down states with velocity scale
}
    Key_ := K
    KeyDown_ := TRUE
    
    ' LFO
    lfo.Set(LFO_Wave, LFO_Frequency)

    ' pitch envelope
    Pitch_ := pitch.Down($200)
    Pitch_ := env#Env_Mid

    ' if portamento is in effect, set the target slide value
    if P
        P <<= 2
        Rate_ := (P * P) + $200 ' same scheme LFO uses
        Clk_ := CNT
    else
        Rate_ := 0

    ' key down each envelope
    repeat op from 0 to Patch_Ops - 1
        OpDown(op, K, V, P)

    Playing_ := TRUE

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
    lfo.Silence

PRI OpDown(Op, K, V, P) | n, s
{
Key down state per operator

Op: operator (0-3)
K:  MIDI note $00-$7f
V:  Velocity $01-$7f
}
    s := Frequency(Op)              ' frequency configuration

    if (s & $80)
        n := IndexForNote(K)        ' note as played
    else
        n := IndexForNote(s)        ' fixed frequency

    n += Detune(Op)                 ' detune as configured

    if P
        Slide_[Op] := n             ' target portamento frequency

    if (NOT P) OR (NOT Frequency_[Op]) OR (NOT Playing_)
        Frequency_[Op] := n         ' currently playing frequency

    if (s & $80)
        Frequency_[Op] |= $8000     ' pitch bend applies

    SetFrequency(Op, BentFrequency(Op)) ' set the actual frequency

    ' velocity scale the envelope (todo: this better)
    V := $7F - V
    n := Level(Op)
    s := $200 - ((V * Velocity(Op)) >> 7)
    n := (n * s) >> 9

    env[Op].Down(n)                 ' enter key-down state


PRI BentFrequency(Op) | p, b, n, s
{
Return an actual frequency per configured multiplier and pitch bend/portamento state
}
    n := Frequency_[Op]
    b := n & $8000
    n &= $7fff

    if b
        if Rate_
            s := Slide_[Op]
            p := ((CNT - Clk_) / Rate_) & $3fff

            if s < n
                n := (n - p) #> s
            elseif s > n
                n := (n + p) <# s
            Frequency_[Op] := n | b

        n += PitchBend ~> 1

    n += (Pitch_ - env#Env_Mid) ~> 4

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
    if F > $fffff
        F := 0
    LONG[VoicePtr_][Op * 4] := F

' patch accessors
PRI LFO_Wave
{
LFO Wave
}
    return WORD[PatchPtr_][Patch_LFO_Wave]

PRI LFO_Frequency
{
LFO Rate
}
    return WORD[PatchPtr_][Patch_LFO_Frequency]

PRI LFO_Pitch
{
LFO pitch sensitivity, 0-$200
}
    return WORD[PatchPtr_][Patch_LFO_Pitch]

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

PRI LFOModSense(Op)
{
LFO sensitivity, 0-$200
}
    return WORD[PatchPtr_][Patch_Op + Patch_OpWords * Op + Patch_Mod_LFO]

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
    return v << 1

PRI FrequencyForIndex(Op, N) : f | octave, index
{
Given a note in units of $800 per octave, return frequency with multiplier
N: note 0:$57ff
}
    N := N #> 0 <# $57ff
    octave := N >> 11
    index := N & $7ff
    ' within the octave, find 2^(n/$800)
    f := (WORD[$d000][index] | $1_0000) >> 4
    ' multiply by C (base note per octave)
    f *= Freq_C10
    ' shave down to desired octave
    f := f >> (12 + (10 - octave))
    ' now apply multiplier
    f := (f * Multiplier(Op)) >> 8

PRI IndexForNote(N) | octave, index
{
Given a MIDI note value, return the frequency units
}
    octave := N / 12
    index := N // 12

    return $800 * octave + Notes[index]

DAT
' frequency units along the octave (of $800) where the 11 notes live
Notes   WORD    0, 171, 341, 512, 683, 853, 1024, 1195, 1365, 1536, 1707, 1877

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
