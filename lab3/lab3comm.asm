.model small                            ; Указывает малую модель памяти (small).
.stack 100h                             ; Выделяет 256 байт для стека.
.data                                   ; Начало секции данных.

bad_params_message db "Bad cmd arguments", '$' ; Сообщение об ошибке аргументов командной строки.
bad_source_file_message db "Cannot open file", '$' ; Сообщение об ошибке открытия файла.
file_not_found_message db "File not found", '$'   ; Сообщение о том, что файл не найден.
error_closing_file_message db "Cannot close file", '$' ; Сообщение об ошибке закрытия файла.
error_read_file_text_message db "Error reading from file", '$' ; Сообщение об ошибке чтения файла.
file_is_empty_message db "File is empty", '$'         ; Сообщение о пустом файле (не используется в коде).
result_message db "Number of lines with a length more than specified: ", '$' ; Сообщение с результатом.

space_char equ 32                       ; Константа для символа пробела (ASCII 32).
new_line_char equ 13                    ; Константа для символа возврата каретки (CR, ASCII 13).
return_char equ 10                      ; Константа для символа перевода строки (LF, ASCII 10).
tabulation equ 9                        ; Константа для символа табуляции (ASCII 9).
endl_char equ 0                         ; Константа для символа конца строки (NULL, ASCII 0).

max_size equ 126                        ; Константа максимального размера буфера (126 байт).
cmd_size db ?                           ; Переменная для хранения размера аргументов командной строки.
cmd_text db max_size + 2 dup(0)         ; Буфер для текста командной строки, заполнен нулями.
source_path db max_size + 2 dup(0)      ; Буфер для пути к файлу, заполнен нулями.

temp_length dw 0                        ; Временная переменная для длины текущей строки (слово).
source_id dw 0                          ; Идентификатор (handle) открытого файла (слово).
min_length dw 0                         ; Минимальная длина строки для подсчета (слово).
lines_counter dw 0                      ; Счетчик строк, превышающих min_length (слово).
buffer db max_size + 2 dup(0)           ; Буфер для чтения данных из файла, заполнен нулями.

.code                                   ; Начало секции кода.

macro exit_app                          ; Макрос для завершения программы.
   mov ax, 4C00h                        ; Установка функции 4Ch прерывания 21h с кодом возврата 0.
   int 21h                              ; Вызов прерывания для выхода.
endm                                    ; Конец макроса.

macro show_str out_str                  ; Макрос для вывода строки с переводом строки.
    push ax                             ; Сохранение AX.
    push dx                             ; Сохранение DX.
    mov ah, 9h                          ; Установка функции 09h (вывод строки).
    mov dx, offset out_str              ; Загрузка адреса строки в DX.
    int 21h                             ; Вызов прерывания для вывода строки.
    mov dl, 10                          ; Установка символа LF в DL.
    mov ah, 2h                          ; Установка функции 02h (вывод символа).
    int 21h                             ; Вывод LF.
    mov dl, 13                          ; Установка символа CR в DL.
    mov ah, 2h                          ; Установка функции 02h.
    int 21h                             ; Вывод CR.
    pop dx                              ; Восстановление DX.
    pop ax                              ; Восстановление AX.
endm                                    ; Конец макроса.

macro read_cmd                          ; Макрос для чтения аргументов командной строки.
    xor ch, ch                          ; Обнуление CH.
    mov cl, ds:[80h]                    ; Загрузка размера аргументов из адреса 80h в CL.
    mov cmd_size, cl                    ; Сохранение размера в cmd_size.
    mov si, 81h                         ; Установка SI на начало текста аргументов (81h).
    mov di, offset cmd_text             ; Установка DI на адрес буфера cmd_text.
    rep movsb                           ; Копирование CL байт из DS:SI в ES:DI.
endm                                    ; Конец макроса.

print_result proc                       ; Процедура вывода числа в AX на экран.
    pusha                               ; Сохранение всех регистров общего назначения.
    mov cx, 10                          ; Установка делителя 10 для преобразования в десятичную систему.
    xor di, di                          ; Обнуление DI (счетчик цифр).
    or ax, ax                           ; Проверка знака AX.
    jns conversion                      ; Если неотрицательное, переход к преобразованию.
    push ax                             ; Сохранение AX.
    mov dx, '-'                         ; Установка символа '-' в DX.
    mov ah, 2                           ; Установка функции 02h (вывод символа).
    int 21h                             ; Вывод '-'.
    pop ax                              ; Восстановление AX.
    neg ax                              ; Инверсия AX (делаем положительным).
conversion:                             ; Метка преобразования числа в цифры.
    xor dx, dx                          ; Обнуление DX.
    div cx                              ; Деление AX на 10, частное в AX, остаток в DX.
    add dl, '0'                         ; Преобразование остатка в символ.
    inc di                              ; Увеличение счетчика цифр.
    push dx                             ; Сохранение символа в стеке.
    or ax, ax                           ; Проверка, остались ли цифры.
    jnz conversion                      ; Если да, повтор цикла.
show:                                   ; Метка вывода цифр.
    pop dx                              ; Извлечение символа из стека.
    mov ah, 2                           ; Установка функции 02h.
    int 21h                             ; Вывод символа.
    dec di                              ; Уменьшение счетчика.
    jnz show                            ; Если остались символы, повтор.
    popa                                ; Восстановление всех регистров.
    ret                                 ; Возврат из процедуры.
endp                                    ; Конец процедуры.

read_from_cmd proc                      ; Процедура разбора аргументов командной строки.
    push bx                             ; Сохранение BX.
    push cx                             ; Сохранение CX.
    push dx                             ; Сохранение DX.
    
    mov cl, cmd_size                    ; Загрузка размера аргументов в CL.
    xor ch, ch                          ; Обнуление CH.
    mov si, offset cmd_text             ; Установка SI на начало cmd_text.
    
    call skip_spaces                    ; Вызов процедуры пропуска пробелов.
    mov di, offset buffer               ; Установка DI на буфер для первого слова (min_length).
    call rewrite_word                   ; Копирование первого слова (число).
    
    call skip_spaces                    ; Пропуск пробелов.
    mov di, offset source_path          ; Установка DI на буфер для пути файла.
    call rewrite_word                   ; Копирование второго слова (путь).
    
    call skip_spaces                    ; Пропуск пробелов.
    cmp byte ptr [si], 0Dh              ; Проверка, является ли следующий символ CR.
    je check_end                        ; Если да, конец аргументов.
    cmp byte ptr [si], 0                ; Проверка, является ли символ нулем.
    jne bad_cmd                         ; Если нет, ошибка аргументов.
check_end:                              ; Метка проверки конца.
    mov ax, 0                           ; Установка AX в 0 (успех).
    jmp endproc                         ; Переход к завершению.

bad_cmd:                                ; Метка ошибки аргументов.
    show_str bad_params_message         ; Вывод сообщения об ошибке.
    mov ax, 1                           ; Установка AX в 1 (ошибка).
    jmp endproc                         ; Переход к завершению.

endproc:                                ; Метка завершения.
    pop dx                              ; Восстановление DX.
    pop cx                              ; Восстановление CX.
    pop bx                              ; Восстановление BX.
    cmp ax, 0                           ; Проверка результата.
    jne end_main                        ; Если ошибка, завершение программы.
    ret                                 ; Возврат из процедуры.
read_from_cmd endp                      ; Конец процедуры.

skip_spaces proc                        ; Процедура пропуска пробелов.
    push ax                             ; Сохранение AX.
skip_loop:                              ; Метка цикла.
    mov al, [si]                        ; Загрузка текущего символа в AL.
    cmp al, ' '                         ; Сравнение с пробелом.
    jne skip_end                        ; Если не пробел, выход.
    inc si                              ; Переход к следующему символу.
    dec cl                              ; Уменьшение счетчика символов.
    jnz skip_loop                       ; Если остались символы, повтор.
skip_end:                               ; Метка конца.
    pop ax                              ; Восстановление AX.
    ret                                 ; Возврат.
skip_spaces endp                        ; Конец процедуры.

strlen proc                             ; Процедура подсчета длины строки до endl_char.
    push bx                             ; Сохранение BX.
    push si                             ; Сохранение SI.
    xor ax, ax                          ; Обнуление AX (счетчик длины).
start_calculation:                      ; Метка начала подсчета.
    mov bl, ds:[si]                     ; Загрузка символа в BL.
    cmp bl, endl_char                   ; Сравнение с нулем (конец строки).
    je end_calculation                  ; Если конец, выход.
    inc si                              ; Переход к следующему символу.
    inc ax                              ; Увеличение счетчика.
    jmp start_calculation               ; Повтор цикла.
end_calculation:                        ; Метка конца.
    pop si                              ; Восстановление SI.
    pop bx                              ; Восстановление BX.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

rewrite_word proc                       ; Процедура копирования слова из SI в DI.
    push ax                             ; Сохранение AX.
    push cx                             ; Сохранение CX.
    push di                             ; Сохранение DI.
loop_parse_word:                        ; Метка цикла.
    mov al, ds:[si]                     ; Загрузка символа из SI.
    cmp al, space_char                  ; Проверка на пробел.
    je is_stopped_char                  ; Если пробел, конец слова.
    cmp al, new_line_char               ; Проверка на CR.
    je is_stopped_char                  ; Если CR, конец.
    cmp al, tabulation                  ; Проверка на табуляцию.
    je is_stopped_char                  ; Если табуляция, конец.
    cmp al, return_char                 ; Проверка на LF.
    je is_stopped_char                  ; Если LF, конец.
    cmp al, endl_char                   ; Проверка на NULL.
    je is_stopped_char                  ; Если NULL, конец.
    mov es:[di], al                     ; Копирование символа в DI.
    inc di                              ; Увеличение DI.
    inc si                              ; Увеличение SI.
    loop loop_parse_word                ; Повтор цикла.
is_stopped_char:                        ; Метка конца слова.
    mov al, endl_char                   ; Установка NULL в конец.
    mov es:[di], al                     ; Запись NULL.
    inc si                              ; Пропуск символа-разделителя.
    pop di                              ; Восстановление DI.
    pop cx                              ; Восстановление CX.
    pop ax                              ; Восстановление AX.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

atoi proc                               ; Процедура преобразования строки в число.
    push si                             ; Сохранение SI.
    push ax                             ; Сохранение AX.
    push bx                             ; Сохранение BX.
    push dx                             ; Сохранение DX.
    push cx                             ; Сохранение CX.
    mov si, offset buffer               ; Установка SI на начало буфера.
    xor ax, ax                          ; Обнуление AX.
    xor bx, bx                          ; Обнуление BX (накопитель результата).
    xor cx, cx                          ; Обнуление CX.
atoi_loop:                              ; Метка цикла.
    mov dl, [si]                        ; Загрузка символа в DL.
    cmp dl, '0'                         ; Проверка, меньше ли '0'.
    jb atoi_end                         ; Если да, конец строки.
    cmp dl, '9'                         ; Проверка, больше ли '9'.
    ja atoi_end                         ; Если да, конец.
    sub dl, '0'                         ; Преобразование символа в цифру.
    mov cl, dl                          ; Сохранение цифры в CL.
    xor ch, ch                          ; Обнуление CH.
    mov ax, bx                          ; Перемещение текущего результата в AX.
    mov dx, 10                          ; Установка множителя 10.
    mul dx                              ; Умножение AX на 10.
    or dx, dx                           ; Проверка переполнения в DX.
    jnz overflow                        ; Если переполнение, переход.
    add ax, cx                          ; Добавление текущей цифры.
    jc overflow                         ; Если перенос (переполнение), переход.
    mov bx, ax                          ; Сохранение результата в BX.
    inc si                              ; Переход к следующему символу.
    jmp atoi_loop                       ; Повтор цикла.
overflow:                               ; Метка переполнения.
    mov bx, 0FFFFh                      ; Установка максимального значения при переполнении.
atoi_end:                               ; Метка конца.
    mov min_length, bx                  ; Сохранение результата в min_length.
    pop cx                              ; Восстановление CX.
    pop dx                              ; Восстановление DX.
    pop bx                              ; Восстановление BX.
    pop ax                              ; Восстановление AX.
    pop si                              ; Восстановление SI.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

open_file proc                          ; Процедура открытия файла.
    push bx                             ; Сохранение BX.
    push dx                             ; Сохранение DX.
    mov ah, 3Dh                         ; Установка функции 3Dh (открытие файла).
    mov al, 00h                         ; Режим открытия: только чтение.
    mov dx, offset source_path          ; Установка DX на путь к файлу.
    int 21h                             ; Вызов прерывания для открытия файла.
    jb bad_open                         ; Если ошибка (CF=1), переход.
    mov source_id, ax                   ; Сохранение дескриптора файла в source_id.
    mov ax, 0                           ; Установка AX в 0 (успех).
    jmp end_open                        ; Переход к завершению.
bad_open:                               ; Метка ошибки открытия.
    show_str bad_source_file_message    ; Вывод сообщения "Cannot open file".
    cmp ax, 02h                         ; Проверка кода ошибки (2 — файл не найден).
    jne error_found                     ; Если не 2, общая ошибка.
    show_str file_not_found_message     ; Вывод "File not found".
    jmp error_found                     ; Переход к завершению с ошибкой.
error_found:                            ; Метка ошибки.
    mov ax, 1                           ; Установка AX в 1 (ошибка).
end_open:                               ; Метка завершения.
    pop dx                              ; Восстановление DX.
    pop bx                              ; Восстановление BX.
    cmp ax, 0                           ; Проверка результата.
    jne end_main                        ; Если ошибка, завершение программы.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

read_from_file proc                     ; Процедура чтения из файла.
    push bx                             ; Сохранение BX.
    push cx                             ; Сохранение CX.
    push dx                             ; Сохранение DX.
    mov ah, 3Fh                         ; Установка функции 3Fh (чтение из файла).
    mov bx, source_id                   ; Загрузка дескриптора файла в BX.
    mov cx, max_size                    ; Установка количества байт для чтения.
    mov dx, offset buffer               ; Установка DX на буфер для данных.
    int 21h                             ; Вызов прерывания для чтения.
    jnb good_read                       ; Если нет ошибки, переход.
    show_str error_read_file_text_message ; Вывод сообщения об ошибке чтения.
    mov ax, 0                           ; Установка AX в 0 (пустой результат).
good_read:                              ; Метка успешного чтения.
    pop dx                              ; Восстановление DX.
    pop cx                              ; Восстановление CX.
    pop bx                              ; Восстановление BX.
    ret                                 ; Возврат (число прочитанных байт в AX).
endp                                    ; Конец процедуры.

file_handling proc                      ; Процедура обработки файла.
    pusha                               ; Сохранение всех регистров.
    call read_from_file                 ; Чтение первой порции данных из файла.
    mov bx, ax                          ; Сохранение числа прочитанных байт в BX.
    mov buffer[bx], endl_char           ; Установка NULL в конец буфера.
    cmp ax, 0                           ; Проверка, прочитано ли что-то.
    je finish_processing                ; Если ничего не прочитано, конец.
    mov si, offset buffer               ; Установка SI на начало буфера.
    mov temp_length, 0                  ; Сброс временной длины строки.

loop_processing:                        ; Метка цикла обработки символов.
    mov al, ds:[si]                     ; Загрузка текущего символа в AL.
    cmp al, new_line_char               ; Проверка на CR.
    je check_next_char                  ; Если CR, проверка следующего символа.
    cmp al, endl_char                   ; Проверка на NULL.
    je read_again                       ; Если конец буфера, чтение следующей порции.
    inc temp_length                     ; Увеличение длины строки.
    inc si                              ; Переход к следующему символу.
    jmp loop_processing                 ; Повтор цикла.

check_next_char:                        ; Метка проверки следующего символа после CR.
    inc si                              ; Переход к следующему символу.
    mov al, ds:[si]                     ; Загрузка следующего символа.
    cmp al, return_char                 ; Проверка на LF.
    jne handle_single_cr                ; Если не LF, обработка одиночного CR.
    inc si                              ; Пропуск LF.
    jmp handle_new_line                 ; Переход к обработке новой строки.

handle_single_cr:                       ; Метка обработки одиночного CR.
    dec si                              ; Возврат SI назад (нет LF).

handle_new_line:                        ; Метка обработки новой строки.
    mov dx, min_length                  ; Загрузка минимальной длины в DX.
    cmp temp_length, dx                 ; Сравнение текущей длины с минимальной.
    jle no_increment                    ; Если меньше или равно, не увеличивать счетчик.
    inc lines_counter                   ; Увеличение счетчика длинных строк.
no_increment:                           ; Метка пропуска инкремента.
    mov temp_length, 0                  ; Сброс длины строки.
    jmp loop_processing                 ; Продолжение обработки.

read_again:                             ; Метка чтения следующей порции.
    call read_from_file                 ; Чтение следующей порции данных.
    mov bx, ax                          ; Сохранение числа прочитанных байт.
    mov buffer[bx], endl_char           ; Установка NULL в конец.
    cmp ax, 0                           ; Проверка, конец ли файла.
    je finish_processing                ; Если конец, завершение.
    mov si, offset buffer               ; Установка SI на начало нового буфера.
    jmp loop_processing                 ; Продолжение обработки.

finish_processing:                      ; Метка завершения обработки.
    mov dx, min_length                  ; Загрузка минимальной длины.
    cmp temp_length, dx                 ; Проверка последней строки.
    jle end_handling                    ; Если не превышает, конец.
    inc lines_counter                   ; Увеличение счетчика, если превышает.
end_handling:                           ; Метка конца.
    popa                                ; Восстановление регистров.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

close_file proc                         ; Процедура закрытия файла.
    push bx                             ; Сохранение BX.
    push cx                             ; Сохранение CX.
    xor cx, cx                          ; Обнуление CX (флаг ошибки).
    mov ah, 3Eh                         ; Установка функции 3Eh (закрытие файла).
    mov bx, source_id                   ; Загрузка дескриптора файла.
    int 21h                             ; Вызов прерывания для закрытия.
    jnb good_close                      ; Если нет ошибки, переход.
    show_str error_closing_file_message ; Вывод сообщения об ошибке.
    inc cx                              ; Установка флага ошибки.
good_close:                             ; Метка успешного закрытия.
    mov ax, cx                          ; Сохранение результата в AX (0 — успех, 1 — ошибка).
    pop cx                              ; Восстановление CX.
    pop bx                              ; Восстановление BX.
    cmp ax, 0                           ; Проверка результата.
    jne end_main                        ; Если ошибка, завершение программы.
    ret                                 ; Возврат.
endp                                    ; Конец процедуры.

start:                                  ; Метка начала программы.
    mov ax, @data                       ; Загрузка адреса секции данных в AX.
    mov es, ax                          ; Установка ES на секцию данных.
    read_cmd                            ; Чтение аргументов командной строки.
    mov ds, ax                          ; Установка DS на секцию данных.
    call read_from_cmd                  ; Разбор аргументов (число и путь).
    call atoi                           ; Преобразование строки min_length в число.
    call open_file                      ; Открытие файла.
    call file_handling                  ; Обработка файла и подсчет строк.
    call close_file                     ; Закрытие файла.
    mov ah, 9h                          ; Установка функции 09h (вывод строки).
    mov dx, offset result_message       ; Загрузка адреса строки результата.
    int 21h                             ; Вывод сообщения результата.
    mov ax, lines_counter               ; Загрузка счетчика строк в AX.
    call print_result                   ; Вывод числа на экран.
    mov dl, 10                          ; Установка LF в DL.
    mov ah, 2h                          ; Установка функции 02h.
    int 21h                             ; Вывод LF.
    mov dl, 13                          ; Установка CR в DL.
    mov ah, 2h                          ; Установка функции 02h.
    int 21h                             ; Вывод CR.
end_main:                               ; Метка завершения программы.
    exit_app                            ; Вызов макроса завершения.
end start                               ; Указание точки входа и конца программы.