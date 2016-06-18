{{
Envelope

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Env_Max     = $3_ffff
    Env_Mid     = $1_0600   ' level shown in Pct as 50 (actual patch value $103)

VAR
    LONG    ValuePtr_       ' long pointer to envelope value
    LONG    EnvPtr_         ' word pointer to envelope: (rate,level) *4, entering 4th when key released +1 bool (looping)

    LONG    Duration_       ' duration, in units of system clock >> 16
    LONG    Delta_          ' distance we need to travel
    LONG    Base_           ' where we came from
    LONG    Env_            ' current level
    LONG    Clk_            ' system clock at start of transition
    LONG    LastT_          ' system clock as last checked, upper 16 bits masked in
    LONG    Mod_            ' modulation/LFO wheel state
    WORD    Scale_          ' scale of entire envelope
    BYTE    State_          ' envelope state (0-5, 0=Init, 1=L1..4=L4, 5=L4 finished)

PUB Init(ValuePtr, EnvPtr)
{
Initialize envelope
ValuePtr: (optional) long pointer to envelope value
EnvPtr: word pointer to envelope
}
    ValuePtr_ := ValuePtr
    EnvPtr_ := EnvPtr
    Duration_ := 1
    
PRI EnvRate(S)
{
Configured Rate, 0-$200
}
    S := (S - 1) #> 0
    return WORD[EnvPtr_][(S << 1)]

PRI EnvLevel(S)
{
Configured Level, 0-$200
}
    S := (S - 1) #> 0
    return WORD[EnvPtr_][(S << 1) | 1]
    
PRI Looping
{
Loop L3->L2, Boolean
}
    return WORD[EnvPtr_][8] <> 0

PRI SetLevel(L) | e, f, m
{
Set effective oscillator output level with log2 scaling
L: 0,Env_Max
M: Modulation +/- $10000
}
    L := L #> 0 <# Env_Max

    ' make note of where we are at
    Env_ := L

    ' outside of persistent envelope state, add in modulation
    m := Mod_ #> -$10000 <# $10000
    m := (m * (L >> 3)) ~> 13   ' scale modulation factor by the envelope state
    L += m                      ' then add to or subtract from it

    L := L #> 0 <# Env_Max

    if NOT ValuePtr_
        return L

    ' only look at 15 MSBs
    L >>= 3
    e := >|L

    ' 11 next most significant bits for lookup
    if (e > 12)
        L >>= e - 12
    else
        L <<= (12 - e)
    L := (e << 16) | WORD[$c000][L & $7ff]

    ' at this point, we are in range 0-$f_ffff. Scale it to 0-$8800 and invert.
    ' Shift to the goofy bit arrangement needed by the oscillator (starting from 31 down).
    ' Add an extra $800 to the final result.
    L := (((L ^ $f_ffff) * $88) + $100) << 3

    LONG[ValuePtr_] := L
    return L

PRI Transition(S) | rate, level
{
Transiation state S:
0- Key down
1- L1
2- L2
3- L3
4- L4
5- L4+1 (done)
}
    Clk_ := CNT     ' system clock at start of transition
    State_ := S     ' new state
    Base_ := Env_   ' level coming from

    if S < 5
        level := EnvLevel(S)
        level := (level * level * Scale_) >> 9
        Delta_ := level - Base_
        rate := $200 - EnvRate(S)
        Duration_ := ((rate * rate) >> 3) #> 1
    else
        SetLevel(Env_)

PUB State
{
Current state 0-5
}
    return State_

PUB Silence
{
Set output level to 0 and state to 5
}
    State_ := 5
    SetLevel(0)

PUB Modulate(M)
{
Set modulation value +/- $10000
}
    Mod_ := M

    result := SetLevel(Env_)

PUB Down(Scale)
{
Enter key down state with scale 0-$200 by transitioning to state 0
}
    Scale_ := Scale
    Transition(0)
    return Advance
    
PUB Up
{
Enter key-up state by transitioning to state L4
}
    Transition(4)
    Advance
    
PUB Advance | t, d, l
{
Idle advance our way through the envelope
  completion of state 0 -> 1, 1 -> 2
state 2 stays there until key up, or if looping is set, transitions back to state 2
completion of state 3 -> 4
state 4 is terminal
within this scope, state 2 is also terminal if not looping. Regarless, state 3 needs an explicit transition
}
    if (State_ < 5) ' do nothing for state 5
        t := (CNT - Clk_) & $ffff_0000                      ' measure elapsed time
        
        if (State_ == 0) OR (t <> LastT_)                   ' within the resolution we care about, update if different
            if (State_ == 0)
                State_ := 1
            LastT_ := t                                     ' make note of current time
    
            t <#= (Duration_ << 16)                         ' limit elapsed time to duration
            d := t / Duration_                              ' compute t*(rise/run) we should be at for this t
            l := ((Delta_ ~> 4) * d) ~> 12                  ' base+t*(rise/run)
            l := Base_ + l

            SetLevel(l)                                     ' set the new level
    
            if (t => (Duration_ << 16))                     ' if we have elapsed duration, possible state change
                if (State_ < 3)                             ' L1 -> L2, L2 -> L3
                    Transition(State_ + 1)
                elseif (State_ == 3 AND Looping)            ' L3 -> L2 only if looping
                    Transition(2)
                elseif (State_ == 4)
                    Transition(5)                           ' L4 -> Done

    return Env_

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
