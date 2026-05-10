[bits 64]
default rel

section .data
curr_thread dq 0
thread_to_free dq 0

;; 0 : rsp
;; 8 : next thread
;; 16 : priority
;; 24 : ticks left
;; 32 : stack base
;; 40 : state
;; 48 : cr3

section .text

scheduler_init:
pushfq
cli
mov rdi, 64
call kmalloc

mov [curr_thread], rax
mov qword [rax], 0
mov [rax + 8], rax
mov qword [rax + 16], 1
mov qword [rax + 24], 1
mov qword [rax + 32], 0
mov qword [rax + 40], 1

mov rcx, cr3
mov [rax + 48], rcx

popfq
ret

;; rdi = function pointer
;; rsi = priority
create_thread:
pushfq
cli
push rbx
push r12
push r13

mov r12, rdi
mov r13, rsi

mov rdi, 8192
call kmalloc
mov rbx, rax

lea rax, [rbx + 8192]

sub rax, 8
mov qword [rax], 0x10 ; SS
sub rax, 8
lea rdx, [rbx + 8192]
mov [rax], rdx ; RSP
sub rax, 8
mov qword [rax], 0x202 ; rflags
sub rax, 8
mov qword [rax], 0x08 ; CS
sub rax, 8
mov [rax], r12 ; RIP

sub rax, 120
mov rdi, rax
mov r8, rax
mov rcx, 15
xor eax, eax
rep stosq
mov rax, r8

mov rdi, 64
push rax
call kmalloc
pop rdx

mov [rax], rdx
mov [rax + 16], r13
mov [rax + 24], r13
mov [rax + 32], rbx
mov qword [rax + 40], 1

mov rcx, cr3
mov [rax + 48], rcx
mov qword [rax + 56], 0

mov rcx, [curr_thread]
mov rdx, [rcx + 8]
mov [rax + 8], rdx
mov [rcx + 8], rax

pop r13
pop r12
pop rbx
popfq
ret

exit_thread:
cli
mov rax, [curr_thread]
mov rbx, [rax + 56]
test rbx, rbx
jz .skip_unmap

add rbx, 4095
shr rbx, 12
mov r12, [rax + 72]
.unmap:
test rbx, rbx
jz .unmap_done

mov rdi, r12
call unmapPage
add r12, 4096
dec rbx
jmp .unmap

.unmap_done:
; Unmap the stack
mov rbx, 256
mov r12, 0x7FFFF0000000
.unmap_stack:
mov rdi, r12
call unmapPage

add r12, 4096
dec rbx
jnz .unmap_stack


mov rax, [curr_thread]
mov rbx, [rax + 64]

.free_vmas:
test rbx, rbx
jz .vmas_done

mov r12, [rbx]
mov r13, [rbx + 8]

.unmap_vma:
test r13, r13
jz .next_vma
mov rdi, r12
call unmapPage
add r12, 4096
dec r13
jmp .unmap_vma

.next_vma:
mov r14, [rbx + 16]
mov rdi, rbx

call kfree
mov rbx, r14
jmp .free_vmas

.vmas_done:
mov r12, 0 ; start pml4 at 0

.clean_pml4:
cmp r12, 256
jae .clean_done

mov rbx, 0xFFFFFFFFFFFFF000 ; PML4
mov rax, [rbx + r12 * 8]
test rax, 1
jz .next_pml4

mov r13, 0 ; start pdpt at 0
.clean_pdpt:
cmp r13, 512
jae .free_pdpt

mov rbx, 0xFFFFFFFFFFE00000 ; PDPT
mov r14, r12
shl r14, 12
add rbx, r14

mov rax, [rbx + r13 * 8]
test rax, 1
jz .next_pdpt

push r13
push rbx

mov r15, 0
.clean_pd:
cmp r15, 512
jae .free_pd

mov rbx, 0xFFFFFFFFC0000000 ; PD
mov r14, r12
shl r14, 9

add r14, r13
shl r14, 12
add rbx, r14

mov rax, [rbx + r15 * 8]
test rax, 1
jz .next_pd

test rax, 0x80
jnz .next_pd

mov rdi, rax
and rdi, ~0xFFF
call free_page

.next_pd:
inc r15
jmp .clean_pd

.free_pd:
pop rbx
pop r13

mov rdi,[rbx + r13 * 8]
and rdi, ~0xFFF
call free_page

.next_pdpt:
inc r13
jmp .clean_pdpt

.free_pdpt:
mov rbx, 0xFFFFFFFFFFFFF000
mov rax, [rbx + r12 * 8]
mov rdi, rax
and rdi, ~0xFFF
call free_page

.next_pml4:
inc r12
jmp .clean_pml4

.clean_done:
mov rcx, pml4_table
mov cr3, rcx
mov rax, [curr_thread]
mov rdi, [rax + 48]
call free_page

.skip_unmap:
mov rax, [curr_thread]
mov qword [rax + 40], 0
sti
call yield_cpu
.halt:
hlt
jmp .halt


;; rdi = current rsp
schedule:
mov rax, [curr_thread]
test rax, rax
jz .nosch

mov [rax], rdi

dec qword [rax + 24]
jg .done

mov rcx, [rax + 16]
mov [rax + 24], rcx

.find_next:
mov rcx, rax
mov rax, [rax + 8]

cmp qword [rax + 40], 0
jne .alive

cmp rcx, rax
je .alive

mov rdx, [rax + 8]
mov [rcx + 8], rdx

push rcx
push rax

mov rdi, [rax + 32]

call kfree

pop rdi
call kfree

pop rax
jmp .find_next

.alive:
mov [curr_thread], rax

mov rdx, [rax + 32]
add rdx, 8192
mov [tss + 4], rdx

mov rcx, [rax + 48]
mov rdx, cr3
cmp rcx, rdx
je .done_cr3
mov cr3, rcx

.done_cr3:

.done:
mov rax, [rax]
ret

.nosch:
mov rax, rdi
ret


yield_sch:
mov rax, [curr_thread]
test rax, rax
jz .nosch

mov [rax], rdi

mov rcx, [rax + 16]
mov [rax + 24], rcx

jmp schedule.find_next

.nosch:
mov rax, rdi
ret

yield_cpu:
int 0x80
ret

;; rdi = user rip
;; rsi = user rsp
;; rdx = priority
;; rcx = cr3
create_user_thread:
pushfq
cli
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13, rsi
mov r14, rdx
mov r15, rcx
push r8
push r9

mov rdi, 8192
call kmalloc
mov rbx, rax

lea rax, [rbx + 8192]

sub rax, 8
mov qword [rax], 0x33 ; user DS
sub rax, 8
mov[rax], r13 ; User SP
sub rax, 8
mov qword [rax], 0x202 ; RFLAGS
sub rax, 8
mov qword [rax], 0x3B ; User CS
sub rax, 8
mov [rax], r12

sub rax, 120
mov rdi, rax
mov r8, rax
mov rcx, 15
xor eax, eax
rep stosq
mov rax, r8

mov rdi, 88
push rax
call kmalloc
pop rdx

mov [rax], rdx
mov [rax + 16], r14
mov[rax + 24], r14
mov [rax + 32], rbx
mov qword [rax + 40], 1
mov [rax + 48], r15
pop r9
pop r8
mov [rax + 56], r8
mov qword [rax + 64], 0
mov [rax + 72], r9

mov rcx, [curr_thread]

mov rdx, [rcx + 8]
mov [rax + 8], rdx
mov[rcx + 8], rax

pop r15
pop r14
pop r13
pop r12
pop rbx
popfq
ret