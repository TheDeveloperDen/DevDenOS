exception_common:
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push rbp
push r8
push r9
push r10
push r11
push r12
push r13
push r14
push r15

lea rdi, [str_panic_hdr]
call serial_print

lea rdi, [str_exc_vector]
call serial_print
mov rdi, [rsp + 120]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_err_code]
call serial_print
mov rdi, [rsp + 128]
call serial_print_hex
lea rdi, [str_newline]
call serial_print
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rip]
call serial_print
mov rdi, [rsp + 136]
call serial_print_hex
lea rdi, [str_cs]
call serial_print
mov rdi, [rsp + 144]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rsp]
call serial_print
mov rdi, [rsp + 160]
call serial_print_hex
lea rdi, [str_ss]
call serial_print
mov rdi, [rsp + 168]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rflags]
call serial_print
mov rdi, [rsp + 152]
call serial_print_hex
lea rdi, [str_newline]
call serial_print
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rax]
call serial_print
mov rdi, [rsp + 112]
call serial_print_hex
lea rdi, [str_rbx]
call serial_print
mov rdi, [rsp + 104]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rcx]
call serial_print
mov rdi, [rsp + 96]
call serial_print_hex
lea rdi, [str_rdx]
call serial_print
mov rdi, [rsp + 88]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rsi]
call serial_print
mov rdi, [rsp + 80]
call serial_print_hex
lea rdi, [str_rdi]
call serial_print
mov rdi, [rsp + 72]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_rbp]
call serial_print
mov rdi, [rsp + 64]
call serial_print_hex
lea rdi, [str_r8]
call serial_print
mov rdi, [rsp + 56]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_r9]
call serial_print
mov rdi, [rsp + 48]
call serial_print_hex
lea rdi, [str_r10]
call serial_print
mov rdi, [rsp + 40]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_r11]
call serial_print
mov rdi, [rsp + 32]
call serial_print_hex
lea rdi, [str_r12]
call serial_print
mov rdi, [rsp + 24]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_r13]
call serial_print
mov rdi, [rsp + 16]
call serial_print_hex
lea rdi, [str_r14]
call serial_print
mov rdi, [rsp + 8]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_r15]
call serial_print
mov rdi, [rsp + 0]
call serial_print_hex
lea rdi, [str_newline]
call serial_print
lea rdi, [str_newline]
call serial_print

lea rdi, [str_cr0]
call serial_print
mov rdi, cr0
call serial_print_hex
lea rdi, [str_cr2]
call serial_print
mov rdi, cr2
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_cr3]
call serial_print
mov rdi, cr3
call serial_print_hex
lea rdi, [str_cr4]
call serial_print
mov rdi, cr4
call serial_print_hex
lea rdi, [str_newline]
call serial_print

lea rdi, [str_cr8]
call serial_print
mov rdi, cr8
call serial_print_hex
lea rdi, [str_newline]
call serial_print
lea rdi, [str_newline]
call serial_print

lea rdi, [str_stack_trace]
call serial_print

lea rdi, [str_trace_entry]
call serial_print
mov rdi, [rsp + 136]
call serial_print_hex
lea rdi, [str_newline]
call serial_print

mov rbp, [rsp + 64]
mov r12, 32

.unwind_loop:
test rbp, rbp
jz .unwind_done

test rbp, 7
jnz .unwind_done

mov rdi, rbp
call is_page_mapped
test rax, rax
jz .unwind_done

lea rdi, [rbp + 8]
call is_page_mapped
test rax, rax
jz .unwind_done

mov rbx, [rbp + 8]
test rbx, rbx
jz .unwind_done

lea rdi, [str_trace_entry]
call serial_print
mov rdi, rbx
call serial_print_hex
lea rdi, [str_newline]
call serial_print

mov rbx, [rbp]
cmp rbx, rbp
jbe .unwind_done
mov rbp, rbx

dec r12
jnz .unwind_loop

.unwind_done:

.halt:
hlt
jmp .halt
