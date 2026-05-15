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

mov rdi, gpu_name
call serial_print

jmp $

.exit:
mov rax, 1
int 0x81


%include "../../kernel/serial.asm"

gpu_name: db "gpu", 0
handle: dq 1


align 4096
prog_end:
