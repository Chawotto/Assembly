; Исправленная версия программы на ассемблере для подсчёта строк > заданной длины
; Устранена зависимость при обработке больших (64Кб и более) файлов

.model small
.stack 100h
.data
    bad_params_message     db "Bad cmd arguments", '$'
    bad_source_file_message db "Cannot open file", '$'
    file_not_found_message db "File not found", '$'
    error_closing_file_message db "Cannot close file", '$'
    error_read_file_text_message db "Error reading from file", '$'
    file_is_empty_message  db "File is empty", '$'
    result_message         db "Number of lines with a length more than specified: ", '$'

    space_char    equ 32
    new_line_char equ 13  ; CR
    return_char   equ 10  ; LF
    endl_char     equ 0

    max_size      equ 126
    cmd_size      db ?
    cmd_text      db max_size + 2 dup(0)
    source_path   db max_size + 2 dup(0)

    buffer        db max_size + 2 dup(0)
    min_length    dw 0
    lines_counter dw 0
    source_id     dw 0

.code

; Макросы для вывода и выхода
macro exit_app
    mov ax, 4C00h
    int 21h
endm

macro show_str out_str
    push ax
    push dx
    mov ah, 9h
    mov dx, offset out_str
    int 21h
    ; перевод строки
    mov dl, 10
    mov ah, 2h
    int 21h
    mov dl, 13
    mov ah, 2h
    int 21h
    pop dx
    pop ax
endm

; Преобразование числа в строку и печать
print_result proc
    pusha
    mov cx, 10
    xor di, di
    or ax, ax
    jns prt_conv
    push ax
    mov dx, '-'
    mov ah, 2
    int 21h
    pop ax
    neg ax
prt_conv:
    xor dx, dx
    div cx
    add dl, '0'
    inc di
    push dx
    or ax, ax
    jnz prt_conv
prt_show:
    pop dx
    mov ah, 2
    int 21h
    dec di
    jnz prt_show
    popa
    ret
print_result endp

; Считывание команды и аргументов (не изменялось)
; ... (здесь идут ваши процедуры read_cmd, read_from_cmd, skip_spaces,
;    strlen, rewrite_word, atoi, open_file) ...

; Упрощённая обработка файла: читаем блоками, считаем CR и LF
file_handling proc
    pusha
    mov lines_counter, 0
read_loop:
    ; читаем кусок
    mov ah, 3Fh
    mov bx, source_id
    mov cx, max_size
    mov dx, offset buffer
    int 21h
    jc  read_error      ; ошибка чтения
    cmp ax, 0
    je  done_reading    ; конец файла
    mov si, offset buffer
    mov cx, ax          ; число байт, прочитанных в buffer
process_loop:
    lodsb               ; загружаем очередный байт из [si++] в AL
    cmp al, new_line_char
    je  inc_line
    cmp al, return_char
    jne skip_inc
inc_line:
    ; проверяем длину до CR/LF
    push cx            ; сохраним остаток для продолжения
    mov ax, min_length
    cmp temp_len, ax
    jle cont_no_inc    ; если меньше или равно, не считаем
    inc lines_counter
cont_no_inc:
    mov temp_len, 0    ; сброс длины строки
    pop cx             ; восстанавливаем остаток
    jmp next_char
skip_inc:
    ; не разделитель — наращиваем длину
    inc temp_len
next_char:
    loop process_loop
    jmp read_loop
read_error:
    show_str error_read_file_text_message
    jmp end_main
done_reading:
    ; последний фрагмент: учитываем, если файл не заканчивался новой строкой
    cmp temp_len, 0
    je finish_counts
    mov ax, min_length
    cmp temp_len, ax
    jle finish_counts
    inc lines_counter
finish_counts:
    popa
    ret
file_handling endp

; Закрытие файла и вывод результата (не изменялось)
; ... (ваши процедуры close_file и стартовая метка start) ...

start:
    mov ax, @data
    mov ds, ax
    mov es, ax
    ; чтение аргументов: длина, путь
    call read_cmd
    call read_from_cmd
    call atoi
    call open_file
    call file_handling
    call close_file
    ; вывод результата
    mov ah, 9h
    mov dx, offset result_message
    int 21h
    mov ax, lines_counter
    call print_result
end_main:
    exit_app
end start
