[bits 64]
default rel

section .data
curr_thread dq 0

;; 0 : rsp
;; 8 : next thread
;; 16 : priority
;; 24 : ticks left
;; 32 : stack base
;; 40 : state


section .text

scheduler_init:
pushfq
cli
mov rdi, 48
call kmalloc

mov [curr_thread], rax
mov qword [rax], 0
mov [rax + 8], rax
mov qword [rax + 16], 1
mov qword [rax + 24], 1
mov qword [rax + 32], 0
mov qword [rax + 40], 1

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

mov rdi, 48
push rax
call kmalloc
pop rdx

mov [rax], rdx
mov [rax + 16], r13
mov [rax + 24], r13
mov [rax + 32], rbx
mov qword [rax + 40], 1

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
