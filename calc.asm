default rel

section .text
    global _start

_start:
    ; 1. Читаем всю строку ввода целиком в буфер
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [input_buf]
    mov rdx, 128        ; читаем до 128 символов
    syscall
    
    ; Сохраняем длину прочитанной строки
    mov r12, rax
    xor r13, r13        ; r13 — индекс в буфере

    ; 2. Парсим первое число (автоматически определяет конец по знаку)
    call parse_float
    movsd xmm1, xmm0    ; xmm1 = первое число

    ; 3. Читаем знак операции
    lea rbx, [input_buf]
.find_op:
    cmp r13, r12
    jge .error
    movzx rcx, byte [rbx + r13]
    inc r13
    cmp rcx, 0x20       ; Пропускаем пробелы, если они есть перед знаком
    je .find_op
    
    ; 4. Парсим второе число
    push rcx            ; Сохраняем знак в стек
    movsd [tmp_float], xmm1 ; Сохраняем первое число в память
    call parse_float
    movsd xmm1, xmm0    ; xmm1 = второе число
    movsd xmm0, [tmp_float] ; xmm0 = первое число
    pop rcx             ; Восстанавливаем знак

    ; 5. Выполняем математику (SSE инструкции)
    cmp rcx, '+'
    je .add
    cmp rcx, '-'
    je .sub
    cmp rcx, '*'
    je .mul
    cmp rcx, '/'
    je .div
    jmp .error

.add:
    addsd xmm0, xmm1
    jmp .output
.sub:
    subsd xmm0, xmm1
    jmp .output
.mul:
    mulsd xmm0, xmm1
    jmp .output
.div:
    xorpd xmm2, xmm2
    ucomisd xmm1, xmm2  ; Проверка на деление на ноль
    je .error
    divsd xmm0, xmm1
    jmp .output

.output:
    ; Вывод вещественного числа из xmm0
    call print_float
    
    ; Печатаем перенос строки
    mov rax, 1          ; sys_write
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
    jmp .exit

.error:
    mov rax, 1          ; sys_write
    mov rdi, 1
    lea rsi, [err_msg]
    mov rdx, 4
    syscall

.exit:
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall


; =====================================================================
; ПОДПРОГРАММА: Умный парсинг вещественного числа (ASCII -> Float)
; =====================================================================
parse_float:
    xorpd xmm0, xmm0    ; Обнуляем результат
    xor rax, rax        ; Текущая цифра
    xor r9, r9          ; Флаг точки (0 - целая часть, 1 - дробная)
    mov r10, 1          ; Делитель дробной части
    lea rbx, [input_buf]

.loop:
    cmp r13, r12
    jge .done
    movzx rdx, byte [rbx + r13]
    
    cmp rdx, 0x20       ; Пропускаем пробелы внутри числа
    je .skip_char
    cmp rdx, 46         ; Точка '.'
    je .set_dot
    
    ; Если это знак операции или конец строки — парсинг текущего числа окончен
    cmp rdx, '+'
    je .done
    cmp rdx, '-'
    je .done
    cmp rdx, '*'
    je .done
    cmp rdx, '/'
    je .done
    cmp rdx, 0x0a       ; '\n'
    je .done
    
    ; Проверяем, что это цифра
    cmp rdx, 48
    jl .error_pop
    cmp rdx, 57
    jg .error_pop
    
    sub rdx, 48         ; В цифру
    cmp r9, 1
    je .fractional
    
    ; Сборка целой части
    cvtsi2sd xmm2, rdx
    mov rax, 10
    cvtsi2sd xmm3, rax
    mulsd xmm0, xmm3
    addsd xmm0, xmm2
    inc r13
    jmp .loop

.fractional:
    ; Сборка дробной части
    imul r10, 10
    cvtsi2sd xmm2, rdx
    mov rax, r10
    cvtsi2sd xmm3, rax
    divsd xmm2, xmm3
    addsd xmm0, xmm2
    inc r13
    jmp .loop

.set_dot:
    mov r9, 1
    inc r13
    jmp .loop
.skip_char:
    inc r13
    jmp .loop
.error_pop:
    jmp _start.error
.done:
    ret


; =====================================================================
; ПОДПРОГРАММА: Корректный вывод больших Float без мусора и округлений
; =====================================================================
print_float:
    ; Проверяем знак числа (используем беззнаковое сравнение для SSE)
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jae .positive
    
    push rax
    mov rax, 1
    mov rdi, 1
    lea rsi, [minus]
    mov rdx, 1
    syscall
    pop rax
    
    mov rax, 0x7FFFFFFFFFFFFFFF
    movq xmm1, rax
    andpd xmm0, xmm1    ; Делаем положительным

.positive:
    ; Обычный вывод вещественного числа (Целая часть . 6 знаков)
    cvttsd2si rax, xmm0 
    cvtsi2sd xmm1, rax  
    subsd xmm0, xmm1    ; xmm0 = дробная часть
    movsd [tmp_float], xmm0
    
    ; Печать целой части
    mov rbx, 10
    lea rsi, [res_buf + 31]
.loop_int:
    xor rdx, rdx
    div rbx
    add rdx, 48
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .loop_int
    
    lea rdx, [res_buf + 31]
    sub rdx, rsi
    mov rax, 1
    mov rdi, 1
    syscall

    ; Печать точки
    mov rax, 1
    mov rdi, 1
    lea rsi, [dot]
    mov rdx, 1
    syscall

    ; Печать дробной части (6 знаков)
    movsd xmm0, [tmp_float]
    mov rax, 1000000
    cvtsi2sd xmm1, rax
    mulsd xmm0, xmm1
    cvttsd2si rax, xmm0

    mov rbx, 10
    lea rsi, [res_buf + 31]
    mov rcx, 6
.loop_frac:
    xor rdx, rdx
    div rbx
    add rdx, 48
    dec rsi
    mov [rsi], dl
    dec rcx
    jnz .loop_frac
    
    mov rax, 1
    mov rdi, 1
    mov rdx, 6
    syscall
    ret

section .data
    newline      db 0x0a
    minus        db 0x2d
    dot          db 0x2e
    err_msg      db "ERR", 0x0a

section .bss
    input_buf resb 128
    res_buf   resb 32
    tmp_float resq 1

