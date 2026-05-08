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

;; rdi = buffer
;; rsi = size
load_userspace_process:
push rbx
push r12
push r13
push r14
push r15

cmp dword [rdi], 0x4E445644
jne .fail2


mov r12, rdi
mov r13, rsi

call create_address_space
mov r14, rax

mov rax, cr3
push rax
mov cr3, r14

mov r15, [r12 + 0x10]
mov rbx, [r12 + 0x18]
add rbx, 4095
shr rbx, 12

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

mov ebx, dword [r12 + 0x20]
add rbx, r12
movzx r15, word [r12 + 0x24]

.copy_sections:
test r15, r15
jz .copy_done

mov rdi,[rbx + 0x00]
mov rcx,[rbx + 0x18]
mov rsi,[rbx + 0x10]
add rsi, r12

test rcx, rcx
jz .next_section
rep movsb

.next_section:
add rbx, 32
dec r15
jmp .copy_sections

.copy_done:

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

mov rdi,[r12 + 0x08]
mov rsi, 0x7FFFF0000000 + 1048576
mov rdx, 1
mov rcx, r14
mov r8, [r12 + 0x18]
mov r9, [r12 + 0x10]
call create_user_thread

mov rdi, r12
call kfree
jmp .fail

.fail2:
call kfree
.fail:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret