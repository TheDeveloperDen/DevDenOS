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
jz .exit

mov rdi, [out_data]
mov rcx, 1680*720
mov eax, 0
rep stosd



mov rax, 2
mov rdi, 1
lea rsi, [msg]
mov rdx, msg_len
int 0x81

mov rax, 7
lea rdi, [kbd_file]
int 0x81
test rax, rax
jz .exit
mov [kbd_handle], rax


mov rax, 6
mov rdi,[kbd_handle]
mov rsi, 2
xor rdx, rdx
lea r10,[mouse_buf]
int 0x81

mov eax, [mouse_buf]
mov ebx,[mouse_buf + 4]
mov [old_mouse_x], eax
mov[old_mouse_y], ebx

mov r9, rbx
imul r9, 1680
add r9, rax
shl r9, 2
mov r8, [out_data]
add r8, r9
mov ecx, [r8]
mov [old_mouse_color], ecx
mov dword [r8], 0xFFFFFFFF

.input_loop:
mov rax, 6
mov rdi, [kbd_handle]
mov rsi, 1
xor rdx, rdx
lea r10, [char_buf]
int 0x81

test rax, rax
jz .check_mouse

mov rax, 2
mov rdi, 1
lea rsi, [char_buf]
mov rdx, 1
int 0x81
jmp .input_loop

.check_mouse:
mov rax, 6
mov rdi, [kbd_handle]
mov rsi, 2
xor rdx, rdx
lea r10, [mouse_buf]
int 0x81

test rax, rax
jz .yield

mov eax, [mouse_buf]
mov ebx, [mouse_buf + 4]

cmp eax, [old_mouse_x]
jne .update_mouse
cmp ebx, [old_mouse_y]
jne .update_mouse

jmp .yield

.update_mouse:
mov eax, [old_mouse_x]
mov ebx, [old_mouse_y]
mov r9, rbx
imul r9, 1680
add r9, rax
shl r9, 2
mov r8, [out_data]
add r8, r9
mov ecx,[old_mouse_color]
mov [r8], ecx

mov eax,[mouse_buf]
mov ebx, [mouse_buf + 4]
mov[old_mouse_x], eax
mov [old_mouse_y], ebx

mov r9, rbx
imul r9, 1680
add r9, rax
shl r9, 2
mov r8, [out_data]
add r8, r9
mov ecx, [r8]
mov [old_mouse_color], ecx
mov dword [r8], 0xFFFFFFFF

jmp .input_loop

.yield:
int 0x80
jmp .input_loop

.exit:
mov rax, 1
int 0x81

drv_file: db "bga.dde", 0
kbd_file: db "ps2.dde", 0

msg: db "Hello Cros"
msg_len equ $ - msg

align 8
handle:   dq 0
kbd_handle: dq 0
resolution:  dq 1680,720
out_data: dq 0
char_buf: db 0

mouse_buf: dd 0, 0, 0
old_mouse_x: dd 0
old_mouse_y: dd 0
old_mouse_color: dd 0

align 4096
prog_end:
