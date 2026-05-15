[bits 64]
default rel

COM1 equ 0x3F8

serial_init:
mov dx, COM1 + 1
mov al, 0x00
out dx, al

mov dx, COM1 + 3
mov al, 0x80
out dx, al

mov dx, COM1 + 0
mov al, 0x03
out dx, al

mov dx, COM1 + 1
mov al, 0x00
out dx, al

mov dx, COM1 + 3
mov al, 0x03
out dx, al

mov dx, COM1 + 2
mov al, 0xC7
out dx, al

mov dx, COM1 + 4
mov al, 0x0B
out dx, al
ret

;; al = char
serial_putchar:
push rdx
push rax
mov dx, COM1 + 5

.wait:
in al, dx
test al, 0x20
jz .wait
mov dx, COM1
pop rax
out dx, al
pop rdx
ret

;; rdi = string
serial_print:
push rdi
push rax

.loop:
mov al, [rdi]
test al, al
jz .done
call serial_putchar
inc rdi
jmp .loop

.done:
pop rax
pop rdi
ret

;; rdi = int as hex
serial_print_hex:
push rcx
push rax
push rdi
mov rax, rdi
mov rcx, 16

.loop:
rol rax, 4
push rax
and al, 0x0F
cmp al, 9
jbe .is_digit
add al, 'A' - 10
jmp .print

.is_digit:
add al, '0'

.print:
call serial_putchar
pop rax
dec rcx
jnz .loop
pop rdi
pop rax
pop rcx
ret