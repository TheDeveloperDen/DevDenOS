[bits 64]
default rel

section .text

;; rdi = bus
;; rsi = device
;; rdx = func
;; rcx = offset
;; eax = value
pci_read_dword:
mov r8, rdx

mov eax, 0x80000000
shl edi, 16
or eax, edi
shl esi, 11
or eax, esi
shl r8d, 8
or eax, r8d
and ecx, 0xFC
or eax, ecx

mov dx, 0xCF8
out dx, eax

mov dx, 0xCFC
in eax, dx

ret

;; rdi = bus
;; rsi = device
;; rdx = func
;; rcx = offset
;; r8 = value to write
pci_write_dword:
mov r9, rdx

mov eax, 0x80000000
shl edi, 16
or eax, edi
shl esi, 11
or eax, esi
shl r9d, 8
or eax, r9d
and ecx, 0xFC
or eax, ecx

mov dx, 0xCF8
out dx, eax

mov dx, 0xCFC
mov eax, r8d
out dx, eax

ret

;; rdi = vendor_id
;; rsi = device_id
;; eax = (bus << 16) | (dev << 8) | func
pci_find_device:
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13, rsi

xor ebx, ebx
.bus_loop:
xor r14d, r14d
.device_loop:
xor r15d, r15d
.func_loop:
mov rdi, rbx
mov rsi, r14
mov rdx, r15
xor rcx, rcx
call pci_read_dword

cmp eax, 0xFFFFFFFF
je .next_func

mov ecx, eax
and ecx, 0xFFFF
cmp cx, r12w
jne .next_func

mov ecx, eax
shr ecx, 16
cmp cx, r13w
jne .next_func

mov eax, ebx
shl eax, 16
mov ecx, r14d
shl ecx, 8
or eax, ecx
or eax, r15d
jmp .done

.next_func:
inc r15d
cmp r15d, 8
jl .func_loop

.next_dev:
inc r14d
cmp r14d, 32
jl .device_loop

.next_bus:
inc ebx
cmp ebx, 256
jl .bus_loop

mov eax, -1

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret