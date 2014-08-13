;;; CrunchyForth (c) 2004 Luke McCarthy
;;; 1440 KiB floppy boot sector

use16
        jmp bootstart
        nop

colour equ 0x07

msg:
;.title: db 0, "CrunchyForth Iteration 009", 0
;.ok:    db "ok!", 0
.err0:  db "error: bios 13,02 returned code ", 0
.err1:  db "error: corrupt image or bad disk", 0
.dot:   db ".", 0

;;; print function
;;; ds:si=string es(0xb800):di=screen
print:
        mov ax, 0xb800
        mov es, ax
        mov ah, colour
.next:  lodsb
        test al, al
        jz .end
        stosw
        jmp .next
.end:   ret

;;; hex byte print function
;;; al=n es(0xb800):di=screen
hexprint:
        mov dx, 0xb800
        mov es, dx
        mov dx, ax
        shr al, 4
        call tochar
        mov ah, colour  ; colour
        stosw
        mov ax, dx
        and al, 0xf
        call tochar
        mov ah, colour  ; colour
        stosw
        ret
tochar:
        cmp al, 9
        ja .hex
        add al, 48
        ret
.hex:   add al, 55
        ret

; convert lba to chs
;
; c = (n / 18) / 2
; h = (n / 18) mod 2
; s = (n mod 18) + 1
chs:
        mov cx, 18
        xor dx, dx
        div cx
        inc dx
        mov [sect], dl
        mov cx, 2
        xor dx, dx
        div cx
        mov [head], dl
        mov [cyld], al
        ret

; read sector
; ax = lba
;
; using bios function 13,02
; ah = function 02
; al = number of sectors
; ch = cylinder
; cl = sector
; dh = head
; dl = drive
; es:bx = buffer
read:
        call chs
        mov byte [trys], 3
.again:
        mov ax, 0x100
desg equ $-2                    ; destination segment
        mov es, ax
        mov bx, 0
deof equ $-2                    ; destination offset
        mov ah, 2
        mov al, 1
        mov ch, 0
cyld equ $-1                    ; cylinder
        mov cl, 0
sect equ $-1                    ; sector
        mov dh, 0
head equ $-1                    ; head
        mov dl, 0
drve equ $-1                    ; drive
        pusha
        int 0x13
        mov [bioserrc], ah
        popa
        jnc .done
        dec byte [trys]
        jnz .again
.error:
        mov si, msg.err0
        call print
        mov al, 0
bioserrc equ $-1                ; error code
        call hexprint
        jmp $
.done:
        mov si, msg.dot
        call print
        ret
trys:   db 2      ; tries


;;; boot start
;;; move loader to lower mem (0xe00)
bootstart:
        mov cx, 512 / 4
        xor di, di
        xor si, si
        mov ax, 0xe0
        mov es, ax
        mov ax, 0x7c0
        mov ds, ax
        rep movsd
        jmp 0:reloc
reloc:
        xor ax, ax
        mov ds, ax
        mov ss, ax
        mov sp, 0xe00
        mov [drve], dl
        sti

;;; cursor off
        xor cl, cl
        mov ah, 1
        mov ch, 32
        int 0x10        ; bios video

;;; clear screen
        mov ax, 0xb800
        mov es, ax
        mov ax, (colour << 8) | 0x20
        mov cx, 80*25
        xor di, di
        rep stosw

;;; display title
        xor di, di
;        mov si, msg.title
;        call print

;;; set vesa mode
;        mov ax, 0x4f02
;        mov bx, 0x114  ; 0x114=800x600, 0x115, 0x117=1024x768
;        int 0x10

;;; load floppy sectors
readloop:
        mov cx, (2*18)-1        ; number of sectors, should be enough!
        mov word [blkn], 1      ; start immediately after the boot sector
.next:
        push cx
        mov ax, 0
blkn equ $-2                    ; logical block
        call read
        add word [desg], 32
        inc word [blkn]
        pop cx
        loop .next

;;; load done, check if it worked
        cmp dword [sig], signature
        je loadok
        mov si, msg.err1
        call print
        jmp $

; load ok!
loadok:
;        mov si, msg.ok
;        call print

;;; floppy motor off
        xor ax, ax
        mov dx, 0x3f2
        out dx, al

;;; interrupts off
        cli
        ;in al, 0x70
        ;or al, 0x80
        ;out 0x70, al

;;; prepare for pmode
        lgdt [gdtr]
        mov eax, cr0
        or ax, 1
        mov cr0, eax
        nop
        jmp 8:protected  ; code selector

;;; protected mode
use32
protected:
        mov ax, 16      ; data selector
        mov ds, ax
        mov es, ax
        mov ss, ax

;;; enable a20 line
        call empty
        mov al, 0xd1
        out 0x64, al
        call empty
        mov al, 0xdf
        out 0x60, al
        call empty
        jmp finish
empty:  in al, 0x64
        test al, 2
        jnz empty
        ret

;;; ok, all done
finish:
        mov ebp, 0xc00
        mov dword [ebp+ctx.rbase], 0x1000
        mov dword [ebp+ctx.sbase], 0x0c00
        jmp bootstrap

        times 510-($-$$) db 0
        db 0x55, 0xaa
bootend:
