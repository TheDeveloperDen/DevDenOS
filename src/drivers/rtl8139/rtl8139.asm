[bits 64]
default rel

section .text

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
db 'rtl8139'
times 10 db 0
opt_hdr_end:

sections:
dq 0
dq drv_end - header
dq 0
dq drv_end - header

align 16
_start:
mov [api_table], rdi

mov rdi, 0x10EC
mov rsi, 0x8139
mov rax, [api_table]
call [rax + 64]

cmp eax, -1
je .fail

mov [pci_loc], eax
mov ebx, eax

mov edi, ebx
shr edi, 16
and edi, 0xFF

mov esi, ebx
shr esi, 8
and esi, 0x1F

mov edx, ebx
and edx, 0x07

push rdi
push rsi
push rdx

mov rcx, 0x04
mov rax, [api_table]
call [rax + 48]

or eax, 0x05

pop rdx
pop rsi
pop rdi

push rdi
push rsi
push rdx

mov rcx, 0x04
mov r8d, eax
mov rax, [api_table]
call [rax + 56]

pop rdx
pop rsi
pop rdi

push rdi
push rsi
push rdx

mov rcx, 0x3C
mov rax, [api_table]
call [rax + 48]

movzx ecx, al
mov [irq_line], cl
add cl, 32
mov [irq_vec], cl

pop rdx
pop rsi
pop rdi

mov rcx, 0x10
mov rax, [api_table]
call [rax + 48]

and ax, 0xFFFC
jz .fail
mov [io_base], ax

mov dx, [io_base]
add dx, 0x52
mov al, 0x00
out dx, al

mov dx, [io_base]
add dx, 0x37
mov al, 0x10
out dx, al

.reset_poll:
in al, dx
test al, 0x10
jnz .reset_poll

mov rdi, 3
mov rax, [api_table]
call [rax + 72]

test rax, rax
jz .fail

mov [rx_buf_virt], rax
mov [rx_buf_phys], rdx

mov rdi, 2
mov rax, [api_table]
call [rax + 72]

test rax, rax
jz .fail

mov [tx_buf_virt], rax
mov [tx_buf_phys], rdx

mov dx, [io_base]
add dx, 0x30
mov eax, dword [rx_buf_phys]
out dx, eax

mov dx, [io_base]
add dx, 0x38
mov ax, 0xFFF0
out dx, ax

mov dx, [io_base]
add dx, 0x3C
mov ax, 0x000F
out dx, ax

mov dx, [io_base]
add dx, 0x44
mov eax, 0x0000E70F
out dx, eax

mov dx, [io_base]
add dx, 0x37
mov al, 0x0C
out dx, al

mov dx, [io_base]
in eax, dx
mov dword [mac_addr], eax

add dx, 4
in ax, dx
mov word [mac_addr + 4], ax

call register_irq

mov byte [initialized], 1

lea rax, [dispatch]
ret

.fail:
xor rax, rax
ret

register_irq:
sub rsp, 16
sidt [rsp]
mov r8, [rsp + 2]
add rsp, 16

movzx rdi, byte [irq_vec]
shl rdi, 4
lea rbx, [r8 + rdi]

lea rax, [rtl8139_irq]
mov [rbx], ax
mov word [rbx + 2], 0x08
mov byte [rbx + 4], 0
mov byte [rbx + 5], 0x8E
shr rax, 16
mov [rbx + 6], ax
shr rax, 16
mov [rbx + 8], eax
mov dword [rbx + 12], 0

movzx ecx, byte [irq_line]
cmp cl, 8
jb .master_pic

in al, 0x21
and al, 0xFB
out 0x21, al

in al, 0xA1
mov dl, cl
sub dl, 8
mov cl, dl
mov dh, 1
shl dh, cl
not dh
and al, dh
out 0xA1, al
movzx ecx, byte [irq_line]
jmp .ioapic_cfg

.master_pic:
in al, 0x21
mov dl, cl
mov dh, 1
shl dh, cl
not dh
and al, dh
out 0x21, al

.ioapic_cfg:
mov r10, 0xFFFF8000FEC00000
mov edx, ecx
shl edx, 1
add edx, 0x10
mov [r10], edx
movzx eax, byte [irq_vec]
or eax, 0xA000
mov [r10 + 0x10], eax
ret

rtl8139_irq:
push rax
push rbx
push rcx
push rdx
push rsi
push rdi
push r8
push r9
push r10
push r11

mov dx, [io_base]
add dx, 0x3E
in ax, dx
out dx, ax

call drain_rx

mov rax, 0xFFFF8000FEE00000
mov dword [rax + 0xB0], 0

pop r11
pop r10
pop r9
pop r8
pop rdi
pop rsi
pop rdx
pop rcx
pop rbx
pop rax
iretq

drain_rx:
mov dx, [io_base]
add dx, 0x37
in al, dx
test al, 0x01
jnz .done

mov rbx, [rx_buf_virt]
movzx rsi, word [rx_curr_offset]

lea rdi, [rbx + rsi]
mov ax, [rdi]
test ax, 0x01
jz .done

movzx ecx, word [rdi + 2]
cmp ecx, 4
jbe .advance

mov rdx, rcx
sub rdx, 4

mov r8, [rx_ring_tail]
mov r9, r8
inc r9
and r9, 15
cmp r9, [rx_ring_head]
je .advance

imul r10, r8, 1536
lea r11, [rx_ring + r10]
mov [r11], edx

push rsi
push rdi
push rcx
lea rdi, [r11 + 4]
lea rsi, [rbx + rsi + 4]
mov rcx, rdx
rep movsb
pop rcx
pop rdi
pop rsi

mov [rx_ring_tail], r9

.advance:
add rsi, rcx
add rsi, 4
add rsi, 3
and rsi, ~3
and rsi, 8191
mov [rx_curr_offset], si

sub si, 0x10
mov dx, [io_base]
add dx, 0x38
mov ax, si
out dx, ax

jmp drain_rx

.done:
ret

send_packet:
cmp rdx, 1792
ja .fail

mov rbx, [tx_buf_virt]
movzx rax, byte [tx_curr]
shl rax, 11
add rbx, rax

push rdx
push rsi
mov rdi, rbx
mov rcx, rdx
rep movsb
pop rsi
pop rdx

cmp rdx, 60
jae .pad_done

mov rdi, rbx
add rdi, rdx
mov rcx, 60
sub rcx, rdx
xor al, al
rep stosb
mov rdx, 60

.pad_done:
mov r8d, edx
movzx rax, byte [tx_curr]
mov rbx, [tx_buf_phys]
shl rax, 11
add rbx, rax

movzx rcx, byte [tx_curr]
shl rcx, 2
mov dx, [io_base]
add dx, 0x20
add dx, cx
mov eax, ebx
out dx, eax

mov dx, [io_base]
add dx, 0x10
add dx, cx
mov eax, r8d
out dx, eax

inc byte [tx_curr]
and byte [tx_curr], 3

xor rax, rax
ret

.fail:
mov rax, -1
ret

recv_packet:
call drain_rx

mov rax, [rx_ring_head]
cmp rax, [rx_ring_tail]
je .no_pkt

imul rbx, rax, 1536
lea r8, [rx_ring + rbx]

mov ecx, [r8]
cmp rcx, rdx
jbe .size_ok
mov rcx, rdx

.size_ok:
push rcx
push rsi
mov rdi, rsi
lea rsi, [r8 + 4]
rep movsb
pop rsi
pop rcx

inc rax
and rax, 15
mov [rx_ring_head], rax

mov rax, rcx
ret

.no_pkt:
xor rax, rax
ret

dispatch:
cmp rdi, 1
je .get_mac
cmp rdi, 2
je .get_status
cmp rdi, 3
je .send_pkt
cmp rdi, 4
je .recv_pkt

mov rax, -1
ret

.get_mac:
test rdx, rdx
jz .mac_fail
mov eax, dword [mac_addr]
mov [rdx], eax
mov ax, word [mac_addr + 4]
mov [rdx + 4], ax
mov rax, 6
ret

.mac_fail:
mov rax, -1
ret

.get_status:
movzx rax, byte [initialized]
ret

.send_pkt:
call send_packet
ret

.recv_pkt:
call recv_packet
ret

align 8
api_table dq 0
pci_loc dd 0
rx_buf_virt dq 0
rx_buf_phys dq 0
tx_buf_virt dq 0
tx_buf_phys dq 0
io_base dw 0
irq_line db 0
irq_vec db 0
mac_addr db 0, 0, 0, 0, 0, 0
initialized db 0
tx_curr db 0
rx_curr_offset dw 0

rx_ring_head dq 0
rx_ring_tail dq 0
align 16
rx_ring times 16 * 1536 db 0

align 4096
drv_end:
