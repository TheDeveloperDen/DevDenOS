[bits 64]
default rel

header:
db 'D','V','D','N'
db 1, 0
dw 2
dq _start
dq 0
dq drv_end - header
dd sections - header
dw 1
dd opt_hdr - header
dd opt_hdr_end - opt_hdr
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

opt_hdr:
db 'K','D','R','V'
dd 0, 0, 0
db 'bga'
times 13 db 0
opt_hdr_end:

sections:
dq 0
dq drv_end - header
dq 0
dq drv_end - header

align 16
_start:
mov [api_table], rdi
lea rax, [dispatch]
ret

dispatch:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15

mov rbx, rdx 

cmp rdi, 1
je .do_init

mov rax, -1
jmp .done

.do_init:
mov r8, [rsi]
mov r9, [rsi + 8]
mov [vwidth], r8
mov [vheight], r9

mov rdi, 0x1234
mov rsi, 0x1111
mov rax, [api_table]
mov rax, [rax + 64] 
call rax
cmp eax, -1
je .fail

mov rdi, rax
shr rdi, 16
and rdi, 0xFF
mov rsi, rax
shr rsi, 8
and rsi, 0xFF
mov rdx, rax
and rdx, 0xFF
mov rcx, 0x10
mov rax, [api_table]
mov rax, [rax + 48]
call rax

and eax, 0xFFFFFFF0
mov [lfb_base], rax

mov dx, 0x01CE
mov ax, 4
out dx, ax
mov dx, 0x01CF
xor ax, ax
out dx, ax

mov dx, 0x01CE
mov ax, 1
out dx, ax
mov dx, 0x01CF
mov ax, word [vwidth]
out dx, ax

mov dx, 0x01CE
mov ax, 2
out dx, ax
mov dx, 0x01CF
mov ax, word [vheight]
out dx, ax

mov dx, 0x01CE
mov ax, 3
out dx, ax
mov dx, 0x01CF
mov ax, 32
out dx, ax

mov dx, 0x01CE
mov ax, 4
out dx, ax
mov dx, 0x01CF
mov ax, 0x41
out dx, ax

mov rax, [vwidth]
imul rax, [vheight]
shl rax, 2
add rax, 4095
shr rax, 12
mov r14, rax

mov r12, 0xE0000000
mov r13, [lfb_base]

.map_loop:
test r14, r14
jz .map_done

mov rdi, r12
mov rsi, r13
mov rdx, 7 
mov rax, [api_table]
mov rax, [rax + 16]
call rax

add r12, 4096
add r13, 4096
dec r14
jmp .map_loop

.map_done:
mov rax, 0xE0000000
mov [rbx], rax
xor rax, rax
jmp .done

.fail:
mov rax, -1

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

align 8
api_table: dq 0
lfb_base:  dq 0
vwidth:    dq 0
vheight:   dq 0

align 4096
drv_end: