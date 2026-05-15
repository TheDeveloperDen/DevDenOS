; A somehwhat external programmer's attempt at a DevDenOS program.
; Prints MANUL enough times to fill the screen.

; Amethyst

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
dq 0x4000000 ; virtual addr
dq prog_end - header ; size in mem
dq 0 ; offset
dq prog_end - header ; size in file

align 16
_start:
; Program prep
mov [argc], rdi
mov [argv], rsi

mov rax, 5 ; Get Driver
lea rdi, [gpu_name]
int 0x81 ; Syscall
mov [handle], rax

; Set up framebuffer
mov rax, 6 ; Invoke driver
mov rdi, [handle]
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81 ; Syscall

; Main program logic
xor r15, r15

.manul_print_loop:
; Leave if there has been enough MANULs.
cmp r15, 44
je .exit

mov rax, 2 ; Write
mov rdi, 1
mov rsi, manul_str
mov rdx, manul_str_len
xor r10, r10
int 0x81 ; Syscall

; End of loop
add r15, 1
jmp .manul_print_loop

.exit:
mov rax, 1
int 0x81 ; Syscall

manul_str: db "MANUL",0Ah
manul_str_len equ $ - manul_str

gpu_name: db "gpu", 0
handle: dq 1
argc: dq 0
argv: dq 0

align 4096
prog_end:
