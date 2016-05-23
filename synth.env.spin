{{
Envelope

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

VAR
    LONG    OscPtr_         ' long pointer to oscillator parameters
    LONG    EnvPtr_         ' word pointer to envelope: (rate,level) *4, entering 4th when key released +1 bool (looping)

    LONG    Duration_       ' duration, in units of system clock >> 16
    LONG    Delta_          ' distance we need to travel
    LONG    Base_           ' where we came from
    LONG    Env_            ' current level
    LONG    Clk_            ' system clock at start of transition
    LONG    LastT_          ' system clock as last checked, upper 16 bits masked in
    WORD    Scale_          ' scale of entire envelope
    BYTE    State_          ' envelope state (0-4, 0=L1..3=L4, 4=L4 finished)
    BYTE    Wheel_          ' modulation wheel state

PUB Init(OscPtr, EnvPtr)
{
Initialize envelope
OscPtr: long pointer to oscillator parameters
EnvPtr: word pointer to envelope
}
    OscPtr_ := OscPtr
    EnvPtr_ := EnvPtr
    Duration_ := 1
    LastT_ := -1
    
PRI EnvRate(S)
{
Configured Rate, 0-$1ff
}
    return WORD[EnvPtr_][(S << 1)]

PRI EnvLevel(S)
{
Configured Level, 0-$1ff
}
    return WORD[EnvPtr_][(S << 1) | 1]
    
PRI Looping
{
Loop L3->L2, Boolean
}
    return WORD[EnvPtr_][8] <> 0

PRI SetLevel(L) | e, f
{
Set effective oscillator output level with log2 scaling
L: 31 bit value 0-$7fff_ffff, although only bits 31-16 are actually significant

The oscillator uses 32 bit unsigned values to facilitate gradual per-sample movements
}

    ' limit to 31 bit unsigned
    if L < 0
        L := $7fff_ffff
    ' make note of where we are at
    Env_ := L
    ' add modulation wheel, which is a 7-bit value, scaled to upper bits
    L += Wheel_ << 24
    ' again limit to 31 bit unsigned
    if L < 0
        L := $7fff_ffff

    ' only look at 15 MSBs
    L >>= 16
    e := >|L

    ' 11 next most significant bits for lookup
    if (e > 12)
        L >>= e - 12
    else
        L <<= (12 - e)
    ' and scale this whole mess back to bits 31-11 (of which only are 31-16 ultimately used)
    LONG[OscPtr_][1] := ((WORD[$c000][L & $7ff]) | (e << 16)) << 11

PRI Transition(S) | rate
{
Transiation state S:
0- L1
1- L2
2- L3
3- L4
4- L4+1 (done)
}
    Clk_ := CNT     ' system clock at start of transition
    State_ := S     ' new state
    Base_ := Env_   ' level coming from

    if S < 4 ' do nothing for state 4
        Delta_ := ((EnvLevel(S) * Scale_) << 13) - Base_
        rate := $200 - EnvRate(S)
        Duration_ := ((rate * rate) >> 3) #> 1
    
        Advance     ' start first idle advance to update with new state

PUB State
{
Current state 0-4
}
    return State_

PUB SetWheel(W)
{
Set modulation wheel value, 0-$7f
}
    Wheel_ := W
    SetLevel(Env_)

PUB Down(Scale)
{
Enter key down state with scale 0-$200 (usually 0-$1ff) by transitioning to state 0
}
    Scale_ := Scale
    Transition(0)
    
PUB Up
{
Enter key-up state by transitioning to state 3
}
    Transition(3)
    
PUB Advance | t, d, l
{
Idle advance our way through the envelope
completion of state 0 -> 1, 1 -> 2
state 2 stays there until key up, or if looping is set, transitions back to state 2
completion of state 3 -> 4
state 4 is terminal
within this scope, state 2 is also terminal if not looping. Regarless, state 3 needs an explicit transition
}
    if (State < 4) ' do nothing for state 4
        t := CNT - Clk_                                     ' measure elapsed time
        
        if (t & $ffff_0000) <> LastT_                       ' within the resolution we care about, update if different
            LastT_ := t & $ffff_0000                        ' make note of current time
    
            t <#= (Duration_ << 16)                         ' limit elapsed time to duration
            d := t / Duration_                              ' compute t*(rise/run) we should be at for this t
            l := Base_ + (Delta_ ~> 16) * d                 ' base+t*(rise/run)

            if l < 0                                        ' limit to 0 or full depending if going up or down
                if Delta_ < 0
                    l := 0
                else
                    l := $7fff_ffff
                    
            SetLevel(l)                                     ' set the new level
    
            if (t => (Duration_ << 16))                     ' if we have elapsed duration, possible state change
                if (State_ < 2)                             ' 0 -> 1, 1-> 2
                    Transition(State_ + 1)
                elseif (State_ == 2 AND Looping)            ' 2 -> 1 only if looping
                    Transition(1)
                elseif (State_ == 3)
                    Transition(4)                           ' 3 -> 4

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
