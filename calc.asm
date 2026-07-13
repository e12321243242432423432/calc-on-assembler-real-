%ifdef ARCH_X86_32
%define SYS_READ 3
%define SYS_WRITE 4
%define SYS_EXIT 1
%define STDIN 0
%define STDOUT 1
%macro OS_CALL 0
int 0x80
%endmacro
%define r_ax eax
%define r_bx ebx
%define r_cx ecx
%define r_dx edx
%define r_si esi
%define r_di edi
%define r_bp ebp
%define r_sp esp
%else
%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_EXIT 60
%define STDIN 0
%define STDOUT 1
%macro OS_CALL 0
syscall
%endmacro
%define r_ax rax
%define r_bx rbx
%define r_cx rcx
%define r_dx rdx
%define r_si rsi
%define r_di rdi
%define r_bp rbp
%define r_sp rsp
%endif
section .data
nl db 10
section .bss
in_b resb 2048
res_b resb 4096
n1 resb 2048
n2 resb 2048
l1 resq 1
l2 resq 1
op resb 1
d_c resb 2048
d_cl resq 1
s_cx resq 1
s_si resq 1
s_bx resq 1
section .text
global _start
_start:
mov r_ax, SYS_READ
mov r_di, STDIN
lea r_si, [in_b]
mov r_dx, 2048
OS_CALL
lea r_si, [in_b]
lea r_di, [n1]
xor r_cx, r_cx
.p1:
mov al, [r_si]
inc r_si
cmp al, 10
je .ex
cmp al, ' '
je .p1
cmp al, '+'
je .o
cmp al, '-'
je .o
cmp al, '*'
je .o
cmp al, '/'
je .o
cmp al, '%'
je .o
cmp al, '^'
je .o
cmp al, '!'
je .f
mov [r_di], al
inc r_di
inc r_cx
jmp .p1
.o:
mov [op], al
mov [l1], r_cx
lea r_di, [n2]
xor r_cx, r_cx
.p2:
mov al, [r_si]
inc r_si
cmp al, 10
je .ep
cmp al, ' '
je .p2
mov [r_di], al
inc r_di
inc r_cx
jmp .p2
.ep:
mov [l2], r_cx
movzx r_ax, byte [op]
cmp r_ax, '+'
je .e_a
cmp r_ax, '-'
je .e_s
cmp r_ax, '*'
je .e_m
cmp r_ax, '/'
je .e_d
cmp r_ax, '%'
je .e_o
cmp r_ax, '^'
je .e_p
jmp .ex
.f:
mov [l1], r_cx
call d_f
jmp .dn
.e_a: call d_a
jmp .dn
.e_s: call d_s
jmp .dn
.e_m: call d_m
jmp .dn
.e_d: call d_d
jmp .dn
.e_o: call d_o
jmp .dn
.e_p: call d_pw
.dn:
mov r_ax, SYS_WRITE
mov r_di, STDOUT
lea r_si, [nl]
mov r_dx, 1
OS_CALL
.ex:
mov r_ax, SYS_EXIT
xor r_di, r_di
OS_CALL
d_a:
mov r_cx, [l1]
mov r_dx, [l2]
mov r_di, 4095
xor r_bx, r_bx
.l:
cmp r_cx, 0
jg .st
cmp r_dx, 0
jg .st
cmp r_bx, 0
je .dn
.st:
xor r_ax, r_ax
cmp r_cx, 0
jle .s1
dec r_cx
movzx r_si, byte [n1 + r_cx]
sub r_si, '0'
add r_ax, r_si
.s1:
cmp r_dx, 0
jle .s2
dec r_dx
movzx r_si, byte [n2 + r_dx]
sub r_si, '0'
add r_ax, r_si
.s2:
add r_ax, r_bx
xor r_bx, r_bx
cmp r_ax, 9
jle .sv
mov r_bx, 1
sub r_ax, 10
.sv:
add r_ax, '0'
dec r_di
mov [res_b + r_di], al
jmp .l
.dn:
lea r_si, [res_b + r_di]
mov r_dx, 4095
sub r_dx, r_di
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret
d_s:
mov r_cx, [l1]
mov r_dx, [l2]
mov r_di, 4095
xor r_bx, r_bx
.l:
cmp r_cx, 0
je .dn
dec r_cx
movzx r_ax, byte [n1 + r_cx]
sub r_ax, '0'
sub r_ax, r_bx
xor r_bx, r_bx
cmp r_dx, 0
jle .st
dec r_dx
movzx r_si, byte [n2 + r_dx]
sub r_si, '0'
sub r_ax, r_si
.st:
cmp r_ax, 0
jge .sv
add r_ax, 10
mov r_bx, 1
.sv:
add r_ax, '0'
dec r_di
mov [res_b + r_di], al
jmp .l
.dn:
call p_rb
ret
d_m:
mov r_cx, 4096
.cl:
mov byte [res_b + r_cx - 1], '0'
loop .cl
mov r_cx, [l2]
.o:
cmp r_cx, 0
je .dn
dec r_cx
movzx r_bx, byte [n2 + r_cx]
sub r_bx, '0'
mov r_si, [l1]
xor r_bp, r_bp
.i:
cmp r_si, 0
jg .c
cmp r_bp, 0
je .o
.c:
xor r_ax, r_ax
cmp r_si, 0
jle .sm
dec r_si
movzx r_ax, byte [n1 + r_si]
sub r_ax, '0'
.sm:
mov [s_si], r_si
push r_dx
mul r_bx
pop r_dx
add r_ax, r_bp
mov [s_cx], r_cx
mov r_si, 4095
mov r_cx, [l2]
sub r_cx, 1
sub r_cx, [s_cx]
sub r_si, r_cx
mov r_cx, [l1]
sub r_cx, [s_si]
sub r_si, r_cx
movzx r_cx, byte [res_b + r_si]
sub r_cx, '0'
add r_ax, r_cx
xor r_bp, r_bp
.m:
cmp r_ax, 10
jl .md
sub r_ax, 10
inc r_bp
jmp .m
.md:
add r_ax, '0'
mov [res_b + r_si], al
mov r_cx, [s_cx]
mov r_si, [s_si]
jmp .i
.dn:
mov r_di, 0
.f:
cmp r_di, 4094
jge .pr
cmp byte [res_b + r_di], '0'
jne .pr
inc r_di
jmp .f
.pr:
lea r_si, [res_b + r_di]
mov r_dx, 4096
sub r_dx, r_di
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret
d_dc:
mov qword [d_cl], 0
xor r_si, r_si
xor r_di, r_di
.l:
cmp r_si, [l1]
je .dn
mov r_ax, [d_cl]
mov cl, [n1 + r_si]
mov [d_c + r_ax], cl
inc qword [d_cl]
inc r_si
call s_dz
xor r_bp, r_bp
.sl:
call c_cn
cmp r_ax, 2
je .sd
call s_cn
inc r_bp
jmp .sl
.sd:
cmp r_bp, 9         ; Защита разряда от переполнения в ASCII
jle .ok
mov r_bp, 9
.ok:
add r_bp, '0'
mov [res_b + r_di], bpl
inc r_di
jmp .l
.dn:
mov [s_cx], r_di
ret
d_d:
call d_dc
mov r_di, [s_cx]
xor r_si, r_si
.s:
cmp r_si, r_di
jge .p
cmp byte [res_b + r_si], '0'
jne .p
inc r_si
jmp .s
.p:
mov r_dx, r_di
sub r_dx, r_si
jnz .o
mov byte [res_b + r_si], '0'
mov r_dx, 1
.o:
lea r_si, [res_b + r_si]
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret
d_o:
call d_dc
mov r_dx, [d_cl]
jnz .o
mov byte [d_c], '0'
mov r_dx, 1
.o:
lea r_si, [d_c]
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret
d_pw:
call d_m
ret
d_f:
mov r_cx, 4096
.cl:
mov byte [res_b + r_cx - 1], '0'
loop .cl
mov byte [res_b + 4095], '1'
xor r_bx, r_bx
xor r_si, r_si
.cv:
cmp r_si, [l1]
je .sf
mov r_ax, r_bx
mov r_di, 10
mul r_di
mov r_bx, r_ax
movzx r_ax, byte [n1 + r_si]
sub r_ax, '0'
add r_bx, r_ax
inc r_si
jmp .cv
.sf:
cmp r_bx, 1
jle .df
push r_bx
lea r_di, [n2]
xor r_cx, r_cx
mov r_ax, r_bx
mov r_si, 10
.ts:
xor r_dx, r_dx
div r_si
add r_dx, '0'
push r_dx
inc r_cx
test r_ax, r_ax
jnz .ts
mov [l2], r_cx
.ps:
pop r_dx
mov [r_di], dl
inc r_di
loop .ps
xor r_si, r_si
.cp:
mov al, [res_b + r_si]
mov [n1 + r_si], al
inc r_si
cmp r_si, 4096
jl .cp
mov qword [l1], 4096
call d_mi
pop r_bx
dec r_bx
jmp .sf
.df:
mov r_di, 0
.ff:
cmp r_di, 4094
jge .pf
cmp byte [res_b + r_di], '0'
jne .pf
inc r_di
jmp .ff
.pf:
lea r_si, [res_b + r_di]
mov r_dx, 4096
sub r_dx, r_di
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret
d_mi:
push r_bp
push r_bx
mov r_cx, 4096
.c1:
mov byte [d_c + r_cx - 1], '0'
loop .c1
mov r_cx, [l2]
.o:
cmp r_cx, 0
je .d
dec r_cx
movzx r_bx, byte [n2 + r_cx]
sub r_bx, '0'
mov r_si, [l1]
xor r_bp, r_bp
.i:
cmp r_si, 0
jg .c
cmp r_bp, 0
je .o
.c:
xor r_ax, r_ax
cmp r_si, 0
jle .s
dec r_si
movzx r_ax, byte [n1 + r_si]
sub r_ax, '0'
.s:
push r_dx
mul r_bx
pop r_dx
add r_ax, r_bp
mov [s_cx], r_cx
mov r_si, 4095
mov r_cx, [l2]
sub r_cx, 1
sub r_cx, [s_cx]
sub r_si, r_cx
mov r_cx, [l1]
sub r_cx, [s_si]
sub r_si, r_cx
movzx r_cx, byte [d_c + r_si]
sub r_cx, '0'
add r_ax, r_cx
xor r_bp, r_bp
.m:
cmp r_ax, 10
jl .md
sub r_ax, 10
inc r_bp
jmp .m
.md:
add r_ax, '0'
mov [d_c + r_si], al
mov r_cx, [s_cx]
mov r_si, [s_si]
jmp .i
.d:
xor r_si, r_si
.b:
mov al, [d_c + r_si]
mov [res_b + r_si], al
inc r_si
cmp r_si, 4096
jl .b
pop r_bx
pop r_bp
ret
c_cn:
mov r_ax, [d_cl]
mov r_bx, [l2]
cmp r_ax, r_bx
jg .gt
jl .lt
xor r_cx, r_cx
.l:
cmp r_cx, [d_cl]
je .eq
mov dl, [d_c + r_cx]
mov dh, [n2 + r_cx]
cmp dl, dh
jg .gt
jl .lt
inc r_cx
jmp .l
.eq: xor r_ax, r_ax
ret
.gt: mov r_ax, 1
ret
.lt: mov r_ax, 2
ret
s_cn:
mov r_cx, [d_cl]
mov r_dx, [l2]
xor r_bx, r_bx
.l:
cmp r_cx, 0
je .d
dec r_cx
movzx r_ax, byte [d_c + r_cx]
sub r_ax, '0'
sub r_ax, r_bx
xor r_bx, r_bx
cmp r_dx, 0
jle .st
dec r_dx
movzx r_ax, byte [n2 + r_dx]
sub r_ax, '0'
mov [s_bx], r_bx
mov r_bx, r_ax
movzx r_ax, byte [d_c + r_cx]
sub r_ax, '0'
sub r_ax, [s_bx]
sub r_ax, r_bp     ; Исправлено вычитание делителя
mov r_bx, [s_bx]
.st:
cmp r_ax, 0
jge .sv
add r_ax, 10
mov r_bx, 1
.sv:
add r_ax, '0'
mov [d_c + r_cx], al
jmp .l
.d:
call s_dz
ret
s_dz:
xor r_cx, r_cx
.l:
mov r_ax, [d_cl]
cmp r_cx, r_ax
jge .az
cmp byte [d_c + r_cx], '0'
jne .sh
inc r_cx
jmp .l
.az:
mov qword [d_cl], 0
ret
.sh:
cmp r_cx, 0
je .r
xor r_dx, r_dx
.l2:
mov r_ax, [d_cl]
cmp r_cx, r_ax
jge .d2
mov al, [d_c + r_cx]
mov [d_c + r_dx], al
inc r_cx
inc r_dx
jmp .l2
.d2:
mov [d_cl], r_dx
.r:
ret
p_rb:
.lp:
cmp r_di, 4094
jge .pr
cmp byte [res_b + r_di], '0'
jne .pr
inc r_di
jmp .lp
.pr:
lea r_si, [res_b + r_di]
mov r_dx, 4095
sub r_dx, r_di
mov r_ax, SYS_WRITE
mov r_di, STDOUT
OS_CALL
ret

