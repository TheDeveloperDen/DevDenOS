[bits 64]
default rel

section .text

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
db 'gpu'
times 13 db 0
opt_hdr_end:

sections:
dq 0
dq drv_end - header
dq 0
dq drv_end - header

%include "globals.asm"

align 16
_start:
mov [api_table], rdi
lea rax, [dispatch]
ret

; rdi = page count
; rax = virt addr
; rdx = phys addr
alloc_driver_contiguous:
mov rax, [api_table]
call [rax + 72]
ret

; rdi = virt addr
; rsi = page count
free_driver_contiguous:
mov rax, [api_table]
call [rax + 80]
ret


dispatch:
push rbp
mov rbp, rsp
push rbx
push r12
push r13
push r14
push r15

cmp rdi, 1
je .do_init
cmp rdi, 2
je .do_init_3d
cmp rdi, 3
je .do_clear_screen
cmp rdi, 4
je .do_create_shader

mov rax, -1
jmp .done

.do_create_shader:
mov r14, rsi
mov rdi, [r14 + 8]
xor rcx, rcx

.len_loop:
cmp byte [rdi + rcx], 0
je .len_done
inc rcx
jmp .len_loop

.len_done:
inc rcx
mov r15, rcx
lea rax, [r15 + 3]
shr rax, 2
mov rbx, rax
lea r8, [rbx + 6]
shl r8, 2
lea r9, [r8 + 32]
lea rax, [r9 + 15]
and rax, ~15
mov rdx, rax
add rax, 24
add rax, 4095
shr rax, 12

push rbx
push r15
push r8
push r9
push rdx
push rax
mov rdi, rax
call alloc_driver_contiguous

test rax, rax
jz .shader_alloc_failed

mov r12, rax
mov r13, rdx
pop r10
push r10
shl r10, 9
mov rcx, r10
mov rdi, r12
xor rax, rax
rep stosq

pop r10
pop rdx
pop r9
pop r8
pop r15
pop rbx

mov dword [r12], 0x0207
mov dword [r12 + 16], 1
mov [r12 + 24], r8d
mov eax, ebx
add eax, 5
shl eax, 16
or eax, 0x0401

mov [r12 + 32], eax
mov rax, [next_obj_id]
mov [r12 + 36], eax
mov rcx, [r14]
mov [r12 + 40], ecx
mov [r12 + 44], r15d
mov [r12 + 48], ebx
mov dword [r12 + 52], 0
mov rdi, r12

add rdi, 56
mov rsi, [r14 + 8]
mov rcx, r15
rep movsb
push r10
push rdx

mov rdi, r13
mov rsi, r9
add rdx, r13
mov rcx, 24

call send_virtio_cmd
pop rdx
mov rdi, r12
add rdi, rdx
cmp dword [rdi], 0x1100
jne .shader_failed
mov rax, [next_obj_id]

mov [r14 + 16], rax
inc qword [next_obj_id]
pop rsi
mov rdi, r12
call free_driver_contiguous
mov rax, 1
jmp .done

.shader_failed:
pop rsi
mov rdi, r12
call free_driver_contiguous
mov rax, -1
jmp .done

.shader_alloc_failed:
add rsp, 48
mov rax, -1
jmp .done

.do_init_3d:
mov rdi, 1
call alloc_driver_contiguous
test rax, rax
jz .err_out
mov r12, rax
mov r13, rdx

mov rdi, r12
mov rcx, 512
xor eax, eax
rep stosq

; CTX_CREATE
mov dword [r12], 0x0200
mov dword [r12 + 16], 1
mov dword [r12 + 24], 7
mov dword [r12 + 32], 0x6e447644 ; "DvDn"
mov dword [r12 + 36], 0x0044332d ; "-3D\0"

mov rdi, r13
mov rsi, 96
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; RESOURCE_CREATE_3D
mov rdi, r12
mov rcx, 32
xor eax, eax
rep stosq

mov dword [r12], 0x0204
mov dword [r12 + 24], 1 ; Color Texture ID
mov dword [r12 + 28], 2 ; VIRGL_TARGET_TEXTURE_2D
mov dword [r12 + 32], 1 ; VIRGL_FORMAT_B8G8R8A8_UNORM
mov dword [r12 + 36], 0x40002 ; BIND_RENDER_TARGET | BIND_SCANOUT
mov rax, [screen_width]
mov dword [r12 + 40], eax
mov rax, [screen_height]
mov dword [r12 + 44], eax
mov dword [r12 + 48], 1
mov dword [r12 + 52], 1

mov rdi, r13
mov rsi, 72
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; ATTACH_RESOURCE
mov rdi, r12
mov rcx, 16
xor eax, eax
rep stosq

mov dword [r12], 0x0202
mov dword [r12 + 16], 1
mov dword [r12 + 24], 1

mov rdi, r13
mov rsi, 32
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

mov rax, [screen_width]
imul rax, [screen_height]
shl rax, 2 ; screen_width * screen_height * 4 bytes
mov [fb_backing_size], rax
add rax, 4095
shr rax, 12
mov rdi, rax
call alloc_driver_contiguous
test rax, rax
jz .failed_3d
mov [fb_backing_virt], rax
mov [fb_backing_phys], rdx

; VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING
mov rdi, r12
mov rcx, 16
xor eax, eax
rep stosq

mov dword [r12], 0x0106
mov dword [r12 + 24], 1 ; Color Buffer
mov dword [r12 + 28], 1 ; nr_entries
mov rax, [fb_backing_phys]
mov [r12 + 32], rax
mov rax, [fb_backing_size]
mov dword [r12 + 40], eax
mov dword [r12 + 44], 0

mov rdi, r13
mov rsi, 48
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; RESOURCE_CREATE_3D
mov rdi, r12
mov rcx, 32
xor eax, eax
rep stosq

mov dword [r12], 0x0204
mov dword [r12 + 24], 2 ; Depth Texture ID
mov dword [r12 + 28], 2 ; VIRGL_TARGET_TEXTURE_2D
mov dword [r12 + 32], 16 ; VIRGL_FORMAT_Z16_UNORM
mov dword [r12 + 36], 1 ; VIRGL_BIND_DEPTH_STENCIL
mov rax, [screen_width]
mov dword [r12 + 40], eax
mov rax, [screen_height]
mov dword [r12 + 44], eax
mov dword [r12 + 48], 1
mov dword [r12 + 52], 1

mov rdi, r13
mov rsi, 72
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; ATTACH_RESOURCE
mov rdi, r12
mov rcx, 16
xor eax, eax
rep stosq

mov dword [r12], 0x0202
mov dword [r12 + 16], 1
mov dword [r12 + 24], 2

mov rdi, r13
mov rsi, 32
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; SET_SCANOUT
mov rdi, r12
mov rcx, 16
xor eax, eax
rep stosq

mov dword [r12], 0x0103
mov dword [r12 + 24], 0
mov dword [r12 + 28], 0
mov rax, [screen_width]
mov dword [r12 + 32], eax
mov rax, [screen_height]
mov dword [r12 + 36], eax
mov dword [r12 + 40], 0
mov dword [r12 + 44], 1

mov rdi, r13
mov rsi, 48
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

; SUBMIT_3D
mov rdi, r12
mov rcx, 128
xor eax, eax
rep stosq

mov dword [r12], 0x0207
mov dword [r12 + 16], 1
mov dword [r12 + 24], 48

; Color Surface
mov dword [r12 + 32], 0x50801 ; VIRGL_CCMD_CREATE_OBJECT
mov dword [r12 + 36], 7
mov dword [r12 + 40], 1 ; Color Texture ID
mov dword [r12 + 44], 1 ; B8G8R8A8_UNORM format
mov dword [r12 + 48], 0
mov dword [r12 + 52], 0

; Depth Surface
mov dword [r12 + 56], 0x50801 ; VIRGL_CCMD_CREATE_OBJECT
mov dword [r12 + 60], 8
mov dword [r12 + 64], 2 ; Depth Texture ID
mov dword [r12 + 68], 16 ; Z16_UNORM format
mov dword [r12 + 72], 0
mov dword [r12 + 76], 0

mov rdi, r13
mov rsi, 80
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .failed_3d

mov rdi, r12
mov rsi, 1
call free_driver_contiguous
mov rax, 1
jmp .done

.failed_3d:
mov rdi, [fb_backing_virt]
test rdi, rdi
jz .skip_fb_free
mov rax, [fb_backing_size]
add rax, 4095
shr rax, 12
mov rsi, rax
call free_driver_contiguous
mov qword [fb_backing_virt], 0

.skip_fb_free:
mov rdi, r12
mov rsi, 1
call free_driver_contiguous
.err_out:
mov rax, -1
jmp .done

;; rsi = float color pointer (RGBA)
.do_clear_screen:
mov r8d, dword [rsi]
mov r9d, dword [rsi + 4]
mov r10d, dword [rsi + 8]
mov r11d, dword [rsi + 12]

mov rdi, 1
call alloc_driver_contiguous
test rax, rax
jz .err_out
mov r12, rax
mov r13, rdx

mov rdi, r12
mov rcx, 128
xor eax, eax
rep stosq

; SUBMIT_3D
mov dword [r12], 0x0207
mov dword [r12 + 16], 1
mov dword [r12 + 24], 52

mov dword [r12 + 32], 0x30005 ; VIRGL_CCMD_SET_FRAMEBUFFER_STATE
mov dword [r12 + 36], 1 ; Active render targets
mov dword [r12 + 40], 8 ; Depth Surface Handle
mov dword [r12 + 44], 7 ; Color Surface Handle

mov dword [r12 + 48], 0x80007 ; VIRGL_CCMD_CLEAR
mov dword [r12 + 52], 5 ; Flags
mov [r12 + 56], r8d ; Red
mov [r12 + 60], r9d ; Green
mov [r12 + 64], r10d ; Blue
mov [r12 + 68], r11d ; Alpha
mov dword [r12 + 72], 0 ; Depth
mov dword [r12 + 76], 0x3ff00000 ; Depth
mov dword [r12 + 80], 0 ; Stencil

mov rdi, r13
mov rsi, 84
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .clear_fail

mov rdi, r12
mov rcx, 16
xor eax, eax
rep stosq

mov dword [r12], 0x0104 ; VIRTIO_GPU_CMD_RESOURCE_FLUSH
mov dword [r12 + 24], 0
mov dword [r12 + 28], 0
mov rax, [screen_width]
mov dword [r12 + 32], eax
mov rax, [screen_height]
mov dword [r12 + 36], eax
mov dword [r12 + 40], 1 ; Color Buffer Resource ID

mov rdi, r13
mov rsi, 48
mov rdx, r13
add rdx, 256
mov rcx, 24
call send_virtio_cmd
cmp dword [r12 + 256], 0x1100
jne .clear_fail

mov rdi, r12
mov rsi, 1
call free_driver_contiguous
mov rax, 1
jmp .done

.clear_fail:
mov rdi, r12
mov rsi, 1
call free_driver_contiguous
mov rax, -1
jmp .done

.do_init:
mov rdi, 0x1AF4
mov rsi, 0x1050
mov rax, [api_table]
call [rax + 64]
cmp eax, -1
je .not_found

mov [dev_bdf], eax

mov rcx, 0x04
call read_pci_reg
or eax, 0x06
mov r8, rax
mov rcx, 0x04
call write_pci_reg

mov dword [common_bar], -1
mov rcx, 0x34
call read_pci_reg
and eax, 0xFF
mov [cap_ptr], eax

.cap_loop:
mov eax, [cap_ptr]
test eax, eax
jz .done_caps

mov rcx, rax
call read_pci_reg
mov [cap_val0], eax

and eax, 0xFF
cmp eax, 0x09
jne .next_cap

mov eax, [cap_val0]
shr eax, 24
cmp eax, 1
je .found_common
cmp eax, 2
je .found_notify
jmp .next_cap

.found_common:
mov eax, [cap_ptr]
add eax, 4
mov rcx, rax
call read_pci_reg
and eax, 0xFF
mov [common_bar], eax

mov eax, [cap_ptr]
add eax, 8
mov rcx, rax
call read_pci_reg
mov [common_offset], eax
jmp .next_cap

.found_notify:
mov eax, [cap_ptr]
add eax, 4
mov rcx, rax
call read_pci_reg
and eax, 0xFF
mov [notify_bar], eax

mov eax, [cap_ptr]
add eax, 8
mov rcx, rax
call read_pci_reg
mov [notify_offset], eax

mov eax, [cap_ptr]
add eax, 16
mov rcx, rax
call read_pci_reg
mov [notify_multiplier], eax
jmp .next_cap

.next_cap:
mov eax, [cap_val0]
shr eax, 8
and eax, 0xFF
mov [cap_ptr], eax
jmp .cap_loop

.done_caps:
mov eax, [common_bar]
cmp eax, -1
je .not_found

mov rcx, [common_bar]
shl rcx, 2
add rcx, 0x10
call read_pci_reg
mov rbx, rax
and ebx, 0xFFFFFFF0

mov rdx, rax
and edx, 6
cmp edx, 4
jne .bar_mapped

mov rcx, [common_bar]
shl rcx, 2
add rcx, 0x14
call read_pci_reg
shl rax, 32
or rbx, rax

.bar_mapped:
mov eax, [common_offset]
add rbx, rax

mov rsi, rbx
and rsi, ~0xFFF
mov rdi, rsi
mov rax, 0xFFFF800000000000
add rdi, rax
mov rdx, 0x12
mov rax, [api_table]
call [rax + 16]

mov rdi, 0xFFFF800000000000
add rbx, rdi

mov eax, [notify_bar]
cmp eax, -1
je .skip_notify

mov rcx, [notify_bar]
shl rcx, 2
add rcx, 0x10
call read_pci_reg
mov r12, rax
and r12d, 0xFFFFFFF0

mov rdx, rax
and edx, 6
cmp edx, 4
jne .notify_mapped

mov rcx, [notify_bar]
shl rcx, 2
add rcx, 0x14
call read_pci_reg
shl rax, 32
or r12, rax

.notify_mapped:
mov eax, [notify_offset]
add r12, rax

mov rsi, r12
and rsi, ~0xFFF
mov rdi, rsi
mov rax, 0xFFFF800000000000
add rdi, rax

mov r13, 4
.notify_map_loop:
push rdi
push rsi

mov rdx, 0x12
mov rax, [api_table]
call [rax + 16]

pop rsi
pop rdi

add rdi, 0x1000
add rsi, 0x1000
dec r13
jnz .notify_map_loop

mov rdi, 0xFFFF800000000000
add r12, rdi
mov [notify_mapped_addr], r12

.skip_notify:
mov byte [rbx + 0x14], 0
mov byte [rbx + 0x14], 1

mov byte [rbx + 0x14], 3

mov dword [rbx + 0x00], 0
mov eax, dword [rbx + 0x04]

mov dword [rbx + 0x08], 0
test eax, 1
jz .no_virgl

lea rdi, [msg_virgl_yes]
call serial_print
mov dword [rbx + 0x0C], 1
jmp .virgl_done

.no_virgl:
lea rdi, [msg_virgl_no]
call serial_print
mov dword [rbx + 0x0C], 0

.virgl_done:

mov dword [rbx + 0x00], 1
mov dword [rbx + 0x08], 1
mov dword [rbx + 0x0C], 1

mov byte [rbx + 0x14], 0x0B
mov al, byte [rbx + 0x14]
test al, 8
jz .fail_features

mov word [rbx + 0x16], 0
mov ax, word [rbx + 0x18]
test ax, ax
jz .fail_queues

movzx r15, ax
movzx eax, word [rbx + 0x1E]
mov [control_notify_off], rax

mov rdi, r15
shl rdi, 4
add rdi, 4095
shr rdi, 12
mov [control_desc_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [control_desc_phys], rax
mov [control_desc_virt], rdx
mov [rbx + 0x20], rax

mov rdi, r15
shl rdi, 1
add rdi, 4101
shr rdi, 12
mov [control_avail_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [control_avail_phys], rax
mov [control_avail_virt], rdx
mov [rbx + 0x28], rax

mov rdi, r15
shl rdi, 3
add rdi, 4101
shr rdi, 12
mov [control_used_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [control_used_phys], rax
mov [control_used_virt], rdx
mov [rbx + 0x30], rax

mov word [rbx + 0x1C], 1

mov word [rbx + 0x16], 1
mov ax, word [rbx + 0x18]
test ax, ax
jz .fail_queues

movzx r15, ax
mov [control_queue_size], ax
movzx eax, word [rbx + 0x1E]
mov [cursor_notify_off], rax

mov rdi, r15
shl rdi, 4
add rdi, 4095
shr rdi, 12
mov [cursor_desc_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [cursor_desc_phys], rax
mov [cursor_desc_virt], rdx
mov [rbx + 0x20], rax

mov rdi, r15
shl rdi, 1
add rdi, 4101
shr rdi, 12
mov [cursor_avail_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [cursor_avail_phys], rax
mov [cursor_avail_virt], rdx
mov [rbx + 0x28], rax

mov rdi, r15
shl rdi, 3
add rdi, 4101
shr rdi, 12
mov [cursor_used_pages], rdi
call alloc_queue_contiguous
test rax, rax
jz .fail_queues
mov [cursor_used_phys], rax
mov [cursor_used_virt], rdx
mov [rbx + 0x30], rax

mov word [rbx + 0x1C], 1

mov byte [rbx + 0x14], 0x0F

mov al, byte [rbx + 0x14]
test al, 0x40
jnz .fail_host
test al, 0x0F
jz .fail_host

lea rdi, [msg_gpu_ready]
call serial_print

mov rdi, 1
call alloc_driver_contiguous
test rax, rax
jz .test_failed

mov [test_buf_virt], rax
mov [test_buf_phys], rdx

mov rdi, [test_buf_virt]
xor rcx, rcx
mov [rdi], rcx
mov [rdi + 8], rcx
mov [rdi + 16], rcx
mov dword [rdi], 0x0100

mov rsi, [control_avail_virt]
movzx rcx, word [rsi + 2]

movzx rax, word [control_queue_size]
dec rax
mov r8, rcx
shl r8, 1
and r8, rax

mov rsi, [control_desc_virt]
mov r9, r8
shl r9, 4
add rsi, r9

mov rax, [test_buf_phys]
mov [rsi], rax
mov dword [rsi + 8], 24
mov word [rsi + 12], 1
lea r10, [r8 + 1]
mov word [rsi + 14], r10w

mov rax, [test_buf_phys]
add rax, 64
mov [rsi + 16], rax
mov dword [rsi + 24], 408
mov word [rsi + 28], 2
mov word [rsi + 30], 0

mov rsi, [control_avail_virt]
mov rdx, rcx
and rdx, rax
mov word [rsi + 4 + rdx * 2], r8w

inc rcx
mfence
mov [rsi + 2], cx
mfence

mov rdi, [notify_mapped_addr]
test rdi, rdi
jz .test_failed

mov rax, [control_notify_off]
mov edx, dword [notify_multiplier]
imul rax, rdx
add rdi, rax
mov word [rdi], 0

mov rsi, [control_used_virt]
.test_wait:
mov ax, [rsi + 2]
cmp ax, cx
jne .test_wait

mov rdi, [test_buf_virt]
add rdi, 64
mov eax, [rdi]
cmp eax, 0x1101
jne .test_failed

lea rdi, [msg_display_info]
call serial_print

mov rdi, [test_buf_virt]
add rdi, 64
movzx rdi, dword [rdi + 32]
call serial_print_hex

lea rdi, [msg_display_x]
call serial_print

mov rdi, [test_buf_virt]
add rdi, 64
movzx rdi, dword [rdi + 36]
call serial_print_hex

mov rsi, [test_buf_virt]
add rsi, 64
mov eax, dword [rsi + 32]
mov [screen_width], rax
mov eax, dword [rsi + 36]
mov [screen_height], rax

lea rdi, [msg_newline]
call serial_print
jmp .test_cleanup

.test_failed:
lea rdi, [msg_test_fail]
call serial_print

.test_cleanup:
mov rdi, [test_buf_virt]
test rdi, rdi
jz .test_done
mov rsi, 1
call free_driver_contiguous

.test_done:
mov rax, 1
jmp .done

.fail_host:
lea rdi, [msg_fail_host]
call serial_print
mov rax, -1
jmp .done


.fail_features:
lea rdi, [msg_fail_feat]
call serial_print
mov rax, -1
jmp .done

.fail_queues:
lea rdi, [msg_fail_queues]
call serial_print
mov rax, -1
jmp .done

.not_found:
lea rdi, [msg_no_dev]
call serial_print
mov rax, -1

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

alloc_queue_contiguous:
push rbx
push rcx
push rdi
push rsi

push rdi
mov rax, [api_table]
call [rax + 72]
pop rdi

test rax, rax
jz .alloc_fail

mov rbx, rax
mov rsi, rdx

mov rcx, rdi
shl rcx, 9
mov rdi, rbx
xor rax, rax
rep stosq

mov rax, rsi
mov rdx, rbx

.alloc_fail:
pop rsi
pop rdi
pop rcx
pop rbx
ret

read_pci_reg:
mov rdi, [dev_bdf]
mov rdx, rdi
and rdx, 0xFF
mov rsi, rdi
shr rsi, 8
and rsi, 0xFF
shr rdi, 16
and rdi, 0xFF
mov rax, [api_table]
call [rax + 48]
ret

write_pci_reg:
mov rdi, [dev_bdf]
mov rdx, rdi
and rdx, 0xFF
mov rsi, rdi
shr rsi, 8
and rsi, 0xFF
shr rdi, 16
and rdi, 0xFF
mov rax, [api_table]
call [rax + 56]
ret



mov rax, 1
jmp .done

.done:
pop r15
pop r14
pop r13
pop r12
pop rbx
pop rbp
ret

;; rdi = cmd phys
;; rsi = cmd size
;; rdx = resp phys
;; rcx = resp size
send_virtio_cmd:
push rbx
push r12
push r13
push r14
push r15
mov r12, rdi
mov r13, rsi
mov r14, rdx
mov r15, rcx

mov rsi, [control_avail_virt]
movzx rcx, word [rsi + 2]
movzx rax, word [control_queue_size]
dec rax
mov r8, rcx
shl r8, 1
and r8, rax

mov rsi, [control_desc_virt]
mov r9, r8
shl r9, 4
add rsi, r9

mov [rsi], r12
mov [rsi + 8], r13d
mov word [rsi + 12], 1 ; VRING_DESC_F_NEXT
lea r10, [r8 + 1]
mov [rsi + 14], r10w

mov [rsi + 16], r14
mov [rsi + 24], r15d
mov word [rsi + 28], 2 ; VRING_DESC_F_WRITE
mov word [rsi + 30], 0

mov rsi, [control_avail_virt]
mov rdx, rcx
and rdx, rax
mov [rsi + 4 + rdx * 2], r8w

inc rcx
mfence
mov [rsi + 2], cx
mfence

; Notify device
mov rdi, [notify_mapped_addr]
mov rax, [control_notify_off]
mov edx, dword [notify_multiplier]
imul rax, rdx
add rdi, rax
mov word [rdi], 0

mov rsi, [control_used_virt]
.wait_loop:
mov ax, [rsi + 2]
cmp ax, cx
jne .wait_loop

pop r15
pop r14
pop r13
pop r12
pop rbx
ret




%include "../../kernel/serial.asm"


msg_no_dev: db "Virtio GPU not found!", 10, 0
msg_virgl_yes: db "VirGL is supported chirp!", 10, 0
msg_virgl_no: db "VirGL isnt supported cro", 10, 0
msg_gpu_ready: db "DRIVER_OK", 10, 0
msg_fail_feat: db "FEATURES_OK failed!", 10, 0
msg_fail_queues: db "Queue setup failed!", 10, 0
msg_fail_host: db "Host rejected init", 10, 0

msg_display_info: db "Display 0 Resolution: ", 0
msg_display_x: db "x", 0
msg_newline: db 10, 0
msg_test_fail: db "Display info query failed!", 10, 0

dev_bdf dq 0
cap_ptr dq 0
cap_val0 dq 0
common_bar dq -1
common_offset dq 0

notify_bar dq -1
notify_offset dq 0
notify_multiplier dq 0
notify_mapped_addr dq 0

next_virt_queue_addr dq 0xFFFF8000A0000000

control_desc_phys dq 0
control_desc_virt dq 0
control_avail_phys dq 0
control_avail_virt dq 0
control_used_phys dq 0
control_used_virt dq 0

control_desc_pages dq 0
control_avail_pages dq 0
control_used_pages dq 0

control_queue_size dw 0
test_buf_virt dq 0
test_buf_phys dq 0

cursor_desc_pages dq 0
cursor_avail_pages dq 0
cursor_used_pages dq 0

cursor_desc_phys dq 0
cursor_desc_virt dq 0
cursor_avail_phys dq 0
cursor_avail_virt dq 0
cursor_used_phys dq 0
cursor_used_virt dq 0
control_notify_off dq 0
cursor_notify_off dq 0

screen_width dq 0
screen_height dq 0

fb_backing_virt dq 0
fb_backing_phys dq 0
fb_backing_size dq 0

next_obj_id dq 7

align 8
api_table: dq 0

align 4096
drv_end:
