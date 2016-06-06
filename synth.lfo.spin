{{
LFO module

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}
CON
    Wave_Sine           = 0
    Wave_Square         = 1
    Wave_Triangle       = 2
    Wave_SawUp          = 3
    Wave_SawDown        = 4

VAR
    LONG Clk_                   ' clock sync
    WORD F_                     ' frequency divider
    BYTE Wave_                  ' one of the Wave_ constants

PUB Set(W, F)
{
Set wave to W and frequency to F (0-$200)
}
    Clk_ := CNT
    F := ($200 - F) #> 1
    F_ := (F * F) + $200
    Wave_ := W

PUB Value | p
{
Get current oscillator value, range -$10000 to $10000
}
    p := ((CNT - Clk_) / F_) & $1fff
    
    case Wave_
        Wave_Sine:
            return Sine(p)

        Wave_Square:
            return Square(p)

        Wave_Triangle:
            return Triangle(p)

        Wave_SawUp:
            return SawUp(p)

        Wave_SawDown:
            return SawDown(p)

    return 0

PRI Sine(P) | s
    s := P & $1000
    P &= $fff
    if P > $800
        P := $1000 - P
    result := WORD[$e000][P]
    if s
        result := -result

PRI Square(P)
    if P & $1000
        return -$10000
    return $10000

PRI Triangle(P) | s
    s := P & $1000
    P &= $fff
    if P > $800
        P := $1000 - P
    result := P * $10
    if s
        result := -result

PRI SawUp(P)
    return (P - $1000) * $10

PRI SawDown(P)
    return ($1000 - P) * $10

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
