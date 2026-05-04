[bits 64]
default rel

section .data
heap_head   dq 0
heap_tail   dq 0
heap_curr   dq 0xFFFF900000000000
heap_mapped dq 0xFFFF900000000000

;; header
;; 0 : block size
;; 8 : free flag
;; 16 : next block
;; 24 : prev block

section .text

;; rdi = size
;; rax = pointer to memory
kmalloc:
pushfq
cli
push rbx
push r12
push r13
sub rsp, 8

test rdi, rdi
jnz .start
xor rax, rax
add rsp, 8
pop r13
pop r12
pop rbx
popfq
ret

.start:
mov r12, rdi
add r12, 15
and r12, ~15

mov rbx, [heap_head]
test rbx, rbx
jz .need_new

.search:
cmp qword [rbx + 8], 1
jne .next_blk
cmp [rbx], r12
jb .next_blk

mov rcx, [rbx]
mov rdx, r12
add rdx, 48
cmp rcx, rdx
jb .no_split

mov [rbx], r12
lea rdx, [rbx + 32 + r12]

sub rcx, r12
sub rcx, 32
mov [rdx], rcx
mov qword [rdx + 8], 1

mov rcx, [rbx + 16]
mov [rdx + 16], rcx
mov [rdx + 24], rbx
mov [rbx + 16], rdx

test rcx, rcx
jz .update_split_tail
mov [rcx + 24], rdx
jmp .no_split

.update_split_tail:
mov [heap_tail], rdx

.no_split:
mov qword [rbx + 8], 0
lea rax, [rbx + 32]
jmp .exit

.next_blk:
mov rbx, [rbx + 16]
test rbx, rbx
jnz .search

.need_new:
mov r13, r12
add r13, 32

.expand:
mov rax, [heap_curr]
add rax, r13
cmp rax, [heap_mapped]
jbe .alloc_struct

call alloc_page

mov rdi, [heap_mapped]
mov rsi, rax
mov rdx, 3 ; R/W
call mapPage

add qword [heap_mapped], 0x1000 ; + 1 page
jmp .expand

.alloc_struct:
mov rax, [heap_curr]

mov [rax], r12
mov qword [rax + 8], 0
mov qword [rax + 16], 0

mov rdx, [heap_tail]
mov [rax + 24], rdx

test rdx, rdx
jz .first_alloc
mov [rdx + 16], rax
jmp .update_tail

.first_alloc:
mov [heap_head], rax

.update_tail:
mov [heap_tail], rax
add [heap_curr], r13
lea rax, [rax + 32]

.exit:
push rax
mov rdi, rax
mov rcx, r12
shr rcx, 3
xor eax, eax
rep stosq
pop rax

add rsp, 8
pop r13
pop r12
pop rbx
popfq
ret

;; rdi = pointer to free
kfree:
pushfq
cli
push rbx
sub rsp, 8
test rdi, rdi
jz .done

sub rdi, 32
mov qword [rdi + 8], 1

mov rcx, [rdi + 16]
test rcx, rcx
jz .try_prev
cmp qword [rcx + 8], 1
jne .try_prev

mov rax, [rcx]
add rax, 32
add [rdi], rax

mov rax, [rcx + 16]
mov [rdi + 16], rax

test rax, rax
jz .tail_adjustN
mov [rax + 24], rdi
jmp .try_prev

.tail_adjustN:
mov [heap_tail], rdi

.try_prev:
mov rcx, [rdi + 24]
test rcx, rcx
jz .check_shrink
cmp qword [rcx + 8], 1
jne .check_shrink

mov rax, [rdi]
add rax, 32
add [rcx], rax

mov rax, [rdi + 16]
mov [rcx + 16], rax

test rax, rax
jz .tail_adjustP
mov [rax + 24], rcx
jmp .check_shrink

.tail_adjustP:
mov [heap_tail], rcx

.check_shrink:
mov rbx, [heap_tail]
test rbx, rbx
jz .done
cmp qword [rbx + 8], 1
jne .done

mov rax, rbx
add rax, 32
add rax, [rbx]
cmp rax, [heap_curr]
jne .done

mov rdx, [rbx + 24]
mov [heap_tail], rdx
test rdx, rdx
jz .empty_heap
mov qword [rdx + 16], 0
jmp .do_unmap

.empty_heap:
mov qword [heap_head], 0

.do_unmap:
mov [heap_curr], rbx

.unmap_loop:
mov rax, [heap_mapped]
sub rax, 4096
cmp rax, [heap_curr]
jb .done

mov [heap_mapped], rax
mov rdi, rax
call unmapPage
jmp .unmap_loop


.done:
add rsp, 8
pop rbx
popfq
ret