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
lea rdi, [bga_file]
int 0x81

mov [handle], rax

mov rax, 6
mov rdi, [handle]
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81

mov rax, 2
mov rdi, 1
lea rsi, [msg]
mov rdx, msg_len
int 0x81

;; rax = 9
;; rdi = filename
;; rsi = buffer
;; rdx = size

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

.exit:
mov rax, 1
int 0x81

msg: db "Loaded from userspace"
msg_len equ $ - msg

bga_file: db "bga.dde",0

file: db "den/verlongfilenamesss1234.txt",0

contents: db "Hello, World!"
contents_len equ $ - contents

handle: dq 1

read_buffer: times 256 db 0


align 4096
prog_end: