[bits 64]
default rel

header:
db 'D','V','D','N'
db 1, 0
dw 3
dq _start
dq 0
dq lib_end - header
dd sections - header
dw 1
dd opt_hdr - header
dd opt_hdr_end - opt_hdr
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

opt_hdr:
db 'S','H','L','B'
dd 0, 0, 0
db 'libc'
times 12 db 0
opt_hdr_end:

sections:
dq 0
dq lib_end - header
dq 0
dq lib_end - header

align 16
_start:
lea r8, [header]
lea rax, [export_table]

; printf
mov rcx, [rax + 0]
add rcx, r8
mov [rax + 0], rcx

; strlen
mov rcx, [rax + 8]
add rcx, r8
mov [rax + 8], rcx

; memcpy
mov rcx, [rax + 16]
add rcx, r8
mov [rax + 16], rcx

; memset
mov rcx, [rax + 24]
add rcx, r8
mov [rax + 24], rcx
ret

align 8
export_table:
dq printf ; 0
dq strlen ; 1
dq memcpy ; 2
dq memset ; 3

printf:
pop r11
push r9
push r8
push rcx
push rdx
push rsi
push r11

push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
lea r13, [rbp + 16]

xor r14, r14

.parse_loop:
mov al, [r12]
test al, al
jz .done

cmp al, '%'
je .format_specifier

mov r15, r12

.find_chunk:
mov al, [r15]
test al, al
jz .flush_chunk
cmp al, '%'
je .flush_chunk
inc r15
jmp .find_chunk

.flush_chunk:
mov rdi, r12
mov rsi, r15
sub rsi, r12
call printf_print_buf
add r14, rsi
    
mov r12, r15
jmp .parse_loop

.format_specifier:
inc r12
mov al, [r12]

test al, al
jz .print_percent

inc r12
    
cmp al, 's'
je .print_string
cmp al, 'd'
je .print_signed
cmp al, 'i'
je .print_signed
cmp al, 'u'
je .print_unsigned
cmp al, 'x'
je .print_hex_lower
cmp al, 'X'
je .print_hex_upper
cmp al, 'p'
je .print_pointer
cmp al, 'c'
je .print_char
cmp al, '%'
je .print_percent

dec r12
mov rdi, r12
sub rdi, 1
mov rsi, 2
call printf_print_buf
add r14, 2
inc r12
jmp .parse_loop

.print_string:
mov rdi, [r13]
add r13, 8
test rdi, rdi

jnz .valid_str
lea rdi, [printf_null_str]

.valid_str:
call strlen
mov rsi, rax
call printf_print_buf
add r14, rsi
jmp .parse_loop

.print_char:
mov rax, [r13]
add r13, 8
push rax
mov rdi, rsp
mov rsi, 1
call printf_print_buf
add r14, 1
pop rax
jmp .parse_loop

.print_signed:
mov rax, [r13]
add r13, 8
call printf_itoa
jmp .parse_loop

.print_unsigned:
mov rax, [r13]
add r13, 8
call printf_utoa
jmp .parse_loop

.print_hex_lower:
mov rax, [r13]
add r13, 8
lea rbx,[printf_hex_lower_map]
call printf_xtoa
jmp .parse_loop


.print_hex_upper:
mov rax, [r13]
add r13, 8
lea rbx, [printf_hex_upper_map]
call printf_xtoa
jmp .parse_loop

.print_pointer:
mov rax, [r13]
add r13, 8
lea rdi, [printf_0x_str]
mov rsi, 2
call printf_print_buf
add r14, 2
    
lea rbx, [printf_hex_lower_map]
call printf_xtoa
jmp .parse_loop

.print_percent:
lea rdi, [printf_percent_str]
mov rsi, 1
call printf_print_buf
add r14, 1
jmp .parse_loop

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp

pop r11

add rsp, 40

mov rax, r14

jmp r11


printf_print_buf:
push rax
push rdi
push rsi
push rdx
push rcx
push r11

mov rdx, rsi
mov rsi, rdi
mov rdi, 1
mov rax, 2
int 0x81

pop r11
pop rcx
pop rdx
pop rsi
pop rdi
pop rax
ret

printf_itoa:
test rax, rax
jns printf_utoa
neg rax
push rax
lea rdi, [printf_minus_str]
mov rsi, 1
call printf_print_buf
add r14, 1
pop rax

printf_utoa:
sub rsp, 32
lea rdi, [rsp + 31]
mov byte [rdi], 0
mov r8, 10

test rax, rax
jnz .loop

dec rdi
mov byte [rdi], '0'
jmp .flush

.loop:
test rax, rax
jz .flush
xor rdx, rdx
div r8
add dl, '0'
dec rdi
mov [rdi], dl
jmp .loop

.flush:
mov rsi, rsp
add rsi, 31
sub rsi, rdi

push rdi
push rsi
call printf_print_buf
pop rsi
pop rdi

add r14, rsi
add rsp, 32
ret

printf_xtoa:
sub rsp, 32
lea rdi, [rsp + 31]
mov byte [rdi], 0
mov r8, 16

test rax, rax
jnz .loop

dec rdi
mov byte [rdi], '0'
jmp .flush

.loop:
test rax, rax
jz .flush
xor rdx, rdx
div r8
mov dl, [rbx + rdx]
dec rdi
mov [rdi], dl
jmp .loop

.flush:
mov rsi, rsp
add rsi, 31
sub rsi, rdi

push rdi
push rsi
call printf_print_buf
pop rsi
pop rdi

add r14, rsi
add rsp, 32
ret

printf_null_str: db "(null)", 0
printf_percent_str: db "%", 0
printf_minus_str: db "-", 0
printf_0x_str: db "0x", 0
printf_hex_lower_map: db "0123456789abcdef"
printf_hex_upper_map: db "0123456789ABCDEF"



strlen:
xor rax, rax

.loop:
cmp byte [rdi + rax], 0
je .done
inc rax
jmp .loop

.done:
ret

memcpy:
mov rax, rdi
mov rcx, rdx
test rcx, rcx
jz .done
rep movsb

.done:
ret

memset:
mov rax, rdi
mov rcx, rdx
mov rax, rsi
test rcx, rcx
jz .done
rep stosb

.done:
mov rax, rdi
ret

align 4096
lib_end: