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
mov [argc], rdi
mov [argv], rsi

mov rax, 7
lea rdi, [bga_file]
int 0x81
mov [handle], rax

mov rax, 6
mov rdi, [handle]
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81



xor r12, r12

.print_loop:
cmp r12, [argc]
jge .args_done

mov rbx, [argv]
mov rsi,[rbx + r12*8]

mov rdx, rsi

.strlen:
cmp byte [rdx], 0
je .got_len
inc rdx
jmp .strlen

.got_len:
sub rdx, rsi

mov rax, 2
mov rdi, 1
int 0x81

mov rax, 2
mov rdi, 1
lea rsi, [newline]
mov rdx, 1
int 0x81

inc r12
jmp .print_loop

.args_done:



mov rax, 2
mov rdi, 1
lea rsi, [msg]
mov rdx, msg_len
int 0x81


;jmp .exit

mov rax, 9
lea rdi, [file]
lea rsi, [contents]
mov rdx, contents_len
int 0x81

mov rax, 8
lea rdi, [file]
lea rsi, [read_buffer]
int 0x81

cmp rax, -1
je .exit

mov rdx, rax
mov rax, 2
mov rdi, 1
lea rsi, [read_buffer]
int 0x81

mov rax, 11
lea rdi, [libc]
int 0x81

test rax, rax
jz .exit

call rax

mov rbx, [rax + 0]
mov [ptr_printf], rbx

lea rdi, [format_str]
lea rsi, [crow]
call printf

.exit:
mov rax, 1
int 0x81


printf: jmp [ptr_printf]

msg: db "Loaded from userspace",10
msg_len equ $ - msg

bga_file: db "den/drivers/bga.dde",0

file: db "den/verlongfilenamesss1234.txt",0

libc: db "den/libs/libc.dde", 0

libc_entry: dq 0
libc_dispatch: dq 0

contents: db "Hello, World!"
contents_len equ $ - contents

format_str: db 10,"Hello, %s", 10, 0
crow:  db "CRO!", 0

handle: dq 1

argc: dq 0
argv: dq 0
newline: db 10

read_buffer: times 256 db 0

align 8
ptr_printf: dq 0





align 4096
prog_end: