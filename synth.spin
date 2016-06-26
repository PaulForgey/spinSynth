{{
Main module

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    _clkmode = xtal1 + pll16x
    _xinfreq = 5_000_000
    
    Knob_BasePin    = 10
    MIDI_Pin        = 8
    Out_Pin         = 9
    
OBJ
    midi        : "synth.midi"
    osc[4]      : "synth.osc"
    v[8]        : "synth.voice"
    out         : "synth.out"
    ui          : "synth.ui"
    graphics    : "synth.ui.graphics"
    flash       : "synth.flash"
 
VAR
    ' shared memory coordinating the oscillators with the voices and master output
    '
    LONG    OscOutputs_[4]                      ' output per oscillator cog
    LONG    OscTriggers_[4]                     ' trigger per oscillator cog
    LONG    OscInputs_[32*4]                    ' 4 cogs * 8 oscillators * 4 parameters = 128 longs total
    LONG    Envelopes_[48*5]                    ' envelope for each oscillator (32) + LFO + Pitch for each voice (8)

    ' UI control IDs and values
    '
    WORD    PatchUI_                            ' patch control
    WORD    AlgoUI_                             ' algorithm control
    WORD    OperatorSel_                        ' current operator selection
    WORD    OperatorUI_                         ' operator selection control
    WORD    EnvelopeSel_                        ' current envelope selection
    WORD    EnvelopeUI_                         ' envelope selection control
    WORD    LoadButton_                         ' load button
    WORD    SwapButton_                         ' swap button
    WORD    SaveButton_                         ' save button
    WORD    CopyAllButton_                      ' copy selected envelope to others button
    WORD    CopyButton_                         ' copy selected envelope button
    WORD    PasteButton_                        ' paste to selected envelope button
    WORD    Waste_                              ' buttons annoyingly need to point to a value
    WORD    PatchStartUI_                       ' controls => this value affect the patch
    WORD    PatchEndUI_                         ' controls < this value affect the patch

    ' State read from keyboard and then picked up after in non-MIDI loop
    BYTE    Pedal_                              ' control $40 value
    BYTE    Wheel_                              ' control $01 value
    LONG    Bend_                               ' pitch bend value (adjusted to +/- $1000*octave)

    ' Global configuraiton settings
    WORD    MinVelocity_                        ' minimum key down velocity
    WORD    MaxVelocity_                        ' maximum key down velocity
    WORD    Portamento_                         ' 0=polyphonic, larger is slower
    WORD    BendRange_                          ' $10 per octave

    ' Patch
    WORD    Patch_[v#Patch_Words]               ' the actual patch data being played
    WORD    PatchSwap_[v#Patch_Words]           ' swap alternate patch data (for comparison)
    WORD    LoadPatchNum_                       ' UI value for "Load Patch" button
    WORD    PatchNum_                           ' the current patch number
    LONG    Dirty_                              ' version of patch not in storage
    WORD    EnvBuffer_[v#Patch_EnvWords]        ' envelope clipboard
    
    ' Misc state
    '
    BYTE    Knob_[3]                            ' rotational encoder status
    BYTE    LastVoice_                          ' last voice allocated
    BYTE    Key2_                               ' in mono mode, keep track of two keys
    BYTE    Velocity_

PUB Main | scopePtr, i, j
{
Main loop of everything
after setting up the UI, do things in this order:
1- process MIDI messages until the receiver is drained
2- advance voices
3- service UI
}
    midi.Start(MIDI_Pin)

    ' 4 oscillator cogs
    repeat i from 0 to 3
        osc[i].Start(@OscInputs_[i * 4 * 8], PatchParamPtr(v#Patch_Algorithm), PatchParamPtr(v#Patch_Feedback))
        OscOutputs_[i] := osc[i].OutputPtr
        OscTriggers_[i] := osc[i].TriggerPtr

    ' master audio output
    out.Start(Out_Pin, @OscOutputs_, @OscTriggers_, 4, @Envelopes_, 48)

    ' allocate 4 oscillators each to 8 voices
    repeat i from 0 to 7
        v[i].Init(@OscInputs_[i * 4 * 4], @Envelopes_[i * 5 * 6], @Patch_, @Pedal_, @Bend_, @Wheel_)

    ' fire up the VGA display
    ui.Start(out.ScopePtr, graphics.GraphicsPtr)

    ' set up default global configuration values
    MinVelocity_ := $01
    MaxVelocity_ := $7f
    BendRange_ := $20

    ' load patch 0 from storage
    OnLoadPatch(0)

    ' establish the UI
    ui.BeginGroup(String("Patch Bank"))
    PatchUI_ := ui.GroupItem(String("Preset"), @PatchNum_, ui#Type_Raw)
    SaveButton_ := ui.GroupItem(String("Save"), @Waste_, ui#Type_Button)
    SwapButton_ := ui.GroupItem(String("Swap"), @Waste_, ui#Type_Button)
    LoadButton_ := ui.GroupItem(String("Load From"), @LoadPatchNum_, ui#Type_Combo)
    ui.EnableItem(SaveButton_, FALSE)
    ui.EndGroup

    ui.BeginGroup(String("LFO"))
    PatchStartUI_ := ui.GroupItem(String("Waveform"), PatchParamPtr(v#Patch_LFO_Wave), ui#Type_Wave)
    ui.GroupItem(String("Frequency"), PatchParamPtr(v#Patch_LFO_Frequency), ui#Type_Pct)
    ui.GroupItem(String("Pitch"), PatchParamPtr(v#Patch_LFO_Pitch), ui#Type_Pct)
    ui.GroupItem(String("1             Rate"), PatchParamPtr(v#Patch_LFO_R1), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_LFO_L1), ui#Type_Pct)
    ui.GroupItem(String("2             Rate"), PatchParamPtr(v#Patch_LFO_R2), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_LFO_L2), ui#Type_Pct)
    ui.GroupItem(String("3             Rate"), PatchParamPtr(v#Patch_LFO_R3), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_LFO_L3), ui#Type_Pct)
    ui.GroupItem(String("4             Rate"), PatchParamPtr(v#Patch_LFO_R4), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_LFO_L4), ui#Type_Pct)
    ui.GroupItem(String("Loop"), PatchParamPtr(v#Patch_LFO_Loop), ui#Type_Bool)
    ui.EndGroup

    ui.BeginGroup(String("Pitch Envelope"))
    ui.GroupItem(String("1             Rate"), PatchParamPtr(v#Patch_Pitch_R1), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_Pitch_L1), ui#Type_Pct)
    ui.GroupItem(String("2             Rate"), PatchParamPtr(v#Patch_Pitch_R2), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_Pitch_L2), ui#Type_Pct)
    ui.GroupItem(String("3             Rate"), PatchParamPtr(v#Patch_Pitch_R3), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_Pitch_L3), ui#Type_Pct)
    ui.GroupItem(String("4             Rate"), PatchParamPtr(v#Patch_Pitch_R4), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchParamPtr(v#Patch_Pitch_L4), ui#Type_Pct)
    ui.GroupItem(String("Loop"), PatchParamPtr(v#Patch_Pitch_Loop), ui#Type_Bool)
    ui.EndGroup

    ui.BeginGroup(String("Voice"))
    AlgoUI_ := ui.GroupItem(String("Algorithm"), PatchParamPtr(v#Patch_Algorithm), ui#Type_Algo)
    ui.GroupItem(String("Feedback"), PatchParamPtr(v#Patch_Feedback), ui#Type_Feedback)
    ui.EndGroup

    ui.BeginGroup(String("Operators"))
    OperatorUI_ := ui.GroupItem(String("Operator"), @OperatorSel_, ui#Type_Op)
    ui.GroupItem(String("Level"), PatchOscParamPtr(0, v#Patch_Level), ui#Type_Pct)
    ui.GroupItem(String("Velocity"), PatchOscParamPtr(0, v#Patch_Velocity), ui#Type_Pct)
    ui.GroupItem(String("Wheel"), PatchOscParamPtr(0, v#Patch_Wheel), ui#Type_Pct)
    ui.GroupItem(String("LFO"), PatchOscParamPtr(0, v#Patch_Mod_LFO), ui#Type_Pct)
    ui.GroupItem(String("Frequency"), PatchOscParamPtr(0, v#Patch_Frequency), ui#Type_Freq)
    ui.GroupItem(String("Multiplier"), PatchOscParamPtr(0, v#Patch_Multiplier), ui#Type_Mult)
    ui.GroupItem(String("Detune"), PatchOscParamPtr(0, v#Patch_Detune), ui#Type_Detune)
    ui.EndGroup

    ui.BeginGroup(String("Envelopes"))
    EnvelopeUI_ := ui.GroupItem(String("Operator"), @EnvelopeSel_, ui#Type_Op)
    ui.GroupItem(String("1             Rate"), PatchEnvParamPtr(0, v#Patch_R1), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchEnvParamPtr(0, v#Patch_L1), ui#Type_Pct)
    ui.GroupItem(String("2             Rate"), PatchEnvParamPtr(0, v#Patch_R2), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchEnvParamPtr(0, v#Patch_L2), ui#Type_Pct)
    ui.GroupItem(String("3             Rate"), PatchEnvParamPtr(0, v#Patch_R3), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchEnvParamPtr(0, v#Patch_L3), ui#Type_Pct)
    ui.GroupItem(String("4             Rate"), PatchEnvParamPtr(0, v#Patch_R4), ui#Type_Pct)
    ui.GroupItem(String("             Level"), PatchEnvParamPtr(0, v#Patch_L4), ui#Type_Pct)
    ui.GroupItem(String("Loop"), PatchEnvParamPtr(0, v#Patch_Loop), ui#Type_Bool)
    CopyAllButton_ := ui.GroupItem(String("Copy To All"), @Waste_, ui#Type_Button)
    CopyButton_ := ui.GroupItem(String("Copy"), @Waste_, ui#Type_Button)
    PasteButton_ := ui.GroupItem(String("Paste"), @Waste_, ui#Type_Button)
    ui.EndGroup
    
    PatchEndUI_ := ui.BeginGroup(String("Global Settings"))
    ui.GroupItem(String("Minimum velocity"), @MinVelocity_, ui#Type_Raw)
    ui.GroupItem(String("Maximum velocity"), @MaxVelocity_, ui#Type_Raw)
    ui.GroupItem(String("Portamento"), @Portamento_, ui#Type_Pct)
    ui.GroupItem(String("Pitch Bend"), @BendRange_, ui#Type_Raw)
    ui.EndGroup

    ' do not leave the non-selectable group selected
    ui.SelectNext

    ' prime rotational encoder state (avoiding random UI activity on startup)
    repeat i from 0 to 2
        Knob_[i] := KnobValue(i)

    '*
    '* MAIN LOOP
    '*
    repeat
        '* Drain MIDI
        repeat while NOT midi.Empty
            OnMidi(midi.Data)

        '* Advance Voices
        repeat i from 0 to 7
            v[i].Advance
        
        '* Read control values for UI
        repeat i from 0 to 2
            j := KnobValue(i)
            if (Knob_[i] <> j)
                Knob_[i] := OnKnob(j, Knob_[i], i)
    repeat

PRI PatchParamPtr(P)
{
returns word pointer for patch parameter
}
    return @Patch_[P]
    
PRI PatchOscParamPtr(Op, P)
{
returns word pointer for operator parameter
}
    return PatchParamPtr(P + v#Patch_Op + v#Patch_Osc + v#Patch_OpWords * Op)
    
PRI PatchEnvParamPtr(Op, P)
{
returns word pointer for envelope parameter
}
    return PatchParamPtr(P + v#Patch_Op + v#Patch_Env + v#Patch_OpWords * Op)

PRI KnobValue(Control) | shift
{
returns rotational value for Control (range 0-2)
}
    shift := Knob_BasePin + (Control << 1)
    return (INA & ($3 << shift)) >> shift
    
PRI OnKnob(New, Old, Control) | b0, b1, button
{
action when rotational value has changed
New: 0-3
Old: 0-3
Control: 0-2
}
    b0 := (Old ^ (New >> 1)) & 1        ' relative old value
    b1 := (New ^ (Old >> 1)) & 1        ' relative new value

    button := -1                        ' initialize to invalid value
    
    case Control            
        2: ' menu selection
            if (b0 > b1)
                ui.SelectNext
            else
                ui.SelectPrev

        1: ' coarse control
            button := ui.Adjust((b0 - b1) * $10)

        0: ' fine control (maybe would be better as two buttons rather than a third knob)
            button := ui.Adjust(b0 - b1)

    ' handle button or selection change
    case button
        SwapButton_:
            OnSwapPatch
        
        SaveButton_:
            OnSavePatch(PatchNum_)

        CopyAllButton_:
            OnCopyAll

        CopyButton_:
            OnCopy

        PasteButton_:
            OnPaste

        LoadButton_:
            OnLoadPatch(LoadPatchNum_)

        PatchUI_:
            OnLoadPatch(PatchNum_)

        AlgoUI_:
            OnAlgoChange

        OperatorUI_:
            OnOperatorChange(OperatorSel_)

        EnvelopeUI_:
            OnEnvelopeChange(EnvelopeSel_)

        other:
            ' activity elsewhere soils the patch
            if button => PatchStartUI_ AND button < PatchEndUI_
                Dirty_ := TRUE

    if ui.Selection => EnvelopeUI_
        graphics.SelectOperator(EnvelopeSel_)
    else
        graphics.SelectOperator(OperatorSel_)

    ' If the patch is unsaved, force the user to load or save before navigating out of it
    ui.EnableItem(PatchUI_, !Dirty_)
    ui.EnableItem(SaveButton_, Dirty_)
    
    return New

PRI OnSavePatch(PatchNum) | okay
{
Save the selected patch
}
    ui.SetStatus(String("Saving"))
    ' free up a cog for the flash driver
    midi.Stop
    
    okay := flash.Save(PatchNum, @Patch_, v#Patch_Words * 2)
    
    ' get midi back
    midi.Start(MIDI_Pin)

    if okay
        ' update the swap buffer
        WordMove(@PatchSwap_, @Patch_, v#Patch_Words)
        ' not dirty
        Dirty_ := FALSE
        ui.SetStatus(String(" "))
    else
        ui.SetStatus(String("FLASH WRITE FAILED"))

PRI OnLoadPatch(PatchNum) | okay
{
Load a patch
}
    ui.SetStatus(String("Loading"))
    ' free up a cog for the flash driver
    midi.Stop

    Silence

    okay := flash.Load(PatchNum, @Patch_, v#Patch_Words * 2)
    
    ' get midi back
    midi.Start(MIDI_Pin)
    
    if okay
        ' update the swap buffer
        WordMove(@PatchSwap_, @Patch_, v#Patch_Words)
        ' default the load button to this patch
        LoadPatchNum_ := PatchNum
        ' update the UI with new values
        ui.Refresh
        graphics.SetAlgorithm(WORD[PatchParamPtr(v#Patch_Algorithm)])
        ' not dirty
        Dirty_ := FALSE
        ui.SetStatus(String(" "))
    else
        ui.SetStatus(String("FLASH READ FAILED"))

PRI Silence | n
{
Silence all outputs
}
    repeat n from 0 to 7
        v[n].Silence

PRI OnSwapPatch | w, n
{
Swap patch with alternate values (initially the loaded ones)
}
    repeat w from 0 to v#Patch_Words-1
        n := Patch_[w]
        Patch_[w] := PatchSwap_[w]
        PatchSwap_[w] := n

    ui.Refresh
    graphics.SetAlgorithm(WORD[PatchParamPtr(v#Patch_Algorithm)])
    Dirty_ := TRUE ' could be smarter here

PRI OnAlgoChange
{
Selected algorithm has changed. Update UI graphics.
}
    graphics.SetAlgorithm(WORD[PatchParamPtr(v#Patch_Algorithm)])
    Dirty_ := TRUE

PRI OnOperatorChange(Sel) | i
{
Selected operator has changed, so update the UI pointers to its parameters
}
    repeat i from 0 to v#Patch_OscWords - 1
        ui.PointItem(OperatorUI_ + i + 1, PatchOscParamPtr(Sel, i))

PRI OnEnvelopeChange(Sel) | i
{
Selected envelope has changed, so update the UI pointers to its parameters
}
    repeat i from 0 to v#Patch_EnvWords - 1
        ui.PointItem(EnvelopeUI_ + i + 1, PatchEnvParamPtr(Sel, i))

PRI OnCopyAll | i, j
{
Copy selected envelope parameters to all the other envelopes
}
    repeat i from 0 to v#Patch_Ops-1
        if i <> EnvelopeSel_
            repeat j from 0 to v#Patch_EnvWords-1
                WORD[PatchEnvParamPtr(i, j)] := WORD[PatchEnvParamPtr(EnvelopeSel_, j)]
    Dirty_ := TRUE

PRI OnCopy
{
Copy selected envelope to buffer
}
    WordMove(@EnvBuffer_, PatchEnvParamPtr(EnvelopeSel_, 0), v#Patch_EnvWords)

PRI OnPaste
{
Paste buffer to selected envelope
}
    WordMove(PatchEnvParamPtr(EnvelopeSel_, 0), @EnvBuffer_, v#Patch_EnvWords)
    Dirty_ := TRUE
    ui.Refresh

PRI OnMidi(M)
{
Received MIDI message
Messages come from the receiver as longs, more significant bytes recieved first
The 3 byte messages we currently care about look like, say, (note down << 16) | (key << 8) | velocity
}
    '* TODO: midi channels and config

    case M >> 20
        %1000:
            OnNoteOff((M >> 8) & $7f)
            
        %1001:
            OnNoteOn((M >> 8) & $7f, M & $7f)
            
        %1011:
            OnControlChange((M >> 8) & $7f, M & $7f)
        
        %1110:
            OnPitchBend(((M & $7f) << 7) | ((M >> 8) & $7f))

PRI OnNoteOn(Key, Velocity) | i
{
Key down
}
    if Velocity == 0
        ' some devices send key down with 0 velocity for key up
        OnNoteOff(Key)
        return

    Velocity #>= MinVelocity_
    Velocity <#= MaxVelocity_

    i := FindVoiceForKey(Key)
    v[i].Down(Key, Velocity, Portamento_)

    if Portamento_
        ' if we aren't already keeping track of one key, keep track of a second
        if NOT Key2_
            Key2_ := $80 | Key
        Velocity_ := Velocity

PRI OnNoteOff(Key) | i
{
Key up

velocity information for key up is ignored
}
    if Portamento_
        i := v[0].Key
        if (v[0].Playing) AND (i <> Key)
            ' what was released is not what is playing, so note what is playing
            Key2_ := ($80 | i)
        elseif (i == Key)
            ' what was release is what is playing
            if Key2_ AND (Key2_ & $7f <> Key)
                ' go back to the other key
                v[0].Down(Key2_ & $7f, Velocity_, Portamento_)
            else
                ' there is no other key, or we released it
                v[0].Up
                Key2_ := 0
    else
        repeat i from 0 to 7
            if v[i].Key == Key
                v[i].Up
                return

PRI OnControlChange(Control, Value)
{
Control change
}
    case Control
        $01:
            OnWheel(Value)
            
        $40:
            OnPedal(Value)

PRI OnPitchBend(Value)
{
Pitch wheel update
Value reported is +/- $1000 * octave, where octave can be fractional. e.g., a half octave range up would be $0800
}
    if Value > $2000
        ++Value
    Value -= $2000
    Bend_ := (Value * BendRange_) ~> 5

PRI OnWheel(Value)
{
Modulation wheel update
Leave the new value to be picked up later
}
    Wheel_ := Value

PRI OnPedal(Value)
{
Sustain pedal update
Leave the new value to be picked up later
}
    Pedal_ := Value

PRI FindVoiceForKey(Key) | i, j
{
Allocate a voice to handle playing a note
}
    ' if we are not being polyphonic, simply return 0
    if Portamento_
        return 0

    ' first, check for any existing voices already playing/having played it
    repeat i from 0 to 7
        if v[i].Key == Key
            return i

    ' rotate the round robin allocation we start from
    LastVoice_++
    repeat i from 0 to 7
        ' try to find a voice that is in key up state
        j := (i + LastVoice_) & 7
        if NOT v[j].Playing
            return j

    ' finally, just take one over
    return (LastVoice_ & 7)

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
