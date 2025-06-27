.model small
.stack 100h
.data
 
message_input  db "Enter a line for sorting: $"
message_output db "Result: $"
message_error  db "Error! $"
message_source db "Your line: $"
endline        db 10, 13, '$'
  
;áóôåð íà 200 ñèìâîëîâ
size equ 200
line db size DUP('$')

.code
output macro str ;âûâîä ñòðîêè
    mov ah, 9
    mov dx, offset str
    int 21h
endm

input macro str ;ââîä ñòðîêè
    mov ah, 0Ah
    mov dx, offset str
    int 21h
endm 

start:         
    mov ax, @data
    mov ds, ax
    mov es, ax
    
    output message_input 
    mov line[0], 197  
    
    input line 
    cmp line[3], '$'
    je error_end
    lea SI, line
    inc si
    inc si
    jmp check_loop

str:
    mov ax, 3
    int 10h  
    
    output message_source   
    mov ah, 9
    mov dx, offset line + 2
    int 21h  
    
    output endline
    output endline
    jmp main_loop
    
main_loop:         
    mov ah, 9
    mov dx, offset line + 2
    int 21h 
    output endline
    ;çàíóëÿåì ðåãèñòðû
    xor si, si
    xor di, di
    xor ax, ax
    xor dx, dx    
    mov si, offset line + 2 ;ds:si - íà÷àëî ñòðîêè
    
first_word:       
    cmp byte ptr[si], 9
    je error_end
    
    cmp byte ptr[si], ' ' 
    jne check_compare ;åñëè ñèìâîë íå ïðîáåë
    inc si
    
    cmp byte ptr[si], 13
    je the_end ;åñëè êîíåö ñòðîêè - ê êîíöó ïðîãðàììû
                      
    jmp first_word
     
loop_per_line:
    inc si
    cmp byte ptr[si], ' '
    je check_whitespace ;åñëè ïðîáåë
    cmp byte ptr[si], 13 
    jne loop_per_line 
    cmp ax, 0
    jne main_loop
    jmp the_end ;åñëè êîíåö ñòðîêè, òî âûõîä
       
check_compare:
    cmp dx, 0
    jne compare ;åñëè åñòü äâà ñëîâà, òî ñðàâíèâàåì
    push si ;çàíîñèì àäðåñ ïåðâîãî ñëîâà â ñòåê
    mov dx, 1 
    jmp loop_per_line
    
check_whitespace:
    cmp byte ptr[si+1], ' '
    je loop_per_line ;åñëè íåñêîëüêî ïðîáåëîâ, èä¸ì äàëüøå
    inc si ;àäðåñ âòîðîãî ñëîâà
    jmp check_compare
    
compare:
    pop di ;èçâëåêàåì â es:di àäðåñ ïåðâîãî ñëîâà    
    push si ;ïîìåùàåì â ñòåê àäðåñ âòîðîãî è ïåðâîãî ñëîâà 
    push di    
    mov cx, si
    sub cx, di
    repe cmpsb ;ñðàâíèâàòü ïîêà ñèìâîëû ðàâíû   
    dec si
    dec di
    xor bx, bx
    mov bl,byte ptr[di] 
    cmp bl, byte ptr[si] 
    jg change ;ïåðåñòàâëÿåì åñëè ïåðâîå ñëîâî > âòîðîãî
    pop di
    pop si
    push si 
    
    jmp loop_per_line
    
change:
    inc al
    pop di
    pop si
    
    xor cx, cx
    xor bx, bx
    mov dx, si ;âòîðîå ñëîâî   
loop1: ;ïîèñê íà÷àëà âòîðîãî ñëîâà 
    dec si
    inc cx
    cmp byte ptr [si-1], ' '
    je loop1
    
loop2:
    dec si
    mov bl, byte ptr [si] 
    push bx ;ïîìåùàåì ïåðâîå ñëîâî â ñòåê (ñ êîíöà, åñòåñòâåííî)
    inc ah ;äëèíà ïåðâîãî ñëîâà
    cmp si, di
    jne loop2
    
    mov si, dx ;dx = àäðåñ íà÷àëà âòîðîãî ñëîâà
    
loop3:  ;âòîðîå ñëîâî íà ïåðâîå
    cmp byte ptr [si], 13
    je loop4
    mov bl, byte ptr [si]
    xchg byte ptr [di], bl
    
    inc si
    inc di
    cmp  byte ptr [si], ' '
    jne loop3
    
loop4:
    mov byte ptr[di], ' '
    inc di
    loop loop4
    
    mov si, di
    mov dx, si
    dec si
loop5: ;ïåðâîå ñëîâî íà âòîðîå èç ñòåêà
    inc si
    cmp byte ptr[si], 13
    je main_loop
    
    pop bx
    mov byte ptr[si], bl
    
    dec ah
    cmp ah, 0
    je loop6
    
    jmp loop5
    
loop6:
    push dx
    mov dx, 1
    xor cx, cx
    jmp loop_per_line 
    
check_loop:      
     cmp [si], 9
     je tab_to_space
     inc si  
     
     cmp [si], '$'
     jne check_loop
     jmp str
               
tab_to_space:
    mov [si], 32
    jmp check_loop
                   
error_end:   
    mov ax, 3
    int 10h
    output message_error
    jmp endend  
        
the_end:   
    output endline
    output message_output 
    
    mov ah, 9
    mov dx, offset line + 2
    int 21h
    
    mov ah, 4Ch
    int 21h
    jmp endend
    
endend:
end start