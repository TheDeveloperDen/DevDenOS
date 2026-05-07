[bits 64]
default rel

create_address_space:
push r12
push r13
push r14

call alloc_page
mov r12, rax
mov rdi, r12
mov rcx, 512
xor rax, rax
rep stosq

call alloc_page
mov r13, rax
mov rdi, r13
mov rcx, 512
xor rax, rax
rep stosq

call alloc_page
mov r14, rax
mov rdi, r14
mov rcx, 512
xor rax, rax
rep stosq

mov rax, r13
or rax, 7
mov [r12], rax

mov rax, r14
or rax, 7
mov[r13], rax

lea rsi,[pml4_table + 256 * 8]
lea rdi,[r12 + 256 * 8]
mov rcx, 256
rep movsq

mov rax, r12
or rax, 3
mov [r12 + 511 * 8], rax

mov rsi, pd_table
mov rdi, r14
mov rcx, 32
rep movsq

mov rax, r12
pop r14
pop r13
pop r12
ret

;; rdi = addr
;; rsi = size
load_userspace_process:
push rbx
push r12
push r13
push r14
push r15
mov r12, rdi
mov r13, rsi

call create_address_space
mov r14, rax

mov rax, cr3
push rax
mov cr3, r14

mov rbx, r13
add rbx, 4095
shr rbx, 12
mov r15, 0x4000000
.map:
test rbx, rbx
jz .map_done

call alloc_page
mov rdi, r15
mov rsi, rax
mov rdx, 7
call mapPage
add r15, 4096
dec rbx
jmp .map

.map_done:

mov rdi, 0x4000000
mov rsi, r12
mov rcx, r13
rep movsb

mov rbx, 256
mov r15, 0x7FFFF0000000

.map_stack:
call alloc_page
mov rdi, r15
mov rsi, rax
mov rdx, 7
call mapPage

add r15, 4096
dec rbx
jnz .map_stack

pop rax
mov cr3, rax

mov rdi, 0x4000000
mov rsi, 0x7FFFF0000000 + 1048576
mov rdx, 1
mov rcx, r14
mov r8, r13
call create_user_thread

pop r15
pop r14
pop r13
pop r12
pop rbx
ret