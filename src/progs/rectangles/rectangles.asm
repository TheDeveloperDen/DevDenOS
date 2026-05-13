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
mov rax, 7
lea rdi, [bga_file]
int 0x81
mov [handle], rax

mov rax, 11
lea rdi, [gapi_file]
int 0x81
test rax, rax
jz .exit

call rax
mov [gapi_exports], rax

mov rbx, [gapi_exports]
lea rdi, [bga_name]
call [rbx + 0]

mov rdi, 500
mov rsi, 300
mov rdx, 150
mov rcx, 150
mov r8, 0x0000FF00
mov rbx, [gapi_exports]
call [rbx + 24]


.exit:
mov rax, 1
int 0x81


bga_file: db "den/drivers/bga.dde", 0
gapi_file: db "den/libs/dengraphics.dde", 0
bga_name: db "bga", 0

handle: dq 1

align 8
gapi_exports: dq 0

align 4096
prog_end: