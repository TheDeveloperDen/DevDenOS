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
mov rax, 7
lea rdi, [drv_file]
int 0x81

test rax, rax
jz .exit
mov [handle], rax

mov rax, 6
mov rdi, [handle]
mov rsi, 1
lea rdx, [resolution]
lea r10, [out_data]
int 0x81

test rax, rax
jnz .exit

mov rdi, [out_data]
mov rcx, 1680*720
mov eax, 0
rep stosd

mov rax, 2
mov rdi, 1
lea rsi, [msg]
mov rdx, msg_len
int 0x81

.exit:
mov rax, 1
int 0x81

drv_file: db "bga.dde", 0

msg: db "Hello Cros"
msg_len equ $ - msg

align 8
handle:   dq 0
resolution:  dq 1680,720
out_data: dq 0

align 4096
prog_end:
