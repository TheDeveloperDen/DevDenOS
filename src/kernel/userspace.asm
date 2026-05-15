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

;; rdi = file buffer
;; rsi = file size
;; rax = virtual entry address
load_shared_library:
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi

cmp dword [r12], 0x4E445644
jne .fail

mov edi, dword [r12 + 0x26]
test edi, edi
jz .fail

lea rbx, [r12 + rdi]
cmp dword [rbx], 0x424C4853
jne .fail

mov r13,[r12 + 0x18]
add r13, 4095
shr r13, 12

mov r14, 0x710000000000

.search_vma:
mov rbx, r14
mov r15, r13
.check_page:
mov rdi, rbx
call is_page_mapped
test rax, rax
jnz .occupied
add rbx, 4096
dec r15
jnz .check_page
jmp .vma_found

.occupied:
lea r14, [rbx + 4096]
jmp .search_vma

.vma_found:
mov rbx, r14
mov r15, r13
.map_loop:
call alloc_page
mov rdi, rbx
mov rsi, rax
mov rdx, 7
call mapPage
add rbx, 4096
dec r15
jnz .map_loop

mov ebx, dword [r12 + 0x20]
add rbx, r12
movzx r15, word [r12 + 0x24]

.copy_sections:
test r15, r15
jz .copy_done

mov rdi, [rbx + 0x00]
sub rdi, [r12 + 0x10]
add rdi, r14
mov rcx, [rbx + 0x18]
mov rsi, [rbx + 0x10]
add rsi, r12

test rcx, rcx
jz .next_section
rep movsb

.next_section:
add rbx, 32
dec r15
jmp .copy_sections

.copy_done:
mov edi, dword [r12 + 0x26]
lea rbx, [r12 + rdi]
mov edi, dword [rbx + 0x08]
test edi, edi
jz .no_relocs

mov r15d, dword [rbx + 0x0C]
shr r15, 3
test r15, r15
jz .no_relocs

lea rbx, [r12 + rdi]
mov r8, r14
sub r8, [r12 + 0x10]

.reloc_loop:
mov rax, [rbx]
add rax, r14
mov rcx, [rax]
add rcx, r8
mov [rax], rcx
add rbx, 8
dec r15
jnz .reloc_loop

.no_relocs:
mov rdi, 24
call kmalloc
mov [rax], r14
mov [rax + 8], r13

cli
mov r8, [curr_thread]
mov r9,[r8 + 64]
mov [rax + 16], r9
mov [r8 + 64], rax
sti

mov rax, [r12 + 0x08]
sub rax, [r12 + 0x10]
add rax, r14
jmp .done

.fail:
xor rax, rax

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret

;; rdi = buffer
;; rsi = size
load_userspace_process:
push rbx
push r12
push r13
push r14
push r15
push rdx
push rcx
push r8

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

mov rdi, [rbx + 0x00]
mov rcx, [rbx + 0x18]
mov rsi, [rbx + 0x10]
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

mov r15, 0x7FFFF0100000
mov r8, [rsp + 8]
mov rcx, [rsp + 16]
mov rdx, [rsp + 24]

test rdx, rdx
jle .skip_args

sub r15, r8
and r15, ~7
mov rdi, r15
mov rsi, rcx
push rcx
mov rcx, r8
rep movsb
pop rcx

mov r10, rdx
shl r10, 3
sub r15, r10

mov rdi, r15
mov rsi, r15
add rsi, r10

push rcx
mov rcx, rdx

.build_argv:
mov [rdi], rsi
add rdi, 8

.skip_str:
mov al, [rsi]
inc rsi
test al, al
jnz .skip_str
dec rcx
jnz .build_argv
pop rcx

mov r11, r15
mov r10, rdx
jmp .args_done

.skip_args:
mov r11, 0
mov r10, 0

.args_done:
and r15, ~15

pop rax
mov cr3, rax

add rsp, 24

mov rdi,[r12 + 0x08]
mov rsi, r15
mov rdx, r14
mov rcx, r14
mov r8, [r12 + 0x18]
mov r9, [r12 + 0x10]
call create_user_thread

mov rdi, r12
call kfree
jmp .fail

.fail2:
call kfree
add rsp, 24
.fail:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret