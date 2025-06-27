.model small
.stack 100h

.data
    newline   db 13, 10, '$'

.code
start:
    mov ax, @data
    mov ds, ax

    mov es, [2Ch]       
    mov si, 80h         

    mov cl, es:[si]
    cmp cl, 0
    je no_params

    mov ah, 02h
    inc si              
print_loop:
    mov dl, es:[si]
    int 21h
    inc si
    loop print_loop

no_params:
    mov ah, 09h
    lea dx, newline
    int 21h

    mov ax, 4C00h
    int 21h

end start