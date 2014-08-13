%define LINUX
%define vbase 0  ; virtual base address
                 ; default is normally 0x8048000
use32
org 0

%include "context.asm"

%define imgtop           vbase
%define source_blks      vbase+0x1000
%define bss              vbase+0x4000  ; start of '.bss' (not really bss)
%define words_names_dst  bss+0x0000    ; 16K
%define macro_names_dst  bss+0x4000    ; 16K
%define words_addrs_dst  bss+0x8000    ; 4K
%define macro_addrs_dst  bss+0x9000    ; 4K
%define code_heap        bss+0xA000    ; 256 KiB ought to be enough for anyone

; ELF header
ehdr:
        db 0x7f, "ELF", 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0  ; ident
        dw 2                 ; type    = executable
        dw 3                 ; machine = x86
        dd 1                 ; version
        dd start             ; entry
        dd phdr - $$         ; phoff  offset to program header table
        dd 0                 ; shoff  offset to section header table
        dd 0                 ; flags
        dw ehdr.end - ehdr   ; ehsize     size of main header
        dw phdr.end - phdr   ; phentsize  size of a program header entry
        dw 1                 ; phnum      number of program header entries
        dw 0                 ; shentsize  size of a section header entry
        dw 0                 ; shnum      number of section header entries
        dw 0                 ; shstrndx   index of string table entry
.end:

phdr:
        dd 1                   ; type
        dd 0                   ; offset
        dd 0                   ; vaddr   virtual address
        dd 0                   ; paddr   physical address
        dd imgsize             ; filesz  file size
        dd 312*1024            ; memsz   memory size = 16K image, 296K bss
        dd 7                   ; flags = read, write, exec
        dd 0x1000              ; align
.end:

start:
        lea esi, [esp-1024]
        mov ebp, esi
        mov [ebp+ctx.rbase], esp
        mov [ebp+ctx.sbase], esi
        jmp bootstrap

%include "kernel.asm"

imgend:
imgsize equ $ - $$
