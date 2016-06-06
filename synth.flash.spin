{{
Non-volatile storage

Copyright (c)2016 Paul Forgey
See end of file for terms of use
}}

CON
    Pin_Clk = 7
    Pin_CS  = 5
    Pin_DI  = 0
    Pin_DO  = 1
    Pin_IO2 = 2
    Pin_IO3 = 3

OBJ
    flash   : "SPI Memory Driver"

VAR
    BYTE    SectorBuf_[$1000]   ' last sector read, also used for read-modify-write if erasing flash sector
    WORD    SectorNum_          ' sector number of SectorBuf_

PUB Load(PatchNum, PatchPtr, PatchSize) | sector, record, ptr
{
Load a patch

PatchNum: patch number
PatchPtr: byte pointer to patch data
PatchSize: patch size (in bytes!)
}
    sector := PatchNum >> 4                     ' 16 patches per sector
    record := PatchNum & 15                     ' patch number mod 16 within sector
    ptr := @SectorBuf_[record * $100]           ' 256 bytes per patch
    
    if !LoadSector(sector)                      ' read sector (if not already)
        return FALSE                            ' return failure

    if (StrComp(@Header, ptr))                  ' validate header to see if a patch is actually here
        ByteMove(PatchPtr, ptr+8, PatchSize)    ' copy it in
    return TRUE                                 ' return success
    
PUB Save(PatchNum, PatchPtr, PatchSize) | sector, record, ptr, i, j
{
Save a patch

PatchNum: patch numner
PatchPtr: byte pointer to patch data
PatchSize; patch size (in bytes!)
}
    sector := PatchNum >> 4                     ' 16 patches per sector
    record := PatchNum & 15                     ' patch number mod 16 within sector
    ptr := @SectorBuf_[record * $100]           ' 256 bytes per patch
    
    if !LoadSector(sector)                      ' read sector (if not already)
        return FALSE                            ' return failure

    i := $ff                                    ' if area is completely $ff, no need to erase the sector
    j := 0
    repeat while (j < $100) AND (i == $ff)
        i &= ptr[j++]
    
    if i <> $ff                                 ' erase sector if we found a non-$ff byte
        if !EraseSector
            return FALSE                        ' return failure

    ByteMove(ptr, @Header, 8)                   ' copy patch data out
    ByteMove(ptr+8, PatchPtr, PatchSize)
    
    if i <> $ff
        repeat record from 0 to $ff             ' write entire sector back if we had to erase it
            if !WriteRecord(record)
                return FALSE
    else
        return WriteRecord(record)              ' or just the record within it
    return TRUE                                 ' return success

PRI EraseSector
{
Erase $1000 byte sector at SectorNum_
}
    if NOT Start
        return FALSE
    flash.EraseFlash((SectorNum_-1) * $1000)
    flash.Stop
    return TRUE
    
PRI WriteRecord(Record) | ptr
{
Write record from loaded sector back to flash
Record: record numer 0-$ff
}
    ptr := @SectorBuf_[Record * $100]           ' 256 bytes per patch

    if (!StrComp(@Header, ptr))                 ' if nothing is actually here, let the flash stay erased
        return TRUE

    if NOT Start
        return FALSE
    
    flash.WriteFlash((SectorNum_-1) * $1000 + Record * $100, ptr, $100)
    flash.Stop ' free the cog when done
    return TRUE

PRI LoadSector(Sector)
{
Read sector from flash, updating current data
Sector: sector number
}
    if Sector <> (SectorNum_-1) ' skip if our sector data is current
        if NOT Start
            return FALSE
        flash.ReadFlash(Sector * $1000, @SectorBuf_, $1000)
        SectorNum_ := Sector+1
        flash.Stop ' free the cog when done
        
    return TRUE

PRI Start
{
Start back end flash driver
}
    if flash.Start(Pin_Clk, Pin_DI, Pin_DO, Pin_CS, -1, Pin_IO2, Pin_IO3) =< 0
        return FALSE
    return TRUE

DAT
Header  BYTE    "synth05", 0

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
