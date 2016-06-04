{{
Minimal IEEE752-ish floating point routines for our purposes of coming up
with fixed point filter coefficients.

Subnormal numbers (exponent < -127) are rounded to 0

Copyright (c)2016 Paul Forgey
See end of file for terms of use

}}

CON
    Negative    = $8000_0000


PRI Unpack(Ptr, F) | s, e, m
{
Unpack F into LONG[Ptr][0..2] for sign, exponent, mantissa
}
    s := F & Negative
    e := ((F >> 23) & $ff)

    if NOT e
        m := 0                                      ' round subnormal to 0
    else
        e -= $7f
        m := ((F & $7f_ffff) << 6) | $2000_0000     ' left justify, add implied msb, leave room for overflow and negation

    LongMove(Ptr, @s, 3)

PRI Pack(Ptr) | ee, s, e, m
{
Return packed 32 bit float from pieces in LONG[Ptr][0..2]
}
    LongMove(@s, Ptr, 3)

    if not M
        return 0                                    ' zero is zero

    ee := 33 - >|m                                  ' find highest bit of mantissa
    m <<= ee                                        ' left justify
    e += 3 - ee                                     ' adjust exponent if we've moved any

    m += $0000_0100                                 ' round up

    if NOT (m & $ffff_ff00)
        e++                                         ' round overflow

    e := (e + $7f) #> 0 <# $ff                      ' limit exponent (Nan/inf difference are ignored)

    if NOT e
        return 0                                    ' round subnormal to 0

    return s | (e << 23) | (m >> 9)                 ' put it all together

PUB F_Mul(X, Y) | s1, e1, m1, s2, e2, m2
{
Multiply X * Y
}
    Unpack(@s1, X)
    Unpack(@s2, Y)

    s1 ^= s2                                        ' opposite signs, negative result
    e1 += e2                                        ' add exponents
    m1 := (m1 ** m2) << 3                           ' multiply mantissas

    return Pack(@s1)

PUB F_Div(X, Y) | d, s1, e1, m1, s2, e2, m2
{
Divide X / Y
}
    Unpack(@s1, X)
    Unpack(@s2, Y)

    s1 ^= s2                                        ' opposite signs, negative result
    e1 -= e2                                        ' subtract exponents

    d := 0                                          ' long divide 30 bits of mantissas
    repeat 30
        d <<= 1                                     ' next result column
        if m1 => m2
            m1 -= m2
            d++                                     ' went into numerator, so we pull down 1*
        m1 <<= 1                                    ' next numerator column
    m1 := d

    return Pack(@s1)

PUB F_Add(X, Y) | e, s1, e1, m1, s2, e2, m2
{
Add X + Y
}
    Unpack(@s1, X)
    Unpack(@s2, Y)

    if s1
        -m1                                         ' deal with signed values
    if s2
        -m2

    e := ||(e1 - e2) <# 31                          ' difference in exponents, scale to smaller

    if e1 > e2
        m2 ~>= e                                    ' scale down Y in terms of X
    else
        m1 ~>= e                                    ' scale down X in terms of Y
        e1 := e2                                    ' use Y's scale

    m1 += m2                                        ' add mantissas now in same scale

    if m1 < 0
        s1 := Negative
        ||m1                                        ' negate result if negative
    else
        s1 := 0

    return Pack(@s1)

PUB F_Sub(X, Y)
{
Subtract X - Y
}
    Y ^= Negative
    return F_Add(X, Y)                              ' add X + -Y

PUB ToFixed(F, D) | s, e, m
{
Convert to fixed point with D fractional bits
(D == 0 returns a plain integer)
}
    Unpack(@s, F)

    if NOT m
        return 0                                    ' zero is zero

    e += D                                          ' adjust center reference as requested

    if e < 0
        return 0                                    ' below minimal value

    m <<= 2                                         ' left justify
    result := m >> (31 - e)                         ' now slide as many bits to the right as we need

    if s
        result := -result                           ' negate

PUB FromFixed(N, D) | s, e, m
{
Convert from fixed point with D fractional bits
(D == 0 converts an integer)
}
    if N < 0
        s := Negative
        m := ||N                                    ' negative number
    else
        s := 0                                      ' positive number
        m := N

    if NOT m
        return 0                                    ' zero is zero

    e := (>|m) - 1                                  ' justify mantissa to $2000_0000 as high bit format
    m <<= 31 - e
    m >>= 2

    e -= D                                          ' -D of these bits are fractional

    return Pack(@s)

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
