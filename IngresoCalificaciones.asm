; ================================================
; IngresoCalificaciones.asm  
; Ingreso de datos 
; ================================================

id db ? ; indice para la busqueda de estudiantes 

MensajeIngreso PROC 
    ; Mostrar mensaje para inserción
    mov dx, offset msjinsert
    mov ah, 9
    int 21h 
    ret
MensajeIngreso ENDP    
            
InputsIngresar PROC
InputLoop:    
    ; Preparar el buffer para leer string
    mov dx, offset buffer ; Dirección del buffer
    mov ah, 0Ah ; Leer cadena
    int 21h
    
    ; Obtener cantidad de caracteres ingresados
    mov si, offset buffer
    mov cl, [si+1]
    cmp cl, 1
    jne Looping   
    
    ; Saltar línea después de ingresar
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h  
    
    ; Verificar si es '9'
    mov al, [si+2]
    cmp al, '9'
    ret  ;volver al menú    
    
Looping:
;-----------el print es solo para verificar q los datos se pasen correctamente, se puede borrar
    ; Print
    mov bx, si
    add bx, 2
    add bx, cx
    mov byte ptr [bx], '$'

    ; Imprimir nombre ingresado
    mov dx, offset buffer + 2
    mov ah, 9
    int 21h 
      
    ; Saltar línea después de ingresar
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h  
            
    ; Mostrar mensaje para inserción
    mov dx, offset msjinsert
    mov ah, 9
    int 21h 
    
    ; Volver a pedir otro nombre
    jmp InputLoop
    
InputsIngresar ENDP
            

MensajePos PROC ; Mostrar mensaje para buscar indice 
    mov dx, offset msjpos
    mov ah, 9
    int 21h   
    
    ; Leer una tecla (la opción del menú)
    mov ah, 1       ; funcion int 21h para leer un caracter
    int 21h
    sub al, '0'     ; convertir de ASCII a número (ej: '1' -> 1)
    mov id, al  ; guardar opción   
    
    ; Saltar un espacio de línea
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    
    ret
MensajePos ENDP 
