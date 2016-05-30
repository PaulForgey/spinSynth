{{
Floating point of sorts (Spinning point?)

Copyright (c)2016 Paul Forgey
See end of file for terms of use

_Very_ quick and sloppy floating point (kind of) support that doesn't require a whole cog
nor a lot of program space. It is close enough for our inexact filter creation.
}}

CON
    Negative    = $8000_0000
    Zero        = $4000_0000
    Flags_Mask  = $c000_0000

PUB FromFixed(F) | e, flags
{
From 16.16 fixed
}
    if NOT F                                ' zero?
        result := Zero
        return

    if F < 0                                ' negative?
        ||F
        flags := Negative
    else
        flags := 0

    e := >|F                                ' log absolute value
    if e < 12                               ' centered around $1_0000 = 1.0 (0 exponent here)
        F <<= (12 - e)
    else
        F >>= (e - 12)
    e -= 17
    F &= $7ff
    result := WORD[$c000][F]
    result |= (e << 16) & !Flags_Mask
    result |= flags

PUB ToFixed(E) | flags, f
{
Return back as 16.16 fixed
}
    flags := E & Flags_Mask
    if (flags & Zero)                       ' zero is zero
        return 0
    E &= !Flags_Mask
    E >>= 5                                 ' 2 ^Exp_
    f := E & $7ff
    E >>= 11
    f := WORD[$d000][f] | $1_0000
    if E & $2000                            ' negative vs positive exponent
        E := (E ^ $3fff) + 1                ' two's complement negative exponent
        f >>= E                             ' < 1.0
    else
        f <<= E                             ' => 1.0

    if (flags & Negative)                   ' negate?
        f := -f

    return f

PUB Mult(E, O) | flags, e1, e2
{
Multiply by other
}
    if (E & Zero) OR (O & Zero)             ' 0*n = 0
        result := Zero
    else
        flags := E & Flags_Mask
        e1 := E & !Flags_Mask
        if e1 & $2000_0000
            e1 |= $c000_0000                ' sign extend
        e2 := O & !Flags_Mask
        if e2 & $2000_0000
            e2 |= $c000_0000
        result := (e1 + e2) & !Flags_Mask   ' multiply
        result |= flags ^ (O & Negative)    ' negate appropriately

PUB Div(E, O) | flags, e1, e2
{
Divide by other instance
}
    if (E & Zero) OR (O & Zero)             ' 0/n = 0, leave it alone. O = 0 should be an error
        return E
    else
        flags := E & Flags_Mask
        e1 := E & !Flags_Mask
        if e1 & $2000_0000
            e1 |= $c000_0000                ' sign extend
        e2 := O & !Flags_Mask
        if e2 & $2000_0000
            e2 |= $c000_0000
        result := (e1 - e2) & !Flags_Mask   ' divide
        result |= flags ^ (O & Negative)    ' negate appropriately

PUB Plus(E, N)
{
Add 16.16f value
}
    return FromFixed(ToFixed(E) + N)

PUB Minus(E, N)
{
Subtract 16.16f value
}
    return FromFixed(ToFixed(E) - N)

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
