[bits 64]
default rel

header:
db 'D','V','D','N'
db 1, 0
dw 2
dq _start
dq 0
dq drv_end - header
dd sections - header
dw 1
dd opt_hdr - header
dd opt_hdr_end - opt_hdr
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

opt_hdr:
db 'K','D','R','V'
dd 0, 0, 0
db 'gpu'
times 13 db 0
opt_hdr_end:

sections:
dq 0
dq drv_end - header
dq 0
dq drv_end - header

align 16
_start:
mov [api_table], rdi
lea rax, [dispatch]
ret

dispatch:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15

cmp rdi, 1
je .do_init

mov rax, -1
jmp .done

.do_init:
mov rdi, 0x1AF4
mov rsi, 0x1050
mov rax, [api_table]
call [rax + 64]
cmp eax, -1
je .not_found

mov [dev_bdf], eax

mov rcx, 0x04
call read_pci_reg
or eax, 0x06
mov r8, rax
mov rcx, 0x04
call write_pci_reg

mov dword [common_bar], -1
mov rcx, 0x34
call read_pci_reg
and eax, 0xFF
mov [cap_ptr], eax

.cap_loop:
mov eax, [cap_ptr]
test eax, eax
jz .done_caps

mov rcx, rax
call read_pci_reg
mov [cap_val0], eax

and eax, 0xFF
cmp eax, 0x09
jne .next_cap

mov eax, [cap_val0]
shr eax, 24
cmp eax, 1
je .found_common
jmp .next_cap

.found_common:
mov eax, [cap_ptr]
add eax, 4
mov rcx, rax
call read_pci_reg
and eax, 0xFF
mov [common_bar], eax

mov eax, [cap_ptr]
add eax, 8
mov rcx, rax
call read_pci_reg
mov [common_offset], eax

.next_cap:
mov eax, [cap_val0]
shr eax, 8
and eax, 0xFF
mov [cap_ptr], eax
jmp .cap_loop

.done_caps:
mov eax, [common_bar]
cmp eax, -1
je .not_found

mov rcx, [common_bar]
shl rcx, 2
add rcx, 0x10
call read_pci_reg
mov rbx, rax
and ebx, 0xFFFFFFF0

mov rdx, rax
and edx, 6
cmp edx, 4
jne .bar_mapped

mov rcx, [common_bar]
shl rcx, 2
add rcx, 0x14
call read_pci_reg
shl rax, 32
or rbx, rax

.bar_mapped:
mov eax, [common_offset]
add rbx, rax

mov rsi, rbx
and rsi, ~0xFFF
mov rdi, rsi
mov rax, 0xFFFF800000000000
add rdi, rax
mov rdx, 0x12
mov rax, [api_table]
call [rax + 16]

mov rdi, 0xFFFF800000000000
add rbx, rdi

mov dword [rbx], 0
mov eax, dword [rbx + 4]

test eax, 1
jz .no_virgl

lea rdi, [msg_virgl_yes]
call serial_print
mov rax, 1
jmp .done

.no_virgl:
lea rdi, [msg_virgl_no]
call serial_print
mov rax, 1
jmp .done

.not_found:
lea rdi, [msg_no_dev]
call serial_print
mov rax, -1

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

read_pci_reg:
mov rdi, [dev_bdf]
mov rdx, rdi
and rdx, 0xFF
mov rsi, rdi
shr rsi, 8
and rsi, 0xFF
shr rdi, 16
and rdi, 0xFF
mov rax, [api_table]
call [rax + 48]
ret

write_pci_reg:
mov rdi, [dev_bdf]
mov rdx, rdi
and rdx, 0xFF
mov rsi, rdi
shr rsi, 8
and rsi, 0xFF
shr rdi, 16
and rdi, 0xFF
mov rax, [api_table]
call [rax + 56]
ret



mov rax, 1
jmp .done

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret


%include "../../kernel/serial.asm"


msg_no_dev: db "Virtio GPU not found!", 10, 0
msg_virgl_yes: db "VirGL is supported chirp!", 10, 0
msg_virgl_no: db "VirGL isnt supported cro", 10, 0

dev_bdf dq 0
cap_ptr dq 0
cap_val0 dq 0
common_bar dq -1
common_offset dq 0

align 8
api_table: dq 0

align 4096
drv_end: