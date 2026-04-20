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

movzx eax, word [0x7c0e]
mov dword [fat_lba], eax

movzx ebx, byte [0x7c10]
mov ecx, dword [0x7c24]
imul ebx, ecx
add eax, ebx
mov dword [data_lba], eax

movzx eax, byte [0x7c0d]
mov dword [spc], eax

mov eax, dword[0x7c2c]

.dir_search:
mov edi, 0x80000
call read_cluster

mov esi, 0x80000
mov ecx, dword [spc]
shl ecx, 9
add ecx, esi

.chk_entry:
cmp byte [esi], 0
je .fail
cmp byte [esi], 0xE5
je .next
cmp byte [esi+11], 0x0F
je .next

push esi
mov edi, kernel_name
push ecx
mov ecx, 11
repe cmpsb
pop ecx
pop esi
je .found

.next:
add esi, 32
cmp esi, ecx
jl .chk_entry
call next_cluster

cmp eax, 0x0FFFFFF8
jae .fail
jmp .dir_search

.found:
movzx eax, word [esi+0x14]
shl eax, 16
mov ax, word [esi+0x1A]

mov edi, 0x100000

.load:
push eax
call read_cluster

mov ebx, dword [spc]
shl ebx, 9
add edi, ebx

pop eax
call next_cluster
cmp eax, 0x0FFFFFF8
jae 0x100000
jmp .load

.fail:
mov ax, 0x0446
mov [0xb8000], ax
jmp $

read_cluster:
push eax
push ecx
sub eax, 2
imul eax, dword [spc]
add eax, dword [data_lba]
mov ecx, dword [spc]
call ata_read
pop ecx
pop eax
ret

next_cluster:
push ebx
push edx

mov ebx, eax
shl eax, 2
mov edx, eax
shr edx, 9
add edx, dword [fat_lba]
and eax, 511

cmp edx, dword [fat_sector]
je .cache
mov dword [fat_sector], edx

push eax
push ecx
mov eax, edx
mov ecx, 1
push edi
mov edi, 0x70000
call ata_read
pop edi
pop ecx
pop eax

.cache:
mov eax, dword [0x70000 + eax]
and eax, 0x0FFFFFFF
pop edx
pop ebx
ret

jmp $


fat_lba dd 0
data_lba dd 0
spc dd 0
fat_sector dd 0xFFFFFFFF
kernel_name db "KERNEL  BIN" 

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
