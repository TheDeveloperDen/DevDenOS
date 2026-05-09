[bits 64]
default rel


section .data
align 8
idtr:
dw 256 * 16 - 1
dq idt_table

cursor_x dq 0
cursor_y dq 0

pit_tick dq 0

%include "drivers/bga/vga_font.asm"

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
mov rsi, 0x8E
call idt_set_entry

lea rax, [isr_UD]
mov rdi, 6
mov rsi, 0x8E
call idt_set_entry

lea rax, [isr_DF]
mov rdi, 8
mov rsi, 0x8E
call idt_set_entry

lea rax, [isr_GPF]
mov rdi, 13
mov rsi, 0x8E
call idt_set_entry

lea rax, [isr_PF]
mov rdi, 14
mov rsi, 0x8E
call idt_set_entry

lea rax, [irq_PIT]
mov rdi, 32
mov rsi, 0x8E
call idt_set_entry

lea rax, [isr_YIELD]
mov rdi, 0x80
mov rsi, 0xEE
call idt_set_entry

lea rax, [isr_SYSCALL]
mov rdi, 0x81
mov rsi, 0xEE
call idt_set_entry

lidt [idtr]

pop rdi
pop rcx
pop rax
ret

;; rdi = vector num
;; rax = handle addr
;; rsi = attr
idt_set_entry:
push rbx
lea rbx, [idt_table]
shl rdi, 4
add rbx, rdi

mov [rbx], ax
mov word [rbx + 2], 0x08
mov byte [rbx + 4], 0
mov byte [rbx + 5], sil
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

isr_SYSCALL:
cmp rax, 1
je exit_thread
cmp rax, 2
je .sys_write
cmp rax, 3
je .sys_mmap
cmp rax, 4
je .sys_unmap
cmp rax, 5
je .sys_get_driver
cmp rax, 6
je .sys_driver_invoke
cmp rax, 7
je .sys_load_driver
iretq

;; rax = 5
;; rdi = driver name
.sys_get_driver:
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11

call driver_find_by_name

pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

;; rax = 6
;; rdi = handle
;; rsi = function
;; rdx = in buffer
;; r10 = out buffer
.sys_driver_invoke:
mov rcx, r10
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11

call driver_invoke

pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

;; rax = 7
;; rdi = filename
.sys_load_driver:
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11

call fat32_load_file
test rax, rax
jz .load_fail

mov rdi, rax
mov rsi, rdx
call load_kernel_driver
jmp .load_done

.load_fail:
xor rax, rax

.load_done:
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

;; rax = 2
;; rdi = fd
;; rsi = buffer pointer
;; rdx = len
.sys_write:
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10

mov rbx, rsi
mov rcx, rdx

.write_loop:
test rcx, rcx
jz .write_done

movzx rax, byte [rbx]

cmp al, 10
je .newline

call .draw_char

add qword [cursor_x], 8
cmp qword [cursor_x], 1680
jb .char_done

.newline:
mov qword [cursor_x], 0
add qword[cursor_y], 16

cmp qword [cursor_y], 720
jb .char_done

push rax
push rcx
push rdi
push rsi

mov rdi, 0xE0000000
mov rsi, 0xE0000000 + 81920
mov rcx, 450560
rep movsq

mov rdi, 0xE0000000 + 3604480
mov rcx, 10240
xor rax, rax
rep stosq

pop rsi
pop rdi
pop rcx
pop rax

mov qword [cursor_y], 704

.char_done:
inc rbx
dec rcx
jmp .write_loop

.write_done:
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

;; rax = character to draw
.draw_char:
push rax
push rbx
push rcx
push rdx
push rdi
push rsi
push r8
push r9

shl rax, 4
lea rsi, [vga_font + rax]

mov rdi, [cursor_y]
imul rdi, 1680
add rdi, [cursor_x]
shl rdi, 2
mov r8, 0xE0000000
add rdi, r8

mov r8, 16

.row_loop:
mov dl, [rsi]
mov r9, 8
mov rcx, rdi

.col_loop:
shl dl, 1
jc .draw_fg

mov dword [rcx], 0x00000000
jmp .next_pixel

.draw_fg:
mov dword [rcx], 0xFFFFFFFF

.next_pixel:
add rcx, 4
dec r9
jnz .col_loop

inc rsi
add rdi, 1680 * 4
dec r8
jnz .row_loop

pop r9
pop r8
pop rsi
pop rdi
pop rdx
pop rcx
pop rbx
pop rax
ret

;; rax = 3
;; rdi = virtual addr
;; rsi = no of pages
;; rdx = prot
;; r10 = flags
.sys_mmap:
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13, rsi

test r13, r13
jz .mmap_err

cmp r13, 0x7FFFFFFF
ja .mmap_err

test r10, 0x20
jz .mmap_err

mov r14, 5
test rdx, 2
jz .prot_parsed
or r14, 2
.prot_parsed:

test r12, 0xFFF
jnz .mmap_err

test r10, 0x10
jnz .check_bounds

test r12, r12
jz .search_vma2

mov rbx, r12
mov r15, r13
.check_hint:
mov rdi, rbx
call is_page_mapped
jnz .search_vma2
add rbx, 4096
dec r15
jnz .check_hint
jmp .check_bounds


.search_vma2:
mov r12, 0x700000000000
.search_vma:
mov rbx, r12
mov r15, r13

.check_vma_page:
mov rdi, rbx
call is_page_mapped
test rax, rax
jnz .vma_occupied
add rbx, 4096
dec r15
jnz .check_vma_page
jmp .check_bounds

.vma_occupied:
lea r12, [rbx + 4096]
mov rax, 0x00007FFFF0000000
cmp r12, rax
jae .mmap_err
jmp .search_vma

.check_bounds:
mov rax, r13
shl rax, 12
add rax, r12
jc .mmap_err
mov rbx, 0x00007FFFFFFFFFFF
cmp rax, rbx
ja .mmap_err

mov rbx, r12
mov r15, r13
.unmap_existing:
mov rdi, rbx
call is_page_mapped
test rax, rax
jz .skip_unmap
mov rdi, rbx
call unmapPage

.skip_unmap:
add rbx, 4096
dec r15
jnz .unmap_existing

mov rbx, r12
mov r15, r13

mov r8, [curr_thread]
lea r9, [r8 + 64]

.clean_vmas:
mov r10, [r9]
test r10, r10
jz .clean_vmasok

mov rcx, [r10]
cmp rcx, r12
jb .keep_vma

mov rax, [r10 + 8]
shl rax, 12
add rax, rcx

mov rdi, r13
shl rdi, 12
add rdi, r12

cmp rax, rdi
ja .keep_vma

mov rcx, [r10 + 16]
mov [r9], rcx

push r9
mov rdi, r10
call kfree
pop r9
jmp .clean_vmas

.keep_vma:
lea r9, [r10 + 16]
jmp .clean_vmas

.clean_vmasok:
mov rbx, r12
mov r15, r13

.mmap_loop:
test r15, r15
jz .mmap_done

call alloc_page
test rax, rax
jz .mmap_rollback

push rax

mov rdi, rbx
mov rsi, rax
mov rdx, r14
or rdx, 2
call mapPage

mov rdi, rbx
mov rcx, 512
xor eax, eax
rep stosq

pop rax

test r14, 2
jnz .next_page
mov rdi, rbx
mov rsi, rax
mov rdx, r14
call mapPage

.next_page:
add rbx, 4096
dec r15
jmp .mmap_loop

.mmap_rollback:
mov r15, rbx
mov rbx, r12

.rollback_loop:
cmp rbx, r15
jae .mmap_err
mov rdi, rbx
call unmapPage
add rbx, 4096
jmp .rollback_loop

.mmap_done:
mov rax, r12

push rax
mov rdi, 24
call kmalloc
mov rbx, rax
pop rax

mov [rbx], rax
mov [rbx + 8], r13

mov r8, [curr_thread]
mov r9, [r8 + 64]
mov [rbx + 16], r9
mov [r8 + 64], rbx

pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

.mmap_err:
mov rax, -1
pop r15
pop r14
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
iretq

;; rax = 4
;; rdi = virtual addr
;; rsi = no of pages
.sys_unmap:
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11
push r12
push r13

test rdi, 0xFFF
jnz .unmap_err

cmp rsi, 0x7FFFFFFF
ja .unmap_err

mov rax, rsi
shl rax, 12
add rax, rdi
jc .unmap_err
mov rbx, 0x00007FFFFFFFFFFF
cmp rax, rbx
ja .unmap_err

mov r12, rdi
mov r13, rsi

.unmap_loop:
test r13, r13
jz .unmap_done

mov rdi, r12
call unmapPage

add r12, 4096
dec r13
jmp .unmap_loop

.unmap_done:
mov r8, [curr_thread]
lea r9, [r8 + 64]

mov r10, [rsp + 48]
mov r11, [rsp + 56]

.find_vma:
mov rbx, [r9]
test rbx, rbx
jz .finish_unmap

cmp [rbx], r10
jne .next_vma
cmp[rbx + 8], r11
jne .next_vma

mov rcx, [rbx + 16]
mov [r9], rcx

mov rdi, rbx
call kfree
jmp .finish_unmap

.next_vma:
lea r9, [rbx + 16]
jmp .find_vma

.finish_unmap:
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
mov rax, 0
iretq


.unmap_err:
pop r13
pop r12
pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
mov rax, -1
iretq

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

