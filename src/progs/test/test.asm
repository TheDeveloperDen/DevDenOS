[bits 64]
default rel

%ifidn __OUTPUT_FORMAT__, bin
org 0x4000000
%endif

section .text

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

%include "globals.asm"

align 16
_start:
mov rax, 5 ; Get Driver
lea rdi, [gpu_name]
int 0x81 ; Syscall
mov [handle], rax

mov rax, 6 ; Invoke driver
mov rdi, [handle]
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81 ; Syscall

mov rax, 6  ; Invoke driver
mov rdi, [handle]
mov rsi, 2
xor rdx, rdx
xor r10, r10
int 0x81  ; Syscall

mov rax, 6  ; Invoke driver
mov rdi, [handle]
mov rsi, 3
lea rdx, [clear_color]
xor r10, r10
int 0x81  ; Syscall

mov qword [shader_params + 0], 0
lea rax, [vs_tgsi]
mov [shader_params + 8], rax
mov qword [shader_params + 16], 0

mov rax, 6
mov rdi, [handle]
mov rsi, 4
lea rdx, [shader_params]
xor r10, r10
int 0x81

cmp rax, 1
jne .test_failure

mov rax, [shader_params + 16]
mov [vs_handle], rax
mov qword [shader_params + 0], 1
lea rax, [fs_tgsi]
mov [shader_params + 8], rax
mov qword [shader_params + 16], 0

mov rax, 6
mov rdi, [handle]
mov rsi, 4
lea rdx, [shader_params]
xor r10, r10
int 0x81

cmp rax, 1
jne .test_failure

mov rax, [shader_params + 16]
mov [fs_handle], rax
jmp .exit_test

.test_failure:
call serial_init
lea rdi, [msg_failed]
call serial_print

.exit_test:

jmp $

.exit:
mov rax, 1
int 0x81


%include "../../kernel/serial.asm"

gpu_name: db "gpu", 0
handle: dq 1

clear_color: dd 0.0, 1.0, 0.0, 1.0

align 8
shader_params:
dq 0
dq 0
dq 0
vs_handle: dq 0
fs_handle: dq 0

vs_tgsi:
db "VERT", 10
db "DCL IN[0]", 10
db "DCL OUT[0], POSITION", 10
db "MOV OUT[0], IN[0]", 10
db "END", 0

fs_tgsi:
db "FRAG", 10
db "DCL OUT[0], COLOR", 10
db "MOV OUT[0], IMM[0]", 10
db "END", 0


msg_failed: db "Shaders failed", 10, 0
msg_failed_len equ $ - msg_failed

align 4096
prog_end:
