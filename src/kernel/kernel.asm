org 0x100000
[bits 32]


entry:

mov edi, pml4_table
mov ecx, (4096 + 4096 + 32768) / 4 
xor eax, eax
rep stosd

mov eax, pdpt_table
or eax, 3
mov [pml4_table], eax

mov edi, pdpt_table
mov eax, pd_table
or eax, 3
mov ecx, 8
.map_pdpt:
mov [edi], eax
add eax, 4096
add edi, 8
dec ecx
jnz .map_pdpt

mov eax, pml4_table
or eax, 3
mov [pml4_table + 511 * 8], eax

mov edi, pd_table
mov eax, 0x83
mov ebx, 4096

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

mov rax, tss
mov word [abs gdt_tss + 2], ax
shr rax, 16
mov byte [abs gdt_tss + 4], al
shr rax, 8
mov byte [abs gdt_tss + 7], al
shr rax, 8
mov dword [abs gdt_tss + 8], eax

mov ax, 0x40
ltr ax

call idt_init
call remap_pic
;call pit_init

call disable_pic
call lapic_init
call ioapic_init

call fat32_init

call drivers_init
call scheduler_init



mov rdi, user_program
call fat32_load_file

test rax, rax
jz .fail

mov rdi, rax
mov rsi, rdx
xor rdx, rdx
xor rcx, rcx
call load_userspace_process


.fail:
sti

int 0x80

.idle:
hlt
jmp .idle


user_program: db "den/bin/example.dde",0


%include "kernel/paging.asm"
%include "kernel/heap.asm"
%include "kernel/interrupts.asm"
%include "kernel/processes.asm"
%include "kernel/userspace.asm"
%include "kernel/fat32.asm"
%include "kernel/drivers.asm"
%include "kernel/pci.asm"

%include "drivers/ata/ata64.asm"

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

gdt64_user_data: ; 0x30
dw 0xFFFF
dw 0x0000
db 0x00
db 11110010b
db 11001111b
db 0x00

gdt64_user_code: ; 0x38
dw 0xFFFF
dw 0x0000
db 0x00
db 11111010b
db 10101111b
db 0x00

gdt_tss: ; 0x40
dw 103
dw 0
db 0
db 10001001b
db 0
db 0
dq 0

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
pd_table:   resb 32768

align 16
tss: resb 104

kernel_end:
