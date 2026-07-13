; =====================================================================
; КРОССАРХИТЕКТУРНЫЕ МАКРОСЫ И РЕГИСТРЫ (x86_64 / x86)
; =====================================================================
%if __BITS__ == 64
    default rel
    %define REG_A rax
    %define REG_B rbx
    %define REG_C rcx
    %define REG_D rdx
    %define REG_SI rsi
    %define REG_DI rdi
    %define REG_SP rsp
%else
    %define REG_A eax
    %define REG_B ebx
    %define REG_C ecx
    %define REG_D edx
    %define REG_SI esi
    %define REG_DI edi
    %define REG_SP esp
%endif

%macro sys_call_io 4
    %if __BITS__ == 64
        mov rax, %1
        mov rdi, %2
        mov rsi, %3
        mov rdx, %4
        syscall
    %else
        mov eax, %1
        mov ebx, %2
        mov ecx, %3
        mov edx, %4
        int 0x80
    %endif
%endmacro

section .text
    global _start

_start:
    ; 1. Читаем строку ввода целиком в буфер
    %if __BITS__ == 64
        sys_call_io 0, 0, input_buf, 128
        mov r12, rax
        xor r13, r13
    %else
        sys_call_io 3, 0, input_buf, 128
        mov [len_32], eax
        mov dword [idx_32], 0
    %endif

    ; Проверяем спец-формулу физики E=mc^2
    lea REG_B, [input_buf]
    movzx REG_C, byte [REG_B]
    cmp REG_C, 'E'
    jne .check_eq
    cmp byte [REG_B + 1], '='
    jne .check_eq
    %if __BITS__ == 64
        add r13, 2
    %else
        add dword [idx_32], 2
    %endif
    call parse_float
    movsd xmm1, [phys_c]
    mulsd xmm1, xmm1
    mulsd xmm0, xmm1    ; E = m * c^2
    jmp .output

.check_eq:
    ; Проверяем, не уравнение ли это (ищем 'x')
    xor REG_C, REG_C
    lea REG_B, [input_buf] ; ФИКС: Гарантируем, что в REG_B адрес буфера
.find_x:
    %if __BITS__ == 64
        cmp rcx, r12
        jge .normal
        movzx rdx, byte [REG_B + rcx] ; ФИКС: Используем REG_B вместо rbx
    %else
        cmp ecx, [len_32]
        jge .normal
        mov edx, [idx_32]
        movzx edx, byte [REG_B + ecx] ; ФИКС: Используем REG_B вместо ebx
    %endif
    cmp REG_D, 'x'
    je .eq_solver
    inc REG_C
    jmp .find_x

.normal:
    call parse_float
    movsd xmm1, xmm0    ; xmm1 = первое число

    ; Считываем знак
.find_op:
    lea REG_B, [input_buf] ; ФИКС: Переинициализация адреса буфера
    %if __BITS__ == 64
        cmp r13, r12
        jge .error
        movzx rcx, byte [REG_B + r13] ; ФИКС: Использование универсального регистра REG_B
        inc r13
    %else
        mov eax, [len_32]
        cmp [idx_32], eax
        jge .error
        mov edx, [idx_32]
        movzx ecx, byte [REG_B + edx]
        inc dword [idx_32]
    %endif
    cmp REG_C, ' '
    je .find_op
    
    cmp REG_C, '!'      ; Если встретили оператор факториала
    je .factorial

    push REG_C            
    movsd [tmp_float], xmm1 
    call parse_float
    movsd xmm1, xmm0    ; xmm1 = второе число
    movsd xmm0, [tmp_float] 
    pop REG_C             

    cmp REG_C, '+'
    je .add
    cmp REG_C, '-'
    je .sub
    cmp REG_C, '*'
    je .mul
    cmp REG_C, '/'
    je .div
    jmp .error

.add: addsd xmm0, xmm1 
    jmp .output
.sub: subsd xmm0, xmm1 
    jmp .output
.mul: mulsd xmm0, xmm1 
    jmp .output
.div: xorpd xmm2, xmm2
    ucomisd xmm1, xmm2
    je .error
    divsd xmm0, xmm1
    jmp .output

.factorial:
    cvttsd2si rax, xmm0
    cmp rax, 0
    jle .fact_one
    mov rcx, rax
    mov rax, 1
    cvtsi2sd xmm0, rax
.loop_f:
    cmp rcx, 1
    jle .output
    cvtsi2sd xmm1, rcx
    mulsd xmm0, xmm1
    dec rcx
    jmp .loop_f
.fact_one:
    mov rax, 1
    cvtsi2sd xmm0, rax
    jmp .output

.eq_solver:
    call parse_float
    movsd xmm1, xmm0    ; xmm1 = a
.skip_eq:
    lea REG_B, [input_buf]
    %if __BITS__ == 64
        movzx rcx, byte [REG_B + r13]
        inc r13
    %else
        mov edx, [idx_32]
        movzx ecx, byte [REG_B + edx]
        inc dword [idx_32]
    %endif
    cmp REG_C, 'x'
    je .skip_eq
    cmp REG_C, '='
    je .skip_eq
    cmp REG_C, ' '
    je .skip_eq
    %if __BITS__ == 64
        dec r13
    %else
        dec dword [idx_32]
    %endif
    call parse_float    ; xmm0 = b
    divsd xmm0, xmm1    ; x = b / a
    jmp .output

.output:
    call print_float
    %if __BITS__ == 64
        sys_call_io 1, 1, newline, 1
        sys_call_io 60, 0, 0, 0
    %else
        sys_call_io 4, 1, newline, 1
        sys_call_io 1, 0, 0, 0
    %endif

.error:
    %if __BITS__ == 64
        sys_call_io 1, 1, err_msg, 4
        sys_call_io 60, 1, 0, 0
    %else
        sys_call_io 4, 1, err_msg, 4
        sys_call_io 1, 1, 0, 0
    %endif

; =====================================================================
; ОПТИМИЗИРОВАННЫЙ СТАНДАРТНЫЙ ПАРСЕР И ВЫВОД ЧИСЕЛ
; =====================================================================
parse_float:
    lea REG_B, [input_buf]
    %if __BITS__ == 64
        movzx rdx, byte [REG_B + r13]
    %else
        mov edx, [idx_32]
        movzx edx, byte [REG_B + edx]
    %endif
    cmp REG_D, 'c'
    je .const_c
    cmp REG_D, 'g'
    je .const_g
    
    xorpd xmm0, xmm0
    push REG_B             ; Сохраняем базу, так как REG_B нужен для флага точки
    xor REG_B, REG_B       ; REG_B теперь работает как флаг точки (0 - целая, 1 - дробная)
    mov REG_D, 1           ; Делитель
.loop:
    lea REG_A, [input_buf] ; Использование REG_A как временного адреса буфера
    %if __BITS__ == 64
        cmp r13, r12
        jge .done
        movzx rcx, byte [REG_A + r13]
    %else
        mov ecx, [len_32]
        cmp [idx_32], ecx
        jge .done
        mov ecx, [idx_32]
        movzx ecx, byte [REG_A + ecx]
    %endif
    cmp REG_C, ' '
    je .next
    cmp REG_C, '.'
    jne .digit
    mov REG_B, 1           ; Включаем режим дробной части
    jmp .next
.digit:
    cmp REG_C, '0'
    jl .done
    cmp REG_C, '9'
    jg .done
    sub REG_C, '0'
    cmp REG_B, 1
    je .frac
    cvtsi2sd xmm2, rcx
    push REG_A
    mov REG_A, 10
    cvtsi2sd xmm3, rax
    mulsd xmm0, xmm3
    pop REG_A
    addsd xmm0, xmm2
    jmp .next
.frac:
    imul REG_D, 10
    cvtsi2sd xmm2, rcx
    push REG_A
    mov REG_A, REG_D
    cvtsi2sd xmm3, rax
    pop REG_A
    divsd xmm2, xmm3
    addsd xmm0, xmm2
.next:
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    jmp .loop
.const_c:
    movsd xmm0, [phys_c]
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    ret                    ; ФИКС: Немедленный выход, чтобы не упасть в .loop
.const_g:
    movsd xmm0, [phys_g]
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    ret                    ; ФИКС: Немедленный выход
.done:
    pop REG_B              ; Восстанавливаем базу перед выходом
    ret

print_float:
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jae .pos
    push REG_A
    %if __BITS__ == 64
        sys_call_io 1, 1, minus, 1
        mov rax, 0x7FFFFFFFFFFFFFFF
        movq xmm1, rax
    %else
        sys_call_io 4, 1, minus, 1
        push 0xFFFFFFFF
        push 0x7FFFFFFF
        movsd xmm1, [REG_SP]
        add REG_SP, 8
    %endif
    andpd xmm0, xmm1
    pop REG_A
.pos:
    cvttsd2si rax, xmm0
    cvtsi2sd xmm1, rax
    subsd xmm0, xmm1
    movsd [tmp_float], xmm0
    
    ; ФИКС ЛОГИКИ ОЧИСТКИ: Вывод целой части использует чистый rax в цикле деления
    mov REG_B, 10
    %if __BITS__ == 64
        lea rsi, [res_buf + 31]
    %else
        mov esi, res_buf
        add esi, 31
    %endif
    mov REG_SI, REG_SI     ; Сохраняем указатель на конец буфера
.l_int:
    xor rdx, rdx           ; Очищаем остаток
    div REG_B              ; rax = частное, rdx = остаток
    add rdx, '0'
    dec REG_SI
    mov [REG_SI], dl
    test rax, rax          ; ФИКС: Проверяем реальное частное rax, а не флаг точки REG_A
    jnz .l_int
    
    %if __BITS__ == 64
        lea rdx, [res_buf + 31]
    %else
        mov edx, res_buf
        add edx, 31
    %endif
    sub REG_D, REG_SI
    
    push REG_D
    %if __BITS__ == 64
        sys_call_io 1, 1, rsi, rdx
        sys_call_io 1, 1, dot, 1
    %else
        sys_call_io 4, 1, esi, edx
        sys_call_io 4, 1, dot, 1
    %endif
    pop REG_D
    
    movsd xmm0, [tmp_float]
    mov rax, 1000000
    cvtsi2sd xmm1, rax
    mulsd xmm0, xmm1
    cvttsd2si rax, xmm0
    mov REG_B, 10
    %if __BITS__ == 64
        lea rsi, [res_buf + 31]
    %else
        mov esi, res_buf
        add esi, 31
    %endif
    mov REG_C, 6
.l_frac:
    xor rdx, rdx
    div REG_B
    add rdx, '0'
    dec REG_SI
    mov [REG_SI], dl
    dec REG_C
    jnz .l_frac
    %if __BITS__ == 64
        sys_call_io 1, 1, rsi, 6
    %else
        sys_call_io 4, 1, esi, 6
    %endif
    ret

section .data
    newline      db 0x0a
    minus        db 0x2d
    dot          db 0x2e
    err_msg      db "ERR", 0x0a
    phys_c       dq 299792458.0
    phys_g       dq 9.80665

section .bss
    input_buf resb 128
    res_buf   resb 32
    tmp_float resq 1
    %if __BITS__ == 32
        len_32   resd 1
        idx_32   resd 1
    %endif

