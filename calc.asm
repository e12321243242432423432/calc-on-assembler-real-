; ==============================================================================
; BigInt КАЛЬКУЛЯТОР (ВВОД С ПРОБЕЛАМИ ИЛИ БЕЗ В ОДНУ СТРОКУ, СТРОГО SYSCALL)
; Форматы: "123+456" или "123 + 456" или "123   +   456"
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
    in_buf    resb 8192
    res_buf   resb 8192
    
    ; Буферы для очищенных от пробелов чисел
    num1      resb 4096
    num2      resb 4096
    
    len1      resq 1
    len2      resq 1
    op_char   resb 1

section .text
    global _start

_start:
    ; Читаем всю строку
    mov r_ax, SYS_READ
    mov r_di, STDIN
    lea r_si, [in_buf]
    mov r_dx, 8192
    EXPAND_SYSCALL

    ; --- УНИВЕРСАЛЬНЫЙ ПАРСЕР СТРОКИ ---
    lea r_si, [in_buf]
    lea r_di, [num1]
    xor r_cx, r_cx          ; Длина num1

.parse_num1:
    mov al, [r_si]
    inc r_si
    cmp al, 10              ; Конец строки
    je .exit
    cmp al, 0
    je .exit
    cmp al, ' '             ; Игнорируем пробелы
    je .parse_num1
    
    ; Проверяем, не является ли символ операцией
    cmp al, '+'
    je .found_op
    cmp al, '-'
    je .found_op
    cmp al, '*'
    je .found_op
    cmp al, '/'
    je .found_op
    cmp al, '%'
    je .found_op
    cmp al, '^'
    je .found_op
    cmp al, '<'
    je .found_op

    ; Если это цифра, пишем в буфер num1
    mov [r_di], al
    inc r_di
    inc r_cx
    jmp .parse_num1

.found_op:
    mov [op_char], al       ; Сохранили операцию
    mov [len1], r_cx        ; Сохранили длину num1
    
    lea r_di, [num2]
    xor r_cx, r_cx          ; Длина num2

.parse_num2:
    mov al, [r_si]
    inc r_si
    cmp al, 10              ; Наткнулись на конец строки
    je .end_num2
    cmp al, 0
    je .end_num2
    cmp al, ' '             ; Игнорируем пробелы
    je .parse_num2

    ; Если цифра, пишем в буфер num2
    mov [r_di], al
    inc r_di
    inc r_cx
    jmp .parse_num2

.end_num2:
    mov [len2], r_cx        ; Сохранили длину num2

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
    movzx r_bx, byte [num2 + r_cx]
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
    movzx r_ax, byte [num1 + r_si]
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

    movzx r_ax, byte [num1 + r_si]
    sub r_ax, '0'
    add r_bx, r_ax

    movzx r_cx, byte [num2 + 0]
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
    mov al, [num1 + r_cx]
    mov bl, [num2 + r_cx]
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

