[bits 64]
default rel

;; rdi = TGA buffer
;; rsi = buffer size
;; rax = allocated ARGB image buffer (0 on fail)
tga_parse:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15
push r10
push r11

mov r12, rdi
mov r13, rsi

cmp r13, 18
jl .fail

movzx r14d, byte [r12 + 13]
shl r14d, 8
movzx eax, byte [r12 + 12]
add r14d, eax

movzx r15d, byte[r12 + 15]
shl r15d, 8
movzx eax, byte [r12 + 14]
add r15d, eax

movzx r8d, byte [r12 + 11]
shl r8d, 8
movzx eax, byte [r12 + 10]
add r8d, eax

mov r9d, 18
cmp byte [r12 + 1], 0
je .m_done
movzx eax, byte [r12 + 7]
shr eax, 3
movzx ecx, byte [r12 + 5]
imul eax, ecx
add r9d, eax

.m_done:
test r14d, r14d
jz .fail
test r15d, r15d
jz .fail

mov eax, r14d
imul eax, r15d
add eax, 2
shl eax, 2

push rax
add eax, 4095
shr eax, 12
mov rsi, rax
mov rax, 3
xor rdi, rdi
mov rdx, 3
mov r10, 0x22
int 0x81
pop rcx

cmp rax, -1
je .fail
test rax, rax
jz .fail

mov rbx, rax
mov[rbx], r14d
mov [rbx + 4], r15d

mov al, byte [r12 + 2]
cmp al, 1
je .case_1
cmp al, 2
je .case_2
cmp al, 9
je .case_9
cmp al, 10
je .case_10
jmp .fail

.case_1:
cmp byte [r12 + 6], 0
jne .fail

cmp byte [r12 + 4], 0
jne .fail

cmp byte [r12 + 3], 0
jne .fail

mov cl, byte [r12 + 7]
cmp cl, 24
je .c1_ok

cmp cl, 32
jne .fail

.c1_ok:
xor r11d, r11d
xor r10d, r10d

.c1_y:
cmp r11d, r15d
jge .done
test r8d, r8d
jnz .c1_yo
mov edx, r15d
sub edx, r11d
dec edx

jmp .c1_yk

.c1_yo:
mov edx, r11d

.c1_yk:
imul edx, r14d
xor ecx, ecx

.c1_x:
cmp ecx, r14d
jge .c1_nx
mov edi, r9d
add edi, edx
inc edx
movzx edi, byte [r12 + rdi]
movzx esi, byte [r12 + 7]
shr esi, 3
imul edi, esi
add edi, 18
call .store_pixel_j

inc ecx
jmp .c1_x

.c1_nx:
inc r11d
jmp .c1_y


.case_2:
cmp byte [r12 + 5], 0
jne .fail
cmp byte[r12 + 6], 0
jne .fail
cmp byte[r12 + 1], 0
jne .fail
mov cl, byte [r12 + 16]
cmp cl, 24
je .c2_ok
cmp cl, 32
jne .fail

.c2_ok:
xor r11d, r11d
xor r10d, r10d

.c2_y:
cmp r11d, r15d
jge .done
test r8d, r8d
jnz .c2_yo
mov edi, r15d
sub edi, r11d
dec edi
jmp .c2_yk

.c2_yo:
mov edi, r11d

.c2_yk:
imul edi, r14d
movzx esi, byte [r12 + 16]
shr esi, 3
imul edi, esi
add edi, 18 
xor ecx, ecx

.c2_x:
cmp ecx, r14d
jge .c2_nx
call .store_pixel_j_16
movzx esi, byte[r12 + 16]
shr esi, 3
add edi, esi
inc ecx
jmp .c2_x

.c2_nx:
inc r11d
jmp .c2_y

.case_9:
cmp byte [r12 + 6], 0
jne .fail

cmp byte [r12 + 4], 0
jne .fail

cmp byte [r12 + 3], 0
jne .fail

mov cl, byte [r12 + 7]
cmp cl, 24
je .c9_ok
cmp cl, 32

jne .fail

.c9_ok:
xor r11d, r11d
xor r10d, r10d
xor ecx, ecx
mov eax, r14d
imul eax, r15d

.c9_loop:
cmp ecx, eax
jge .done
cmp r9d, r13d
jge .done
movzx edx, byte[r12 + r9]
inc r9d
cmp edx, 127
jle .c9_else

sub edx, 127
add ecx, edx

movzx edi, byte [r12 + r9]
inc r9d
movzx esi, byte [r12 + 7]

shr esi, 3
imul edi, esi
add edi, 18

.c9_w1:
test edx, edx
jz .c9_loop
dec edx
call .check_i
call .store_pixel_j
jmp .c9_w1

.c9_else:
inc edx
add ecx, edx

.c9_w2:
test edx, edx
jz .c9_loop
dec edx
movzx edi, byte [r12 + r9]
inc r9d
movzx esi, byte[r12 + 7]

shr esi, 3
imul edi, esi
add edi, 18

call .check_i
call .store_pixel_j
jmp .c9_w2

.case_10:
cmp byte [r12 + 5], 0
jne .fail

cmp byte [r12 + 6], 0
jne .fail

cmp byte [r12 + 1], 0
jne .fail

mov cl, byte [r12 + 16]
cmp cl, 24
je .c10_ok
cmp cl, 32
jne .fail

.c10_ok:
xor r11d, r11d
xor r10d, r10d
xor ecx, ecx
mov eax, r14d
imul eax, r15d

.c10_loop:
cmp ecx, eax
jge .done
cmp r9d, r13d
jge .done
movzx edx, byte [r12 + r9]
inc r9d
cmp edx, 127
jle .c10_else

sub edx, 127
add ecx, edx

.c10_w1:
test edx, edx
jz .c10_post

dec edx
call .check_i
mov edi, r9d

call .store_pixel_j_16
jmp .c10_w1

.c10_post:
movzx esi, byte[r12 + 16]
shr esi, 3
add r9d, esi
jmp .c10_loop

.c10_else:
inc edx
add ecx, edx

.c10_w2:
test edx, edx
jz .c10_loop
dec edx
call .check_i

mov edi, r9d
call .store_pixel_j_16

movzx esi, byte[r12 + 16]
shr esi, 3
add r9d, esi
jmp .c10_w2

.check_i:
push rax
push rdx
mov eax, r10d
xor edx, edx
div r14d
test edx, edx

jnz .check_done
test r8d, r8d

jnz .check_o
mov eax, r15d
sub eax, r11d
dec eax
jmp .check_m

.check_o:
mov eax, r11d

.check_m:
imul eax, r14d
mov r10d, eax
inc r11d

.check_done:
pop rdx
pop rax
ret

.store_pixel_j:
push rax
push rcx
movzx eax, byte [r12 + 7]
cmp eax, 32
je .spj_32
mov eax, 0xFF000000
jmp .spj_st

.spj_32:
movzx eax, byte[r12 + rdi + 3]
shl eax, 24

.spj_st:
movzx ecx, byte [r12 + rdi + 2]
shl ecx, 16
or eax, ecx

movzx ecx, byte [r12 + rdi + 1]
shl ecx, 8
or eax, ecx

movzx ecx, byte [r12 + rdi]
or eax, ecx
mov[rbx + 8 + r10 * 4], eax

inc r10d
pop rcx
pop rax
ret

.store_pixel_j_16:
push rax
push rcx
movzx eax, byte [r12 + 16]
cmp eax, 32
je .spj16_32
mov eax, 0xFF000000
jmp .spj16_st

.spj16_32:
movzx eax, byte [r12 + rdi + 3]
shl eax, 24

.spj16_st:
movzx ecx, byte[r12 + rdi + 2]
shl ecx, 16
or eax, ecx

movzx ecx, byte [r12 + rdi + 1]
shl ecx, 8
or eax, ecx

movzx ecx, byte [r12 + rdi]
or eax, ecx
mov [rbx + 8 + r10 * 4], eax

inc r10d
pop rcx
pop rax
ret

.fail:
xor rax, rax
jmp .exit

.done:
mov rax, rbx

.exit:
pop r11
pop r10
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret