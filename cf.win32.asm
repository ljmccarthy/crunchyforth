%define WIN32
%define vbase 0x10000  ; default is normally 0x400000, must be 64K aligned
use32
org 0x10E00

%include "context.asm"

%define imgtop           0x11000
%define source_blks      (imgtop+0x1000)
%define bss              (vbase+0x5000)  ; start of '.bss' (not really bss)
%define words_names_dst  (bss+0x0000)    ; 16K
%define macro_names_dst  (bss+0x4000)    ; 16K
%define words_addrs_dst  (bss+0x8000)    ; 4K
%define macro_addrs_dst  (bss+0x9000)    ; 4K
%define code_heap        (bss+0xA000)    ; 256 KiB ought to be enough for anyone

mzhdr:
        incbin "mzstub.bin"  ; DOS MZ stub
pehdr:
        db "PE",0,0            ; PE signature
        dw 0x14C               ; Machine = 386
        dw 1                   ; NumberOfSections
        dd 0                   ; TimeDateStamp
        dd 0                   ; PointerToSymbolTable
        dd 0                   ; NumberOfSymbols
        dw sectiontbl-coffhdr  ; SizeOfOptionalHeader (required for EXEs)
        dw 0x818E              ; Characteristics
coffhdr:
        dw 0x10B   ; Magic = PE32
        db 1,0x30  ; Major,Minor LinkerVersion
        dd 0       ; SizeOfCode
        dd 0       ; SizeOfInitialisedData
        dd 0       ; SizeOfUninitialisedData
        dd 0x1000  ; AddressOfEntryPoint
        dd 0       ; BaseOfCode
        dd 0       ; BaseOfData
winnthdr:
        dd 0x10000            ; ImageBase
        dd 0x1000             ; SectionAlignment
        dd 0x200              ; FileAlignment
        dw 4,0                ; Major,Minor OperatingSystemVersion
        dw 0,0                ; Major,Minor ImageVersion
        dw 4,0                ; Major,Minor SubsystemVersion
        dd 0                  ; Reserved
        dd (312*1024)+0x1000  ; SizeOfImage
        dd 0x200              ; SizeOfHeaders
        dd 0                  ; CheckSum
        dw 2                  ; Subsystem = WINDOWS_GUI
        dw 0                  ; DLLCharacteristics
        dd 0x1000             ; SizeOfStackReserve
        dd 0x1000             ; SizeOfStackCommit
        dd 0                  ; SizeOfHeapReserve
        dd 0                  ; SizeOfHeapCommit
        dd 0                  ; LoaderFlags
        dd 16                 ; NumberOfRvaAndSizes
        dd 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; Lots of unused tables
        dd 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
sectiontbl:
        db "gtForth!"    ; Name
        dd 312*1024      ; VirtualSize
        dd 0x1000        ; VirtualAddress
        dd imgend-start  ; SizeOfRawData
        dd 0x200         ; PointerToRawData
        dd 0             ; PointerToRelocations
        dd 0             ; PointerToLinenumbers
        dw 0             ; NumberOfRelocations
        dw 0             ; NumberOfLinenumbers
        dd 0xE00000E0    ; Characteristics
;        db "Imports!"
;        dd 0x1000
;        dd 0x1000  ; change to better address
;        dd 0       ; size not known yet
;        dd 0       ; neither pointer!
;        dd 0
;        dd 0
;        dw 0
;        dw 0
;        dd 0x40000040

_AllocConsole:
_SetConsoleTitleA:
_LoadLibraryA:
_GetProcAddress:

align 0x200, db 0

start:
;        call _AllocConsole
;        push title
;        call _SetConsoleTitleA

        lea esi, [esp-1024]
        mov ebp, esi
        mov [ebp+ctx.rbase], esp
        mov [ebp+ctx.sbase], esi
        jmp bootstrap

title:  db "CrunchyForth Win32 Luke McCarthy June 2004",0

%include "kernel.asm"

align 0x200, db 0
imgend:
imgsize equ $ - $$
