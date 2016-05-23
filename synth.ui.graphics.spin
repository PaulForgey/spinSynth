{{
User interface graphics plotting

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

VAR
    LONG    Buffer_[256]                ' graphics buffer

    BYTE    Algo_                       ' which algorithm are we showing
    BYTE    Selection_                  ' selected operator
    
PUB GraphicsPtr
{
Return long pointer to free form graphics buffer
}
    return @Buffer_[0]
    
PUB Clear
{
Clear the graphics area
}
    LongFill(@Buffer_[0], 0, 256)

PUB SetAlgorithm(Algo) | o, c, ptr
{
Display diagram of algorith Algo (0 based)
}
    Clear
    Algo_ := Algo
    ptr := @BYTE[@OperatorConnections][Algo * 8]
    repeat o from 0 to 3
        Box(o)                  ' draw the operator
        c := BYTE[ptr++]        ' operator to connect TO
        if (c <> 0)             ' ..if any
            Connect(o, c-1)
        c := BYTE[ptr++]        ' operator to connect FROM
        if (c <> 0)             ' ..if any
            Connect(c-1, o)
    
PUB SelectOperator(Op)
{
Indicate operator Op is selected by filling it
}
    Box(Selection_)
    Selection_ := Op
    Square(Op)
    
PRI TileAt(X, Y)
{
Return long pointer to 16x1 four color tile at X,Y
}
    return @LONG[@Buffer_][X + 8 * Y]

PRI Operator(Op)
{
Return byte pointer to two bytes (X,Y) for operator Op's location
0,0 is top left, 3,3 is bottom right
}
    return (@BYTE[@OperatorLayouts][Algo_*8]) + (Op * 2)

PRI TileAtOperator(Op) | ptr, x, y
{
Return long pointer to first tile location of operator Op
}
    ptr := Operator(Op)
    x := BYTE[ptr][0]
    y := BYTE[ptr][1]
    return TileAt(x * 2, y * 8)

PRI Box(Op) | i, ptr
{
Draw a filled box at the operator's location
}
    ptr := TileAtOperator(Op)
    LONG[ptr][1*8] := %%3333333333333333
    LONG[ptr][6*8] := %%3333333333333333
    repeat i from 2 to 5
        LONG[ptr][i*8] := %%3000000000000003
    
PRI Square(Op) | i, ptr
{
Draw a hollow square at the operator's location
}
    ptr := TileAtOperator(Op)
    LONG[ptr][1*8] := %%3333333333333333
    LONG[ptr][6*8] := %%3333333333333333
    repeat i from 2 to 5
        LONG[ptr][i*8] := %%3222222222222223

PRI Connect(F, T) | ptr1, ptr2, x1, y1, x2, y2, tile1, tile2, x, y, ptr
{
Draw a connecting line from operator F to operator T
Outputs come out from bottom and inputs go in to the top
If F modulates T, T must be lower vertically (higher Y value)
}
    ptr1 := Operator(F)
    ptr2 := Operator(T)
    ' From the bottom and To the top
    x1 := BYTE[ptr1][0] * 4 + 1
    y1 := BYTE[ptr1][1] * 8 + 7
    x2 := BYTE[ptr2][0] * 4 + 1
    y2 := BYTE[ptr2][1] * 8
    
    if (y1 == y2-1)
        Vertical(x1, y1, y1)
        Horizontal(x1, x2, y2)      ' draw a line (or dot) to the operator immediately below
    else
        Horizontal(x1, x1+1, y1)    ' always start to the right
        Vertical(x1+1, y1, y2)      ' down or up toward the destination height
        Horizontal(x1+1, x2, y2)    ' and slide into it
    
PRI Vertical(X, Y1, Y2) | y, ptr
{
Draw vertical line at X from Y1 to Y2
X resolution is twice operator width (so X location for a given operator would be 2*)
}
    repeat y from Y1 to Y2
        ptr := TileAt(X>>1, y)
        LONG[ptr] |= %%0000000110000000
        
PRI Horizontal(X1, X2, Y) | x, ptr
{
Draw horizontal line at Y from X1 to X2
X resolution if twice operator width (so X location for a given operator would be 2*)
}
    if X1 <> X2
        if (X2 > X1 AND (X2 & 1))
            --X2
        elseif (X1 > X2 AND (X1 & 1))
            --X1
        repeat x from X1 to X2
            ptr := TileAt(X>>1,Y)
            if (x & 1)
                LONG[ptr] |= %%1111111110000000
            else
                LONG[ptr] |= %%0000000111111111
    else
        ptr := TileAt(X1>>1, Y)
        LONG[ptr] |= %%0000000110000000
    

DAT

OperatorLayouts '(X, Y) 0-3, 0,0 is top left
BYTE    0, 3,   1, 3,   2, 3,   3, 3        ' 1
BYTE    1, 3,   2, 3,   3, 3,   3, 2        ' 2
BYTE    1, 3,   2, 3,   3, 3,   3, 2        ' 3
BYTE    2, 3,   2, 2,   3, 3,   3, 2        ' 4
BYTE    2, 3,   3, 3,   3, 2,   3, 1        ' 5
BYTE    2, 3,   3, 3,   3, 2,   3, 1        ' 6
BYTE    3, 3,   2, 2,   3, 2,   3, 1        ' 7
BYTE    3, 3,   2, 2,   3, 2,   3, 1        ' 8
BYTE    3, 3,   2, 2,   2, 1,   3, 2        ' 9
BYTE    3, 3,   3, 2,   2, 1,   3, 1        ' 10
BYTE    3, 3,   3, 2,   3, 1,   3, 0        ' 11
BYTE    3, 3,   3, 2,   3, 1,   3, 0        ' 12

OperatorConnections '(To, From) 1 based, 0 to indicate none
BYTE    0, 0,   0, 0,   0, 0,   0, 4        ' 1
BYTE    0, 0,   0, 0,   0, 0,   3, 4        ' 2
BYTE    0, 4,   0, 4,   0, 4,   0, 4        ' 3
BYTE    0, 0,   1, 0,   0, 0,   3, 4        ' 4
BYTE    0, 0,   0, 0,   2, 0,   3, 4        ' 5
BYTE    0, 0,   0, 0,   2, 0,   3, 2        ' 6
BYTE    0, 0,   1, 0,   1, 0,   3, 4        ' 7
BYTE    0, 0,   1, 0,   1, 0,   3, 3        ' 8
BYTE    0, 0,   1, 0,   2, 0,   1, 4        ' 9
BYTE    0, 0,   1, 0,   2, 0,   2, 4        ' 10
BYTE    0, 0,   1, 0,   2, 0,   3, 4        ' 11
BYTE    0, 0,   1, 0,   2, 0,   3, 1        ' 12

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
