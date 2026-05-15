ATA_PRIMARY_DATA equ 0x1F0
ATA_PRIMARY_ERR equ 0x1F1
ATA_PRIMARY_SECTORS equ 0x1F2
ATA_PRIMARY_LBALO equ 0x1F3
ATA_PRIMARY_LBAMI equ 0x1F4
ATA_PRIMARY_LBAHI equ 0x1F5
ATA_PRIMARY_HEAD equ 0x1F6
ATA_PRIMARY_STATUS equ 0x1F7
ATA_PRIMARY_CMD equ 0x1F7

ATA_ERR equ 0x01
ATA_DRQ equ 0x08
ATA_BSY equ 0x80

CMD_READ_SECTORS equ 0x20
CMD_WRITE_SECTORS equ 0x30

[bits 64]
default rel

section .text

;; rdi = lba
;; rsi = sectors
;; rdx = buffer
ata_read64:
push rbx
push r12
push r13
push r14
push rdi
push rsi

mov rbx, rdi 
mov r12, rsi 
mov r13, rdx 

.loop:
test r12, r12
jz .done

mov r14, r12
cmp r14, 255
jbe .ok
mov r14, 255
.ok:

mov rdx, ATA_PRIMARY_HEAD
mov rax, rbx
shr rax, 24
and al, 0x0F
or al, 0xE0
out dx, al

mov rdx, ATA_PRIMARY_SECTORS
mov rax, r14
out dx, al

mov rdx, ATA_PRIMARY_LBALO
mov rax, rbx
out dx, al

mov rdx, ATA_PRIMARY_LBAMI
mov rax, rbx
shr rax, 8
out dx, al

mov rdx, ATA_PRIMARY_LBAHI
mov rax, rbx
shr rax, 16
out dx, al

mov rdx, ATA_PRIMARY_CMD
mov al, CMD_READ_SECTORS
out dx, al

mov rdx, 0x3F6
in al, dx
in al, dx
in al, dx
in al, dx

mov rcx, r14
.sector_loop:
push rcx
mov rdx, ATA_PRIMARY_STATUS
.wait:
in al, dx
test al, ATA_BSY
jnz .wait
test al, ATA_ERR
jnz .err
test al, ATA_DRQ
jz .wait

mov rdx, ATA_PRIMARY_DATA
mov rcx, 256
mov rdi, r13
rep insw
mov r13, rdi

pop rcx
dec rcx
jnz .sector_loop

add rbx, r14
sub r12, r14
jmp .loop

.done:
pop rsi
pop rdi
pop r14
pop r13
pop r12
pop rbx
ret

.err:
jmp $

;; rdi = lba
;; rsi = sectors
;; rdx = buffer
ata_write64:
push rbx
push r12
push r13
push r14
push rdi
push rsi

mov rbx, rdi 
mov r12, rsi 
mov r13, rdx 

.loop:
test r12, r12
jz .done

mov r14, r12
cmp r14, 255
jbe .ok
mov r14, 255

.ok:
mov rdx, ATA_PRIMARY_HEAD
mov rax, rbx
shr rax, 24
and al, 0x0F
or al, 0xE0
out dx, al

mov rdx, ATA_PRIMARY_SECTORS
mov rax, r14
out dx, al

mov rdx, ATA_PRIMARY_LBALO
mov rax, rbx
out dx, al

mov rdx, ATA_PRIMARY_LBAMI
mov rax, rbx
shr rax, 8
out dx, al

mov rdx, ATA_PRIMARY_LBAHI
mov rax, rbx
shr rax, 16
out dx, al

mov rdx, ATA_PRIMARY_CMD
mov al, CMD_WRITE_SECTORS
out dx, al

mov rdx, 0x3F6
in al, dx
in al, dx
in al, dx
in al, dx

mov rcx, r14

.sector_loop:
push rcx
mov rdx, ATA_PRIMARY_STATUS

.wait:
in al, dx

test al, ATA_BSY
jnz .wait

test al, ATA_ERR
jnz .err

test al, ATA_DRQ
jz .wait

mov rdx, ATA_PRIMARY_DATA
mov rcx, 256
mov rsi, r13
rep outsw
mov r13, rsi

pop rcx
dec rcx
jnz .sector_loop

mov rdx, ATA_PRIMARY_CMD
mov al, 0xE7
out dx, al

.flush_wait:
mov rdx, ATA_PRIMARY_STATUS
in al, dx
test al, ATA_BSY
jnz .flush_wait

add rbx, r14
sub r12, r14
jmp .loop

.done:
pop rsi
pop rdi
pop r14
pop r13
pop r12
pop rbx
ret

.err:
jmp $