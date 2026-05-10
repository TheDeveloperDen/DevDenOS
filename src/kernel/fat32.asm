[bits 64]
default rel

section .bss
fat_lba resd 1
data_lba resd 1
spc resd 1
root_cluster resd 1
cached_fat_sector resd 1
fat_buf resb 512
dir_buf resb 32768
sfn_buf resb 16
lfn_buf resb 256
path_token resb 256

section .text

fat32_init:
movzx eax, word [abs 0x7c0e]
mov [fat_lba], eax

movzx ebx, byte [abs 0x7c10]
mov ecx, dword [abs 0x7c24]
imul ebx, ecx
add eax, ebx
mov [data_lba], eax

movzx eax, byte [abs 0x7c0d]
mov [spc], eax

mov eax, dword [abs 0x7c2c]
mov [root_cluster], eax
mov dword [cached_fat_sector], 0xFFFFFFFF
ret

;; rdi = cluster
;; rax = next cluster
fat32_get_next_cluster:
push rbx
push r12
push r13

mov rbx, rdi
mov rax, rbx
shl rax, 2
mov r12, rax
shr r12, 9
add r12d, dword [fat_lba]

mov r13, rax
and r13, 511

cmp r12d, dword [cached_fat_sector]
je .cached

mov dword [cached_fat_sector], r12d

mov edi, r12d
mov rsi, 1
lea rdx, [rel fat_buf]
call ata_read64

.cached:
lea rax, [rel fat_buf]
mov eax, dword [rax + r13]
and eax, 0x0FFFFFFF

pop r13
pop r12
pop rbx
ret

;; rdi = cluster
;; rsi = buffer
fat32_read_cluster:
push rbx
push r12
mov r12, rsi

mov eax, edi
sub eax, 2
imul eax, dword [spc]
add eax, dword [data_lba]

mov rdi, rax
mov esi, dword [spc]
mov rdx, r12
call ata_read64

pop r12
pop rbx
ret

;; rdi = start cluster
;; rsi = buffer
fat32_read_file:
push rbx
push r12
push r13
mov r12, rdi
mov r13, rsi
.read_loop:
mov rdi, r12
mov rsi, r13
call fat32_read_cluster

mov eax, dword [spc]
shl eax, 9
add r13, rax

mov rdi, r12
call fat32_get_next_cluster
mov r12, rax

cmp r12d, 0x0FFFFFF8
jae .done_read
jmp .read_loop
.done_read:
pop r13
pop r12
pop rbx
ret

;; rdi = filename
;; rax = cluster
;; rdx = size
fat32_find_file:
push rbx
push r12
push r13
push r14
push r15

mov r12, rdi
mov r13d, dword [root_cluster]

.next_token:
cmp byte [r12], '/'
jne .copy_token
inc r12
jmp .next_token

.copy_token:
cmp byte [r12], 0
je .not_found

lea rdi, [rel path_token]
mov rcx, 255

.copy_loop:
mov al, [r12]
cmp al, '/'
je .token_done
cmp al, 0
je .token_done
mov [rdi], al
inc rdi
inc r12
dec rcx
jnz .copy_loop

.token_done:
mov byte [rdi], 0

.read_dir:
mov rdi, r13
lea rsi, [rel dir_buf]
call fat32_read_cluster

lea r14, [rel dir_buf]
mov r15d, dword [spc]
shl r15, 9
add r15, r14

.parse_entry:
cmp r14, r15
jae .next_cluster

cmp byte [r14], 0
je .not_found
cmp byte [r14], 0xE5
je .deleted

cmp byte[r14 + 11], 0x0F
je .is_lfn

lea rdi, [rel lfn_buf]
cmp byte [rdi], 0
jne .check_lfn

mov rdi, r14
lea rsi, [rel sfn_buf]
call build_sfn

lea rdi, [rel path_token]
lea rsi,[rel sfn_buf]
call stricmp
test rax, rax
jnz .found
jmp .reset_lfn

.check_lfn:
lea rdi, [rel path_token]
lea rsi,[rel lfn_buf]
call stricmp
test rax, rax
jnz .found

.reset_lfn:
lea r8, [rel lfn_buf]
mov rcx, 32
xor rax, rax
.clear_lfn:
mov[r8 + rcx*8 - 8], rax
loop .clear_lfn
jmp .next_entry

.is_lfn:
movzx eax, byte [r14]
and eax, 0x1F
dec eax
imul eax, eax, 13
lea rdi, [rel lfn_buf]
add rdi, rax
mov rsi, r14
call extract_lfn
jmp .next_entry

.deleted:
lea r8, [rel lfn_buf]
mov rcx, 32
xor rax, rax
.clear_lfn2:
mov[r8 + rcx*8 - 8], rax
loop .clear_lfn2

.next_entry:
add r14, 32
jmp .parse_entry

.next_cluster:
mov rdi, r13
call fat32_get_next_cluster
cmp eax, 0x0FFFFFF8
jae .not_found
mov r13, rax
jmp .read_dir

.found:
cmp byte [r12], '/'
jne .check_end
inc r12
jmp .found

.check_end:
cmp byte [r12], 0
je .final_file

test byte [r14 + 11], 0x10
jz .not_found

movzx eax, word [r14 + 20]
shl eax, 16
mov ax, word [r14 + 26]
mov r13d, eax

lea r8, [rel lfn_buf]
mov rcx, 32
xor rax, rax
.clear_lfn3:
mov [r8 + rcx*8 - 8], rax
loop .clear_lfn3

jmp .next_token

.not_found:
xor rax, rax
xor rdx, rdx
jmp .exit

.final_file:
movzx eax, word [r14 + 20]
shl eax, 16
mov ax, word [r14 + 26]
mov edx, dword[r14 + 28]

.exit:
pop r15
pop r14
pop r13
pop r12
pop rbx
ret

extract_lfn:
push rbx
mov rcx, 13
lea rbx, [rel .offsets]

.ext_loop:
movzx edx, byte [rbx]
mov al, [rsi + rdx]
cmp al, 0xFF
jne .store
xor al, al

.store:
mov [rdi], al
inc rdi
inc rbx
loop .ext_loop
pop rbx
ret
.offsets: db 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30

build_sfn:
push rbx
push rdi
mov rcx, 8

.b1:
mov al, [rdi]
cmp al, ' '
je .b_ext
mov [rsi], al
inc rdi
inc rsi
dec rcx
jnz .b1

.b_ext:
pop rdi
push rdi
add rdi, 8
cmp byte [rdi], ' '
je .b_done
mov byte [rsi], '.'
inc rsi
mov rcx, 3

.b2:
mov al, [rdi]
cmp al, ' '
je .b_done
mov [rsi], al
inc rdi
inc rsi
dec rcx
jnz .b2

.b_done:
mov byte [rsi], 0
pop rdi
pop rbx
ret

stricmp:
push rdi
push rsi
.cmp_loop:
mov al, [rdi]
mov bl, [rsi]
test al, al
jz .cmp_end

cmp al, 'a'
jb .s1
cmp al, 'z'
ja .s1
sub al, 32

.s1:
cmp bl, 'a'
jb .s2
cmp bl, 'z'
ja .s2
sub bl, 32

.s2:
cmp al, bl
jne .cmp_fail
inc rdi
inc rsi
jmp .cmp_loop

.cmp_end:
test bl, bl
jnz .cmp_fail
mov rax, 1
pop rsi
pop rdi
ret

.cmp_fail:
xor rax, rax
pop rsi
pop rdi
ret

;; rdi = filename
;; rax = buffer
;; rdx = file size
fat32_load_file:
push rbx
push r12
push r13

call fat32_find_file
test rax, rax
jz .fail

mov r12, rax
mov r13, rdx

mov rdi, r13
call kmalloc
test rax, rax
jz .fail

mov rbx, rax

mov rdi, r12
mov rsi, rbx
call fat32_read_file

mov rax, rbx
mov rdx, r13
jmp .done

.fail:
xor rax, rax
xor rdx, rdx

.done:
pop r13
pop r12
pop rbx
ret