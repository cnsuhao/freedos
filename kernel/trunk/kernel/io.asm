;
; File:
;                             io.asm
; Description:
;                       DOS-C I/O Subsystem
;
;                       Copyright (c) 1998
;                       Pasquale J. Villani
;                       All Rights Reserved
;
; This file is part of DOS-C.
;
; DOS-C is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version
; 2, or (at your option) any later version.
;
; DOS-C is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
; the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public
; License along with DOS-C; see the file COPYING.  If not,
; write to the Free Software Foundation, 675 Mass Ave,
; Cambridge, MA 02139, USA.
;
; $Header$
;
; $Log$
; Revision 1.5  2000/06/01 06:37:38  jimtabor
; Read History for Changes
;
; Revision 1.4  2000/05/26 19:25:19  jimtabor
; Read History file for Change info
;
; Revision 1.3  2000/05/25 20:56:21  jimtabor
; Fixed project history
;
; Revision 1.2  2000/05/08 04:30:00  jimtabor
; Update CVS to 2020
;
; Revision 1.1.1.1  2000/05/06 19:34:53  jhall1
; The FreeDOS Kernel.  A DOS kernel that aims to be 100% compatible with
; MS-DOS.  Distributed under the GNU GPL.
;
; Revision 1.3  2000/03/09 06:07:11  kernel
; 2017f updates by James Tabor
;
; Revision 1.2  1999/08/10 17:57:12  jprice
; ror4 2011-02 patch
;
; Revision 1.1.1.1  1999/03/29 15:41:07  jprice
; New version without IPL.SYS
;
; Revision 1.1  1999/02/08 05:55:57  jprice
; Added Pat's 1937 kernel patches
;
; $EndLog$
;

                %include "segs.inc"

                extern   ConTable:wrt TGROUP
                extern   LptTable:wrt TGROUP
                extern   ComTable:wrt TGROUP
                extern   uPrtNo:wrt TGROUP
                extern   CommonNdRdExit:wrt TGROUP
                extern   _NumFloppies:wrt DGROUP
                extern   blk_stk_top:wrt DGROUP
                extern   clk_stk_top:wrt DGROUP
                extern   _blk_driver:wrt TGROUP
                extern   _clk_driver:wrt TGROUP

;---------------------------------------------------
;
; Device entry points
;
; This really should be a struct and go into a request.inc file
;
cmdlen  equ     0                       ; Length of this command
unit    equ     1                       ; Subunit Specified
cmd     equ     2                       ; Command Code
status  equ     3                       ; Status
media   equ     13                      ; Media Descriptor
trans   equ     14                      ; Transfer Address
count   equ     18                      ; Count of blocks or characters
start   equ     20                      ; First block to transfer
vid     equ     22                      ; Volume id pointer
huge    equ     26                      ; First block (32-bit) to transfer

;
; The following is the "array" of device driver headers for the internal
; devices.  There is one header per device including special aux: and prn: 
; pseudo devices.  These psuedo devices are necessary for printer 
; redirection, i.e., serial or parallel ports, and com port aux selection.
;
; The devices are linked into each other and terminate with a -1 next 
; pointer.  This saves some time on boot up and also allows us to throw all
; device initialization into a single io_init function that may be placed 
; into a discardable code segmemnt.
;
segment	_IO_FIXED_DATA

                ;
                ; The "CON" device
                ;
                ; This device is the standard console device used by
                ; DOS-C and kernel
                ;
                global  _con_dev
_con_dev        equ     $
                dw      _prn_dev,TGROUP
                dw      8013h           ; con device (stdin & stdout)
                dw      GenStrategy
                dw      ConIntr
                db      'CON     '

                ;
                ; Generic prn device that can be redirected via mode
                ;
                global  _prn_dev
_prn_dev        dw      _aux_dev,TGROUP
                dw      0A040h
                dw      GenStrategy
                dw      PrnIntr
                db      'PRN     '

                ;
                ; Generic aux device that can be redirected via mode
                ;
                global  _aux_dev
_aux_dev        dw      _Lpt1Dev,TGROUP
                dw      8000h
                dw      GenStrategy
                dw      AuxIntr
                db      'AUX     '

                ;
                ; Printer device drivers
                ;
_Lpt1Dev        dw      _Lpt2Dev,TGROUP
                dw      0A040h
                dw      GenStrategy
                dw      Lpt1Intr
                db      'LPT1    '
_Lpt2Dev        dw      _Lpt3Dev,TGROUP
                dw      0A040h
                dw      GenStrategy
                dw      Lpt2Intr
                db      'LPT2    '
_Lpt3Dev        dw      _Com1Dev,TGROUP
                dw      0A040h
                dw      GenStrategy
                dw      Lpt3Intr
                db      'LPT3    '

                ;
                ; Com device drivers
                ;
_Com1Dev        dw      _Com2Dev,TGROUP
                dw      8000h
                dw      GenStrategy
                dw      AuxIntr
                db      'COM1    '
_Com2Dev        dw      _Com3Dev,TGROUP
                dw      8000h
                dw      GenStrategy
                dw      Com2Intr
                db      'COM2    '
_Com3Dev        dw      _Com4Dev,TGROUP
                dw      8000h
                dw      GenStrategy
                dw      Com3Intr
                db      'COM3    '
_Com4Dev        dw      _clk_dev,TGROUP
                dw      8000h
                dw      GenStrategy
                dw      Com4Intr
                db      'COM4    '

                ;
                ; Header for clock device
                ;
                global  _clk_dev
_clk_dev        equ     $
                dw      _blk_dev,TGROUP
                dw      8004h           ; clock device
                dw      GenStrategy
                dw      clk_entry
                db      'CLOCK$  '

                ;
                ; Header for device
                ;
                global  _blk_dev
_blk_dev        equ     $
                dd      -1
                dw      08c2h           ; block device with ioctl
                dw      GenStrategy
                dw      blk_entry
                global  _nblk_rel
_nblk_rel       db      4
                db      0,0,0,0,0,0,0


;
; Temporary table until next release
;
segment	_IO_FIXED_DATA
DiskTable       db      0


;
; Local storage
;

segment	_BSS
blk_dos_stk	resw	1
blk_dos_seg	resw	1
clk_dos_stk	resw	1
clk_dos_seg	resw	1

segment	_IO_TEXT

		global	_ReqPktPtr
_ReqPktPtr	dd	0
uUnitNumber	dw	0

;
; Name:
;       GenStrategy
;
; Function:
;       Store the pointer to the request packet passed in es:bx
;
; Description:
;       Generic strategy routine.  Unlike the original multitasking versions, 
;       this version assumes that no more thank one device driver is active
;       at any time.  The request is stored into memory in the one and only
;       location available for that purpose.
;
GenStrategy:
                mov     word [cs:_ReqPktPtr],bx
                mov     word [cs:_ReqPktPtr+2],es
                retf


;
; Name:
;       XXXXIntr
;
; Function:
;       Individual Interrupt routines for each device driver
;
; Description:
;       This is actually a single routine with entry points for each device. 
;       The name used for the entry point is the device name with Intr 
;       appended to it.
;
;       Funtionally, each device driver has an entry and an associated 
;       table.  The table is a structure that consists of a control byte 
;       followed by an array of pointers to C functions or assembly 
;       subroutines that implement the individual device driver functions.  
;       This allows the usage of common error dummy filler code to be used.  
;       It also allows standardization of the calling procedure for these 
;       internal device driver functions.
;
;       Assembler call/return convention:
;       Each driver function is entered by a jump into the function and 
;       exits by a jump to the appropriate success or error exit routine.  
;       This speeds up the call and return and helps to minimize the stack 
;       useage.  The contents of the request packet are passed to each 
;       routine in registers as follows:
;
;             Register  Function                Description
;             --------  --------                -----------
;               al      unit                    Subunit Specified
;               ah      media                   Media Descriptor
;               cx      count                   Count of blocks or characters
;               dx      start                   First block to transfer
;               es:di   trans                   Transfer Address
;               ds:bx   reqptr                  Request pointer
;               cs      kernel code segment
;               ds      kernel data segment
;
;       The exit routines generally set the status based on the individual 
;       routine.  For example, _IOSuccess will clear the count where 
;       _IOErrCnt will subtract the remaining amount in cx from the original 
;       count.  See each utility routine for expectations.
;
;       C call/return convention:
;       The C calling convention simply sets up the C stack and passes the
;       request packet pointer as a far pointer to the function.  Although 
;       the utility routine names are such that they are accesible from the 
;       C name space, they are cannot used.  Instead, the common interrupt 
;       code expects a return status to set in the request packet.  It is up 
;       to the device driver function to set the appropriate fields such as 
;       count when an error occurs.
;
;       How to differntiate between the two calling conventions:
;       This code is entirely table driven.  The table is a structure that 
;       is generally in the _IO_FIXED_DATA segment.  It consists of a flag 
;       byte followed by short pointers to the driver functions.  Selecting 
;       a driver type is accomplished by setting the type bit in the flag 
;       (see below).
;
;         7   6   5   4   3   2   1   0
;       +---+---+---+---+---+---+---+---+
;       |   |   |   |   |   |   |   |   |
;       +---+---+---+---+---+---+---+---+
;         | |       |                   |---    Number of table entries
;         | |       +-------------------+
;         | |       |-----------------------    Reserved
;         | +-------+
;         +---------------------------------    type bit (1 == C / 0 == asm)
;
ConIntr:
                push    si
                mov     si,ConTable
                jmp     short CharIntrEntry

PrnIntr:
                push    si
                push    ax
                xor     ax,ax
                jmp     short LptCmnIntr

Lpt1Intr:
                push    si
                push    ax
                xor     al,al
                mov     ah,1
                jmp     short LptCmnIntr

Lpt2Intr:
                push    si
                push    ax
                mov     al,1
                mov     ah,2
                jmp     short LptCmnIntr

Lpt3Intr:
                push    si
                push    ax
                mov     al,2
                mov     ah,3

LptCmnIntr:
                mov     si,LptTable
                mov     [cs:uPrtNo],ah
                jmp     short DiskIntrEntry


AuxIntr:
                push    si
                push    ax
                xor     al,al
                jmp     short ComCmnIntr

Com2Intr:
                push    si
                push    ax
                mov     al,1
                jmp     short ComCmnIntr

Com3Intr:
                push    si
                push    ax
                mov     al,2
                jmp     short ComCmnIntr

Com4Intr:
                push    si
                push    ax
                mov     al,3
                jmp     short ComCmnIntr

ComCmnIntr:
                mov     si,ComTable
                jmp     short DiskIntrEntry


DskIntr:
                push    si
                mov     si,DiskTable
CharIntrEntry:
                push    ax
DiskIntrEntry:
                push    cx
                push    dx
                push    di
                push    bp
                push    ds
                push    es
                push    bx
                mov     byte [cs:uUnitNumber],al
                lds     bx,[cs:_ReqPktPtr]
                test    byte [cs:si],80h
                je      AsmType

                mov     al,[bx+cmd]
                cmp     al,[cs:si]
                ja      _IOCommandError
                cbw
                shl     ax,1
                add     si,ax
                xchg    di,ax

                push    ds
                push    bx
                mov     bp,sp
                mov     ax,DGROUP
                mov     ds,ax
                cld
                call    word [cs:si+1]
                pop     cx
                pop     cx
                jmp     short StoreStatus

AsmType:        mov     al,[bx+unit]
                mov     ah,[bx+media]
                mov     cx,[bx+count]
                mov     dx,[bx+start]
                xchg    di,ax
                mov     al,[bx+cmd]
                cmp     al,[cs:si]
                ja      _IOCommandError
                cbw
                shl     ax,1
                add     si,ax
                xchg    di,ax

                les     di,[bx+trans]
                push    ax
                mov     ax,DGROUP
                mov     ds,ax
                pop     ax
                cld
                jmp     word [cs:si+1]

;
; Name:
;       _IOXXXXXXX
;
; Function:
;       Exit routines for internal device drivers.
;
; Description:
;       These routines are the exit for internal device drivers.  _IOSuccess 
;       is for read/write functions and correctly returns for a successful 
;       read/write operation by setting the remainng count to zero.  _IOExit 
;       simply sets success bit and returns.  _IODone returns complete and 
;       busy status.  _IOCommandError returns and error status for invalid 
;       commands.  _IOErrCnt corrects the remaining bytes for errors that 
;       occurred during partial read/write operation.  _IOErrorExit is a 
;       generic error exit that sets done and error.
;
                global  _IOSuccess
_IOSuccess:
                lds     bx,[cs:_ReqPktPtr]
                xor     ax,ax
                mov     [bx+count],ax

                global  _IOExit
_IOExit:
                mov     ah,1

StoreStatus:
                lds     bx,[cs:_ReqPktPtr]
                mov     [bx+status],ax
                pop     bx
                pop     es
                pop     ds
                pop     bp
                pop     di
                pop     dx
                pop     cx
                pop     ax
                pop     si
                retf


                global  _IODone
_IODone:
                mov     ah,3
                jmp     short StoreStatus

                global  _IOCommandError
_IOCommandError:
                mov     al,3

                global  _IOErrCnt
_IOErrCnt: 
                lds     bx,[cs:_ReqPktPtr]
                sub     [bx+count],cx
                global  _IOErrorExit
_IOErrorExit:
                mov     ah,81h
                jmp     short StoreStatus

;
; Name:
;       GetUnitNum
;
; Function:
;       Return the internally set unit number.
;
; Description:
;       Simply return the contents of uUnitNumber.  This version relies on 
;       no segment registers and makes a safe call regardless of driver 
;       state.
;
                global  GetUnitNum
GetUnitNum:
                mov     dx,[cs:uUnitNumber]
                ret

                ;
                ; These are still old style DOS-C drivers.  I'll replace 
                ; them in the next release
                ;


                ;
                ; block device interrupt
                ;
                ; NOTE: This code is not standard device driver handlers
                ; It is written for sperate code and data space.
                ;
blk_entry:
                pushf
                push    ax
                push    bx
                push    cx
                push    dx
                push    bp
                push    si
                push    di
                push    ds
                push    es

                ; small model
                mov     ax,DGROUP                       ; correct for segments
                mov     ds,ax                           ; ax to carry segment
                mov     word [blk_dos_stk],sp		; use internal stack
                mov     word [blk_dos_seg],ss
                pushf                                   ; put flags in bx
                pop     bx
                cli                                     ; no interrupts
                mov     ss,ax
                mov     sp,blk_stk_top
                push    bx
                popf                                    ; restore interrupt flag
                mov     bp,sp                           ; make a c frame
                push    word [cs:_ReqPktPtr+2]
                push    word [cs:_ReqPktPtr]
                call    _blk_driver
                pop     cx
                pop     cx
                les     bx,[cs:_ReqPktPtr]		; now return completion code
                mov     word [es:bx+status],ax		; mark operation complete
                cli                                     ; no interrupts
                mov     sp,[blk_dos_stk]		; use dos stack
                mov     ss,[blk_dos_seg]
                pop     es
                pop     ds
                pop     di
                pop     si
                pop     bp
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                popf
                retf



                ;
                ; clock device interrupt
                ;
                ; NOTE: This code is not standard device driver handlers
                ; It is written for sperate code and data space.
                ;
clk_entry:
                pushf
                push    ax
                push    bx
                push    cx
                push    dx
                push    bp
                push    si
                push    di
                push    ds
                push    es

                ; small model
                mov     ax,DGROUP                       ; correct for segments
                mov     ds,ax                           ; ax to carry segment
                mov     word [clk_dos_stk],sp		; use internal stack
                mov     word [clk_dos_seg],ss
                pushf                                   ; put flags in bx
                pop     bx
                cli                                     ; no interrupts
                mov     ss,ax
                mov     sp,clk_stk_top
                push    bx
                popf                                    ; restore interrupt flag
                mov     bp,sp                           ; make a c frame
                push    word [cs:_ReqPktPtr+2]
                push    word [cs:_ReqPktPtr]
                call    _clk_driver
                pop     cx
                pop     cx
                les     bx,[cs:_ReqPktPtr]		; now return completion code
                mov     word [es:bx+status],ax		; mark operation complete
                cli                                     ; no interrupts
                mov     sp,[clk_dos_stk]		; use dos stack
                mov     ss,[clk_dos_seg]
                pop     es
                pop     ds
                pop     di
                pop     si
                pop     bp
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                popf
                retf

