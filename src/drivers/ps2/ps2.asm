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
db 'ps2'
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

sub rsp, 16
sidt [rsp]
mov r8, [rsp + 2]
add rsp, 16


mov rdi, 33
shl rdi, 4
lea rbx, [r8 + rdi]

lea rax, [kbd_irq]
mov [rbx], ax
mov word [rbx + 2], 0x08
mov byte [rbx + 4], 0
mov byte [rbx + 5], 0x8E
shr rax, 16
mov [rbx + 6], ax
shr rax, 16
mov [rbx + 8], eax
mov dword [rbx + 12], 0

mov rdi, 44
shl rdi, 4
lea rbx, [r8 + rdi]

lea rax, [mouse_irq]
mov [rbx], ax
mov word [rbx + 2], 0x08
mov byte [rbx + 4], 0
mov byte [rbx + 5], 0x8E
shr rax, 16
mov [rbx + 6], ax
shr rax, 16
mov [rbx + 8], eax
mov dword [rbx + 12], 0

;in al, 0x21
;and al, 0xFD
;and al, 0xFB
;out 0x21, al

;in al, 0xA1
;and al, 0xEF
;out 0xA1, al

call mouse_init

lea rax, [dispatch]
ret

dispatch:
cmp rdi, 1
je .read_key
cmp rdi, 2
je .read_mouse_state
cmp rdi, 3
je .read_mouse_event

mov rax, -1
ret

.read_key:
mov rax, [buf_head]
cmp rax, [buf_tail]
je .no_key

lea rbx, [key_buf]
mov cl, [rbx + rax]
mov [rdx], cl

inc rax
and rax, 255
mov [buf_head], rax
mov rax, 1
ret

.no_key:
xor rax, rax
ret

.read_mouse_state:
mov eax, [mouse_x]
mov [rdx], eax
mov eax, [mouse_y]
mov [rdx + 4], eax
mov eax, [mouse_buttons]
mov [rdx + 8], eax
mov rax, 1
ret

.read_mouse_event:
movzx eax, byte [mouse_ring_head]
movzx ecx, byte [mouse_ring_tail]
cmp eax, ecx
je .no_event

mov r8, rax
imul r8, 12
lea r9, [mouse_ring]
add r9, r8

mov ebx, [r9]
mov [rdx], ebx
mov ebx, [r9 + 4]
mov [rdx + 4], ebx
mov ebx, [r9 + 8]
mov [rdx + 8], ebx

inc eax
and eax, 31
mov [mouse_ring_head], al
mov rax, 1
ret

.no_event:
xor rax, rax
ret


mouse_wait:
push rcx
mov rcx, 100000
.loop:
in al, 0x64
test al, 2
jz .done
dec rcx
jnz .loop
.done:
pop rcx
ret

mouse_wait_input:
push rcx
mov rcx, 100000
.loop:
in al, 0x64
test al, 1
jnz .done
dec rcx
jnz .loop
.done:
pop rcx
ret

mouse_write:
call mouse_wait
mov al, 0xD4
out 0x64, al
call mouse_wait
mov rax, rdi
out 0x60, al
ret

mouse_read:
call mouse_wait_input
in al, 0x60
ret

mouse_init:
call mouse_wait
mov al, 0xA8
out 0x64, al

call mouse_wait
mov al, 0x20
out 0x64, al

call mouse_wait_input
in al, 0x60
mov bl, al
or bl, 2

call mouse_wait
mov al, 0x60
out 0x64, al

call mouse_wait
mov al, bl
out 0x60, al

mov rdi, 0xF6
call mouse_write
call mouse_read

mov rdi, 0xF4
call mouse_write
call mouse_read
ret

mouse_irq:
push rax
push rbx
push rcx
push rdx
push r8
push r9
push r10
push r11
push rdi
push rsi

in al, 0x64
test al, 0x20
jz .done

in al, 0x60
mov bl, al

mov cl, [mouse_cycle]
cmp cl, 0
jne .cycle1

test bl, 0x08
jz .reset_cycle

mov [mouse_packet], bl
mov byte [mouse_cycle], 1
jmp .done

.cycle1:
cmp cl, 1
jne .cycle2

mov [mouse_packet + 1], bl
mov byte[mouse_cycle], 2
jmp .done

.cycle2:
mov [mouse_packet + 2], bl
mov byte [mouse_cycle], 0
call process_mouse
jmp .done

.reset_cycle:
mov byte [mouse_cycle], 0

.done:
;mov al, 0x20
;out 0xA0, al
;out 0x20, al

mov rax, 0xFFFF8000FEE00000
mov dword [rax + 0xB0], 0

pop rsi
pop rdi
pop r11
pop r10
pop r9
pop r8
pop rdx
pop rcx
pop rbx
pop rax
iretq

process_mouse:
movzx eax, byte [mouse_packet]

test al, 0xC0
jnz .ret

mov ebx, eax
and ebx, 0x07
mov [mouse_buttons], ebx

movzx ebx, byte[mouse_packet + 1]
test al, 0x10
jz .x_pos
or ebx, 0xFFFFFF00
.x_pos:

movzx ecx, byte[mouse_packet + 2]
test al, 0x20
jz .y_pos
or ecx, 0xFFFFFF00
.y_pos:

mov edi, [mouse_x]
add edi, ebx
cmp edi, 0
jge .x_clamp1
xor edi, edi
.x_clamp1:
cmp edi, 1679
jle .x_clamp2
mov edi, 1679
.x_clamp2:
mov [mouse_x], edi

mov esi, [mouse_y]
sub esi, ecx
cmp esi, 0
jge .y_clamp1
xor esi, esi
.y_clamp1:
cmp esi, 719
jle .y_clamp2
mov esi, 719
.y_clamp2:
mov [mouse_y], esi

movzx eax, byte [mouse_ring_tail]
mov edx, eax
inc edx
and edx, 31

movzx r8d, byte [mouse_ring_head]
cmp edx, r8d
jne .store_event
inc r8d
and r8d, 31
mov [mouse_ring_head], r8b

.store_event:
mov r9, rax
imul r9, 12
lea r11, [mouse_ring]
add r11, r9

mov [r11], ebx
neg ecx
mov [r11 + 4], ecx
mov ebx, [mouse_buttons]
mov [r11 + 8], ebx

mov [mouse_ring_tail], dl

.ret:
ret


kbd_irq:
push rax
push rbx
push rcx
push rdx

in al, 0x60


cmp al, 0xAA
je .lshift_up

cmp al, 0xB6
je .rshift_up

test al, 0x80
jnz .done

cmp al, 0x2A
je .lshift_down
cmp al, 0x36
je .rshift_down
cmp al, 0x3A
je .caps_down

movzx rcx, al
cmp byte [shift_state], 0
je .use_normal
lea rbx,[scancode_map_shift]
jmp .map_selected

.use_normal:
lea rbx, [scancode_map]

.map_selected:
mov al, [rbx + rcx]
cmp byte [caps_state], 0
je .check_valid

mov ah, al
or ah, 0x20
cmp ah, 'a'
jl .check_valid
cmp ah, 'z'
jg .check_valid
xor al, 0x20

.check_valid:
test al, al
jz .done

mov rbx, [buf_tail]
mov rcx, rbx
inc rcx
and rcx, 255
cmp rcx, [buf_head]
je .done

lea rdx, [key_buf]
mov [rdx + rbx], al
mov [buf_tail], rcx

jmp .done

.lshift_down:
or byte[shift_state], 1
jmp .done
.rshift_down:
or byte [shift_state], 2
jmp .done
.lshift_up:
and byte [shift_state], 0xFE
jmp .done
.rshift_up:
and byte [shift_state], 0xFD
jmp .done
.caps_down:
xor byte [caps_state], 1

.done:
;mov al, 0x20
;out 0x20, al

mov rax, 0xFFFF8000FEE00000
mov dword [rax + 0xB0], 0

pop rdx
pop rcx
pop rbx
pop rax
iretq

align 8
api_table dq 0
buf_head dq 0
buf_tail dq 0
key_buf times 256 db 0
shift_state db 0
caps_state db 0

mouse_cycle db 0
mouse_packet db 0, 0, 0
mouse_x dd 840
mouse_y dd 360
mouse_buttons dd 0

mouse_ring_head db 0
mouse_ring_tail db 0
align 4
mouse_ring times 384 db 0

scancode_map:
db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8
db 9, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 10
db 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`'
db 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0
db '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
db '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0', '.'
times 128 - ($ - scancode_map) db 0

scancode_map_shift:
db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8
db 9, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 10
db 0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~'
db 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0
db '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
db '7', '8', '9', '-', '4', '5', '6', '+', '1', '2', '3', '0', '.'
times 128 - ($ - scancode_map_shift) db 0

align 4096
drv_end: