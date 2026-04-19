org 0x7e00

mov ah, 0x0e
mov al, 'Y'
int 0x10

xor ax, ax
mov es, ax
mov di, 0x7000
xor ebx, ebx
xor bp, bp

.e820:
mov eax, 0xe820
mov ecx, 24
mov edx, 0x534D4150
int 0x15

jc .e820done
cmp eax, 0x534D4150
jne .e820done

test ecx, ecx
jz .e820next
cmp ecx, 20
jl .e820next

inc bp
add di, 24
.e820next:
test ebx, ebx
jz .e820done
jmp .e820

.e820done:
mov [0x6FF8], bp

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

cld

mov eax, 0 
mov ecx, 1 
mov edi, 0x100000
call ata_read

mov ax, [0x1001FE]
cmp ax, 0xAA55
jne .fail

mov ax, 0x024F
mov [0xb8000], ax

mov ax, 0x024B
mov [0xb8002], ax

jmp $


.fail:
mov ax, 0x0446
mov [0xb8000], ax
jmp $

%include "drivers/ata/ata.asm"

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
