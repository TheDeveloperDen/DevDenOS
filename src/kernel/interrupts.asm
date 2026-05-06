[bits 64]
default rel


section .data
align 8
idtr:
dw 256 * 16 - 1
dq idt_table

pit_tick dq 0

section .bss
align 16
idt_table: resb 256 * 16


section .text


%macro ISR_ERR 2
isr_%1:
cli
mov rdi, 0xb8000
mov word [rdi], %2
hlt
jmp isr_%1
%endmacro


idt_init:
push rax
push rcx
push rdi

lea rdi, [idt_table]
mov rcx, 512
xor eax, eax
rep stosq

lea rax, [isr_DIV]
mov rdi, 0
call idt_set_entry

lea rax, [isr_UD]
mov rdi, 6
call idt_set_entry

lea rax, [isr_DF]
mov rdi, 8
call idt_set_entry

lea rax, [isr_GPF]
mov rdi, 13
call idt_set_entry

lea rax, [isr_PF]
mov rdi, 14
call idt_set_entry

lea rax, [irq_PIT]
mov rdi, 32
call idt_set_entry

lea rax, [isr_YIELD]
mov rdi, 0x80
call idt_set_entry

lidt [idtr]

pop rdi
pop rcx
pop rax
ret

;; rdi = vector num
;; rax = handle addr
idt_set_entry:
push rbx
lea rbx, [idt_table]
shl rdi, 4
add rbx, rdi

mov [rbx], ax
mov word [rbx + 2], 0x08
mov byte [rbx + 4], 0
mov byte [rbx + 5], 0x8E
shr rax, 16
mov [rbx + 6], ax
shr rax, 16
mov [rbx + 8], eax
mov dword [rbx + 12], 0
pop rbx
ret



remap_pic:
mov al, 0x11
out 0x20, al
out 0xeb, al
out 0xa0, al
out 0xeb, al


mov al, 0x20
out 0x21, al
out 0xeb, al
mov al, 0x28
out 0xa1, al
out 0xeb, al

mov al, 0x04
out 0x21, al
out 0xeb, al
mov al, 0x02
out 0xa1, al
out 0xeb, al

mov al, 0x01
out 0x21, al
out 0xeb, al
out 0xa1, al
out 0xeb, al

mov al, 0xfe
out 0x21, al
mov al, 0xff
out 0xa1, al
ret


pit_init:
mov al, 0x36
out 0x43, al

mov al, 0xa9
out 0x40, al
mov al, 0x04
out 0x40, al

ret

;; rdi = irq num
pic_eoi:
push rax

cmp rdi, 8
jb .master

mov al, 0x20
out 0xa0, al

.master:
mov al, 0x20
out 0x20, al

pop rax
ret

ISR_ERR DIV, 0x4f44
ISR_ERR GPF, 0x4f47
ISR_ERR PF, 0x4f50
ISR_ERR DF, 0x4f46
ISR_ERR UD, 0x4f55

irq_PIT:
push r15
push r14
push r13
push r12
push r11
push r10
push r9
push r8
push rdi
push rsi
push rbp
push rbx
push rdx
push rcx
push rax

inc qword [pit_tick]

mov rdi, 0
call pic_eoi

mov rdi, rsp
call schedule
mov rsp, rax

pop rax
pop rcx
pop rdx
pop rbx
pop rbp
pop rsi
pop rdi
pop r8
pop r9
pop r10
pop r11
pop r12
pop r13
pop r14
pop r15
iretq

isr_YIELD:
push r15
push r14
push r13
push r12
push r11
push r10
push r9
push r8
push rdi
push rsi
push rbp
push rbx
push rdx
push rcx
push rax

mov rdi, rsp
call yield_sch
mov rsp, rax

pop rax
pop rcx
pop rdx
pop rbx
pop rbp
pop rsi
pop rdi
pop r8
pop r9
pop r10
pop r11
pop r12
pop r13
pop r14
pop r15
iretq

