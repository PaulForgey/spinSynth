{{
  Driver for Winbond SPI Flash Memory (W25Q32FV 4MB)
  It also supports Microchip 23LC1024 SPI SRAM.
  
  Copyright (c) 2009, 2013 by Michael Green
       See end of file for terms of use.

  Modified 2013 for 
}}

'' The start method is used to supply pin numbers for both the
'' Flash and SRAM chips.  Separate CS pins are required for
'' each chip.  If a chip is not provided, -1 should be
'' used for the CS pin number.  The Clk, DI (DIO), and DO
'' pins are shared (in common) for all the chips used.
'' If present, the SRAM chips are initialized for sequential
'' mode.  If present, the size of the flash memory is read
'' from the device and returned by the start method.
'' If /WP and /HOLD pins are provided (not -1), they're set
'' to high before /CS is asserted.

'' This object is written to allow shared use of the Clk, DI (DIOn),
'' and DO I/O pins.  There is no locking done here, but all the I/O
'' pins are set to input mode once any operation is completed.

'' sendRecv is the low level SPI driver.  It provides for
'' sending a command code plus an address or other control
'' information followed by sending a block of data or receiving
'' a block of data.  There's no checking possible.

'' ReadSRAM and WriteSRAM are the main user routines for SRAM
'' use.  See the method description below for details.

'' readData, writeData, and eraseData are the main user routines
'' for Winbond flash access.  Reading can start at any address
'' and continue to the end of flash memory.  Writing can start
'' at any address and continue to the end of flash memory.  The
'' locations being written must be erased (value $FF) and the
'' write operation is done in 256 byte pages internal to the
'' write routine.  The erase operation is done for the 4K block
'' containing the address passed to eraseData.


CON

    WR_DATA  = $02_000000              ' Write Data / Address / Data
    RD_DATA  = $03_000000              ' Read Data / Address / (Data)
    STATUS   = $05                     ' Read STATUS / (Data)
    WRT_ENA  = $06                     ' Write Enable
    SEC_ERA  = $20_000000              ' Erase Sector / Address
    JEDEC    = $9F                     ' Return JEDEC device info
    JEDEC4MS = $1640EF                 '  4MB Flash Memory (W25Q32FV SPI)
    JEDEC4MQ = $1660EF                 '  4MB Flash Memory (W25Q32FV QPI)

    SRAM     = 0                       ' Device # for SRAM 0
    FLASH    = 1                       ' Device # for Flash Memory
    INV_DEV  = 2                       ' Invalid device number

    BUSY     = $01                     ' BUSY STATUS
    SEC_SIZE = 4096                    ' Number of bytes in sector


VAR

    long Cog                           ' Cog used for assembly routine
    long Params[3]                     ' Parameters to assembly I/O driver


PUB Start(Clk, DIO, DO, CSflsh, CSsram, WP, HOLD) | WPMask, HoldMask
{
   Initialize the object.  Set up parameters for the PASM portion.
   Start the new cog for the low level I/O.  Initialize the SRAM and Flash.
   Note: 23LC1024 SRAM powers up in 1-bit SPI and sequential mode.
         W25X32FV Flash powers up in 1-bit SPI mod with no write protection
         unless previously set as non-volatile.  This is not changed here.
      Clk    = Pin number for clock line on all chips
      DIO    = Pin number for DIO or DI line on all chips
      DO     = Pin number for DO line on all chips
      CSflsh = Pin number for flash memory chip (or -1 if none)
      CSsram = Pin number for SRAM chip (or -1 if none)
      WP     = Pin number for /WP or IO2 (or -1 if none)
      HOLD   = Pin number for /HOLD or IO3 (or -1 if none)
}
   Stop                                                 ' Stop any running I/O driver
   ClkMask     := (Clk <> -1) & |< Clk
   DIOMask     := (DIO <> -1) & |< DIO                  ' Initialize the I/O masks
   DOMask      := (DO  <> -1) & |< DO
   CSflshMask  := (CSflsh <> -1) & |< CSflsh
   CSsramMask  := (CSsram <> -1) & |< CSsram
   WPMask      := (WP <> -1) & |< WP
   HoldMask    := (HOLD <> -1) & |< HOLD
   OutaMask    := CSflshMask | CSsramMask | WPMask | HoldMask
   DiraMask    := DIOMask | ClkMask | CSflshMask | CSsramMask
   DiraMask    |= WPMask | HoldMask
   Params[0]   := Params[1] := 0                        ' Clear the parameters
   Params[2]   := INV_DEV
   if Cog := cognew(@EntryPoint, @Params) + 1           ' Return 0 if no cogs
      result := -1                                      ' Default is unknown size flash
      if CSflshMask <> 0
         case sendRecv(FLASH, JEDEC, 3, 0)              ' Get JEDEC code for the device
            JEDEC4MS, JEDEC4MQ:                         ' Winbond W25X32FV - 4MB Flash
               result := 4 * |<20


PUB Stop

   if Cog                                               ' Stop any running I/O driver
      cogstop(Cog~ - 1)


PRI SendRecv(Device, Value, Count, Address)             ' Send and possibly receive
{
   Device = Device to be used: 0 - SRAM, 1 - Flash
   Value = Value to be sent MSB first, right justified in parameter
   Count = Number of bytes to be transferred (>0 received, <0 sent)
   Address = 0 or address of buffer area. If 0, @RESULT is used
}
  if cog
    repeat while Params.byte[8] < INV_DEV               ' Wait until done
    Params.long[0] := Value                             ' Possible literal value
    Params.word[2] := Count                             ' Byte count
    if Address
       Params.word[3] := Address
    else
       Params.word[3] := @result                        ' Use RESULT if rA is zero
    Params.byte[8] := Device                            ' Set device to use (starts)
    repeat while Params.byte[8] < INV_DEV               ' Wait until done


PUB ReadSRAM(Addr, Data, Count)        ' Read bytes from SRAM
{
   Addr  = SRAM memory starting address for reading data
   data  = Hub starting address for data
   count = Number of bytes to be read from SRAM memory
           If count is -1 to -4, use @RESULT for data address
}
   if Count < 0
      SendRecv(SRAM, RD_DATA | Addr, -Count, @result)
   else
      SendRecv(SRAM, RD_DATA | Addr, Count, Data)


PUB WriteSRAM(Addr, Data, Count)       ' Write bytes to SRAM
{
   Addr  = SRAM memory starting address for writing data
   data  = Hub starting address for data or data itself
   count = Number of bytes to be written to SRAM memory
           If count is -1 to -4, use @data for data address
}
   if Count < 0
      SendRecv(SRAM, WR_DATA | Addr, Count, @Data)
   else
      SendRecv(SRAM, WR_DATA | Addr, -Count, Data)


PUB ReadFlash(Addr, Data, Count)        ' Read bytes from flash memory
{
   Addr  = Flash memory starting address for reading data
   data  = Hub starting address for data
   count = Number of bytes to be read from flash memory
           If count is -1 to -4, use @result for data address
}
   if Count < 0
      SendRecv(FLASH, RD_DATA | Addr, -Count, @result)
   else
      SendRecv(FLASH, RD_DATA | Addr, Count, Data)


PUB WriteFlash(Addr, Data, Count) | DataPointer, Offset ' Write bytes to flash memory
{
   Addr  = Flash memory starting address for writing data
   Data  = Hub starting address for data or data itself
   Count = Number of bytes to be written to flash memory
           If Count is -1 to -4, use @Data for data address
   This routine handles the process of writing to flash memory
   in pages of 256 bytes or less (aligned to 256 page boundaries)
}
   if Count < 0
      DataPointer := @Data
      Count := -Count
   else
      DataPointer := Data
   repeat while Count > 0                               ' Handle end of page, full pages,
      Offset := Count <# (256 - (Addr & $FF))           ' and last partial page
      sendRecv(FLASH, WRT_ENA, 0, 0)                    ' Enable writes
      sendRecv(FLASH, WR_DATA | Addr, -Offset, DataPointer)
      repeat until sendRecv(FLASH, STATUS, 1, 0) & BUSY == 0 ' Wait until done
      Addr += Offset
      DataPointer += Offset                             ' Advance pointers
      Count -= Offset


PUB EraseFlash(Addr)                                    ' Erase a 4K sector of flash
'  Addr  = Flash memory address within sector to be erased

   SendRecv(FLASH, WRT_ENA, 0, 0)                       ' Enable writes
   SendRecv(FLASH, SEC_ERA | Addr, 0, 0)                ' Erase 4K sector
   repeat until SendRecv(FLASH, STATUS, 1, 0) & BUSY == 0 ' Wait until done


DAT ' I/O driver for flash and SRAM
{{
  I/O driver for flash and SRAM.  If the address passed in PAR is > 32K,
  it is the starting block number of the file to be loaded * 4.  If the
  address is < 32K, it is the address of a three long parameter block.
  The first long is a 0 to 4 byte literal value to be transmitted to the
  device as described in sendRecv.  The next word is the number of bytes to
  be read (> 0) or written (< 0).  The next word is the starting address for
  the transfer.  The next byte is the device number.  1 is the flash chip.
  0 is the SRAM chip.  After the operation is completed, the byte count is
  set to zero and the address is updated.
}}
                        org     0
EntryPoint              mov     FlashTemp,PAR
                        rdlong  Preamble+0,FlashTemp    ' Get parameters
                        add     FlashTemp,#4
                        rdword  Preamble+1,FlashTemp    ' Byte count
                        add     FlashTemp,#2
                        test    Preamble+1,StartROM  wc ' Extend word sign
                        rdword  Preamble+2,FlashTemp    ' Starting address
                 if_c   or      Preamble+1,WordSign
                        add     FlashTemp,#2
                        rdbyte  Preamble+3,FlashTemp    ' Device #
                        cmp     Preamble+3,#INV_DEV  wc ' If invalid device #,
                if_nc   jmp     #EntryPoint             '  go back and wait
                        or      outa,OutaMask           ' Will set /WP, /HOLD
                        andn    outa,ClkMask            '  make sure Clk low
                        or      dira,DiraMask           ' DOpin is only input
                        movs    :SelectDev,#CSsramMask
                        add     :SelectDev,Preamble+3   ' Select proper /CS
                        movs    SkipRecv,:SelectDev
                        mov     FlashMask,#$FF          ' Set up sending mask
                        shl     FlashMask,#24           ' m := $FF000000
:SelectDev              andn    outa,0-0                ' Select device
:ScanMask               test    Preamble+0,FlashMask wz ' sD & m == 0?
                 if_z   shr     FlashMask,#8            '  m >>= 8, m == 0?
                 if_z   tjnz    FlashMask,#:ScanMask
                        and     FlashMask,MSBMask       ' m &= $80808080
                        tjz     FlashMask,#:SkipImm     ' Skip if nothing
:SendImm                test    Preamble+0,FlashMask wz ' Output bit to be sent
                        muxnz   outa,DIOMask
                        or      outa,ClkMask            ' Toggle clock
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:SendImm     ' Continue to lsb
:SkipImm                test    Preamble+1,CmdMask   wc ' If byte count < 0
                if_nc   jmp     #SkipSend               '  then transmit data
                        neg     Preamble+1,Preamble+1   ' Make transmit count
SendData                mov     FlashMask,#$80          '  positive
                        rdbyte  FlashTemp,Preamble+2    ' Get the data byte and
                        add     Preamble+2,#1           '  increment address
:BitLoop                test    FlashTemp,FlashMask  wz ' Output bit to be sent
                        muxnz   outa,DIOMask
                        or      outa,ClkMask            ' Toggle clock
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:BitLoop     ' Continue to lsb
                        djnz    Preamble+1,#SendData    ' Continue to next byte
SkipSend                andn    dira,DIOMask            ' Don't need DIO now
                        tjz     Preamble+1,#SkipRecv    ' Skip if count == 0
RecvByte                mov     FlashMask,#$80
:BitLoop                or      outa,ClkMask            ' Toggle clock
                        test    DOMask,ina           wz ' Test input bit
                        muxnz   FlashTemp,FlashMask     ' Copy to result byte
                        andn    outa,ClkMask
                        shr     FlashMask,#1            ' Advance bit mask
                        tjnz    FlashMask,#:BitLoop     ' Continue to lsb
                        wrbyte  FlashTemp,Preamble+2    ' Store the data byte
                        add     Preamble+2,#1           ' Increment address
                        djnz    Preamble+1,#RecvByte    ' Continue to next byte
SkipRecv                or      outa,0-0                ' Deselect device
                        mov     FlashTemp,PAR           ' Force invalid device #
                        add     FlashTemp,#8            '  to notify sendRecv
                        andn    dira,DiraMask           ' Turn off all outputs
                        wrbyte  WordMask,FlashTemp      '  after /CS high >100ns
                        jmp     #EntryPoint
                        
CmdMask                 long    $80000000               ' Also used for long sign
MSBMask                 long    $80808080               ' MSB mask for reading
WordMask                long    $FFFF
WordSign                long    $FFFF0000               ' For extending word sign
StartROM                long    $8000                   ' Also used for word sign
DiraMask                long    0                       ' DIO, Clk, CS all outputs
OutaMask                long    0                       ' DIO, Clk, selected CS
DOMask                  long    0                       ' DO from flash
DIOMask                 long    0                       ' DIO to flash
ClkMask                 long    0                       ' Clock to flash
CSsramMask              long    0                       ' CS to SRAM  - Dev #0
CSflshMask              long    0                       ' CS to flash - Dev #1

FlashTemp               res     1
FlashMask               res     1

Preamble                res     4
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