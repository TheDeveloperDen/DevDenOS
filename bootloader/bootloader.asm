org 0x7c00

jmp short start
nop

times 90 db 0 


start:
xor ax, ax 
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

mov ah, 0x02
mov al, 32
mov ch, 0
mov cl, 2
mov dh, 0
mov dl, 0x80
mov bx, 0x7e00
int 0x13
; CF: Set on error
jc .disk_fail

jmp 0x7e00
jmp $

.disk_fail: ; CH: Status
xor cx,cx
mov ch, ah
mov ah, 0x0e
mov al, 'x'
int 0x10
jmp $

times 510-($-$$) db 0 
dw 0xaa55
