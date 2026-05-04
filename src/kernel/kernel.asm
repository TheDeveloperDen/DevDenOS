org 0x100000
[bits 32]


entry:

mov edi, pml4_table
mov ecx, 3072
xor eax, eax
rep stosd

mov eax, pdpt_table
or eax, 3
mov [pml4_table], eax

mov eax, pd_table
or eax, 3
mov [pdpt_table], eax

mov eax, pml4_table
or eax, 3
mov[pml4_table + 511 * 8], eax

mov edi, pd_table
mov eax, 0x83

mov ebx, kernel_end
add ebx, 0x1FFFFF
shr ebx, 21

.map:
mov [edi], eax
add eax, 0x200000
add edi, 8
dec ebx
jnz .map

mov eax, cr4
or eax, 1 << 5
mov cr4, eax

mov eax, pml4_table
mov cr3, eax

mov ecx, 0xC0000080
rdmsr
or eax, 1 <<8
wrmsr

mov eax, cr0
or eax, (1 << 31) | (1 << 16)
mov cr0, eax

lgdt [gdt64_desc]
jmp code64_segment:long_mode
jmp $

[bits 64]

%macro map_page 3
mov rdi, %1
mov rsi, %2
mov rdx, %3
call mapPage
%endmacro

%macro unmap_page 1
mov rdi, %1
call unmapPage
%endmacro

%macro bios_interrupt 1-7 0, 0, 0, 0, 0, 0

push %7
push %6
push %5
push %4
push %3
push %2
push %1

pop rdi
pop rsi
pop rdx
pop rcx
pop r8
pop r9

call biosinterrupt
add rsp, 8

%endmacro

long_mode:
mov ax, data64_segment
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax

mov rax, 0xb8000
mov rbx, 0

.loop:
cmp rbx, 80*25
je .exit
inc rbx
mov word [rax], 0x0720
add rax, 2
jmp .loop

.exit:

call idt_init
call remap_pic
call pit_init
sti

mov rdi, 4*1024*1024
call kmalloc
push rax

mov [rax], word 0x0241
mov ax, [rax]

mov [abs 0xb8000], ax

pop rdi
call kfree


.hang:
hlt
jmp .hang


%include "kernel/paging.asm"
%include "kernel/heap.asm"
%include "kernel/interrupts.asm"

align 8
gdt64_start:
gdt64_null: dq 0 ; required

gdt64_code:  ; ring 0 CS
dw 0xFFFF  ; limit low
dw 0x0000  ; base low
db 0x00    ; base mid
db 10011010b ; access byte
db 10101111b ; flags
db 0x00    ; base high

gdt64_data: ; ring 0 DS 
dw 0xFFFF ; limit low
dw 0x0000 ; base low
db 0x00   ; base mid
db 10010010b ; access byte
db 11001111b ; flags
db 0x00 ; base high

gdt32_code: ; 0x18
dw 0xFFFF
dw 0x0000
db 0x00
db 10011010b
db 11001111b
db 0x00

gdt16_code: ; 0x20
dw 0xFFFF
dw 0x0000
db 0x00
db 10011010b
db 00001111b
db 0x00

gdt16_data: ; 0x28
dw 0xFFFF
dw 0x0000
db 0x00
db 10010010b
db 00001111b
db 0x00

gdt64_end:

gdt64_desc:
dw gdt64_end - gdt64_start - 1 
dd gdt64_start

code64_segment equ gdt64_code - gdt64_start
data64_segment equ gdt64_data - gdt64_start




section .bss
alignb 4096
pml4_table: resb 4096
pdpt_table: resb 4096
pd_table:   resb 4096
kernel_end:
