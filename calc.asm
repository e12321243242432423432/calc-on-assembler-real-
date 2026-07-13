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

    ; Разделяем ввод на два bignum-числа и знак
    call split_bignum_input

    ; Проверяем знак операции
    lea REG_B, [op]
    movzx REG_C, byte [REG_B]
    
    cmp REG_C, '!'
    je .factorial_bignum

    cmp REG_C, '*'
    je .mul_bignum
    
    jmp .error

.mul_bignum:
    call bignum_multiply
    jmp .output_bignum

.factorial_bignum:
    call bignum_factorial
    jmp .output_bignum

.output_bignum:
    ; Считаем длину строки результата в res_buf
    xor REG_D, REG_D
    lea REG_SI, [res_buf]
.count_len:
    movzx REG_A, byte [REG_SI + REG_D]
    test al, al
    jz .write_out
    inc REG_D
    jmp .count_len

.write_out:
    %if __BITS__ == 64
        sys_call_io 1, 1, res_buf, rdx
        sys_call_io 1, 1, newline, 1
        sys_call_io 60, 0, 0, 0
    %else
        push edx
        sys_call_io 4, 1, res_buf, edx
        sys_call_io 4, 1, newline, 1
        sys_call_io 1, 0, 0, 0
        pop edx
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
; ПОДПРОГРАММА: Разделение ввода на строки-операнды
; =====================================================================
split_bignum_input:
    xor REG_SI, REG_SI
    lea REG_B, [input_buf]
.loop1:
    %if __BITS__ == 64
        cmp r13, r12
        jge .set_op
        movzx rax, byte [rbx + r13]
    %else
        mov eax, [len_32]
        cmp [idx_32], eax
        jge .set_op
        mov edx, [idx_32]
        movzx eax, byte [ebx + edx]
    %endif
    
    cmp al, '*'
    je .set_op
    cmp al, '!'
    je .set_op
    cmp al, 0x20
    je .next1
    cmp al, 0x0a
    je .set_op

    lea REG_D, [num1]
    mov [REG_D + REG_SI], al
    inc REG_SI
.next1:
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    jmp .loop1

.set_op:
    lea REG_D, [op]
    mov [REG_D], al
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    cmp al, '!'
    je .done_split

    xor REG_SI, REG_SI
.loop2:
    %if __BITS__ == 64
        cmp r13, r12
        jge .done_split
        movzx rax, byte [rbx + r13]
    %else
        mov eax, [len_32]
        cmp [idx_32], eax
        jge .done_split
        mov edx, [idx_32]
        movzx eax, byte [ebx + edx]
    %endif
    cmp al, 0x20
    je .next2
    cmp al, 0x0a
    je .next2

    lea REG_D, [num2]
    mov [REG_D + REG_SI], al
    inc REG_SI
.next2:
    %if __BITS__ == 64
        inc r13
    %else
        inc dword [idx_32]
    %endif
    jmp .loop2

.done_split:
    ret


; =====================================================================
; ПОДПРОГРАММА: Умножение Огромных Чисел в Столбик (BigNum Multiply)
; =====================================================================
bignum_multiply:
    ; Очищаем буфер результата
    lea REG_DI, [res_buf]
    xor REG_A, REG_A
    mov REG_C, 256
    rep stosb

    ; Находим длину строки num1
    xor REG_SI, REG_SI
.l1: 
    cmp byte [num1 + REG_SI], 0 
    jz .l2_init 
    inc REG_SI 
    jmp .l1

.l2_init: 
    mov [len1_32], REG_SI
    
    ; Находим длину строки num2
    xor REG_SI, REG_SI
.l2: 
    cmp byte [num2 + REG_SI], 0 
    jz .math 
    inc REG_SI 
    jmp .l2

.math:
    mov [len2_32], REG_SI
    
    ; Инициализируем циклы умножения в столбик
    mov REG_SI, [len1_32]
.loop_i:
    test REG_SI, REG_SI
    jz .invert_res
    dec REG_SI
    
    movzx REG_A, byte [num1 + REG_SI]
    sub REG_A, '0'
    
    mov REG_DI, [len2_32]
.loop_j:
    test REG_DI, REG_DI
    jz .loop_i
    dec REG_DI
    
    movzx REG_C, byte [num2 + REG_DI]
    sub REG_C, '0'
    
    ; Умножаем цифры
    imul REG_A, REG_C
    
    ; Вычисляем позицию в res_buf
    mov REG_D, [len1_32]
    sub REG_D, 1
    sub REG_D, REG_SI
    mov REG_B, [len2_32]
    sub REG_B, 1
    sub REG_B, REG_DI
    add REG_D, REG_B      
    
    ; Добавляем к текущему значению в res_buf
    movzx REG_B, byte [res_buf + REG_D]
    add REG_A, REG_B
    
    ; Обработка переносов разрядов
.carry_loop:
    mov REG_B, REG_A
    xor REG_C, REG_C
    mov REG_A, 10
    push REG_D
    xor REG_D, REG_D
    div REG_B             
    mov REG_C, REG_A      
    mov REG_A, REG_D      
    pop REG_D
    
    mov [res_buf + REG_D], al
    test REG_C, REG_C
    jz .next_j
    
    inc REG_D
    movzx REG_B, byte [res_buf + REG_D]
    add REG_C, REG_B
    mov REG_A, REG_C
    jmp .carry_loop

.next_j:
    movzx REG_A, byte [num1 + REG_SI]
    sub REG_A, '0'
    jmp .loop_j

.invert_res:
    xor REG_SI, REG_SI
.find_end:
    cmp byte [res_buf + REG_SI], 0
    jz .do_invert
    add byte [res_buf + REG_SI], '0' 
    inc REG_SI
    jmp .find_end
.do_invert:
    dec REG_SI
    xor REG_DI, REG_DI
.inv_l:
    cmp REG_DI, REG_SI
    jge .done_mul
    mov al, [res_buf + REG_DI]
    mov bl, [res_buf + REG_SI]
    mov [res_buf + REG_DI], bl
    mov [res_buf + REG_SI], al
    inc REG_DI
    dec REG_SI
    jmp .inv_l
.done_mul:
    ret


; =====================================================================
; ПОДПРОГРАММА: Факториал Огромных Чисел (BigNum Factorial)
; =====================================================================
bignum_factorial:
    xor REG_C, REG_C
    xor REG_SI, REG_SI
.to_int:
    movzx REG_A, byte [num1 + REG_SI]
    test al, al
    jz .fact_start
    sub REG_A, '0'
    imul REG_C, 10
    add REG_C, REG_A
    inc REG_SI
    jmp .to_int

.fact_start:
    cmp REG_C, 1
    jle .f_one
    
    mov byte [res_buf], '1'
    mov byte [res_buf + 1], 0
    
    mov REG_B, 2          
.f_loop:
    cmp REG_B, REG_C
    jg .f_done
    
    push REG_C
    push REG_B
    mov REG_A, REG_B
    mov REG_B, 10
    lea REG_SI, [num2 + 20]
    mov byte [REG_SI], 0
.to_str:
    xor REG_D, REG_D
    div REG_B
    add REG_D, '0'
    dec REG_SI
    mov [REG_SI], dl
    test REG_A, REG_A
    jnz .to_str
    
    lea REG_DI, [num2]
.move_str:
    mov al, [REG_SI]
    mov [REG_DI], al
    inc REG_DI
    inc REG_SI
    test al, al
    jnz .move_str
    
    lea REG_SI, [res_buf]
    lea REG_DI, [num1]
.copy_res:
    mov al, [REG_SI]
    mov [REG_DI], al
    inc REG_SI
    inc REG_DI
    test al, al
    jnz .copy_res
    
    call bignum_multiply
    
    pop REG_B
    pop REG_C
    inc REG_B
    jmp .f_loop

.f_one:
    mov byte [res_buf], '1'
    mov byte [res_buf + 1], 0
.f_done:
    ret

section .data
    newline      db 0x0a
    err_msg      db "ERR", 0x0a

section .bss
    input_buf resb 128
    num1      resb 64
    num2      resb 64
    op        resb 1
    res_buf   resb 256
    len1_32   resq 1
    len2_32   resq 1
    %if __BITS__ == 32
        len_32   resd 1
        idx_32   resd 1
    %endif

