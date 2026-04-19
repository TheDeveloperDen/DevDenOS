ATA_PRIMARY_DATA equ 0x1F0
ATA_PRIMARY_ERR equ 0x1F1
ATA_PRIMARY_SECTORS equ 0x1F2
ATA_PRIMARY_LBALO equ 0x1F3
ATA_PRIMARY_LBAMI equ 0x1F4
ATA_PRIMARY_LBAHI equ 0x1F5
ATA_PRIMARY_HEAD equ 0x1F6
ATA_PRIMARY_STATUS equ 0x1F7
ATA_PRIMARY_CMD equ 0x1F7

ATA_ERR equ 0x01
ATA_DRQ equ 0x08
ATA_BSY equ 0x80

CMD_READ_SECTORS equ 0x20

ata_read:
pushad
.loop:
test ecx, ecx
jz .done

mov ebx, ecx
cmp ebx, 255
jbe .chk_ok
mov ebx, 255

.chk_ok:
mov edx, ATA_PRIMARY_HEAD
mov esi, eax
shr esi, 24
and esi, 0x0F
or esi, 0xE0
push eax
mov eax, esi
out dx, al 
pop eax

mov edx, ATA_PRIMARY_SECTORS
push eax
mov eax, ebx 
out dx, al 
pop eax 

mov edx, ATA_PRIMARY_LBALO
out dx, al 

mov edx, ATA_PRIMARY_LBAMI
push eax
shr eax, 8 
out dx, al 
pop eax

mov edx, ATA_PRIMARY_LBAHI
push eax 
shr eax, 16 
out dx, al 
pop eax

mov edx, ATA_PRIMARY_CMD
push eax
mov al, CMD_READ_SECTORS
out dx, al
mov edx, 0x3F6
in al, dx
in al, dx
in al, dx
in al, dx
pop eax

mov esi, ebx
push eax

.read_sectors:
mov edx, ATA_PRIMARY_STATUS
in al, dx

test al, ATA_BSY
jnz .read_sectors
test al, ATA_ERR
jnz .error
test al, ATA_DRQ
jz .read_sectors

mov edx, ATA_PRIMARY_DATA
push ecx
mov ecx, 256
rep insw
pop ecx

dec esi
jnz .read_sectors

pop eax
add eax, ebx
sub ecx, ebx
jmp .loop

.done:
popad
ret

.error:
mov edx, ATA_PRIMARY_ERR
in al, dx
jmp $