[bits 64]
default rel

section .data
e820_idx dw 0
nextPage dq 0

section .text

mapPage:
push rbx
push r12
push r13

mov r12, rdi
mov r13, rsi

mov rax, cr3
and rax, ~0xFFF
mov rbx, rax

mov rcx, 39
.walk:
mov rax, r12
shr rax, cl
and rax, 0x1ff

lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jnz .next
push rcx
push rdx
push r8
call alloc_page

push rax
mov rdi, rax
mov rcx, 512
xor eax, eax
rep stosq
pop rax

pop r8
pop rdx
pop rcx

or rax, 7
mov [r8], rax
.next:
and rax, ~0xFFF
mov rbx, rax

sub rcx, 9
cmp rcx, 12
jg .walk

mov rax, r12
shr rax, 12
and rax, 0x1FF

mov rcx, r13
and rcx, ~0xFFF
or rcx, rdx
or rcx, 1

mov [rbx + rax * 8], rcx
invlpg [r12]

pop r13
pop r12
pop rbx
ret

unmapPage:
push rbx
mov rax, cr3
and rax, ~0xFFF
mov rbx, rax
mov rcx, 39

.walk:
mov rax, rdi
shr rax, cl
and rax, 0x1FF

mov rax, [rbx + rax *8]
test rax, 1
jz .done

and rax, ~0xFFF
mov rbx, rax

sub rcx, 9
cmp rcx, 12
jg .walk

mov rax, rdi
shr rax, 12
and rax, 0x1FF
mov qword [rbx + rax * 8], 0

invlpg [rdi]
.done:
pop rbx
ret

alloc_page:
push rbx
push rsi
.find_page:
movzx rbx, word [e820_idx]
mov rdi, 0x6FF8
movzx rcx, word [rdi]
cmp rbx, rcx
jae .oom

imul rsi, rbx, 24
add rsi, 0x7000

cmp dword[rsi + 16], 1
jne .next_entry

mov rax,[rsi]
mov rdx, [rsi + 8]
add rdx, rax

mov rcx, [nextPage]
test rcx, rcx
jnz .chk_overlap
mov rcx, rax

.chk_overlap:
mov r8, kernel_end
add r8, 0xFFF
and r8, ~0xFFF
cmp rcx, r8
jae .align_page
mov rcx, r8

.align_page:
add rcx, 0xFFF
and rcx, ~0xFFF

mov r9, rcx
add r9, 4096
cmp r9, rdx
ja .next_entry

mov [nextPage], r9
mov rax, rcx

pop rsi
pop rbx
ret

.next_entry:
inc word [e820_idx]
mov qword [nextPage], 0
jmp .find_page

.oom:
cli
hlt
jmp $
