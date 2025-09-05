; ================================================
; Ordenamiento.asm 
; Ascendente/Descendente                       
; Referencia: La Ruta Dev (Youtube)
; ================================================ 

;===== SIMBOLOS EXTERNOS ======= 

SLOT_LEN EQU 64      ; tamano de cada registro de estudiante
MAX_STUDENTS EQU 15  ; maximo de estudiantes                  

;========== VARIABLES===========  

op db ? ; opción elegida por el usuario (1/2)  

;===============================  

; obtener la nota del record
GetNotaFromRecords PROC
    PUSH SI
    PUSH BX
    PUSH CX
    PUSH DI

    ; calcular direccion del registro
    MOV AL, cID
    DEC AL              ; cID base 1 a base 0
    XOR AH, AH          ; Limpiar AH
    MOV BX, SLOT_LEN
    MUL BX              ; AX = índice * SLOT_LEN
    MOV SI, offset records
    ADD SI, AX             

    ; Buscar el último espacio
    MOV DI, SI          
    MOV CX, SLOT_LEN
    MOV BX, SI          ; Inicializar BX con SI (inicio del registro)

FindLastSpace:
    CMP BYTE PTR [DI], '$'
    JE FoundEnd
    CMP BYTE PTR [DI], ' '
    JNE NotSpace
    MOV BX, DI          ; Guardar posición del espacio
    INC BX              ; BX apunta al carácter después del espacio

NotSpace:
    INC DI
    LOOP FindLastSpace

FoundEnd:
    ; BX apunta al inicio de la nota
    MOV DI, BX
    XOR AX, AX          ; Parte entera
    XOR DX, DX          ; Parte decimal

ParseInt:
    MOV BL, [DI]
    CMP BL, '.'
    JE ParseDecimal
    CMP BL, '$'
    JE Done
    CMP BL, '0'
    JB Done
    CMP BL, '9'
    JA Done

    SUB BL, '0'
    MOV BH, 0
    ; AX = AX * 10 + BX
    MOV CX, 10
    MUL CX
    ADD AX, BX
    INC DI
    JMP ParseInt
    
ParseDecimal:
    INC DI              ; Saltar el '.'
    MOV BX, 10000       ; Factor para hasta 5 decimales (10000, 1000, 100, 10, 1)
    MOV CH, 0  
ParseFrac:    
    CMP CH, 5           ; ¿Ya procesamos 5 dígitos?
    JAE Done  
    MOV CL, [DI]
    CMP CL, '$'
    JE Done
    CMP CL, '0'
    JB Done  
    CMP CL, '9'
    JA Done

    SUB CL, '0'
    ; DX = DX + (dígito * factor)
    PUSH AX
    MOV AL, CL
    XOR AH, AH
    MUL BX
    ADD DX, AX
    POP AX
    
    ; factor = factor / 10
    PUSH AX
    PUSH DX
    MOV AX, BX
    MOV BX, 10
    XOR DX, DX
    DIV BX
    MOV BX, AX
    POP DX
    POP AX
    
    INC CH
    INC DI
    JMP ParseFrac

Done:
    POP DI
    POP CX
    POP BX
    POP SI
    RET
GetNotaFromRecords ENDP
           
;======== ALGORITMO BURBUJA ==========  
Burbuja PROC 
    PUSH AX   
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Inicializar arreglo de índices
    MOV CL, [student_count]    
    MOV CH, 0
    XOR SI, SI
    MOV AL, 1               ; Contador para los índices (empezar en 1)

InitLoop:  
    MOV [index_estudiante + SI], AL
    INC AL                  ; Siguiente índice
    INC SI                  ; Siguiente posición en el array
    CMP SI, CX
    JL InitLoop

CICLO1: 
    XOR BH, BH          ; BH = bandera de intercambio
    XOR SI, SI          ; SI = índice para recorrer el arreglo
    
    MOV CL, [student_count]
    DEC CL              ; Número de comparaciones = n-1
    MOV BL, CL          ; BL = contador de comparaciones

CICLO2:          
    ; Obtener nota 1
    MOV AL, [index_estudiante + SI]
    MOV cID, AL
    CALL GetNotaFromRecords 
    MOV [nota1_l], AX
    MOV [nota1_h], DX 

    ; Obtener nota 2 
    MOV AL, [index_estudiante + SI + 1]
    MOV cID, AL
    CALL GetNotaFromRecords 
    MOV [nota2_l], AX
    MOV [nota2_h], DX  

    ; Comparar parte entera primero
    MOV AX, [nota1_l]
    CMP AX, [nota2_l]
    JA mayor1
    JB menor1   

    ; Si partes enteras son iguales, comparar decimales
    MOV AX, [nota1_h]
    CMP AX, [nota2_h]
    JA mayor1
    JB menor1 

    JMP skip   ; Son completamente iguales
    
mayor1:
    CMP op, 1           ; ¿Orden descendente?
    JE Intercambio 
    JMP skip       

menor1:          
    CMP op, 2           ; ¿Orden ascendente?
    JE Intercambio 
    JMP skip          
            
Intercambio:  
    ; Intercambiar los índices
    MOV AL, [index_estudiante + SI] 
    MOV AH, [index_estudiante + SI + 1]
    MOV [index_estudiante + SI], AH
    MOV [index_estudiante + SI + 1], AL           
    MOV BH, 1           ; Marcar que hubo intercambio

skip:
    INC SI   
    DEC BL
    JNZ CICLO2 

    CMP BH, 1 
    JE CICLO1  

    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET  
Burbuja ENDP                                                          

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
ReadAgain:
    mov ah, 1       ; leer una tecla
    int 21h

    sub al, '0'     ; convertir ASCII a número

    cmp al, 1       ; validar si es 1 o 2
    je Valid
    cmp al, 2
    je Valid

    ; si no es válido
    mov dx, offset msjinv
    mov ah, 9
    int 21h

    mov ah, 2       ; CRLF
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    jmp ReadAgain

Valid:
    mov op, al

    mov ah, 2       ; salto de línea final
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h  
    RET                                               
InputsOrden ENDP    

MostrarNombresOrdenados PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    XOR SI, SI
    MOV CL, [student_count]

MostrarNombresLoop:
    MOV AL, [index_estudiante + SI]  ; obtener indice de estudiante ordenado
    MOV id, AL                       
    CALL MostrarPorIndice            ; reutiliza funcion, para print

    INC SI
    LOOP MostrarNombresLoop

    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
MostrarNombresOrdenados ENDP   

;======== DEBUGG===============
MostrarIndicesOrden PROC
    PUSH SI
    XOR SI, SI
    MOV CL, [student_count]
MostrarLoop:
    MOV AL,[index_estudiante + SI]
    ADD AL,'0'
    MOV DL,AL
    MOV AH,2
    INT 21h
    MOV DL,' '
    INT 21h
    INC SI
    LOOP MostrarLoop
    ; salto de línea
    MOV AH,2
    MOV DL,13
    INT 21h
    MOV DL,10
    INT 21h
    POP SI  
    RET
MostrarIndicesOrden ENDP