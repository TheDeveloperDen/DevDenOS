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
db 'gpu'
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

cmp rdi, 1
je .do_init

mov rax, -1
jmp .done

.do_init:
lea rdi, [msg_test]
call serial_print


mov rax, 1
jmp .done

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

msg_test: db "hello bird", 10, 0

%include "../../kernel/serial.asm"

align 8
api_table: dq 0

align 4096
drv_end: