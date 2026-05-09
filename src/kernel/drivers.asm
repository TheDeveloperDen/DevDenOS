[bits 64]
default rel

section .data
driver_list_head dq 0
driver_list_tail dq 0
next_driver_handle dq 1

kernel_api_table:
dq kmalloc
dq kfree
dq mapPage
dq unmapPage
dq alloc_page
dq free_page
dq pci_read_dword
dq pci_write_dword
dq pci_find_device

section .text

drivers_init:
mov qword [driver_list_head], 0
mov qword [driver_list_tail], 0
mov qword [next_driver_handle], 1
ret

;; rdi = buffer
;; rsi = size
load_kernel_driver:
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13, rsi

cmp dword [rdi], 0x4E445644
jne .fail

mov cx, word [rdi + 0x06]
test cx, 2
jz .fail

mov eax, dword [r12 + 0x26]
test eax, eax
jz .fail

lea rbx, [r12 + rax]
cmp dword [rbx], 0x5652444B
jne .fail

lea rdi, [rbx + 0x10]
call driver_find_by_name
test rax, rax
jz .not_loaded

mov r15, rax
mov rdi, r12
call kfree
mov rax, r15
jmp .done

.not_loaded:

mov rdi, [r12 + 0x18]
call kmalloc
test rax, rax
jz .fail
mov r14, rax

mov ebx, dword[r12 + 0x20]
add rbx, r12
movzx r15, word[r12 + 0x24]

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
test edi, edi
jz .no_relocs
    
lea rbx, [r12 + rdi]
cmp dword [rbx], 0x5652444B
jne .fail

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
mov rdi, 40
call kmalloc
mov r15, rax

mov qword [r15], 0
mov rbx, [next_driver_handle]
mov [r15 + 8], rbx
inc qword [next_driver_handle]

mov edi, dword [r12 + 0x26]
test edi, edi
jz .skip_name
lea rsi, [r12 + rdi + 0x10]
lea rdi, [r15 + 24]
mov rcx, 16
rep movsb
jmp .name_done

.skip_name:
lea rdi, [r15 + 24]
mov rcx, 16
xor al, al
rep stosb

.name_done:
mov rax, [r12 + 0x08]
mov r8, r14
sub r8, [r12 + 0x10]
add rax, r8

lea rdi, [kernel_api_table]
push r12
push r13
call rax
pop r13
pop r12

mov [r15 + 16], rax

mov rdi, r12
call kfree

cli
mov rdx, [driver_list_tail]
test rdx, rdx
jz .first_driver
mov [rdx], r15
mov [driver_list_tail], r15
jmp .list_done

.first_driver:
mov [driver_list_head], r15
mov [driver_list_tail], r15

.list_done:
sti

mov rax, [r15 + 8]
jmp .done

.fail:
mov rdi, r12
call kfree
xor rax, rax

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret

driver_find_by_name:
push rbx
push r12
mov r12, rdi

mov rbx, [driver_list_head]

.search_loop:
test rbx, rbx
jz .not_found

lea rdi, [rbx + 24]
mov rsi, r12
mov rcx, 16

.str_cmp:
mov al, [rdi]
mov dl, [rsi]
cmp al, dl
jne .next_node
test al, al
jz .found
inc rdi
inc rsi
dec rcx
jnz .str_cmp

.found:
mov rax, [rbx + 8]
pop r12
pop rbx
ret

.next_node:
mov rbx, [rbx]
jmp .search_loop

.not_found:
xor rax, rax
pop r12
pop rbx
ret

driver_invoke:
push rbx
mov rbx, [driver_list_head]

.loop:
test rbx, rbx
jz .not_found

cmp[rbx + 8], rdi
je .found

mov rbx, [rbx]
jmp .loop

.found:
mov rax, [rbx + 16]
mov rdi, rsi
mov rsi, rdx
mov rdx, rcx
call rax
pop rbx
ret

.not_found:
mov rax, -1
pop rbx
ret