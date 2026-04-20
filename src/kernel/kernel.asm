org 0x100000
[bits 32]

entry:
mov eax, 0xb8000
xor ebx, ebx

.loop:
cmp ebx, 80*25
je .end
mov word [eax], 0x0720
inc ebx
add eax, 2
jmp .loop

.end:

jmp $
