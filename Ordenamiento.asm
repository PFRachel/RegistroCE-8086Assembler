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
    MUL BX              ; AX = indice * SLOT_LEN
    MOV SI, offset records
    ADD SI, AX             

    ; buscar el ultimo espacio
    MOV DI, SI          
    MOV CX, SLOT_LEN
    MOV BX, SI          ; Inicializar BX con SI 

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
    CMP BL, ' '
    JB Done
    CMP BL, '0'
    JB Done
    CMP BL, '9'
    JA Done

    SUB BL, '0'
    MOV BH, 0
    ; AX = AX * 10 + BX 
    PUSH DX
    MOV CX, 10
    MUL CX 
    ADD AX, BX 
    POP DX
    INC DI
    JMP ParseInt
    
ParseDecimal:
    INC DI              ; Saltar el '.'
    MOV BX, 10000       ; Factor para 5 decimales 
    MOV CH, 0  
ParseFrac:    
    CMP CH, 5           ; Ya proceso 5 dígitos
    JAE Done  
    MOV CL, [DI]
    CMP CL, '$'
    JE Done 
    CMP CL, ' '
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
    
    ; validar rango
    MOV AL, [student_count]
    CMP AL, MAX_STUDENTS        ; Si excede el máximo
    JA FinSort                  ; Salir 
    
    ; Verificar si hay al menos 2 estudiantes
    CMP AL, 2
    JB FinSort
    
    ; Inicializar arreglo de índices 
    MOV CL, [student_count]    
    MOV CH, 0
    XOR SI, SI
    MOV AL, 1               ; Contador para los índices (empezar en 1) 
    MOV DX, CX

InitLoop:  
    CMP SI, MAX_STUDENTS        ; Verificación de rango
    JAE LimpiarCache           ; Si excede, ir a limpiar cache
    
    MOV [index_estudiante + SI], AL
    INC AL                  ; Siguiente índice
    INC SI                  ; Siguiente posición en el array
    CMP SI, DX
    JL InitLoop  

LimpiarCache:
    XOR SI, SI              ; Resetear SI a 0
    MOV CX, MAX_STUDENTS    ;  limpiar 
    
LimpiarLoop:
    CMP SI, MAX_STUDENTS    ; Si SI >= 15
    JAE PrecalcularNotas    ; Salir 
    
    MOV BX, SI
    SHL BX, 1               ; BX = SI * 2
    
    ; verificar rango
    CMP BX, MAX_STUDENTS * 2    ; Si BX >= 30 
    JAE SiguienteLimpieza      
    
    MOV [notas_l + BX], 0
    MOV [notas_h + BX], 0

SiguienteLimpieza:
    INC SI
    LOOP LimpiarLoop        ; LOOP decrementa CX 
    
    ; calcular notas para cada estudiante 
    XOR SI, SI              
    MOV CL, [student_count]
    MOV CH, 0               
    

PrecalcularNotas: 
    
    CMP SI, MAX_STUDENTS    ; Si SI >= 15
    JAE CICLO1              ; Ir directamente al ordenamiento
    
    CMP SI, CX              ; Si SI >= student_count
    JAE CICLO1              ; También salir
    
    MOV AL, [index_estudiante + SI]  ; Obtener ID
    
    CMP AL, 1
    JB SiguienteEstudiante
    CMP AL, MAX_STUDENTS
    JA SiguienteEstudiante
    
    PUSH AX                 ; Guardar el ID original en el stack
    
    MOV cID, AL
    CALL GetNotaFromRecords ; AX = parte entera, DX = parte decimal
    
    ; obtener id orginal
    POP BX                  ; BX ahora contiene el ID original
    PUSH AX                 ; parte entera
    PUSH DX                 ; parte decimal
    
    MOV AL, BL              
    DEC AL                  ; Convertir a 0-based (ID-1)
    XOR AH, AH              ; AX = ID - 1
    MOV BX, AX              ; BX = ID - 1
    
    CMP BX, MAX_STUDENTS    ; Si BX >= 15
    JAE RestaurarStack      ; Saltar este estudiante y limpiar stack
    
    SHL BX, 1               ; BX = (ID-1) * 2
    
    CMP BX, MAX_STUDENTS * 2    ; Si BX >= 30
    JAE RestaurarStack          ; Saltar este estudiante y limpiar stack
    
 
    POP DX                  ; Restaurar parte decimal
    POP AX                  ; Restaurar parte entera
    
    MOV [notas_l + BX], AX  ; Guardar parte entera
    MOV [notas_h + BX], DX  ; Guardar parte decimal
    JMP SiguienteEstudiante

RestaurarStack:
    ; Limpiar el stack si hubo error
    POP DX                  ; Descartar parte decimal
    POP AX                  ; Descartar parte entera

SiguienteEstudiante:
    INC SI
    CMP SI, CX              ; Usar CX en lugar de comparación directa
    JL PrecalcularNotas

    ; Algoritmo de ordenamiento - solo intercambiar índices
CICLO1: 
    XOR BH, BH          ; BH = bandera de intercambio
    XOR SI, SI          ; SI = índice para recorrer el arreglo
    
    MOV CL, [student_count]
    DEC CL              ; Número de comparaciones = n-1
    MOV BL, CL          ; BL = contador de comparaciones

CICLO2:  
CMP SI, MAX_STUDENTS - 1    ; Verificar que SI+1 no exceda
    JAE skip          
    MOV AL, [index_estudiante + SI]  ; ID del estudiante
    
    ; validar id
    CMP AL, 1
    JB skip                 ; Si ID < 1, saltar
    CMP AL, MAX_STUDENTS    
    JA skip                 ; Si ID > 15, saltar
    
    DEC AL                  ; Convertir a 0-based
    XOR AH, AH
    MOV DI, AX
    
    CMP DI, MAX_STUDENTS
    JAE skip
    
    SHL DI, 1               ; DI = (ID-1) * 2
                                          
    CMP DI, MAX_STUDENTS * 2
    JAE skip
    
    MOV AX, [notas_l + DI]  ; Parte entera
    MOV DX, [notas_h + DI]  ; Parte decimal
    MOV [nota1_l], AX
    MOV [nota1_h], DX 

    ; Nota2
    MOV AL, [index_estudiante + SI + 1]  ; ID del estudiante
    
    CMP AL, 1
    JB skip                 ; Si ID < 1, saltar
    CMP AL, MAX_STUDENTS    
    JA skip                 ; Si ID > 15, saltar
    
    DEC AL                  ; Convertir a 0-based
    XOR AH, AH
    MOV DI, AX
    
    CMP DI, MAX_STUDENTS
    JAE skip
    
    SHL DI, 1               ; DI = (ID-1) * 2
    
    CMP DI, MAX_STUDENTS * 2
    JAE skip
    
    MOV AX, [notas_l + DI]  ; Parte entera  
    MOV DX, [notas_h + DI]  ; Parte decimal
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
    ; Solo intercambiar los índices (simple y eficiente)
    MOV AL, [index_estudiante + SI]
    MOV CL, [index_estudiante + SI + 1]
    MOV [index_estudiante + SI], CL
    MOV [index_estudiante + SI + 1], AL
    MOV BH, 1                   ; Marcar que hubo intercambio

skip:
    INC SI   
    DEC BL
    JNZ CICLO2 

    CMP BH, 1 
    JE CICLO1  

FinSort:
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET  
Burbuja ENDP

MensajeOrden PROC  
    ; Verificar si hay estudiantes cargados
    mov al, [student_count]
    cmp al, 0
    jne ContinuarOrden  
    
    ; Mostrar mensaje de error si no hay registros
    mov dx, offset msjnoreg
    mov ah, 9
    int 21h
    call PrintCRLF 
    jmp menu_principal   
    ret
    
ContinuarOrden:
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
    mov op, al      ; Guardar la opción seleccionada

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
    MOV CH, 0

MostrarNombresLoop:
    CMP CX, 0
    JE FinMostrar
    
    MOV AL, [index_estudiante + SI]  ; obtener indice de estudiante ordenado
    MOV id, AL                       
    CALL MostrarPorIndice            ; reutiliza funcion, para print

    INC SI
    DEC CX
    JMP MostrarNombresLoop

FinMostrar:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
MostrarNombresOrdenados ENDP   
