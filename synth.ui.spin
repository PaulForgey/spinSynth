{{
User interface front end

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Type_Raw            = 0 ' 9 bit hex value
    Type_Pct            = 1 ' 00-99 scaled from 0-$1ff
    Type_Freq           = 2 ' frequency value as multiplier or fixed
    Type_Bool           = 3 ' yes or no
    Type_Op             = 4 ' Op 1-4
    Type_Detune         = 5 ' detuning from -256 to 255 scaled from $1ff to $ff
    Type_Feedback       = 6 ' 0-19 with value being 19-displayed
    Type_Algo           = 7 ' algorithm selection, which also updates graphical drawing
    Type_Button         = 8 ' button with no displayed value, activated on adjust(1)
    Type_Combo          = 9 ' button with displayed 9 bit hex value, activated on adjust(1), adjusted in units on adjust(-$10 or $10)

OBJ
    vga         : "synth.vga"
    graphics    : "synth.ui.graphics" 
    
VAR
    WORD    Line_                           ' line number/control ID of next added, or total number
    WORD    Selection_                      ' current selection
    BYTE    DisplayStr_[5]                  ' buffer for formatting values
    WORD    ParamPtrs_[vga#Height]          ' word pointers to parameters
    BYTE    ParamTypes_[vga#Height]         ' parameter types
    BYTE    ParamEnable_[vga#Height]        ' parameter enabled if non-0

PUB Start(Scope)
{
Start the back end graphics driver
Scope: byte pointer to scope data
}
    vga.Start(Scope, graphics.GraphicsPtr)
    
PUB SetStatus(Status)
{
Set text for the reservered bottom line
Status: string of 23 characters or less
}
    vga.SetStatus(Status)
    
PUB BeginGroup(Name) | x, l
{
Start a group of controls, indicated by a gray heading and line draw stuff
Name: label for group 23 characters or less
}
    vga.TextAt(String(159), 0, Line_, 2)    ' left corner lines
    vga.TextAt(Name, 1, Line_, 1)           ' text

    x := strsize(Name)
    l := 23 - x
    repeat while (l-- > 0)
        vga.TextAt(String(144), ++x, Line_, 2) ' draw line after text to end

    vga.TextAt(String(158), 24, Line_, 2)   ' right corner lines

    return Line_++                          ' not really a control ID, but can be used for comparison (lowest in group -1)
    
PUB GroupItem(Name, ValuePtr, Type)
{
A control within the group entered from BeginGroup
Name:       label for control 19 characters or less
ValuePtr:   word pointer to value
Type:       one of the Type_ constants
}
    vga.TextAt(String(145), 0, Line_, 2)    ' vertical line to the left
    vga.TextAt(Name, 1, Line_, 0)           ' label
    vga.TextAt(String(145), 24, Line_, 2)   ' vertical line to the right

    ParamPtrs_[Line_] := ValuePtr           ' value
    ParamTypes_[Line_] := Type              ' type
    ParamEnable_[Line_] := 1                ' enabled until set otherwise
    DisplayField(Line_)                     ' display the value

    return Line_++                          ' return control ID

PUB EnableItem(Line, Enabled)
{
Enable a control for editing. Disabled controls can still be selected, but not activated or edited
Line:    control
Enabled: non-0 to enable
}
    if Enabled
        ParamEnable_[Line] := 1
    else
        ParamEnable_[Line] := 0
    DisplayField(Line)

PUB PointItem(Line, ValuePtr)
{
Re-point a control's value to a new location
Line:       control ID
ValuePtr:   word pointer to value
}
    ParamPtrs_[Line] := ValuePtr
    DisplayField(Line)

PUB EndGroup | x
{
End group of controls started by BeginGroup
}
    vga.TextAt(String(157), 0, Line_, 2)        ' left corner

    repeat x from 1 to 24
        vga.TextAt(String(144), x, Line_, 2)    ' horizontal line

    vga.TextAt(String(156), 24, Line_, 2)       ' right corner

    return Line_++                              ' returns not really a control ID, but can be used for relative comparison (highest in group +1)

PUB Select(S) | scroll
{
Select a control
Value is highlighted and, if enabled, editing happens in this field
}
    scroll := S
    repeat while (scroll > 0) AND (ParamPtrs_[scroll])
        --scroll
    vga.Scroll(scroll)                          ' scroll to start of group
    
    vga.Highlight(20, 4, Selection_, FALSE)     ' unhighlight old selection
    Selection_ := S                             ' set new selection
    vga.Highlight(20, 4, Selection_, TRUE)      ' ..and highlight
    DisplayField(S)                             ' update field view

PUB SelectPrev | s
{
Select previously selectable item
}
    s := Selection_
    repeat
        if (--s < 0)
            s := Line_ -1
    until ParamPtrs_[s]
    Select(s)
    
PUB SelectNext | s
{
Select next selectable item
}
    s := Selection_
    repeat
        if (++s => Line_)
            s := 0
    until ParamPtrs_[s]
    Select(s)

PUB Refresh | l
{
Update all displayed fields
}
    repeat l from 0 to vga#Height - 1
        if ParamPtrs_[l]
            DisplayField(l)

PUB Adjust(D) | v
{
Adjust current selection by -$10, -1, 1, or $10
+/- 1 is for fine adjustment, +/- $10 for coarse
}
    v := WORD[ParamPtrs_[Selection_]]       ' current value

    if ParamEnable_[Selection_]             ' do nothing if not enabled
        case ParamTypes_[Selection_]        ' adjust according to type (and this is where limitations of Spin's object-ish nature get annoying)
            Type_Pct:
                v := AdjustPct(v, D)

            Type_Freq:
                v := AdjustFreq(v, D)

            Type_Bool:
                v := AdjustBool(v, D)

            Type_Detune:
                v := AdjustDetune(v, D)

            Type_Feedback:
                v := AdjustFeedback(v, D)

            Type_Algo:
                v := AdjustOne(v, D)

            Type_Op:
                v := AdjustOne(v, D)

            Type_Button:
                ' nothing

            Type_Combo:
                v := AdjustCombo(v, D)

            other:
                v += D

        v := Limit(v, ParamTypes_[Selection_])  ' apply limits after adjuh
        WORD[ParamPtrs_[Selection_]] := v       ' update new value
        DisplayField(Selection_)                ' update display of it

        ' buttons do not return their ID unless activated
        if (ParamTypes_[Selection_] => Type_Button AND D <> 1)
            return -1
        return Selection_                       ' return affected control ID

    return -1 ' no control affected

PRI DisplayField(Line) | l, v, c
{
Update display of field's value
}
    v := WORD[ParamPtrs_[Line]] ' get value

    case ParamTypes_[Line]      ' display according to type into DisplayStr_ buffer
        Type_Raw:
            DisplayRaw(v)

        Type_Pct:
            DisplayPct(v)

        Type_Freq:
            DisplayFreq(v)

        Type_Bool:
            DisplayBool(v)

        Type_Op:
            DisplayOp(v)

        Type_Detune:
            DisplayDetune(v)

        Type_Feedback:
            DisplayFeedback(v)

        Type_Algo:
            DisplayAlgo(v)

        Type_Button:
            DisplayButton(v)

        Type_Combo:
            DisplayCombo(v)

    if ParamEnable_[Line]       ' color is white or gray depending if enabled
        c := 0
    else
        c := 1
    vga.TextAt(@DisplayStr_, 20, Line, c) ' display value

PRI Limit(Value, Type) | minValue, maxValue
{
Limit a proposed new value according to type
}
    minValue := 0

    case Type
        Type_Freq:
            maxValue := $17f

        Type_Bool:
            maxValue := 1
            
        Type_Op:
            maxValue := 3

        Type_Feedback:
            maxValue := 19
    
        Type_Algo:
            maxValue := 11

        other:
            maxValue := $1ff
            
    Value <#= maxValue
    Value #>= minValue
    
    return Value

PRI DisplayBool(v)
{
Type_Bool::Display
}
    if v
        ByteMove(@DisplayStr_, String("Yes "), 5)
    else
        ByteMove(@DisplayStr_, String("No  "), 5)

PRI AdjustBool(V, D)
{
Type_Bool::Adjust
}
    if D > 0
        V := 1
    else
        V := 0
    return V

PRI DisplayRaw(V) | l
{
Type_Raw::Display
}
    FormatNumber(@DisplayStr_[0], V, 3, 16, "0")
    DisplayStr_[3] := " "
    
PRI AdjustOne(V, D)
{
adjust by one only regardless of coarse/fine
}
    if D > 0
        V++
    else
        V--
    return V

PRI AdjustCombo(V, D)
{
adjust combo button; no effect for fine, coarse adjusts by one
}
    if D > 1
        V++
    elseif D < 1
        V--
    return V
    
PRI DisplayPct(V) | l
{
Type_Pct::Display
}
    V := (V * 100) / 512
    V <#= 99
    DisplayStr_[0] := " "
    DisplayStr_[1] := " "
    FormatNumber(@DisplayStr_[2], V, 2, 10, "0")

PRI AdjustPct(V, D)
{
Type_Pct::Adjust
}
    if D < -1
        D := -10
    elseif D > 1
        D := 10

    V := (V * 100) / 512
    V <#= 99
    V += D
    
    if V <> 0
        if V => 99
            V := $1ff
        else
            V := (V * 10) + 5
            V := (V * 512) / 1000

    return V
    
PRI DisplayFreq(V) | p
{
Type_Freq::Display
}
    if (V & $100)
        V &= $7f
        p := @NoteNames + ((V // 12) * 2)
        V /= 12
        V <#= 10
        ByteMove(@DisplayStr_, p, 2)
        FormatNumber(@DisplayStr_[2], V, 2, $10, "0")
    else
        V &= $ff
        FormatNumber(@DisplayStr_[0], V >> 4, 2, 10, "x")
        DisplayStr_[2] := " "
        DisplayStr_[3] := " "
        V &= $f
        ' denote some exact tuning values
        case V
            $0:
                ' nothing

            $4:
                DisplayStr_[2] := "+"
                DisplayStr_[3] := "3"
                
            $8:
                DisplayStr_[2] := "+"
                DisplayStr_[3] := "5"
                
            $c:
                DisplayStr_[2] := "+"
                DisplayStr_[3] := "7"
                
            other:
                DisplayStr_[2] := "."
                DisplayStr_[3] := LookupZ(V : "0".."9", "a".."f")

PRI AdjustFreq(V, D)
{
Type_Freq::Adjust
}
    if (D == -$10)
        if (V & $100)
            D := -12
        else
            D := -8
    elseif (D == $10)
        if (V & $100)
            D := 12
        else
            D := 8
    return V + D

PRI DisplayOp(V)
{
Type_Op::Display
}
    DisplayStr_[0] := "O"
    DisplayStr_[1] := "p"
    DisplayStr_[2] := " "
    DisplayStr_[3] := LookupZ(V : "1".."4")
    graphics.SelectOperator(V)

PRI DisplayDetune(V)
{
Type_Detune::Display
}
    if (V & $100)
        DisplayStr_[0] := "-"
        V := (!V & $ff) + 1
    elseif (V == 0)
        DisplayStr_[0] := " "
        DisplayStr_[1] := "-"
        DisplayStr_[2] := "-"
        DisplayStr_[3] := "-"
    else
        DisplayStr_[0] := "+"

    if (V)
        FormatNumber(@DisplayStr_[1], V, 3, 10, " ")

PRI AdjustDetune(V, D)
{
Type_Detune::Adjust
}
    if D < -1
        D := -10
    elseif D > 1
        D := 10
    V ^= $100
    V += D
    V #>= 0
    V <#= $1ff
    return V ^ $100

PRI DisplayFeedback(V)
{
Type_Feedback::Display
}
    FormatNumber(@DisplayStr_[0], 19 - V, 4, 10, " ")
    
PRI AdjustFeedback(V, D)
{
Type_Feedback::Adjust
}
    if (D == -$10)
        V := 19
    elseif (D == $10)
        V := 0
    else
        V -= D
    return V

PRI DisplayAlgo(V)
{
Type_Algo::Display
}
    FormatNumber(@DisplayStr_[0], V+1, 4, 10, " ")
    graphics.SetAlgorithm(V)

PRI DisplayButton(V)
{
Type_Button::Display
}
    ByteFill(@DisplayStr_[0], " ", 3)
    DisplayStr_[3] := 7

PRI DisplayCombo(V)
{
Type_Combo::Display
}
    FormatNumber(@DisplayStr_[0], V, 3, $10, "0")
    DisplayStr_[3] := 7

PRI FormatNumber(StringPtr, V, Digits, Base, Fill) | n, d, p
{
Format a numeric value of any base with any specified leading 0 fill
StringPtr: buffer to write into (does not 0 terminate)
V:         value
Digits:    number of digits to fill
Base:      number base 2->36
Fill:      leading 0 fill character
}
    Digits--
    p := StringPtr + Digits
    repeat n from 0 to Digits
        d := V // Base
        if V <> 0 OR n == 0
            BYTE[p] := LookupZ(d : "0".."9", "a".."z")
        else
            BYTE[p] := Fill
        V /= Base
        p--

DAT
NoteNames   BYTE "C ", "C#", "D ", "D#", "E ", "F ", "F#", "G ", "G#", "A ", "A#", "B "

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
