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

section .data
fat32_lock_flag dd 0

section .text

fat32_lock:
lock bts dword[fat32_lock_flag], 0
jnc .done

.spin:
int 0x80
lock bts dword[fat32_lock_flag], 0
jc .spin

.done:
ret

fat32_unlock:
mov dword [fat32_lock_flag], 0
ret

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

lea r8, [rel lfn_buf]
mov rcx, 32
xor rax, rax
.clear_lfn_init:
mov[r8 + rcx*8 - 8], rax
loop .clear_lfn_init

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

;; rdi = dest buffer
;; rsi = LFN directory entry
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

;; rax = allocated cluster
fat32_alloc_cluster:
push rbx
mov rdi, 2

.scan:
push rdi
call fat32_get_next_cluster
pop rdi
test eax, eax
jz .found

inc rdi
jmp .scan

.found:
mov rax, rdi
pop rbx
ret

;; rdi = cluster
;; rsi = buffer
fat32_write_cluster:
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
call ata_write64

pop r12
pop rbx
ret

;; rdi = cluster
;; rsi = next cluster value
fat32_set_next_cluster:
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

mov edi, r12d
push rsi
mov rsi, 1
lea rdx, [fat_buf]
call ata_read64
pop rsi

lea rax, [fat_buf]
mov [rax + r13], esi

mov edi, r12d
mov rsi, 1
lea rdx, [fat_buf]
call ata_write64

mov dword [cached_fat_sector], r12d
pop r13
pop r12
pop rbx
ret

;; rdi = pointer to SFN filename
lfn_write_offsets: db 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30
sfn_checksum:
push rcx
push rdi
xor rax, rax
mov rcx, 11

.chk_loop:
ror al, 1
add al, byte [rdi]
inc rdi
dec rcx
jnz .chk_loop
pop rdi
pop rcx
ret

;; rdi = original filename
;; rsi = dest buffer
generate_sfn:
push rdi
push rsi
push rcx
push rax
push r8
push r9

push rdi
push rsi
mov rdi, rsi
mov rcx, 11
mov al, ' '
rep stosb
pop rsi
pop rdi

mov rcx, 6
mov r8, rdi
mov r9, rsi

.name_loop:
mov al,[rdi]
cmp al, '.'
je .do_tilde
cmp al, 0
je .do_tilde
cmp al, 'a'
jb .store
cmp al, 'z'
ja .store
sub al, 32

.store:
mov [rsi], al
inc rdi
inc rsi
dec rcx
jnz .name_loop

.find_ext:
mov al, [rdi]
cmp al, '.'
je .do_tilde
cmp al, 0
je .do_tilde
inc rdi
jmp .find_ext

.do_tilde:
mov byte [rsi], '~'
mov byte[rsi+1], '1'
mov rdi, r8

.ext_find:
mov al, [rdi]
cmp al, 0
je .done
cmp al, '.'
je .copy_ext
inc rdi
jmp .ext_find

.copy_ext:
inc rdi
lea rsi, [r9 + 8]
mov rcx, 3
.ext_loop:
mov al, [rdi]
cmp al, 0
je .done

cmp al, 'a'
jb .store_ext

cmp al, 'z'
ja .store_ext
sub al, 32

.store_ext:
mov [rsi], al
inc rdi
inc rsi
dec rcx
jnz .ext_loop

.done:
pop r9
pop r8
pop rax
pop rcx
pop rsi
pop rdi
ret

;; rdi = filename
;; rsi = buffer
;; rdx = size
fat32_write_file:
push rbx
push rcx
push rdi
push rsi
push rdx
push r12
push r13
push r14
push r15

mov r12, rsi
mov r13, rdx
mov r14, rdi

call fat32_find_file
test rax, rax
jnz .do_write

mov rbx, r14
xor rcx, rcx

.find_slash:
mov al, [rbx]
test al, al
jz .slash_done
cmp al, '/'
jne .next_char
mov rcx, rbx

.next_char:
inc rbx
jmp .find_slash

.slash_done:
test rcx, rcx
jz .in_root

cmp rcx, r14
je .root_slash

mov byte [rcx], 0
mov rdi, r14
push rcx
call fat32_find_file
pop rcx
mov byte [rcx], '/'

test rax, rax
jz .fail
mov r15, rax
lea r14, [rcx + 1]
jmp .build_name

.root_slash:
mov r15, [root_cluster]
lea r14, [rcx + 1]
jmp .build_name

.in_root:
mov r15,[root_cluster]

.build_name:
mov rdi, r14
lea rsi,[rel sfn_buf]
call generate_sfn

mov rdi, r14
xor rcx, rcx
.len_loop:
cmp byte [rdi + rcx], 0
je .len_done
inc rcx
jmp .len_loop

.len_done:
add rcx, 12
mov rax, rcx
xor rdx, rdx
mov rcx, 13
div rcx
mov r10, rax
mov r11, r10
inc r11

.scan_dir:
mov rdi, r15
lea rsi, [rel dir_buf]
call fat32_read_cluster

lea rbx, [rel dir_buf]
mov ecx, dword [spc]
shl ecx, 9
add rcx, rbx

xor r8, r8

.check_slot:
cmp rbx, rcx
jae .next_dir
cmp byte[rbx], 0
je .found_empty
cmp byte [rbx], 0xE5
je .found_empty

xor r8, r8
jmp .slot_continue

.found_empty:
test r8, r8
jnz .inc_count
mov r9, rbx

.inc_count:
inc r8

cmp byte [rbx], 0
jne .check_done
lea rax, [rbx + 32]
cmp rax, rcx
jae .check_done
mov byte [rax], 0

.check_done:
cmp r8, r11
je .found_slots

.slot_continue:
add rbx, 32
jmp .check_slot

.next_dir:
mov rdi, r15
call fat32_get_next_cluster
cmp eax, 0x0FFFFFF8
jae .fail
mov r15, rax
jmp .scan_dir

.found_slots:
lea rdi, [rel sfn_buf]
call sfn_checksum
mov r11b, al

mov rbx, r9
mov rcx, r10

.lfn_loop:
test rcx, rcx
jz .write_sfn

mov al, cl
cmp rcx, r10
jne .not_last_lfn
or al, 0x40
.not_last_lfn:
mov [rbx], al
mov byte [rbx + 11], 0x0F
mov byte[rbx + 12], 0
mov [rbx + 13], r11b
mov word[rbx + 26], 0

mov rax, rcx
dec rax
imul rax, 13
mov rdi, r14
add rdi, rax

push rcx
push rbx
lea rdx, [rel lfn_write_offsets]
mov rcx, 13
xor r9, r9
.lfn_char_loop:
movzx r8, byte [rdx]
cmp r9, 1
je .pad_ff
mov al,[rdi]
test al, al
jz .pad_null

mov [rbx + r8], al
mov byte [rbx + r8 + 1], 0
inc rdi
jmp .next_lfn_char

.pad_null:
mov word [rbx + r8], 0x0000
mov r9, 1
jmp .next_lfn_char

.pad_ff:
mov word [rbx + r8], 0xFFFF

.next_lfn_char:
inc rdx
dec rcx
jnz .lfn_char_loop

pop rbx
pop rcx
add rbx, 32
dec rcx
jmp .lfn_loop

.write_sfn:
call fat32_alloc_cluster
push rax
mov rdi, rax
mov rsi, 0x0FFFFFF8
call fat32_set_next_cluster
pop rax

push rax
mov rdi, rbx
lea rsi, [rel sfn_buf]
mov rcx, 11
rep movsb

mov byte [rbx + 11], 0x20
mov rdx, r13
mov dword [rbx + 28], edx

pop rax
mov word [rbx + 26], ax
shr eax, 16
mov word [rbx + 20], ax

mov rdi, r15
lea rsi, [rel dir_buf]
call fat32_write_cluster

movzx rax, word[rbx + 26]
movzx rcx, word [rbx + 20]
shl rcx, 16
or rax, rcx

.do_write:
mov r15, rax

.write_loop:
mov rdi, r15
mov rsi, r12
call fat32_write_cluster

mov eax, dword [spc]
shl eax, 9
add r12, rax
sub r13, rax
jle .done

mov rdi, r15
call fat32_get_next_cluster
cmp eax, 0x0FFFFFF8
jae .alloc_next
mov r15, rax
jmp .write_loop

.alloc_next:
call fat32_alloc_cluster
push rax
mov rdi, r15
mov rsi, rax
call fat32_set_next_cluster

pop rax
mov rdi, rax
mov rsi, 0x0FFFFFF8
call fat32_set_next_cluster
mov r15, rax
jmp .write_loop

.fail:
mov rax, -1

.done:
pop r15
pop r14
pop r13
pop r12
pop rdx
pop rsi
pop rdi
pop rcx
pop rbx
ret