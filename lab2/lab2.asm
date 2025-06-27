.MODEL flat, stdcall
.STACK 4096
.DATA
msg1            DB "Enter first operand: ", '$'
msg2            DB "Enter second operand: ", '$'
msg3            DB "Enter operation: ", '$'
newline         DB 0Dh,0Ah, '$'          
msg4            DB 0Dh,0Ah, "Result: ",0Dh,0Ah,'$'
msg5            DB 0Dh,0Ah, "Input Error",0Dh,0Ah,'$'
msg6            DB 0Dh,0Ah, "Overflow Error",0Dh,0Ah,'$'
msg7            DB 0Dh,0Ah, "Division by Zero",0Dh,0Ah,'$'

max_length      equ 8
first_operand_str  DB max_length dup('$')
second_operand_str DB max_length dup('$')
answer_str        DB 0Dh,0Ah,"+00000", '$'
operation         DB 4 dup('$')

first_operand   DW 0
second_operand  DW 0
ten             DW 10
isError         DB 0
isNegative      DB 0

.CODE
str_output macro current_str
    push ax
    mov ah, 09h
    lea dx, current_str
    int 21h
    pop ax
endm

str_input macro current_str
    push ax
    mov ah, 0Ah
    lea dx, current_str
    int 21h
    pop ax
endm

str_check macro current_str
    local @str_is_negative, @check_plus, @shift_plus, @goNextCheck, @goCheckSign
    local @negative, @error, @goEnd, @next_digit
    push bx
    push cx
    mov si, 2            
    xor ax, ax
    mov isNegative, 0
    cmp current_str[si], '-'
    je @str_is_negative
    cmp current_str[si], '+'
    je @shift_plus
    jmp @goNextCheck

@str_is_negative:
    mov isNegative, 1
    inc si
    jmp @goNextCheck

@shift_plus:
    inc si

@goNextCheck:
    xor cx, cx
@next_digit:
    cmp current_str[si], '$'
    je @goCheckSign
    cmp current_str[si], '0'
    jl @error
    cmp current_str[si], '9'
    jg @error
    inc cx
    cmp cx, 5
    jg @error
    mul ten
    jo @error
    mov bx, 0
    mov bl, current_str[si]
    sub bl, '0'
    add ax, bx
    jo @error
    inc si
    jmp @next_digit

@goCheckSign:
    cmp isNegative, 1
    je @negative
    cmp ax, 32767
    jg @error
    jmp @goEnd

@negative:
    neg ax
    cmp ax, -32768
    jl @error
    jmp @goEnd

@error:
    mov isError, 1

@goEnd:
    pop cx
    pop bx
endm

str_preparation macro current_str
    mov si, 1
    xor bx, bx
    mov bl, current_str[si]
    add si, bx
    inc si
    mov current_str[si], '$'
    mov isError, 0
endm

operation_add macro
    local @error, @goEnd
    mov ax, first_operand
    cwd
    mov bx, second_operand
    add ax, bx
    jo @error
    jmp @goEnd
@error:
    mov isError, 1
@goEnd:
endm

operation_sub macro
    local @error, @goEnd
    mov ax, first_operand
    cwd
    mov bx, second_operand
    sub ax, bx
    jo @error
    jmp @goEnd
@error:
    mov isError, 1
@goEnd:
endm

operation_mul macro
    local @error, @goEnd
    mov ax, first_operand
    cwd
    mov bx, second_operand
    imul bx
    jo @error
    jmp @goEnd
@error:
    mov isError, 1
@goEnd:
endm

operation_div macro
    local @error, @goEnd, @div_zero
    mov bx, second_operand
    cmp bx, 0
    je @div_zero
    mov ax, first_operand
    cwd
    idiv bx
    jo @error
    jmp @goEnd
@div_zero:
    mov isError, 2
    jmp @goEnd
@error:
    mov isError, 1
@goEnd:
endm

operation_remdiv macro
    local @error, @goEnd, @div_zero
    mov bx, second_operand
    cmp bx, 0
    je @div_zero
    mov ax, first_operand
    cwd
    idiv bx
    mov ax, dx
    jo @error
    jmp @goEnd
@div_zero:
    mov isError, 2
    jmp @goEnd
@error:
    mov isError, 1
@goEnd:
endm

convert_str_to_int macro
    local @skip_negative, @loop, @add_minus, @output_str
    mov isNegative, 0
    cmp ax, 0
    jge @skip_negative
    mov isNegative, 1
    neg ax

@skip_negative:
    mov si, 7
    mov cx, 5
    xor dx, dx
    mov bx, ten

@loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov answer_str[si], dl
    dec si
    loop @loop

    cmp isNegative, 1
    je @add_minus
    mov answer_str[si], '+'
    jmp @output_str

@add_minus:
    mov answer_str[si], '-'

@output_str:
    str_output answer_str
endm

begin:
    mov ax, @data
    mov ds, ax
    mov es, ax
    xor ax, ax

firstInput:
    str_output msg1
    str_input first_operand_str
    str_output newline         
    str_preparation first_operand_str
    str_check first_operand_str
    cmp isError, 1
    je output_error
    mov first_operand, ax
    jmp secondInput

output_error:
    str_output msg5
    jmp firstInput

secondInput:
    str_output msg2
    str_input second_operand_str
    str_output newline          
    str_preparation second_operand_str
    str_check second_operand_str
    cmp isError, 1
    je _output_error
    mov second_operand, ax
    jmp thirdInput

_output_error:
    str_output msg5
    jmp secondInput

thirdInput:
    str_output msg3
    str_input operation
    str_output newline          
    mov si, 2
    mov bl, operation[si]
    mov isError, 0

    cmp bl, '+'
    je _operation_add
    cmp bl, '-'
    je _operation_sub
    cmp bl, '*'
    je _operation_mul
    cmp bl, '/'
    je _operation_div
    cmp bl, '%'
    je _operation_remdiv
    jmp __output_error

_operation_add:
    operation_add
    jmp _check_error

_operation_sub:
    operation_sub
    jmp _check_error

_operation_mul:
    operation_mul
    jmp _check_error

_operation_div:
    operation_div
    jmp _check_error

_operation_remdiv:
    operation_remdiv
    jmp _check_error

_check_error:
    cmp isError, 1
    je __output_overflow
    cmp isError, 2
    je __output_div_zero
    jmp _output_end_answer

__output_overflow:
    str_output msg6
    jmp _goEnd

__output_div_zero:
    str_output msg7
    jmp _goEnd

__output_error:
    str_output msg5
    jmp thirdInput

_output_end_answer:
    convert_str_to_int

_goEnd:
    mov ah, 4Ch
    int 21h
end begin
