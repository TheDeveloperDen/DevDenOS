org 0x7e00

mov ah, 0x0e
mov al, 'Y'
int 0x10

cli

in al, 0x92
or al, 2 
out 0x92, al

lgdt [gdt_desc]

mov eax, cr0
or eax, 1 
mov cr0, eax

jmp code_segment:prot_mode

jmp $

[bits 32]
prot_mode:
mov ax, data_segment
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov esp, 0x90000

mov ax, 0x0248
mov [0xb8000], ax
xor eax, eax
movzx eax, word [0x7c0b]

jmp $


gdt_start:
gdt_null: dq 0 ; required

gdt_code:  ; ring 0 CS
dw 0xFFFF  ; limit low
dw 0x0000  ; base low
db 0x00    ; base mid
db 10011010b ; access byte
db 11001111b ; flags
db 0x00    ; base high

gdt_data: ; ring 0 DS 
dw 0xFFFF ; limit low
dw 0x0000 ; base low
db 0x00   ; base mid
db 10010010b ; access byte
db 11001111b ; flags
db 0x00 ; base high
gdt_end:

gdt_desc:
dw gdt_end - gdt_start - 1 
dd gdt_start

code_segment equ gdt_code - gdt_start
data_segment equ gdt_data - gdt_start

times 2048-($-$$) db 0 
