{{
Envelope

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Env_Max     = $2_0000
    Env_Mid     = $0_8304   ' level shown in Pct as 50 (actual patch value $103)

VAR
    LONG    ParamPtr_       ' word pointer to params: (rate,level) *4, entering 4th when key released +1 bool (looping)
    LONG    EnvPtr_         ' long pointer to envelope control values
    LONG    CounterPtr_     ' long pointer to envelope ticks

    LONG    Duration_       ' number of envelope ticks to spend in this state
    LONG    Count_          ' reference counter value at start of state
    LONG    Mod_            ' modulation/LFO wheel state
    WORD    Scale_          ' scale of entire envelope
    BYTE    State_          ' envelope state (0-5, 0=Init, 1=L1..4=L4, 5=L4 finished)

PUB Init(ValuePtr, EnvPtr, ParamPtr, CounterPtr)
{
Initialize envelope
ValuePtr: (optional) long pointer to oscillator's envelope input
EnvPtr: long pointer to envelope
ParamPtr: word pointer to envelope parameters
CounterPtr: long pointer to envelope ticks
}
    EnvPtr_ := EnvPtr
    ParamPtr_ := ParamPtr
    CounterPtr_ := CounterPtr
    SetEnvPtr(ValuePtr)                     ' oscillator's envelope input
    Silence

PRI ParamRate(S)
{
Configured Rate, 0-$200
}
    S := (S - 1) #> 0
    return WORD[ParamPtr_][(S << 1)]

PRI ParamLevel(S)
{
Configured Level, 0-$200
}
    S := (S - 1) #> 0
    return WORD[ParamPtr_][(S << 1) | 1]
    
PRI Looping
{
Loop L3->L2, Boolean
}
    return WORD[ParamPtr_][8] <> 0

PRI EnvLevel
{
Current envelope (linear) level
}
    return LONG[EnvPtr_][0]

PRI SetEnvGoal(G)
{
Set envelope goal value
}
    LONG[EnvPtr_][1] := G

PRI SetEnvRate(R)
{
Set envelope rate value
}
    LONG[EnvPtr_][2] := R

PRI SetEnvMod(M)
{
Set envelope modulation value
}
    LONG[EnvPtr_][3] := M

PRI SetEnvPtr(P)
{
Set envelope oscillator output pointer
}
    LONG[EnvPtr_][4] := P

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
    Count_ := LONG[CounterPtr_]
    State_ := S

    if S == 5
        return

    level := ParamLevel(S)
    level := (level * level * Scale_) >> 10

    Duration_ := $200 - ParamRate(S)
    Duration_ := (Duration_ * Duration_) >> 1

    rate := (||(level - EnvLevel) / (Duration_ #> 1)) #> 1

    SetEnvRate(rate)
    SetEnvGoal(level)

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
    SetEnvGoal(0)
    SetEnvRate(Env_Max)

PUB Modulate(M)
{
Set modulation value +/- $10000
}
    Mod_ := M

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
    
PUB Advance | count, mod
{
Idle advance our way through the envelope
}
    count := LONG[CounterPtr_] - Count_                     ' how long have we been in this state?

    if (State_ == 0) OR (count => Duration_)                ' advance if state 0 (immediately) or after requisite time spent
        case State_
            0:                                              ' key down transitions to state 1
                Transition(1)

            1:
                Transition(2)

            2:
                Transition(3)

            3:
                if Looping
                    Transition(2)                           ' either loop between 3->2 or stay at 3

            4:
                Transition(5)

            5:
                ' do nothing

    result := EnvLevel
    mod := (Mod_ * (result >> 4)) ~> 12
    SetEnvMod(mod)

    result += mod
    result := result #> 0 <# Env_Max

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
