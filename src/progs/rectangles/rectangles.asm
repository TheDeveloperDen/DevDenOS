[bits 64]
default rel

org 0x4000000

header:
db 'D','V','D','N'
db 1
db 0
dw 0
dq _start
dq 0x4000000
dq prog_end - header
dd sections - header
dw 1
dd 0
dd 0
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

sections:
dq 0x4000000
dq prog_end - header
dq 0
dq prog_end - header

align 16
_start:
mov rax, 5
lea rdi, [gpu_name]
int 0x81
mov [handle], rax

mov rax, 11
lea rdi, [glrbm]
int 0x81
test rax, rax
jz .exit

call rax
mov [glrbm_exports], rax

mov rbx, [glrbm_exports]
call [rbx + 0]

mov rdi, 0x0000FF00
call [rbx + 56]

mov rdi, 0x00FF0000
call [rbx + 48]

mov rdi, 100
mov rsi, 100
mov rdx, 400
mov rcx, 300
call [rbx + 80]

mov rdi, 100
mov rsi, 100
call [rbx + 32]

mov rdi, 400
mov rsi, 300
call [rbx + 40]

mov rdi, 500
mov rsi, 100
mov rdx, 600
mov rcx, 300
mov r8, 400
mov r9, 300
call [rbx + 96]

mov rax, 0x000000FF
push rax
mov rax, 600
push rax
mov rax, 400
push rax

mov rdi, 500
mov rsi, 400
mov rdx, 0x00FF0000
mov rcx, 600
mov r8, 600
mov r9, 0x0000FF00

call [rbx + 104]

add rsp, 24

mov rax, 0x00CC0020
push rax
mov rax, 100
push rax
xor rax, rax
push rax

mov rdi, 750
mov rsi, 100
mov rdx, 100
mov rcx, 100
lea r8, [test_bitblt]
xor r9, r9

call [rbx + 112]
add rsp, 2

.exit:
mov rax, 1
int 0x81

gpu_name: db "gpu", 0
glrbm: db "den/libs/glrbm.dde", 0

handle: dq 1

test_bitblt:
times 10000 dd 0x000000FF

align 8
glrbm_exports: dq 0

align 4096
prog_end: