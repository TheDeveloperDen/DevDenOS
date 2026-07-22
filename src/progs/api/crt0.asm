[bits 64]
default rel

global _start
global exit
extern main

section .text

_start:
xor rbp, rbp

push rsi
push rdi

mov rax, 5
lea rdi, [gpu_name]
int 0x81
mov [handle], rax

mov rax, 6
mov rdi, [handle]
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81

pop rdi
pop rsi

and rsp, -16
call main

mov rdi, rax
call exit

exit:
mov rax, 1
int 0x81
hlt

section .data
gpu_name: db "gpu",0

section .bss
handle: resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
