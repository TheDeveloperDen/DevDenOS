[bits 64]
default rel

section .data
e820_idx dw 0
nextPage dq 0
freed_count dq 0
last_idx dq 0

section .bss
page_bitmap: resb 2097152

section .text

;; rdi = virtual address 
;; rsi = physical address 
;; rdx = flags
mapPage:
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13, rsi
mov r14, rdx
mov rbx, 0xFFFFFFFFFFFFF000 ; PML4

mov r15, r12
shr r15, 39
and r15, 0x1FF
lea r8,[rbx + r15 * 8]

mov rax, [r8]
test rax, 1
jnz .has_pdpt

call alloc_page

or rax, 7 ; Present | R/W | User
mov [r8], rax

mov rax, r15
shl rax, 12

mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
mov rdi, rbx
add rdi, rax
mov rcx, 512
xor eax, eax
rep stosq

.has_pdpt:
; Get the PML4 + PDPT index
mov r15, r12
shr r15, 30
and r15, 0x3FFFF
mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
lea r8,[rbx + r15 * 8]

mov rax, [r8]
test rax, 1
jnz .has_pd

call alloc_page

or rax, 7
mov [r8], rax

mov rax, r15
shl rax, 12
mov rdi, 0xFFFFFFFFC0000000 ; PD
add rdi, rax
mov rcx, 512
xor eax, eax
rep stosq

.has_pd:
; Get the PML4 + PDPT + PD index
mov r15, r12
shr r15, 21
and r15, 0x7FFFFFF
mov rbx, 0xFFFFFFFFC0000000 ; PD
lea r8,[rbx + r15 * 8]

mov rax, [r8]
test rax, 1
jnz .has_pt

call alloc_page

or rax, 7
mov[r8], rax

mov rax, r15
shl rax, 12
mov rdi, 0xFFFFFF8000000000 ; PT
add rdi, rax
mov rcx, 512
xor eax, eax
rep stosq

.has_pt:
; Get the PT entry addr
mov rbx, 0xFFFFFF8000000000 ; PT
mov rax, r12
shr rax, 12
mov rcx, 0xFFFFFFFFF
and rax, rcx
lea r8,[rbx + rax * 8]

; Phys addr + flags + present bit
mov rax, r13
and rax, ~0xFFF
or rax, r14
or rax, 1
mov [r8], rax

invlpg [r12]

pop r15
pop r14
pop r13
pop r12
pop rbx
ret

;; rdi = virtual addr to unmap
unmapPage:
push rbx
push rdi

mov rbx, 0xFFFFFFFFFFFFF000 ; PML4
mov rax, rdi
shr rax, 39
and eax, 0x1FF
lea r8,[rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done

mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
mov rax, rdi
shr rax, 30
and eax, 0x3FFFF
lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done

mov rbx, 0xFFFFFFFFC0000000 ; PD
mov rax, rdi
shr rax, 21
and eax, 0x7FFFFFF
lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done

test rax, 0x80
jnz .huge_page

mov rbx, 0xFFFFFF8000000000 ; PT
mov rax, rdi
shr rax, 12
mov rcx, 0xFFFFFFFFF
and rax, rcx
lea r8,[rbx + rax * 8]

mov rax, [r8]
test rax, 1
jz .done


mov qword [r8], 0
invlpg [rdi]

mov rdi, r8
and rdi, ~0xFFF
mov rcx, 512
xor eax, eax
rep scasq
jnz .done

mov rax, [rsp]
shr rax, 21
and eax, 0x7FFFFFF
mov rbx, 0xFFFFFFFFC0000000 ; PD
lea r8, [rbx + rax * 8]

mov rax, [r8]
and rax, ~0xFFF
mov rdi, rax
call free_page

mov qword [r8], 0

.done:
pop rdi
pop rbx
ret

.huge_page:
mov qword [r8], 0
invlpg [rdi]
pop rdi
pop rbx
ret

;; rax = physical addr of the allocated page
alloc_page:
pushfq
cli
push rbx
push rsi
push rcx
push rdx
push rdi
push r8
push r9

cmp qword[freed_count], 0
je .no_freed

mov rcx, [last_idx]
mov r8, rcx
lea rsi, [page_bitmap]

.scan:
mov rax,[rsi + rcx * 8]
test rax, rax
jnz .found
inc rcx
cmp rcx, 262144
jb .skip_wrap
xor rcx, rcx

.skip_wrap:
cmp rcx, r8
je .no_freed
jmp .scan

.found:
mov [last_idx], rcx
bsf rdx, rax
shl rcx, 6
add rcx, rdx
btr qword[page_bitmap], rcx
dec qword[freed_count]
mov rax, rcx
shl rax, 12
pop r9
pop r8
pop rdi
pop rdx
pop rcx
pop rsi
pop rbx
popfq
ret

.no_freed:

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

pop r9
pop r8
pop rdi
pop rdx
pop rcx
pop rsi
pop rbx
popfq
ret

.next_entry:
inc word [e820_idx]
mov qword [nextPage], 0
jmp .find_page

.oom:
cli
hlt
jmp $

;; rdi = physical addr of the page to free
free_page:
pushfq
cli
push rax
push rcx
mov rax, rdi

mov rcx, 0x1000000000 
cmp rax, rcx
jae .done

; protect the kernel
mov rcx, kernel_end
add rcx, 0xFFF
and rcx, ~0xFFF
cmp rax, rcx
jb .done

shr rax, 12
bts qword [page_bitmap], rax

jc .done
mov rcx, rax
shr rcx, 6
cmp rcx,[last_idx]

jae .skip_idx
mov [last_idx], rcx

.skip_idx:
inc qword [freed_count]
.done:
pop rcx
pop rax
popfq
ret
