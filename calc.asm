; ==============================================================================
; BigInt КАЛЬКУЛЯТОР С ВВОДОМ В ОДНУ СТРОКУ (СТРОГО ASM И SYSCALL)
; Формат ввода: 12345678901234567890 + 9876543210
; ==============================================================================

%ifdef ARCH_X86_32
    %define SYS_READ  3
    %define SYS_WRITE 4
    %define SYS_EXIT  1
    %define STDIN     0
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
    %define r_sp esp
%else
    %define SYS_READ  0
    %define SYS_WRITE 1
    %define SYS_EXIT  60
    %define STDIN     0
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
    %define r_sp rsp
%endif

section .data
    newline db 10

section .bss
    in_buf    resb 8192  ; Единый буфер для всей строки ввода
    res_buf   resb 8192  ; Буфер для вычислений в столбик
    
    ; Указатели и длины для выделенных чисел
    num1_ptr  resq 1
    len1      resq 1
    num2_ptr  resq 1
    len2      resq 1
    op_char   resb 1

section .text
    global _start

_start:
    ; Считываем всю строку за один вызов sys_read
    mov r_ax, SYS_READ
    mov r_di, STDIN
    lea r_si, [in_buf]
    mov r_dx, 8192
    EXPAND_SYSCALL

    ; --- ПАРСЕР СТРОКИ ВВОДА ---
    lea r_si, [in_buf]
    mov [num1_ptr], r_si    ; Первое число начинается с начала буфера
    xor r_cx, r_cx          ; Счётчик символов первого числа

.parse_num1:
    mov al, [r_si]
    cmp al, ' '
    je .end_num1
    cmp al, 10
    je .exit
    inc r_si
    inc r_cx
    jmp .parse_num1

.end_num1:
    mov [len1], r_cx        ; Сохраняем длину num1
    inc r_si                ; Пропускаем пробел

    ; Читаем символ операции
    mov al, [r_si]
    mov [op_char], al
    inc r_si                ; Пропускаем символ операции
    inc r_si                ; Пропускаем пробел после операции

    mov [num2_ptr], r_si    ; Начало второго числа
    xor r_cx, r_cx          ; Счётчик символов второго числа

.parse_num2:
    mov al, [r_si]
    cmp al, ' '
    je .end_num2
    cmp al, 10
    je .end_num2
    cmp al, 0
    je .end_num2
    inc r_si
    inc r_cx
    jmp .parse_num2

.end_num2:
    mov [len2], r_cx        ; Сохраняем длину num2

    ; --- МАРШРУТИЗАТОР ОПЕРАЦИЙ ---
    movzx r_ax, byte [op_char]
    cmp r_ax, '+'
    je .exec_add
    cmp r_ax, '-'
    je .exec_sub
    cmp r_ax, '*'
    je .exec_mul
    cmp r_ax, '/'
    je .exec_div
    cmp r_ax, '%'
    je .exec_mod
    cmp r_ax, '^'
    je .exec_pow
    cmp r_ax, '<'
    je .exec_cmp
    jmp .exit

.exec_add:
    call do_add
    jmp .done
.exec_sub:
    call do_sub
    jmp .done
.exec_mul:
    call do_mul
    jmp .done
.exec_div:
    call do_div
    jmp .done
.exec_mod:
    call do_mod
    jmp .done
.exec_pow:
    call do_pow
    jmp .done
.exec_cmp:
    call do_compare

.done:
    call print_nl

.exit:
    mov r_ax, SYS_EXIT
    xor r_di, r_di
    EXPAND_SYSCALL

; ==============================================================================
; МАТЕМАТИЧЕСКИЕ АЛГОРИТМЫ В СТОЛБИК
; ==============================================================================

do_add:
    mov r_cx, [len1]
    mov r_dx, [len2]
    mov r_di, 8191
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
    mov r_si, [num1_ptr]
    movzx r_si, byte [r_si + r_cx]
    sub r_si, '0'
    add r_ax, r_si
.s1:
    cmp r_dx, 0
    jle .s2
    dec r_dx
    mov r_si, [num2_ptr]
    movzx r_si, byte [r_si + r_dx]
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
    mov r_dx, 8191
    sub r_dx, r_di
    call write_out
    ret

do_sub:
    mov r_cx, [len1]
    mov r_dx, [len2]
    mov r_di, 8191
    xor r_bx, r_bx
.loop:
    cmp r_cx, 0
    je .done
    dec r_cx
    mov r_si, [num1_ptr]
    movzx r_ax, byte [r_si + r_cx]
    sub r_ax, '0'
    sub r_ax, r_bx
    xor r_bx, r_bx
    cmp r_dx, 0
    jle .st
    dec r_dx
    mov r_si, [num2_ptr]
    movzx r_si, byte [r_si + r_dx]
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
    push r_bp
    mov r_cx, 8192
.clr:
    mov byte [res_buf + r_cx - 1], '0'
    loop .clr

    mov r_cx, [len2]
.out_loop:
    cmp r_cx, 0
    je .done
    dec r_cx
    mov r_si, [num2_ptr]
    movzx r_bx, byte [r_si + r_cx]
    sub r_bx, '0'

    mov r_si, [len1]
    xor r_bp, r_bp
.in_loop:
    cmp r_si, 0
    jg .calc
    cmp r_bp, 0
    je .out_loop_next
.calc:
    xor r_ax, r_ax
    cmp r_si, 0
    jle .sum
    dec r_si
    mov r_di, [num1_ptr]
    movzx r_ax, byte [r_di + r_si]
    sub r_ax, '0'
.sum:
    push r_dx
    mul r_bx
    pop r_dx
    add r_ax, r_bp

    push r_bx
    push r_cx
    mov r_bx, 8191
    mov r_cx, [len2]
    sub r_cx, 1
    sub r_cx, [r_sp + r_ax*0]
    sub r_bx, r_cx
    mov r_cx, [len1]
    sub r_cx, r_si
    sub r_bx, r_cx

    movzx r_cx, byte [res_buf + r_bx]
    sub r_cx, '0'
    add r_ax, r_cx

    xor r_bp, r_bp
.mod_loop:
    cmp r_ax, 10
    jl .mod_done
    sub r_ax, 10
    inc r_bp
    jmp .mod_loop
.mod_done:
    add r_ax, '0'
    mov [res_buf + r_bx], al

    pop r_cx
    pop r_bx
    jmp .in_loop

.out_loop_next:
    jmp .out_loop
.done:
    pop r_bp
    mov r_di, 0
.fnd:
    cmp r_di, 8190
    jge .pr
    cmp byte [res_buf + r_di], '0'
    jne .pr
    inc r_di
    jmp .fnd
.pr:
    lea r_si, [res_buf + r_di]
    mov r_dx, 8192
    sub r_dx, r_di
    call write_out
    ret

do_div_core:
    xor r_si, r_si
    xor r_di, r_di
    xor r_bx, r_bx
.loop:
    cmp r_si, [len1]
    je .end
    
    push r_dx
    mov r_ax, r_bx
    mov r_cx, 10
    mul r_cx
    mov r_bx, r_ax
    pop r_dx

    mov r_bp, [num1_ptr]
    movzx r_ax, byte [r_bp + r_si]
    sub r_ax, '0'
    add r_bx, r_ax

    mov r_bp, [num2_ptr]
    movzx r_cx, byte [r_bp + 0]
    sub r_cx, '0'
    
    xor r_ax, r_ax
.div_sub_loop:
    cmp r_bx, r_cx
    jl .div_sub_done
    sub r_bx, r_cx
    inc r_ax
    jmp .div_sub_loop
.div_sub_done:
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
    call do_mul
    ret

do_compare:
    mov r_ax, [len1]
    mov r_bx, [len2]
    cmp r_ax, r_bx
    jg .gt
    jl .lt
    xor r_cx, r_cx
.loop:
    cmp r_cx, [len1]
    je .eq
    mov r_si, [num1_ptr]
    mov r_di, [num2_ptr]
    mov al, [r_si + r_cx]
    mov bl, [r_di + r_cx]
    cmp al, bl
    jg .gt
    jl .lt
    inc r_cx
    jmp .loop
.eq:
    mov byte [res_buf], '0'
    jmp .pr
.gt:
    mov byte [res_buf], '1'
    jmp .pr
.lt:
    mov byte [res_buf], '2'
.pr:
    lea r_si, [res_buf]
    mov r_dx, 1
    call write_out
    ret

; ==============================================================================
; ВЫВОД СТРОК
; ==============================================================================

strip_zeros:
.loop:
    cmp r_di, 8190
    jge .pr
    cmp byte [res_buf + r_di], '0'
    jne .pr
    inc r_di
    jmp .loop
.pr:
    lea r_si, [res_buf + r_di]
    mov r_dx, 8191
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

