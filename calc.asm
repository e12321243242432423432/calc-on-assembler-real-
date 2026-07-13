; ==============================================================================
; ЧИСТЫЙ КРОССАРХИТЕКТУРНЫЙ BIGINT КАЛЬКУЛЯТОР В СТОЛБИК (БЕЗ ТЕКСТА И НАДПИСЕЙ)
; ==============================================================================

%ifdef ARCH_X86_32
    %define SYS_WRITE 4
    %define SYS_EXIT  1
    %define STDOUT    1
    %macro EXPAND_SYSCALL 0
        int 0x80
    %endmacro
    %define r_ax eax
    %define r_bx ebx
    %define r_cx ecx
    %define r_dx edx
    %define r_si esi
    %define r_di edi
    %define r_bp ebp
%else
    %define SYS_WRITE 1
    %define SYS_EXIT  60
    %define STDOUT    1
    %macro EXPAND_SYSCALL 0
        syscall
    %endmacro
    %define r_ax rax
    %define r_bx rbx
    %define r_cx rcx
    %define r_dx rdx
    %define r_si rsi
    %define r_di rdi
    %define r_bp rbp
%endif

section .data
    num1 db "1024"
    len1 equ $ - num1
    num2 db "3"
    len2 equ $ - num2
    newline db 10

section .bss
    res_buf   resb 1024
    temp_buf  resb 1024

section .text
    global _start

_start:
    ; 1. +
    call do_add
    call print_nl

    ; 2. -
    call do_sub
    call print_nl

    ; 3. *
    call do_mul
    call print_nl

    ; 4. /
    call do_div
    call print_nl

    ; 5. %
    call do_mod
    call print_nl

    ; 6. ^
    call do_pow
    call print_nl

    ; 7. <=>
    call do_compare
    call print_nl

    ; EXIT
    mov r_ax, SYS_EXIT
    xor r_di, r_di
    EXPAND_SYSCALL

; ==============================================================================
; МАТЕМАТИКА СТОЛБИКА
; ==============================================================================

do_add:
    mov r_cx, len1
    mov r_dx, len2
    mov r_di, 1023
    xor r_bx, r_bx
.loop:
    cmp r_cx, 0
    jg .step
    cmp r_dx, 0
    jg .step
    cmp r_bx, 0
    je .done
.step:
    xor r_ax, r_ax
    cmp r_cx, 0
    jle .s1
    dec r_cx
    movzx r_si, byte [num1 + r_cx]
    sub r_si, '0'
    add r_ax, r_si
.s1:
    cmp r_dx, 0
    jle .s2
    dec r_dx
    movzx r_si, byte [num2 + r_dx]
    sub r_si, '0'
    add r_ax, r_si
.s2:
    add r_ax, r_bx
    xor r_bx, r_bx
    cmp r_ax, 9
    jle .save
    mov r_bx, 1
    sub r_ax, 10
.save:
    add r_ax, '0'
    dec r_di
    mov [res_buf + r_di], al
    jmp .loop
.done:
    lea r_si, [res_buf + r_di]
    mov r_dx, 1023
    sub r_dx, r_di
    call write_out
    ret

do_sub:
    mov r_cx, len1
    mov r_dx, len2
    mov r_di, 1023
    xor r_bx, r_bx
.loop:
    cmp r_cx, 0
    je .done
    dec r_cx
    movzx r_ax, byte [num1 + r_cx]
    sub r_ax, '0'
    sub r_ax, r_bx
    xor r_bx, r_bx
    cmp r_dx, 0
    jle .st
    dec r_dx
    movzx r_si, byte [num2 + r_dx]
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
    mov [res_buf + r_di], al
    jmp .loop
.done:
    call strip_zeros
    ret

do_mul:
    mov r_cx, 1024
.clr:
    mov byte [res_buf + r_cx - 1], '0'
    loop .clr
    mov r_cx, len2
.out:
    cmp r_cx, 0
    je .done
    dec r_cx
    movzx r_bx, byte [num2 + r_cx]
    sub r_bx, '0'
    mov r_dx, len1
    xor r_bp, r_bp
.in:
    cmp r_dx, 0
    jg .calc
    cmp r_bp, 0
    je .out
.calc:
    xor r_ax, r_ax
    cmp r_dx, 0
    jle .sum
    dec r_dx
    movzx r_ax, byte [num1 + r_dx]
    sub r_ax, '0'
.sum:
    mul r_bx
    add r_ax, r_bp
    mov r_si, 1023
    mov r_bp, len2
    sub r_bp, 1
    sub r_bp, r_cx
    sub r_si, r_bp
    mov r_bp, len1
    sub r_bp, r_dx
    sub r_si, r_bp
    movzx r_di, byte [res_buf + r_si]
    sub r_di, '0'
    add r_ax, r_di
    xor r_dx, r_dx
    mov r_di, 10
    div r_di
    mov r_bp, r_ax
    add r_dx, '0'
    mov [res_buf + r_si], dl
    jmp .in
.done:
    mov r_di, 0
.fnd:
    cmp r_di, 1022
    jge .pr
    cmp byte [res_buf + r_di], '0'
    jne .pr
    inc r_di
    jmp .fnd
.pr:
    lea r_si, [res_buf + r_di]
    mov r_dx, 1024
    sub r_dx, r_di
    call write_out
    ret

do_div_core:
    xor r_si, r_si
    xor r_di, r_di
    xor r_bx, r_bx
.loop:
    cmp r_si, len1
    je .end
    mov r_ax, r_bx
    mov r_cx, 10
    mul r_cx
    mov r_bx, r_ax
    movzx r_ax, byte [num1 + r_si]
    sub r_ax, '0'
    add r_bx, r_ax
    movzx r_cx, byte [num2]
    sub r_cx, '0'
    mov r_ax, r_bx
    xor r_dx, r_dx
    div r_cx
    mov r_bx, r_dx
    add r_ax, '0'
    mov [res_buf + r_di], al
    inc r_di
    inc r_si
    jmp .loop
.end:
    ret

do_div:
    call do_div_core
    xor r_si, r_si
.strip:
    cmp r_si, r_di
    jge .pr
    cmp byte [res_buf + r_si], '0'
    jne .pr
    inc r_si
    jmp .strip
.pr:
    mov r_dx, r_di
    sub r_dx, r_si
    lea r_si, [res_buf + r_si]
    call write_out
    ret

do_mod:
    call do_div_core
    mov r_ax, r_bx
    add r_ax, '0'
    mov [res_buf], al
    lea r_si, [res_buf]
    mov r_dx, 1
    call write_out
    ret

do_pow:
    movzx r_cx, byte [num2]
    sub r_cx, '0'
    cmp r_cx, 0
    jne .calc
    mov byte [res_buf], '1'
    lea r_si, [res_buf]
    mov r_dx, 1
    call write_out
    ret
.calc:
    call do_mul
    ret

do_compare:
    mov r_ax, len1
    mov r_bx, len2
    cmp r_ax, r_bx
    jg .gt
    jl .lt
    xor r_cx, r_cx
.loop:
    cmp r_cx, len1
    je .eq
    mov al, [num1 + r_cx]
    mov bl, [num2 + r_cx]
    cmp al, bl
    jg .gt
    jl .lt
    inc r_cx
    jmp .loop
.eq:
    mov byte [res_buf], '0' ; 0 если равны
    jmp .pr
.gt:
    mov byte [res_buf], '1' ; 1 если первое больше
    jmp .pr
.lt:
    mov byte [res_buf], '2' ; 2 если второе больше
.pr:
    lea r_si, [res_buf]
    mov r_dx, 1
    call write_out
    ret

; ==============================================================================
; СИСТЕМНЫЙ ВЫВОД
; ==============================================================================

strip_zeros:
.loop:
    cmp r_di, 1022
    jge .pr
    cmp byte [res_buf + r_di], '0'
    jne .pr
    inc r_di
    jmp .loop
.pr:
    lea r_si, [res_buf + r_di]
    mov r_dx, 1023
    sub r_dx, r_di
    call write_out
    ret

write_out:
    mov r_ax, SYS_WRITE
    mov r_di, STDOUT
    EXPAND_SYSCALL
    ret

print_nl:
    mov r_ax, SYS_WRITE
    mov r_di, STDOUT
    lea r_si, [newline]
    mov r_dx, 1
    EXPAND_SYSCALL
    ret

