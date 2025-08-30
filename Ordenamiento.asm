;Ordenamiento.asm 
;Ascendente/descendente 

op db ? ;aquí se guardará la opción elegida por el usuario (1/2)
 

MensajeOrden PROC 
    mov dx, offset msjorden
    mov ah, 9
    int 21h 
    
    mov dx, offset orden1
    mov ah, 9
    int 21h   
    
    mov dx, offset orden2
    mov ah, 9
    int 21h
    ret    
    
MensajeOrden ENDP  

InputsOrden PROC   
    ; Leer una tecla (la opción del menú)
    mov ah, 1       ; funcion int 21h para leer un caracter
    int 21h
    sub al, '0'     ; convertir de ASCII a número (ej: '1' -> 1)
    mov op, al  ; guardar opción   
    
    ; Saltar línea después de ingresar
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h    
    
    
    
    cmp op, 1
    je orden_asc

    cmp op, 2
    je orden_des
    
orden_asc:
;aqui va la logica del codigo
    mov al, op
    add al, '0'   ; convertir a ASCII
    mov dl, al
    mov ah, 2
    int 21h

orden_des:   
;aqui va la logica del codigo
    mov al, op
    add al, '0'   ; convertir a ASCII
    mov dl, al
    mov ah, 2
    int 21h                            
                                  
InputsOrden ENDP

