default rel             ; Убирает варнинг implicit DEFAULT ABS

section .text
    global _start

_start:
    ; 1. Читаем всю строку ввода целиком в буфер
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [input_buf]
    mov rdx, 64         ; читаем до 64 символов
    syscall
    
    ; Сохраняем длину прочитанной строки
    mov r12, rax
    xor r13, r13        ; r13 — индекс в буфере

    ; 2. Парсим первое число
    call parse_int
    mov r14, rax        ; r14 = первое число

    ; 3. Читаем знак операции
    lea rbx, [input_buf]
    movzx rcx, byte [rbx + r13] ; rcx = знак
    inc r13             ; сдвигаем указатель за знак

    ; 4. Парсим второе число
    call parse_int
    mov r15, rax        ; r15 = второе число

    ; 5. Выполняем математику
    mov rax, r14        ; первое число в rax
    cmp rcx, 0x2b       ; '+'
    je .add
    cmp rcx, 0x2d       ; '-'
    je .sub
    cmp rcx, 0x2a       ; '*'
    je .mul
    jmp .error

.add:
    add rax, r15
    jmp .output

.sub:
    sub rax, r15
    jmp .output

.mul:
    imul rax, r15
    jmp .output

.output:
    ; Проверяем на отрицательный результат
    cmp rax, 0
    jge .print_num
    
    ; Если меньше нуля — выводим минус
    push rax
    mov rax, 1          ; sys_write
    mov rdi, 1
    lea rsi, [minus]
    mov rdx, 1
    syscall
    pop rax
    neg rax             ; Делаем число положительным для вывода

.print_num:
    call print_int      ; Перевод в ASCII и вывод
    
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
; ПОДПРОГРАММА: Парсинг строки в число (ASCII -> Integer)
; =====================================================================
parse_int:
    xor rax, rax        ; Обнуляем результат
    lea rbx, [input_buf]
.loop:
    cmp r13, r12        ; Проверяем конец буфера
    jge .done
    
    movzx rdx, byte [rbx + r13] ; Читаем символ
    
    ; Фильтруем символ переноса строки (Enter)
    cmp rdx, 0x0a       ; Проверяем на '\n'
    je .skip_char
    
    ; Проверяем, что это цифра (0x30 - 0x39)
    cmp rdx, 48         ; '0'
    jl .done
    cmp rdx, 57         ; '9'
    jg .done
    
    sub rdx, 48         ; В цифру
    imul rax, 10        ; RAX * 10
    add rax, rdx        ; Добавляем цифру
    
.skip_char:
    inc r13             ; К следующему символу
    jmp .loop
.done:
    ret


; =====================================================================
; ПОДПРОГРАММА: Вывод многозначного числа (Integer -> ASCII)
; =====================================================================
print_int:
    mov rbx, 10         ; Делитель
    lea rsi, [res_buf + 31] ; С конца буфера
    
.loop_div:
    xor rdx, rdx        ; Очищаем rdx перед div
    div rbx             ; RAX = частное, RDX = остаток
    add rdx, 48         ; В ASCII
    dec rsi             ; Сдвиг влево
    mov [rsi], dl       ; Запись символа
    
    test rax, rax
    jnz .loop_div       ; Повторяем, пока RAX не 0
    
    ; Вычисляем длину строки
    lea rdx, [res_buf + 31]
    sub rdx, rsi        ; RDX = длина
    
    mov rax, 1          ; sys_write
    mov rdi, 1
    syscall
    ret

section .data
    newline db 0x0a
    minus   db 0x2d
    err_msg db "ERR", 0x0a

section .bss
    input_buf resb 64
    res_buf   resb 32
