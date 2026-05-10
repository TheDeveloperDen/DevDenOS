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
mov rdi,[handle]
mov rsi, 1
xor rdx, rdx
lea r10, [out_data]
int 0x81

test rax, rax
jz .exit

mov rax, 6
mov rdi, [handle]
mov rsi, 3
lea rdx, [resolution]
xor r10, r10
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

mov rax, 8
lea rdi, [cursor_file]
xor rsi, rsi
int 0x81

cmp rax, -1
je .draw_init
test rax, rax
jz .draw_init

push rax
add rax, 4095
shr rax, 12
mov rsi, rax
mov rax, 3
xor rdi, rdi
mov rdx, 3
mov r10, 0x22
int 0x81
pop rcx

cmp rax, -1
je .draw_init
test rax, rax
jz .draw_init

mov r13, rax
mov rax, 8
lea rdi, [cursor_file]
mov rsi, r13
int 0x81

mov rdi, r13
mov rsi, rax
call tga_parse
mov [cursor_data], rax

.draw_init:
call draw_cursor

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
mov rdi,[kbd_handle]
mov rsi, 2
xor rdx, rdx
lea r10, [mouse_buf]
int 0x81

test rax, rax
jz .yield

mov eax, [mouse_buf]
mov ebx, [mouse_buf + 4]

cmp eax, [bg_save_x]
jne .update_mouse
cmp ebx,[bg_save_y]
jne .update_mouse

jmp .yield

.update_mouse:
call restore_cursor
call draw_cursor

jmp .input_loop

.yield:
int 0x80
jmp .input_loop

.exit:
mov rax, 1
int 0x81

restore_cursor:
mov eax, [bg_save_x]
mov ebx, [bg_save_y]
mov r8, [out_data]
mov ecx, [bg_save_h]
mov edx, [bg_save_w]
test ecx, ecx
jz .done_rest

lea rsi, [bg_save]
xor r10d, r10d

.loop_y_rest:
cmp r10d, ecx
jge .done_rest
xor r11d, r11d

.loop_x_rest:
cmp r11d, edx
jge .next_y_rest

mov edi, ebx
add edi, r10d
cmp edi, 720
jge .skip_rest
mov r9d, eax
add r9d, r11d
cmp r9d, 1680
jge .skip_rest

imul edi, 1680
add edi, r9d
mov r9, rdi
shl r9, 2
add r9, r8

mov edi, [rsi]
mov [r9], edi

.skip_rest:
add rsi, 4
inc r11d
jmp .loop_x_rest

.next_y_rest:
inc r10d
jmp .loop_y_rest

.done_rest:
ret


draw_cursor:
mov eax, [mouse_buf]
mov ebx, [mouse_buf + 4]
mov [bg_save_x], eax
mov [bg_save_y], ebx

mov r12,[cursor_data]
test r12, r12
jz .no_cursor

mov ecx, [r12 + 4]
mov edx, [r12]
mov[bg_save_h], ecx
mov [bg_save_w], edx

lea r13, [r12 + 8]
lea r14, [bg_save]
mov r8, [out_data]

xor r10d, r10d

.loop_y_drw:
cmp r10d, ecx
jge .done_drw
xor r11d, r11d

.loop_x_drw:
cmp r11d, edx
jge .next_y_drw

mov edi, ebx
add edi, r10d
cmp edi, 720
jge .skip_drw
mov r9d, eax
add r9d, r11d
cmp r9d, 1680
jge .skip_drw

imul edi, 1680
add edi, r9d
mov r9, rdi
shl r9, 2
add r9, r8

mov edi, [r9]
mov [r14], edi

mov edi, [r13]
test edi, 0xFF000000
jz .skip_drw
mov [r9], edi

.skip_drw:
add r13, 4
add r14, 4
inc r11d
jmp .loop_x_drw

.next_y_drw:
inc r10d
jmp .loop_y_drw

.done_drw:
ret

.no_cursor:
mov dword [bg_save_h], 1
mov dword [bg_save_w], 1

mov edi, ebx
cmp edi, 720
jge .done_drw
mov r9d, eax
cmp r9d, 1680
jge .done_drw

imul edi, 1680
add edi, r9d
mov r9, rdi
shl r9, 2
add r9, [out_data]

mov edi, [r9]
mov [bg_save], edi
mov dword [r9], 0xFFFFFFFF
ret

%include "tga.asm"

drv_file: db "bga.dde", 0
kbd_file: db "ps2.dde", 0
cursor_file: db "den/cursors/cursor.tga", 0

msg: db "Hello Cros"
msg_len equ $ - msg

align 8
handle:   dq 0
kbd_handle: dq 0
resolution:  dq 1680,720
out_data: dq 0
char_buf: db 0

mouse_buf: dd 0, 0, 0
cursor_data: dq 0
bg_save_x: dd 0
bg_save_y: dd 0
bg_save_w: dd 0
bg_save_h: dd 0
align 4
bg_save: times 4096 dd 0

align 4096
prog_end:
