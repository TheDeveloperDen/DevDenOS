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
invlpg [rdi]
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
invlpg [rdi]
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
invlpg [rdi]
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

push rdi
mov rdi, rax
and rdi, ~0xFFF
call free_page
pop rdi


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

mov rdi, r8
and rdi, ~0xFFF
mov rcx, 512
xor eax, eax
rep scasq
jnz .flush_tlb

mov rax, [rsp]
shr rax, 30
and eax, 0x3FFFF
mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
lea r8, [rbx + rax * 8]
mov rax, [r8]
and rax, ~0xFFF
mov rdi, rax
call free_page
mov qword[r8], 0

mov rdi, r8
and rdi, ~0xFFF
mov rcx, 512
xor eax, eax
rep scasq
jnz .flush_tlb

mov rax, [rsp]
shr rax, 39
and eax, 0x1FF
mov rbx, 0xFFFFFFFFFFFFF000 ; PML4
lea r8, [rbx + rax * 8]
mov rax, [r8]
and rax, ~0xFFF
mov rdi, rax
call free_page
mov qword [r8], 0

.flush_tlb:
mov rax, cr3
mov cr3, rax

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

;; rdi = virtual addr
;; rax = mapped?
is_page_mapped:
push rbx
push rcx
push r8
push rdi

mov rbx, 0xFFFFFFFFFFFFF000 ; PML4
mov rax, rdi
shr rax, 39
and eax, 0x1FF
lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done_false

mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
mov rax, rdi
shr rax, 30
and eax, 0x3FFFF
lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done_false

mov rbx, 0xFFFFFFFFC0000000 ; PD
mov rax, rdi
shr rax, 21
and eax, 0x7FFFFFF
lea r8, [rbx + rax * 8]
mov rax, [r8]
test rax, 1
jz .done_false

test rax, 0x80
jnz .done_true

mov rbx, 0xFFFFFF8000000000 ; PT
mov rax, rdi
shr rax, 12
mov rcx, 0xFFFFFFFFF
and rax, rcx
lea r8, [rbx + rax * 8]
mov rax,[r8]
test rax, 1
jz .done_false

.done_true:
mov rax, 1
jmp .done
.done_false:
xor rax, rax
.done:
pop rdi
pop r8
pop rcx
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
xor rax, rax
pop r9
pop r8
pop rdi
pop rdx
pop rcx
pop rsi
pop rbx
popfq
ret
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


; rdi = page count
; rax = virt addr
alloc_contiguous:
pushfq
cli
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
test r12, r12
jz .fail

mov rcx, r12
call find_free_virt_range
test rbx, rbx
jz .fail
mov r13, rbx

cmp qword [freed_count], r12
jb .use_e820

mov rcx, r12
call find_phys_bitmap_opt
test rax, rax
jnz .got_phys

.use_e820:
mov rcx, r12
call alloc_phys_e820
test rax, rax
jz .fail

.got_phys:
mov r14, rax
xor r15, r15

.map_loop:
cmp r15, r12
jae .map_done

mov rdi, r13
mov rax, r15
shl rax, 12
add rdi, rax

mov rsi, r14
add rsi, rax

mov rdx, 3
call mapPage

inc r15
jmp .map_loop

.map_done:
mov rax, r13
mov rdx, r14
jmp .exit

.fail:
xor rax, rax
xor rdx, rdx

.exit:
pop r15
pop r14
pop r13
pop r12
pop rbx
popfq
ret

; rdi = virt start addr
; rsi = page count
free_contiguous:
pushfq
cli
push rbx
push r12
push r13

mov r12, rdi
mov r13, rsi

test r12, r12
jz .done
test r13, r13
jz .done

xor rbx, rbx

.unmap_loop:
cmp rbx, r13
jae .done

mov rdi, r12
mov rax, rbx
shl rax, 12
add rdi, rax

call unmapPage

inc rbx
jmp .unmap_loop

.done:
pop r13
pop r12
pop rbx
popfq
ret

; rcx = page count
; rbx = virt addr of start (0 if fail)
find_free_virt_range:
push rdi
push rsi
push r8
push r9
push r11

mov rbx, 0xFFFF980000000000

.search:
mov r8, rbx
mov r9, rcx

.check_loop:
mov rdi, r8
call is_page_mapped
test rax, rax
jnz .occupied
add r8, 4096
dec r9
jnz .check_loop
jmp .done

.occupied:
add r8, 4096
mov rbx, r8
mov r11, 0xFFFF9F0000000000
cmp rbx, r11
jb .search
xor rbx, rbx

.done:
pop r11
pop r9
pop r8
pop rsi
pop rdi
ret

; rcx = page count
; rax = phys addr
find_phys_bitmap_opt:
push rbx
push rsi
push rdi
push r8
push r9
push r10
push r11

lea rsi, [page_bitmap]
xor rdx, rdx
xor r8, r8

.loop:
cmp rdx, 16777216
jae .not_found

test rdx, 63
jnz .bit_check
test r8, r8
jnz .bit_check

mov r9, rdx
shr r9, 3
mov rax, [rsi + r9]
test rax, rax
jnz .bit_check

add rdx, 64
jmp .loop

.bit_check:
bt [rsi], rdx
jnc .reset_run

inc r8
cmp r8, rcx
je .found
inc rdx
jmp .loop

.reset_run:
xor r8, r8
inc rdx
jmp .loop

.found:
mov rax, rdx
sub rax, rcx
inc rax

mov r8, rax
mov r9, rcx

.clear_loop:
btr [rsi], r8
dec qword [freed_count]
inc r8
dec r9
jnz .clear_loop

shl rax, 12
jmp .done

.not_found:
xor rax, rax

.done:
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rbx
ret

; rcx = page count
; rax = phys addr of the block (0 if oom)
alloc_phys_e820:
push rbx
push rsi
push rdi
push r8
push r9
push r11

mov r11, rcx
shl r11, 12

.find_page:
movzx rbx, word [e820_idx]
mov rdi, 0x6FF8
movzx rcx, word [rdi]
cmp rbx, rcx
jae .oom

imul rsi, rbx, 24
add rsi, 0x7000

cmp dword [rsi + 16], 1
jne .next_entry

mov rax, [rsi]
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
add r9, r11
cmp r9, rdx
ja .next_entry

mov [nextPage], r9
mov rax, rcx
jmp .done

.next_entry:
inc word [e820_idx]
mov qword [nextPage], 0
jmp .find_page

.oom:
xor rax, rax

.done:
pop r11
pop r9
pop r8
pop rdi
pop rsi
pop rbx
ret
