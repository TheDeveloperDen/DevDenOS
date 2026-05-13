[bits 64]
default rel

header:
db 'D','V','D','N'
db 1, 0
dw 3
dq _start
dq 0
dq lib_end - header
dd sections - header
dw 1
dd opt_hdr - header
dd opt_hdr_end - opt_hdr
dw 64
dw 0x8664
dq 0
db 0, 0, 0, 0, 0, 0

opt_hdr:
db 'S','H','L','B'
dd 0, 0, 0
db 'grap'
times 12 db 0
opt_hdr_end:

sections:
dq 0
dq lib_end - header
dq 0
dq lib_end - header

align 16
_start:
lea r8, [header]
lea rax, [export_table]

mov rcx, [rax + 0]
add rcx, r8
mov [rax + 0], rcx

mov rcx, [rax + 8]
add rcx, r8
mov [rax + 8], rcx

mov rcx, [rax + 16]
add rcx, r8
mov [rax + 16], rcx

mov rcx, [rax + 24]
add rcx, r8
mov [rax + 24], rcx

mov rcx, [rax + 32]
add rcx, r8
mov [rax + 32], rcx
ret

align 8
export_table:
dq gapi_init ; 0
dq gapi_set_res ; 1
dq gapi_put_pixel ; 2
dq gapi_draw_rect ; 3

gapi_init:
push rbp
mov rbp, rsp
push rbx

mov rax, 5
int 0x81
mov [gpu_handle], rax

mov rdi, rax
mov rax, 6
mov rsi, 1
xor rdx, rdx
xor r10, r10
int 0x81

pop rbx
mov rsp, rbp
pop rbp
ret

gapi_set_res:
push rbp
mov rbp, rsp
sub rsp, 16
mov [rsp], rdi
mov [rsp + 8], rsi

mov rax, 6
mov rdi, [gpu_handle]
mov rsi, 3
mov rdx, rsp
xor r10, r10
int 0x81

mov rsp, rbp
pop rbp
ret

gapi_put_pixel:
push rbp
mov rbp, rsp
sub rsp, 24
mov [rsp], rdi
mov [rsp + 8], rsi
mov [rsp + 16], rdx

mov rax, 6
mov rdi, [gpu_handle]
mov rsi, 2
mov rdx, rsp
xor r10, r10
int 0x81

mov rsp, rbp
pop rbp
ret

gapi_draw_rect:
push rbp
mov rbp, rsp
sub rsp, 40
mov [rsp], rdi
mov [rsp + 8], rsi
mov [rsp + 16], rdx
mov [rsp + 24], rcx
mov [rsp + 32], r8

mov rax, 6
mov rdi, [gpu_handle]
mov rsi, 4
mov rdx, rsp
xor r10, r10
int 0x81

mov rsp, rbp
pop rbp
ret


align 8
gpu_handle: dq 0

align 4096
lib_end: