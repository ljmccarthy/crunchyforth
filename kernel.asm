;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   CrunchyForth Kernel                                                        ;
;   (c) 2004 Luke McCarthy                                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


use32

%ifdef NATIVE
gdtr:
        dw 0x0017
        dd gdtr
        dw 0x0000
        dw 0xffff, 0x0000, 0x9a00, 0x00cf  ; code segment
        dw 0xffff, 0x0000, 0x9200, 0x00cf  ; data segment
%endif


; register usage:
;
; eax  top of stack
; esi  next on stack pointer
; edx  address register
; esp  return stack pointer
; ebx  temporary
; ecx  temporary
; edi  temporary, strings
; ebp  compiler context pointer


%macro drop 0
        lodsd
%endmacro


%macro dup 0
        lea esi, [esi-4]
        mov [esi], eax
%endmacro


%macro dpush 1
        dup
        mov eax, %1
%endmacro


%macro dpop 1
        mov %1, eax
        drop
%endmacro


%macro nip 0
        lea esi, [esi+4]
%endmacro


%macro twodup 0
        mov ecx, [esi]
        lea esi, [esi-8]
        mov [esi+4], eax
        mov [esi], ecx
%endmacro


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   Compiler                                                                   ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


here:
        dpush [ebp+ctx.hp]
        ret
herestore:
        dpop [ebp+ctx.hp]
        ret
there:
        dup
        sub eax, [ebp+ctx.hp]
        neg eax
        ret

; optimising dup and drop

qdrop:
        dpush 1
        call optimiser
        lea ecx, [ebp+ctx.hp]
        mov ebx, [ecx]
        cmp byte [ebx-1], 0xad
        jne .false
        dec dword [ecx]  ; T
        ret
.false:
        xor ecx, ecx  ; F
        ret
cdrop:
        call optimisable
        dup
        mov al, 0xad
        jmp comma1
sdup:
        call qdrop
        jz cdup0
        ret
cdup0:
        dpush 0xfc768d  ; lea esi, [esi-4]
        call comma3
        dup
        mov ax, 0x0689  ; mov [esi], eax
        jmp comma2
cdup:
        call qdrop
        jz cdup0
        dup
        mov ax, 0x068b  ; mov eax, [esi]
        jmp comma2
litcomma:
        call optimisable
        call cdup0
        dup
        mov al, 0xb8    ; mov eax, n
        call comma1
; falls into comma


comma:
        mov cl, 4
xcomma0:
        movzx ecx, cl
xcomma1:
        mov edi, [ebp+ctx.hp]
        mov [edi], eax
        add [ebp+ctx.hp], ecx
        drop
        ret
comma1:
        mov cl, 1
        jmp xcomma0
comma2:
        mov cl, 2
        jmp xcomma0
comma3:
        mov cl, 3
        jmp xcomma0
allot:
        mov ecx, eax
        jmp xcomma1


alignw:
        mov ecx, eax
        mov eax, [ebp+ctx.hp]
        xor edx, edx
        div ecx
        test edx, edx
        jz .done
        sub ecx, edx
        add [ebp+ctx.hp], ecx
.done:
        drop
        ret

addrcomma:
        jmp comma  ; TODO: implement ORG

callcomma:
        call optimisable
        dup
        mov al, 0xe8
        call comma1
        sub eax, [ebp+ctx.hp]
        lea eax, [eax-4]
        jmp addrcomma

resolve:
        call there
        dec eax
        mov ebx, [esi]
        mov [ebx], al
        nip
        drop
        ret

optimiser:
        sub eax, [ebp+ctx.hp]
        neg eax
        cmp eax, [ebp+ctx.lops]  ; last optimisable instruction
        drop
        je .yes
        lea esp, [esp+4]  ; exit from optimising macro
        xor ecx, ecx
        ret
.yes:   or ecx, byte 1
        ret

optimisable:
        mov ecx, [ebp+ctx.hp]
        mov [ebp+ctx.lops], ecx
        ret

branches:
        mov dword [ebp+ctx.lops], 0
        ret

qlit:
        dpush 10
        call optimiser
        lea ecx, [ebp+ctx.hp]
        mov ebx, [ecx]
        cmp dword [ebx-8], 0xb80689fc   ; 8d 76 fc         lea esi, [esi-4]
        jne .false                      ; 89 06            mov [esi], eax
        cmp word [ebx-10], 0x768d       ; b8 nn nn nn nn   mov eax, n
        jne .false
        dpush [ebx-4]
        sub dword [ecx], byte 10  ; T
        ret
.false:
        xor ecx, ecx  ; F
        ret

semi:
        mov dword [ebp+ctx.mode], inext
semisemi:
        mov edx, [ebp+ctx.lops]
        mov dword [ebp+ctx.lops], 0
        push branches         ; call later ;-)
        mov ecx, [ebp+ctx.hp]
        lea ecx, [ecx-5]
        dup
        mov al, 0xc3
        cmp ecx, edx          ; last optimisable = hp - 5?
        jne comma1
        cmp byte [ecx], 0xe8  ; call opcode?
        jne comma1
        drop
        mov byte [ecx], 0xe9  ; convert to jmp opcode
        ret

definew:
        ; ( Na A Dp -- )
        dpop edi
        dpop edx
define:
        ; edi=dp eax=name edx=address drops stack
        mov ecx, [edi]
        cmp dword ecx, [edi+12] ; count >= max?
        jae .full
        inc dword [edi]
        mov ebx, [edi+4]        ; names
        mov [ebx+ecx*4], eax
        mov ebx, [edi+8]        ; addresses
        mov [ebx+ecx*4], edx
        drop
        ret
.full:
        drop
        mov dword [ebp+ctx.ierr], IERR_FULL
        ret
colon:
        mov dword [ebp+ctx.mode], cnext
        call branches
        call token
        call name
        mov edx, [ebp+ctx.hp]
        mov edi, [ebp+ctx.dp]
        jmp define
variable:
        call token
        call name
        dup
        mov edx, [ebp+ctx.hp]
        mov edi, [ebp+ctx.wp]
        call define
        dpush dovar_word
        call callcomma
        mov edx, [ebp+ctx.hp]
        mov edi, [ebp+ctx.mp]
        call define
        dpush dovar_macro
        jmp callcomma


dovar_word:
        dup
        pop eax
        lea eax, [eax+5]
        ret

dovar_macro:
        dup
        pop eax
        jmp litcomma

hide:
        ; todo

; postponing
callcommacomma:
        call litcomma
        dpush callcomma
        jmp callcomma

litcommacomma:
        call litcomma
        dpush litcomma
        jmp callcomma


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   Scanner                                                                    ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


scanw:
        mov ecx, [esi]
        mov edi, [esi+4]
        add ecx, edi
        mov [esi], ecx
        dup
.next:
        cmp edi, ecx
        jae .done
        movzx eax, byte [edi]
        inc edi
        mov [esi+8], edi
        call [esi]
        mov ecx, [esi+4]
        mov edi, [esi+8]
        jnz .next
.done:
        sub [esi+4], edi
        drop
        drop
        ret


instore:
        mov ecx, [esi]
        mov [ebp+ctx.input], ecx
        add ecx, eax
        mov [ebp+ctx.inmax], ecx
        drop
        drop
        ret

infetch:
        dup
        mov ecx, [ebp+ctx.input]
        lea esi, [esi-4]
        mov [esi], ecx
        mov eax, [ebp+ctx.inmax]
        sub eax, ecx
        ret

convchar:
        cmp cl, '!'
        jae .L1
        xor cl, cl
        ret
.L1:
        cmp cl, 0x7f
        jb .L2
        xor cl, cl
.L2:
        ret

scantobl:
        mov byte [scans.j], 0x75  ; JNZ opcode
scans:
        lea edx, [ebp+ctx.input]
        mov edi, [edx]
        mov ebx, [ebp+ctx.inmax]
        jmp .start
.next:
        inc edi
.start:
        cmp edi, ebx
        jae .eois
        mov cl, [edi]
        call convchar
        test cl, cl
.j:     jz .next
.done:
        mov [edx], edi
        ret
.eois:
        mov [edx], edi
        mov dword [ebp+ctx.ierr], IERR_EOIS
        ret
scantogf:
        mov byte [scans.j], 0x74  ; JZ opcode
        jmp scans

scan:
        lea ebx, [ebp+ctx.input]
        mov edi, [ebx]
.next:  mov cl, [edi]
        inc edi
        cmp al, cl
        jne .next
        mov [ebx], edi
        drop
        ret

parse:
        call scantogf
        push dword [ebp+ctx.input]
        call scan
        dup
        pop eax
        dup
        sub eax, [ebp+ctx.input]
        neg eax
        dec eax
        ret

oparen:
        dup
        mov al, ')'
        jmp scan
backslash:
        dup
        mov al, 0x0a
        jmp scan

char:
        call scantogf
        dup
        lea ebx, [ebp+ctx.input]
        mov eax, [ebx]
        movzx eax, byte [eax]
        inc dword [ebx]
        ret

token:
        call scantogf
        dpush [ebp+ctx.input]
        call scantobl
        dup
        sub eax, [ebp+ctx.input]
        neg eax
        ret

; short name (4 chars) from token:
; first and last two chars for count >= 4
; else full name padded with zeros
name:
        cmp eax, 4
        jae name0
; create mask
        lea eax, [eax*8]
        mov ecx, eax
        mov eax, -1
        shl eax, cl
        not eax
; fetch chars and apply mask
        mov ecx, [esi]
        and eax, [ecx]
        nip
        ret
name0:
        dpop ecx
        mov ebx, eax
; first two chars
        mov eax, [eax]
        and eax, 0xffff
; second two chars
        mov ecx, [ebx+ecx-2]
        shl ecx, 16
        or eax, ecx
        ret

tick:
        push wfind
tick0:
        call token
        jmp name
mtick:
        push mfind
        jmp tick0
tickm:
        call tick
        jmp litcomma


nextchar:
        test ecx, ecx
        jz .empty
        movzx edx, byte [edi]
        dec ecx
        inc edi
.empty:
        ret
digit:
        cmp dl, '0'     ; 0-9
        jb .no
        cmp dl, '9'
        jbe .number
        cmp dl, 'A'     ; A-Z
        jb .no
        cmp dl, 'Z'
        jbe .ualpha
        cmp dl, 'a'     ; a-z
        jb .no
        cmp dl, 'z'
        ja .no
.lalpha:
        sub dl, 'a'-10
        ret
.ualpha:
        sub dl, 'A'-10
        ret
.number:
        sub dl, '0'
        ret
.no:
        lea esp, [esp+4]
        mov dword [ebp+ctx.ierr], IERR_NAN
        ret
number:
        mov ecx, eax
        mov edi, [esi]
        nip
        xor eax, eax      ; clear accumulator
.prefix:
        call nextchar
        jz .nan           ; zero-length string!
        cmp edx, '$'
        je .hex
        cmp edx, '%'
        je .bin
.dec:
        mov ebx, 10
        jmp .next1
.bin:
        mov ebx, 2
        jmp .convert
.hex:
        mov ebx, 16
.convert:
        test ecx, ecx
        jz .nan           ; no digits!
.next:
        call nextchar
        jz .done
.next1:
        call digit
        cmp edx, ebx   ; digit too high for base?
        jae .nan
        push edx
        mul ebx
        pop edx
        add eax, edx
        jmp .next
.done:
        ret
.nan:
        mov dword [ebp+ctx.ierr], IERR_NAN
        ret


chil:
        call [ebp+ctx.mode]
        cmp dword [ebp+ctx.ierr], IERR_OK
        je chil
.done:
;        mov byte [0xb8000], '!'
        ret


eval:
        push dword [ebp+ctx.input]
        push dword [ebp+ctx.inmax]
        push dword [ebp+ctx.mode]
        mov ecx, [esi]
        mov [ebp+ctx.input], ecx
        add ecx, eax
        mov [ebp+ctx.inmax], ecx
        drop
        call chil
        mov eax, [ebp+ctx.ierr]
        mov dword [ebp+ctx.ierr], IERR_OK
        pop dword [ebp+ctx.mode]
        pop dword [ebp+ctx.inmax]
        pop dword [ebp+ctx.input]
        ret


load:
        shl eax, 10
        add eax, source_blks
        dup
        mov eax, 1024
        call eval
        drop
        ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   Interpreter                                                                ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


execute:
        dpop ecx
        jmp ecx


wfind:
        mov edx, [ebp+ctx.wp]
finds0:
        mov ecx, [edx]    ; count
        mov edi, [edx+4]  ; names
        mov ebx, [edx+8]  ; addresses
        lea edi, [-4+edi+ecx*4]
finds1:
        std
        repne scasd
        cld
        jne .nf
        mov eax, [ebx+ecx*4]
        or ecx, byte 1  ; nz
        ret
.nf:    xor ecx, ecx  ; z
        ret
mfind:
        mov edx, [ebp+ctx.mp]
        jmp finds0
find:
        mov edx, eax
        drop
        jmp finds0



_find:
        ; edi=dp eax=name
        mov ecx, [edi]    ; count
        mov ebx, [edi+8]  ; addresses
        mov edi, [edi+4]  ; names
        lea edi, [-4+edi+ecx*4]
        std
        repne scasd
        cld
        jne .nf
        or edi, byte 1  ; T
        ret
.nf:
        xor edi, edi  ; F
        ret
findw:
        ; ( Na Dp -- Do Dp )
        push eax
        mov edi, eax
        mov eax, [esi]
        call _find
        pop eax
        mov [esi], ecx
        ret
selectw:
        ; ( Do Dp -- A )
        mov edi, [eax+8]
        mov eax, [esi]
        nip
select:
        ; edi=dp eax=offset
        mov eax, [edi+eax*4]
        ret
wordp:
        dpush [ebp+ctx.wp]
        ret
macrop:
        dpush [ebp+ctx.mp]
        ret

; find and execute word behavior defined by the return table
; word address/number available on the stack
;
; +0 macro
; +4 word
; +8 number

word0:
        call token
        twodup
        call name
        dup
        call mfind
        jnz domac
        drop
        jmp word2
word1:
        call token
        twodup
        call name
word2:
        call wfind
        jnz doword
donum:
        drop
        call number
        pop ecx
        jmp [ecx+8]
domac:
        lea esi, [esi+12]  ; nip nip nip
        pop ecx
        jmp [ecx]
doword:
        lea esi, [esi+8] ; nip nip
        pop ecx
        jmp [ecx+4]

; interpret behaviour
inext:
        call word1
.tbl:   dd 0
        dd execute   ; execute word
        dd continue  ; leave number on stack

; compile behaviour
cnext:
        call word0
.tbl:   dd execute    ; execute macro
        dd callcomma  ; compile call to word
        dd litcomma   ; compile push of number

; postpone behaviour
pnext:
        call word0
.tbl:   dd callcomma       ; compile call to macro
        dd callcommacomma  ; compile code to compile call to word
        dd litcommacomma   ; compile code to compile push of number



imode:  mov dword [ebp+ctx.mode], inext
        ret
cmode:  mov dword [ebp+ctx.mode], cnext
        ret

modestore:
        dpop [ebp+ctx.mode]
        ret
modefetch:
        dpush [ebp+ctx.mode]
        ret

words:
        mov ecx, [ebp+ctx.wp]
        mov [ebp+ctx.dp], ecx
        ret
macros:
        mov ecx, [ebp+ctx.mp]
        mov [ebp+ctx.dp], ecx
continue:
        ret

reset:
        ; reset stack
        mov esp, [ebp+ctx.rbase]
        mov esi, [ebp+ctx.sbase]
        ret

errc:
        dup
        lea eax, [ebp+ctx.ierr]
        ret

bootstrap:
        ; specific ONLY to the bootstrap thread, do not call!
        mov dword [ebp+ctx.mode],  inext
        mov dword [ebp+ctx.hp],    code_heap
        mov dword [ebp+ctx.input], source
        mov dword [ebp+ctx.inmax], source.end
        mov dword [ebp+ctx.mode],  inext
        mov dword [ebp+ctx.lops],  0
        mov dword [ebp+ctx.dp],    wordsdict
        mov dword [ebp+ctx.wp],    wordsdict
        mov dword [ebp+ctx.mp],    macrodict
        mov dword [ebp+ctx.inner], bootil
cold:
        ; words names (16K) 0001 0000 : 0001 3FFF
        ; macro names (16K) 0001 4000 : 0001 7FFF
        ; words addrs (4K)  0001 8000 : 0001 8FFF
        ; macro addrs (4K)  0001 9000 : 0001 9FFF
        cld
        mov esi, words_names
        mov edi, words_names_dst
        mov ecx, (words_names.end - words_names) / 4
        mov ebx, [ebp+ctx.wp]
        mov dword [ebx], ecx
        rep movsd
        mov esi, macro_names
        mov edi, macro_names_dst
        mov ecx, (macro_names.end - macro_names) / 4
        mov ebx, [ebp+ctx.mp]
        mov dword [macrodict], ecx
        rep movsd
        mov esi, words_addrs
        mov edi, words_addrs_dst
        mov ecx, (words_addrs.end - words_addrs) / 4
        rep movsd
        mov esi, macro_addrs
        mov edi, macro_addrs_dst
        mov ecx, (macro_addrs.end - macro_addrs) / 4
        rep movsd
warm:
        ; data stack   (1K) 0000 0800 : 0000 0bff
        ; return stack (1K) 0000 0c00 : 0000 0fff
        mov esp, [ebp+ctx.rbase]
        mov esi, [ebp+ctx.sbase]
        jmp [ebp+ctx.inner]

; --bootstrap interpreter loop--

bootil:
        push bootil
        jmp [ebp+ctx.mode]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   Utilities                                                                  ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


%ifdef LINUX

syscallw:
        ; Linux x86 system call entry for Forth programs
        ; Luke McCarthy 22 April 2004
        ;
        ; (arg1) (arg2) (arg3) (arg4) (arg5) argcount callno -- retno

        mov [call_no], eax      ; save syscall number
        mov eax, [esi]          ; get argument count
        mov [esp_sav], esp      ; save esp
        lea esp, [esi+4]        ; point esp to arguments
        lea esi, [4+esi+eax*4]  ; set esi pointing past arguments
        mov [esi_sav], esi      ; and save it
        neg eax                 ; eax (arg count) is subtracted
        lea ebx, [syscall0+eax] ; from syscall0
        jmp ebx                 ; to find where to jmp into
        pop edi                 ; arg 5
        pop esi                 ; arg 4
        pop edx                 ; arg 3
        pop ecx                 ; arg 2
        pop ebx                 ; arg 1
syscall0:
        mov eax, 0              ; load call number
call_no equ $-4
        int 0x80                ; call linux... return code in eax
        mov esp, 0              ; restore esp
esp_sav equ $-4
        mov esi, 0              ; restore esi
esi_sav equ $-4
        ret                     ; whew!


argv:
        dup
        mov ecx, [ebp+ctx.rbase]
        lea eax, [ecx+4]
        dup
        mov eax, [ecx]
        ret

%endif


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                                                              ;
;   Source                                                                     ;
;                                                                              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; dictionary headers with vital stats:
;
; +00 number of slots left
; +04 pointer to name array
; +08 pointer to address array
; +12 maximum size

wordsdict:
        dd (words_addrs.end - words_addrs) / 4
        dd words_names_dst  ; starts with copy of words_names
        dd words_addrs_dst  ; starts with copy of words_addrs
        dd 1024

macrodict:
        dd (macro_addrs.end - macro_addrs) / 4
        dd macro_names_dst  ; starts with copy of macro_names
        dd macro_addrs_dst  ; starts with copy of macro_addrs
        dd 1024

; --4-char name arrays--
;
; keywords
; words
; macros
;
; these are preserved in low memory with the kernel.
; their copies in higher memory are actually used.
; this allows a 'cold' boot where the system is
; returned to initial state without a hardware reboot.

align 16, db 0

words_names:
        db "cold"
        db "warm"
        db "here"
        db "hee!"
        db "thre"
        db ",",0,0,0
        db "1,",0,0
        db "2,",0,0
        db "3,",0,0
        db "alot"
        db "algn"
        db "adr,"
        db "lit,"
        db "cal,"
        db "dene"
        db ":",0,0,0
        db "vale"
        db "wods"
        db "maos"
        db "?lit"
        db "reve"
        db "bres"
        db "]",0,0,0
        db "scan"
        db "pase"
        db "char"
        db "toen"
        db "name"
        db "'",0,0,0
        db "m'",0,0
        db "exte"
        db "coue"
        db "moe@"
        db "moe!"
        db "?dop"
        db "/dup"
        db "in@",0
        db "in!",0
        db "(",0,0,0
        db "\",0,0,0
        db "find"
        db "sect"
        db "word"
        db "maro"
        db "eval"
        db "load"
        db "err#"
        db "reet"
        db "scnw"
        db "src",0
%ifdef LINUX
        db "syll"
        db "argv"
%endif
%ifdef WIN32
        db "dll",0
        db "sym",0
%endif
.end:

macro_names:
        db ";",0,0,0
        db ";;",0,0
        db "[",0,0,0
        db "pone"
        db "[']",0
        db ":",0,0,0
        db "drop"
        db "dup",0
        db "(",0,0,0
        db "\",0,0,0
        db "err#"
.end:

; --addresses arrays--

words_addrs:
        dd cold         ; cold
        dd warm         ; warm
        dd here         ; here
        dd herestore    ; here!
        dd there        ; there
        dd comma        ; ,
        dd comma1       ; 1,
        dd comma2       ; 2,
        dd comma3       ; 3,
        dd allot        ; allot
        dd alignw       ; align
        dd addrcomma    ; addr,
        dd litcomma     ; lit,
        dd callcomma    ; call,
        dd definew      ; define
        dd colon        ; :
        dd variable     ; variable
        dd words        ; words
        dd macros       ; macros
        dd qlit         ; ?lit
        dd resolve      ; resolve
        dd branches     ; branches
        dd cmode        ; ]
        dd scan         ; scan
        dd parse        ; parse
        dd char         ; char
        dd token        ; token
        dd name         ; name
        dd tick         ; '
        dd mtick        ; m'
        dd execute      ; execute
        dd continue     ; continue
        dd modefetch    ; mode@
        dd modestore    ; mode!
        dd qdrop        ; ?drop
        dd sdup         ; /dup
        dd infetch      ; in@
        dd instore      ; in!
        dd oparen       ; (
        dd backslash
        dd findw        ; find
        dd selectw      ; select
        dd wordp        ; word
        dd macrop       ; macro
        dd eval         ; eval
        dd load         ; load
        dd errc         ; err#
        dd reset        ; reset
        dd scanw        ; scanw
        dd source
%ifdef LINUX
        dd syscallw     ; syscall
        dd argv         ; argv
%endif
%ifdef WIN32
        dd _LoadLibraryA
        dd _GetProcAddress
%endif
.end:

macro_addrs:
        dd semi         ; ;
        dd semisemi     ; ;;
        dd imode        ; [
        dd pnext        ; postpone
        dd tickm        ; [']
        dd colon        ; :
        dd cdrop        ; drop
        dd cdup         ; dup
        dd oparen       ; (
        dd backslash
        dd errc+4
.end:


; --source code--
; this is the source code that is compiled on boot.

        db 0,"0 load 1 load 2 load 3 load"
        db 0,"char ! $b8000 1!"
        db 0,"halt halt ; halt"

times (source_blks)-(imgtop+($-$$)) db 0
source:
        incbin "core/base.fb"
        incbin "core/alu.fb"
        incbin "core/mem.fb"
        incbin "core/text.fb"
%ifdef NATIVE
        incbin "kernel.native.fs"
%endif
%ifdef LINUX
        incbin "kernel.linux.fs"
%endif
%ifdef WIN32
        incbin "kernel.win32.fs"
%endif
        db " "
        align 16, db " "
.end:


%ifdef NATIVE
        sig:  dd signature  ; the boot loader checks this signature
%endif
