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

mov rax, 8
lea rdi, [wallpaper]
xor rsi, rsi
int 0x81

cmp rax, -1
je .clear_black
test rax, rax
jz .clear_black

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
je .clear_black
test rax, rax
jz .clear_black

mov r13, rax
mov rax, 8
lea rdi, [wallpaper]
mov rsi, r13
int 0x81

mov rdi, r13
mov rsi, rax
call tga_parse
test rax, rax
jz .clear_black

mov [wallpaper_data], rax

mov r14, rax
mov r8d, dword[r14]
mov r9d, dword [r14 + 4]

cmp r9d, 720
jle .height_ok
mov r9d, 720

.height_ok:
mov r11d, r8d
cmp r8d, 1680
jle .width_ok
mov r8d, 1680

.width_ok:
mov rsi, r14
add rsi, 8
mov rdi, [out_data]
xor r10, r10

.row_loop:
cmp r10d, r9d
jge .wallpaper_done

mov ecx, r8d
rep movsd

mov eax, 1680
sub eax, r8d
shl eax, 2
add rdi, rax

mov eax, r11d
sub eax, r8d
shl eax, 2
add rsi, rax

inc r10d
jmp .row_loop

.clear_black:
mov rdi, [out_data]
mov rcx, 1680*720
xor eax, eax
rep stosd

.wallpaper_done:
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

mov rax, 3
xor rdi, rdi
mov rsi, 1
mov rdx, 3
mov r10, 0x22
int 0x81
mov [cmd_buf_ptr], rax

mov rax, 3
xor rdi, rdi
mov rsi, 1
mov rdx, 3
mov r10, 0x22
int 0x81
mov [exec_path_ptr], rax

mov rax, 3
xor rdi, rdi
mov rsi, 1
mov rdx, 3
mov r10, 0x22
int 0x81
mov [shell_argv_ptr], rax

call print_prompt

.input_loop:
mov rax, 6
mov rdi, [kbd_handle]
mov rsi, 1
xor rdx, rdx
lea r10, [char_buf]
int 0x81

test rax, rax
jz .check_mouse

mov al, [char_buf]
cmp al, 10
je .do_enter
cmp al, 8
je .do_bckspace

mov rcx, [cmd_len]
mov rdx, [cmd_buf_cap]
dec rdx
cmp rcx, rdx
jl .store_char

push rax
push rcx

mov rax, 3
xor rdi, rdi
mov rsi, [cmd_buf_pages]
shl rsi, 1
push rsi
mov rdx, 3
mov r10, 0x22
int 0x81

mov rdi, rax
mov rsi, [cmd_buf_ptr]
mov rcx, [cmd_buf_pages]
shl rcx, 12
push rdi
rep movsb
pop rdi

mov rax, 4
push rdi
mov rdi, [cmd_buf_ptr]
mov rsi, [cmd_buf_pages]
int 0x81
pop rdi

mov [cmd_buf_ptr], rdi

mov rax, 3
xor rdi, rdi
mov rsi, [cmd_buf_pages]
shl rsi, 1
mov rdx, 3
mov r10, 0x22
int 0x81

mov rdi, rax
mov rax, 4
push rdi
mov rdi, [exec_path_ptr]
mov rsi, [cmd_buf_pages]
int 0x81
pop rdi
mov [exec_path_ptr], rdi

pop rsi
mov [cmd_buf_pages], rsi
shl rsi, 12
mov [cmd_buf_cap], rsi

pop rcx
pop rax

.store_char:
mov rbx, [cmd_buf_ptr]
mov [rbx + rcx], al
inc qword [cmd_len]

.print_char:
mov rax, 2
mov rdi, 1
lea rsi, [char_buf]
mov rdx, 1
int 0x81
jmp .input_loop

.do_bckspace:
mov rcx, [cmd_len]
test rcx, rcx
jz .input_loop
dec qword [cmd_len]

mov byte [char_buf], 8
mov rax, 2
mov rdi, 1
lea rsi, [char_buf]
mov rdx, 1
int 0x81

mov rax, 12
int 0x81

mov r8, [wallpaper_data]
test r8, r8
jz .input_loop

add r8, 8
mov rsi, r8
mov rdi, [out_data]

mov r9, rdx
imul r9, 1680
add r9, rax
shl r9, 2

add rsi, r9
add rdi, r9


mov rcx, 16

.restore_row:
mov r9, [rsi]
mov [rdi], r9

mov r9, [rsi+4]
mov [rdi+4], r9

mov r9, [rsi+8]
mov [rdi+8], r9

mov r9, [rsi+12]
mov [rdi+12], r9

mov r9, [rsi+16]
mov [rdi+16], r9

mov r9, [rsi+20]
mov [rdi+20], r9

mov r9, [rsi+24]
mov [rdi+24], r9

mov r9, [rsi+28]
mov [rdi+28], r9

add rsi, 1680 * 4
add rdi, 1680 * 4
dec rcx
jnz .restore_row

jmp .input_loop

.do_enter:
mov rax, 2
mov rdi, 1
lea rsi, [char_buf]
mov rdx, 1
int 0x81
    
call process_command
    
mov qword [cmd_len], 0
call print_prompt
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

print_prompt:
mov rax, 2
mov rdi, 1
lea rsi, [prompt_msg]
mov rdx, prompt_len
int 0x81
ret

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

process_command:
mov rcx, [cmd_len]
test rcx, rcx
jz .done
mov rbx, [cmd_buf_ptr]
mov byte [rbx + rcx], 0

mov rsi, rbx
xor rcx, rcx

.next_token:
mov al, [rsi]
test al, al
jz .parse_done
cmp al, ' '
je .skip_space

mov rdx, [shell_argv_cap]
cmp rcx, rdx
jl .cap_ok

push rax
push rcx
push rsi

mov rax, 3
xor rdi, rdi
mov rsi, [shell_argv_pages]
shl rsi, 1
push rsi
mov rdx, 3
mov r10, 0x22
int 0x81

mov rdi, rax
mov rsi, [shell_argv_ptr]
mov rcx, [shell_argv_pages]
shl rcx, 12
push rdi
rep movsb
pop rdi

mov rax, 4
push rdi
mov rdi, [shell_argv_ptr]
mov rsi, [shell_argv_pages]
int 0x81
pop rdi

pop rsi
mov [shell_argv_pages], rsi
shl rsi, 9
mov [shell_argv_cap], rsi
mov [shell_argv_ptr], rdi

pop rsi
pop rcx
pop rax

.cap_ok:
cmp al, '"'
je .start_quote

mov rdx, [shell_argv_ptr]
mov [rdx + rcx*8], rsi
inc rcx

.scan_normal:
mov al, [rsi]
test al, al
jz .parse_done
cmp al, ' '
je .end_token
inc rsi
jmp .scan_normal

.start_quote:
inc rsi
mov rdx, [shell_argv_ptr]
mov [rdx + rcx*8], rsi
inc rcx
.scan_quote:
mov al, [rsi]
test al, al
jz .parse_done
cmp al, '"'
je .end_token
inc rsi
jmp .scan_quote

.end_token:
mov byte [rsi], 0
inc rsi
jmp .next_token

.skip_space:
inc rsi
jmp .next_token

.parse_done:
mov [shell_argc], rcx
test rcx, rcx
jz .done

mov rdx, [shell_argv_ptr]
mov rsi, [rdx]
xor rdx, rdx

.check_slash:
mov al, [rsi]
test al, al
jz .slash_checked
cmp al, '/'
je .has_slash
inc rsi
jmp .check_slash

.has_slash:
mov rdx, 1

.slash_checked:
test rdx, rdx
jnz .try_absolute

mov rdi, [exec_path_ptr]
lea rsi, [den_bin_str]
call strcpy
mov rdx, [shell_argv_ptr]
mov rsi, [rdx]
call strcat

mov rax, 10
mov rdi, [exec_path_ptr]
mov rsi, [shell_argc]
mov rdx, [shell_argv_ptr]
int 0x81

cmp rax, -1
jne .yield_wait

.try_absolute:
mov rax, 10
mov rdx, [shell_argv_ptr]
mov rdi, [rdx]
mov rsi, [shell_argc]
int 0x81

cmp rax, -1
jne .yield_wait

mov rax, 2
mov rdi, 1
lea rsi, [err_msg]
mov rdx, err_msg_len
int 0x81
jmp .done

.yield_wait:
mov rcx, 25

.y_loop:
push rcx
int 0x80
pop rcx
loop .y_loop

.done:
ret

strcpy:

.loop:
mov al, [rsi]
mov [rdi], al
test al, al
jz .ret
inc rsi
inc rdi
jmp .loop

.ret:
ret

strcat:
.find_null:
mov al, [rdi]
test al, al
jz strcpy.loop
inc rdi
jmp .find_null

%include "tga.asm"

drv_file: db "den/drivers/bga.dde", 0
kbd_file: db "den/drivers/ps2.dde", 0
cursor_file: db "den/cursors/cursor.tga", 0

msg: db "Hello Cros",10
msg_len equ $ - msg

filename: db "den/bin/example2.dde",0

wallpaper: db 'den/manul.tga',0

align 8
handle:   dq 0
kbd_handle: dq 0
resolution:  dq 1680,720
out_data: dq 0
wallpaper_data: dq 0
char_buf: db 0

mouse_buf: dd 0, 0, 0
cursor_data: dq 0
bg_save_x: dd 0
bg_save_y: dd 0
bg_save_w: dd 0
bg_save_h: dd 0

cmd_buf_ptr: dq 0
cmd_buf_pages: dq 1
cmd_buf_cap: dq 4096
cmd_len: dq 0

shell_argv_ptr: dq 0
shell_argv_pages: dq 1
shell_argv_cap: dq 512
shell_argc: dq 0

exec_path_ptr: dq 0

den_bin_str: db "den/bin/", 0

prompt_msg: db "> "
prompt_len equ $ - prompt_msg

err_msg: db "Command not found", 10
err_msg_len equ $ - err_msg

align 4
bg_save: times 4096 dd 0

align 4096
prog_end:
