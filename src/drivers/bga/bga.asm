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

mov rbx, rdx 

cmp rdi, 1
je .do_init

cmp rdi, 2
je .put_pixel

cmp rdi, 3
je .set_res

cmp rdi, 4
je .draw_rect

mov rax, -1
jmp .done


.draw_rect:
mov r8, [rsi]
mov r9, [rsi + 8]
mov r10, [rsi + 16]
mov r11, [rsi + 24]
mov rcx, [rsi + 32]

cmp r8, [vwidth]
jae .dp_fail
cmp r9, [vheight]
jae .dp_fail

mov rax, r8
add rax, r10
cmp rax, [vwidth]
jbe .dr_w_ok
mov r10, [vwidth]
sub r10, r8
.dr_w_ok:

mov rax, r9
add rax, r11
cmp rax, [vheight]
jbe .dr_h_ok
mov r11, [vheight]
sub r11, r9
.dr_h_ok:

.dr_y_loop:
test r11, r11
jz .dr_done

mov rax, [vwidth]
imul rax, r9
add rax, r8
shl rax, 2

mov rdi, 0xE0000000
add rdi, rax

mov r12, r10
.dr_x_loop:
test r12, r12
jz .dr_x_done
mov [rdi], ecx
add rdi, 4
dec r12
jmp .dr_x_loop

.dr_x_done:
inc r9
dec r11
jmp .dr_y_loop

.dr_done:
mov rax, 1
jmp .done

.put_pixel:
mov r8, [rsi]
mov r9, [rsi + 8]
mov rcx, [rsi + 16]

cmp r8, [vwidth]
jae .dp_fail
cmp r9, [vheight]
jae .dp_fail

mov rax, [vwidth]
imul rax, r9
add rax, r8
shl rax, 2

mov rdi, 0xE0000000
add rdi, rax
mov [rdi], ecx

mov rax, 1
jmp .done

.dp_fail:
mov rax, 0
jmp .done

.do_init:
mov rdi, 0x1234
mov rsi, 0x1111
mov rax, [api_table]
mov rax, [rax + 64] 
call rax
cmp eax, -1
je .fail

mov rdi, rax
shr rdi, 16
and rdi, 0xFF
mov rsi, rax
shr rsi, 8
and rsi, 0xFF
mov rdx, rax
and rdx, 0xFF
mov rcx, 0x10
mov rax, [api_table]
mov rax, [rax + 48]
call rax

and eax, 0xFFFFFFF0
mov [lfb_base], rax

mov r14, 2048
mov r12, 0xE0000000
mov r13,[lfb_base]

.map_loop:
test r14, r14
jz .map_done

mov rdi, r12
mov rsi, r13
mov rdx, 7 
mov rax, [api_table]
mov rax, [rax + 16]
call rax

add r12, 4096
add r13, 4096
dec r14
jmp .map_loop

.map_done:
mov dx, 0x01CE
mov ax, 1
out dx, ax
mov dx, 0x01CF
xor rax, rax
in ax, dx
mov [vwidth], rax

mov dx, 0x01CE
mov ax, 2
out dx, ax
mov dx, 0x01CF
xor rax, rax
in ax, dx
mov [vheight], rax

mov rax, 0xE0000000
test rbx, rbx
jz .skip_out
mov [rbx], rax

.skip_out:
mov rax, 1
jmp .done

.set_res:
mov r8, [rsi]
mov r9, [rsi + 8]
mov [vwidth], r8
mov [vheight], r9

mov dx, 0x01CE
mov ax, 4
out dx, ax
mov dx, 0x01CF
xor ax, ax
out dx, ax

mov dx, 0x01CE
mov ax, 1
out dx, ax
mov dx, 0x01CF
mov ax, word [vwidth]
out dx, ax

mov dx, 0x01CE
mov ax, 2
out dx, ax
mov dx, 0x01CF
mov ax, word [vheight]
out dx, ax

mov dx, 0x01CE
mov ax, 3
out dx, ax
mov dx, 0x01CF
mov ax, 32
out dx, ax

mov dx, 0x01CE
mov ax, 4
out dx, ax
mov dx, 0x01CF
mov ax, 0x41
out dx, ax

mov rax, 1
jmp .done

.fail:
mov rax, 0

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

align 8
api_table: dq 0
lfb_base:  dq 0
vwidth:    dq 0
vheight:   dq 0

align 4096
drv_end: