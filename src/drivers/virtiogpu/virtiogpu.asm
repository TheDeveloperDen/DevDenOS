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
cmp eax, 2
je .found_notify
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

.found_notify:
mov eax, [cap_ptr]
add eax, 4
mov rcx, rax
call read_pci_reg
and eax, 0xFF
mov [notify_bar], eax

mov eax, [cap_ptr]
add eax, 8
mov rcx, rax
call read_pci_reg
mov [notify_offset], eax

mov eax, [cap_ptr]
add eax, 16
mov rcx, rax
call read_pci_reg
mov [notify_multiplier], eax
jmp .next_cap

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

mov eax, [notify_bar]
cmp eax, -1
je .skip_notify

mov rcx, [notify_bar]
shl rcx, 2
add rcx, 0x10
call read_pci_reg
mov r12, rax
and r12d, 0xFFFFFFF0

mov rdx, rax
and edx, 6
cmp edx, 4
jne .notify_mapped

mov rcx, [notify_bar]
shl rcx, 2
add rcx, 0x14
call read_pci_reg
shl rax, 32
or r12, rax

.notify_mapped:
mov eax, [notify_offset]
add r12, rax

mov rsi, r12
and rsi, ~0xFFF
mov rdi, rsi
mov rax, 0xFFFF800000000000
add rdi, rax

mov r13, 4
.notify_map_loop:
push rdi
push rsi

mov rdx, 0x12
mov rax, [api_table]
call [rax + 16]

pop rsi
pop rdi

add rdi, 0x1000
add rsi, 0x1000
dec r13
jnz .notify_map_loop

mov rdi, 0xFFFF800000000000
add r12, rdi
mov [notify_mapped_addr], r12

.skip_notify:
mov byte [rbx + 0x14], 0
mov byte [rbx + 0x14], 1

mov byte [rbx + 0x14], 3

mov dword [rbx + 0x00], 0
mov eax, dword [rbx + 0x04]

mov dword [rbx + 0x08], 0
test eax, 1
jz .no_virgl

lea rdi, [msg_virgl_yes]
call serial_print
mov dword [rbx + 0x0C], 1
jmp .virgl_done

.no_virgl:
lea rdi, [msg_virgl_no]
call serial_print
mov dword [rbx + 0x0C], 0

.virgl_done:

mov dword [rbx + 0x00], 1
mov dword [rbx + 0x08], 1
mov dword [rbx + 0x0C], 1

mov byte [rbx + 0x14], 0x0B
mov al, byte [rbx + 0x14]
test al, 8
jz .fail_features

mov word [rbx + 0x16], 0 
mov ax, word [rbx + 0x18] 
cmp ax, 256
jbe .size0_ok
mov ax, 256
mov word [rbx + 0x18], ax

.size0_ok:
test ax, ax
jz .fail_queues

movzx eax, word [rbx + 0x1E]
mov [control_notify_off], rax

call alloc_queue_page
mov [control_desc_phys], rax
mov [control_desc_virt], rdx
mov [rbx + 0x20], rax

call alloc_queue_page
mov [control_avail_phys], rax
mov [control_avail_virt], rdx
mov [rbx + 0x28], rax

call alloc_queue_page
mov [control_used_phys], rax
mov [control_used_virt], rdx
mov [rbx + 0x30], rax

mov word [rbx + 0x1C], 1

mov word [rbx + 0x16], 1 
mov ax, word [rbx + 0x18]
cmp ax, 256
jbe .size1_ok
mov ax, 256
mov word [rbx + 0x18], ax
.size1_ok:
test ax, ax
jz .fail_queues

movzx eax, word [rbx + 0x1E]
mov [cursor_notify_off], rax

call alloc_queue_page
mov [cursor_desc_phys], rax
mov [cursor_desc_virt], rdx
mov [rbx + 0x20], rax

call alloc_queue_page
mov [cursor_avail_phys], rax
mov [cursor_avail_virt], rdx
mov [rbx + 0x28], rax

call alloc_queue_page
mov [cursor_used_phys], rax
mov [cursor_used_virt], rdx
mov [rbx + 0x30], rax

mov word [rbx + 0x1C], 1

mov byte [rbx + 0x14], 0x0F

mov al, byte [rbx + 0x14]
test al, 0x40
jnz .fail_host
test al, 0x0F
jz .fail_host

lea rdi, [msg_gpu_ready]
call serial_print
mov rax, 1
jmp .done

.fail_host:
lea rdi, [msg_fail_host]
call serial_print
mov rax, -1
jmp .done


.fail_features:
lea rdi, [msg_fail_feat]
call serial_print
mov rax, -1
jmp .done

.fail_queues:
lea rdi, [msg_fail_queues]
call serial_print
mov rax, -1
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

alloc_queue_page:
push rbx
push rcx
push rdi
push rsi

mov rax, [api_table]
call [rax + 32]
mov rbx, rax

mov rdi, [next_virt_queue_addr]
mov rsi, rax
mov rdx, 3
mov rax, [api_table]
call [rax + 16]

mov rdi, [next_virt_queue_addr]
mov rcx, 512
xor rax, rax
rep stosq

mov rax, rbx
mov rdx, [next_virt_queue_addr]
add qword [next_virt_queue_addr], 4096

pop rsi
pop rdi
pop rcx
pop rbx
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
msg_gpu_ready: db "DRIVER_OK", 10, 0
msg_fail_feat: db "FEATURES_OK failed!", 10, 0
msg_fail_queues: db "Queue setup failed!", 10, 0
msg_fail_host: db "Host rejected init", 10, 0

dev_bdf dq 0
cap_ptr dq 0
cap_val0 dq 0
common_bar dq -1
common_offset dq 0

notify_bar dq -1
notify_offset dq 0
notify_multiplier dq 0
notify_mapped_addr dq 0

next_virt_queue_addr dq 0xFFFF8000A0000000

control_desc_phys dq 0
control_desc_virt dq 0
control_avail_phys dq 0
control_avail_virt dq 0
control_used_phys dq 0
control_used_virt dq 0

cursor_desc_phys dq 0
cursor_desc_virt dq 0
cursor_avail_phys dq 0
cursor_avail_virt dq 0
cursor_used_phys dq 0
cursor_used_virt dq 0
control_notify_off dq 0
cursor_notify_off dq 0

align 8
api_table: dq 0

align 4096
drv_end: