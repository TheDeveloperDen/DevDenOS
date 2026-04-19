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

mov ah, 0x0e
mov al, 'X'
int 0x10

jmp $

times 510-($-$$) db 0 
dw 0xaa55
