%define NATIVE
org 0xe00

%define imgtop           0x00e00
%define source_blks      0x02000
%define words_names_dst  0x10000
%define macro_names_dst  0x14000
%define words_addrs_dst  0x18000
%define macro_addrs_dst  0x19000
%define code_heap        0x20000
%define signature 'CFTH'

%include "context.asm"
%include "boot.asm"
%include "kernel.asm"

imgend:
imgsize equ $ - $$
