[bits 64]
default rel

header:
db 'D','V','D','N'
db 1, 0
dw 3
dq _start
dq 0
dq lib_end - header
dd sections - header
dw 1
dd opt_hdr - header
dd opt_hdr_end - opt_hdr
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

opt_hdr:
db 'S','H','L','B'
dd 0, 0, 0
db 'GLRBM'
times 11 db 0
opt_hdr_end:

sections:
dq 0
dq lib_end - header
dq 0
dq lib_end - header

align 16
_start:
lea r8, [header]
lea rax, [export_table]
push rax

mov r9, 14

.reloc_loop:
mov rcx, [rax]
add rcx, r8
mov [rax], rcx
add rax, 8
dec r9
jnz .reloc_loop

pop rax
ret

align 8
export_table:
dq glrbm_init ; 0
dq glrbm_set_res ; 1
dq glrbm_put_pixel ; 2
dq glrbm_draw_rect ; 3
dq glrbm_MoveTo ; 4
dq glrbm_LineTo ; 5
dq glrbm_SetPenColor ; 6
dq glrbm_SetBrushColor ; 7
dq glrbm_FillRect ; 8
dq glrbm_FrameRect ; 9
dq glrbm_Rectangle ; 10
dq glrbm_FrameTriangle ; 11
dq glrbm_FillTriangle ; 12
dq glrbm_InterpolatedTriangle ; 13

glrbm_init:
push rbp
mov rbp, rsp
push rbx

mov rax, 5
lea rdi, [gpu_name]
int 0x81
mov [gpu_handle], rax

mov rdi, rax
mov rax, 6
mov rsi, 1
xor rdx, rdx
lea r10, [fb_ptr]
int 0x81

pop rbx
mov rsp, rbp
pop rbp
ret

glrbm_set_res:
push rbp
mov rbp, rsp
sub rsp, 16

mov [screen_width], rdi
mov [screen_height], rsi

mov [rsp], rdi
mov [rsp + 8], rsi

mov rax, 6
mov rdi, [gpu_handle]
mov rsi, 3
mov rdx, rsp
xor r10, r10
int 0x81

mov rsp, rbp
pop rbp
ret

glrbm_put_pixel:
cmp rdi, [screen_width]
jae .done
cmp rsi, [screen_height]
jae .done

mov rax, [screen_width]
imul rax, rsi
add rax, rdi
shl rax, 2

mov rcx, [fb_ptr]
test rcx, rcx
jz .done

add rcx, rax
mov [rcx], edx

.done:
ret

glrbm_draw_rect:
push rbp
mov rbp, rsp
sub rsp, 40
mov [rsp], rdi
mov [rsp + 8], rsi
mov [rsp + 16], rdx
mov [rsp + 24], rcx
mov [rsp + 32], r8

mov rax, 6
mov rdi, [gpu_handle]
mov rsi, 4
mov rdx, rsp
xor r10, r10
int 0x81

mov rsp, rbp
pop rbp
ret

glrbm_MoveTo:
mov [current_x], rdi
mov [current_y], rsi
ret

glrbm_LineTo:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15
sub rsp, 40

mov r12, [current_x]
mov r13, [current_y]

mov [rbp-48], rdi
mov [rbp-56], rsi

mov r14, rdi
sub r14, r12
mov rax, 1
cmp r14, 0
jge .dx_pos
neg r14
mov rax, -1
.dx_pos:
mov [rbp-64], rax

mov r15, rsi
sub r15, r13
mov rax, 1
cmp r15, 0
jge .dy_pos
neg r15
mov rax, -1
.dy_pos:
neg r15
mov [rbp-72], rax

mov rbx, r14
add rbx, r15

.loop:
mov rdi, r12
mov rsi, r13
mov rdx, [pen_color]
call glrbm_put_pixel

cmp r12, [rbp-48]
jne .continue
cmp r13, [rbp-56]
je .done

.continue:
mov rax, rbx
shl rax, 1

cmp rax, r15
jl .check_e2_dx
cmp r12, [rbp-48]
je .done
add rbx, r15
add r12, [rbp-64]

.check_e2_dx:
cmp rax, r14
jg .loop
cmp r13, [rbp-56]
je .done
add rbx, r14
add r13, [rbp-72]
jmp .loop

.done:
mov rax, [rbp-48]
mov [current_x], rax
mov rax, [rbp-56]
mov [current_y], rax

add rsp, 40
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

glrbm_SetPenColor:
mov [pen_color], rdi
ret

glrbm_SetBrushColor:
mov [brush_color], rdi
ret

glrbm_FillRect:
push rbp
mov rbp, rsp

mov r8, rdx
sub r8, rdi
jle .done
mov r9, rcx
sub r9, rsi
jle .done

mov rdx, r8
mov rcx, r9
mov r8, [brush_color]
call glrbm_draw_rect

.done:
mov rsp, rbp
pop rbp
ret

glrbm_FrameRect:
push rbp
mov rbp, rsp
push r12
push r13
push r14
push r15
sub rsp, 16

mov r12, rdi
mov r13, rsi
mov r14, rdx
mov r15, rcx

mov rdi, r12
mov rsi, r13
call glrbm_MoveTo
mov rdi, r14
mov rsi, r13
call glrbm_LineTo
mov rdi, r14
mov rsi, r15
call glrbm_LineTo
mov rdi, r12
mov rsi, r15
call glrbm_LineTo
mov rdi, r12
mov rsi, r13
call glrbm_LineTo

add rsp, 16
pop r15
pop r14
pop r13
pop r12
pop rbp
ret

glrbm_Rectangle:
push rbp
mov rbp, rsp
sub rsp, 32

mov [rbp-8], rdi
mov [rbp-16], rsi
mov [rbp-24], rdx
mov [rbp-32], rcx

call glrbm_FillRect

mov rdi, [rbp-8]
mov rsi, [rbp-16]
mov rdx, [rbp-24]
mov rcx, [rbp-32]
call glrbm_FrameRect

add rsp, 32
pop rbp
ret

glrbm_FrameTriangle:
push rbp
mov rbp, rsp
sub rsp, 48

mov [rbp-8], rdi
mov [rbp-16], rsi
mov [rbp-24], rdx
mov [rbp-32], rcx
mov [rbp-40], r8
mov [rbp-48], r9

call glrbm_MoveTo

mov rdi, [rbp-24]
mov rsi, [rbp-32]
call glrbm_LineTo

mov rdi, [rbp-40]
mov rsi, [rbp-48]
call glrbm_LineTo

mov rdi, [rbp-8]
mov rsi, [rbp-16]
call glrbm_LineTo

add rsp, 48
pop rbp
ret


glrbm_FillTriangle:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15
sub rsp, 104

mov rax, rdx
sub rax, rdi
mov r10, r9
sub r10, rsi
imul rax, r10

mov r10, rcx
sub r10, rsi
mov r11, r8
sub r11, rdi
imul r10, r11

sub rax, r10
test rax, rax
jz .done_ret
jg .area_pos
xchg rdx, r8
xchg rcx, r9
neg rax

.area_pos:
mov r10, rdi
cmp r10, rdx
jle .m1
mov r10, rdx

.m1:
cmp r10, r8
jle .m2
mov r10, r8

.m2:
mov [rbp-48], r10

mov r10, rdi
cmp r10, rdx
jge .M1
mov r10, rdx

.M1:
cmp r10, r8
jge .M2
mov r10, r8

.M2:
mov [rbp-56], r10

mov r10, rsi
cmp r10, rcx
jle .my1
mov r10, rcx

.my1:
cmp r10, r9
jle .my2
mov r10, r9

.my2:
mov [rbp-64], r10

mov r10, rsi
cmp r10, rcx
jge .My1
mov r10, rcx

.My1:
cmp r10, r9
jge .My2
mov r10, r9

.My2:
mov [rbp-72], r10

mov rax, r8
sub rax, rdx
mov [rbp-80], rax
mov rax, r9
sub rax, rcx
mov [rbp-88], rax
imul rax, rdx
mov r10, [rbp-80]
imul r10, rcx
sub rax, r10
mov [rbp-96], rax

mov rax, rdi
sub rax, r8
mov [rbp-104], rax
mov rax, rsi
sub rax, r9
mov [rbp-112], rax
imul rax, r8
mov r10, [rbp-104]
imul r10, r9
sub rax, r10
mov [rbp-120], rax

mov rax, rdx
sub rax, rdi
mov [rbp-128], rax
mov rax, rcx
sub rax, rsi
mov [rbp-136], rax
imul rax, rdi
mov r10, [rbp-128]
imul r10, rsi
sub rax, r10
mov [rbp-144], rax

mov r12, [rbp-64]

.loop_y:
cmp r12, [rbp-72]
jg .done_ret

mov r13, [rbp-48]

mov r14, [rbp-80]
imul r14, r12
mov rax, [rbp-88]
imul rax, r13
sub r14, rax
add r14, [rbp-96]

mov r15, [rbp-104]
imul r15, r12
mov rax, [rbp-112]
imul rax, r13
sub r15, rax
add r15, [rbp-120]

mov rbx, [rbp-128]
imul rbx, r12
mov rax, [rbp-136]
imul rax, r13
sub rbx, rax
add rbx, [rbp-144]

.loop_x:
cmp r13, [rbp-56]
jg .next_y

test r14, r14
js .skip_pixel
test r15, r15
js .skip_pixel
test rbx, rbx
js .skip_pixel

mov rdi, r13
mov rsi, r12
mov rdx, [brush_color]
call glrbm_put_pixel

.skip_pixel:
sub r14, [rbp-88]
sub r15, [rbp-112]
sub rbx, [rbp-136]
inc r13
jmp .loop_x

.next_y:
inc r12
jmp .loop_y

.done_ret:
add rsp, 104
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

glrbm_InterpolatedTriangle:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15
sub rsp, 200

mov r10, [rbp+16]
mov r11, [rbp+24]
mov r12, [rbp+32]

mov rax, rcx
sub rax, rdi
mov r13, r11
sub r13, rsi
imul rax, r13

mov r13, r8
sub r13, rsi
mov r14, r10
sub r14, rdi
imul r13, r14

sub rax, r13
test rax, rax
jz .done_ret
jg .area_pos
xchg rcx, r10
xchg r8, r11
xchg r9, r12
neg rax

.area_pos:
mov [rbp-152], rax

mov rax, rdx
shr rax, 16
and rax, 0xFF
mov [rbp-160], rax
mov rax, rdx
shr rax, 8
and rax, 0xFF
mov [rbp-168], rax
mov rax, rdx
and rax, 0xFF
mov [rbp-176], rax

mov rax, r9
shr rax, 16
and rax, 0xFF
mov [rbp-184], rax
mov rax, r9
shr rax, 8
and rax, 0xFF
mov [rbp-192], rax
mov rax, r9
and rax, 0xFF
mov [rbp-200], rax

mov rax, r12
shr rax, 16
and rax, 0xFF
mov [rbp-208], rax
mov rax, r12
shr rax, 8
and rax, 0xFF
mov [rbp-216], rax
mov rax, r12
and rax, 0xFF
mov [rbp-224], rax

mov r13, rdi
cmp r13, rcx
jle .m1
mov r13, rcx

.m1:
cmp r13, r10
jle .m2
mov r13, r10

.m2:
mov [rbp-48], r13

mov r13, rdi
cmp r13, rcx
jge .M1
mov r13, rcx

.M1:
cmp r13, r10
jge .M2
mov r13, r10

.M2:
mov [rbp-56], r13

mov r13, rsi
cmp r13, r8
jle .my1
mov r13, r8

.my1:
cmp r13, r11
jle .my2
mov r13, r11

.my2:
mov [rbp-64], r13

mov r13, rsi
cmp r13, r8
jge .My1
mov r13, r8

.My1:
cmp r13, r11
jge .My2
mov r13, r11

.My2:
mov [rbp-72], r13

mov rax, r10
sub rax, rcx
mov [rbp-80], rax
mov rax, r11
sub rax, r8
mov [rbp-88], rax
imul rax, rcx
mov r13, [rbp-80]
imul r13, r8
sub rax, r13
mov [rbp-96], rax

mov rax, rdi
sub rax, r10
mov [rbp-104], rax
mov rax, rsi
sub rax, r11
mov [rbp-112], rax
imul rax, r10
mov r13, [rbp-104]
imul r13, r11
sub rax, r13
mov [rbp-120], rax

mov rax, rcx
sub rax, rdi
mov [rbp-128], rax
mov rax, r8
sub rax, rsi
mov [rbp-136], rax
imul rax, rdi
mov r13, [rbp-128]
imul r13, rsi
sub rax, r13
mov [rbp-144], rax

mov r12, [rbp-64]

.loop_y:
cmp r12, [rbp-72]
jg .done_ret

mov r13, [rbp-48]

mov r14, [rbp-80]
imul r14, r12
mov rax, [rbp-88]
imul rax, r13
sub r14, rax
add r14, [rbp-96]

mov r15, [rbp-104]
imul r15, r12
mov rax, [rbp-112]
imul rax, r13
sub r15, rax
add r15, [rbp-120]

mov rbx, [rbp-128]
imul rbx, r12
mov rax, [rbp-136]
imul rax, r13
sub rbx, rax
add rbx, [rbp-144]

.loop_x:
cmp r13, [rbp-56]
jg .next_y

test r14, r14
js .skip_pixel
test r15, r15
js .skip_pixel
test rbx, rbx
js .skip_pixel

mov rax, [rbp-160]
imul rax, r14
mov r10, [rbp-184]
imul r10, r15
add rax, r10
mov r10, [rbp-208]
imul r10, rbx
add rax, r10
xor rdx, rdx
div qword [rbp-152]
mov r8, rax

mov rax, [rbp-168]
imul rax, r14
mov r10, [rbp-192]
imul r10, r15
add rax, r10
mov r10, [rbp-216]
imul r10, rbx
add rax, r10
xor rdx, rdx
div qword [rbp-152]
mov r9, rax

mov rax, [rbp-176]
imul rax, r14
mov r10, [rbp-200]
imul r10, r15
add rax, r10
mov r10, [rbp-224]
imul r10, rbx
add rax, r10
xor rdx, rdx
div qword [rbp-152]

shl r8, 16
shl r9, 8
or r8, r9
or r8, rax
mov rdx, r8

mov rdi, r13
mov rsi, r12
call glrbm_put_pixel

.skip_pixel:
sub r14, [rbp-88]
sub r15, [rbp-112]
sub rbx, [rbp-136]
inc r13
jmp .loop_x

.next_y:
inc r12
jmp .loop_y

.done_ret:
add rsp, 200
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

section .data
gpu_name: db 'gpu',0

align 8
gpu_handle: dq 0

current_x: dq 0
current_y: dq 0
pen_color: dq 0xFFFFFFFF
brush_color: dq 0xFFFFFFFF
fb_ptr: dq 0
screen_width: dq 1680
screen_height: dq 720

align 4096
lib_end: