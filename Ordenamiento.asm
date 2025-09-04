; ================================================
; Ordenamiento.asm 
; Ascendente/Descendente 
; ================================================ 

;===== SIMBOLOS EXTERNOS ======= 

SLOT_LEN EQU 64      ; tamano de cada registro de estudiante
MAX_STUDENTS EQU 15  ; maximo de estudiantes
;===============================                    

;========== VARIABLES===========  

op db ? ; opción elegida por el usuario (1/2)

;===============================  

; obtener la nota del record
GetNotaFromRecords PROC
; inicializar los registros
PUSH SI
PUSH BX
PUSH CX
PUSH DI

; calcular direccion del registro
MOV AL, cID
DEC AL          ; cID base 1 a base 0
MOV BL, AL
MOV AX, SLOT_LEN
MOV CX, BX
IMUL CX          
MOV SI, offset records  ;SI apunta al inicio del registro del estudiante
ADD SI, AX              

; copia de SI para buscar
MOV DI, SI          
MOV CX, SLOT_LEN
XOR BX, BX                 ; posicion del ultimo espacio
FindLastSpace:
CMP BYTE PTR [DI], '$'
JE FoundEnd
CMP BYTE PTR [DI], ' '
JNE NotSpace
MOV BX, DI                 ; guardar posicion del ultimo espacio   

NotSpace:
INC DI
LOOP FindLastSpace

FoundEnd:
; DI apunta al ultimo espacio, la nota empieza despues
INC BX

; parsear parte entera (antes del punto)
XOR AX, AX                ; AX = parte entera 
MOV DI, BX
ParseInt:
MOV BL, [DI]
CMP BL, '.'
JE ParseDecimal
CMP BL, '$'
JE EndParse
CMP BL, '0'
JB EndParse
CMP BL, '9'
JA EndParse

SUB BL, '0'
MOV BH, 0
SHL AX, 1                 ; AX = AX * 10
MOV CX, AX
SHL AX, 2                 ; AX = AX * 4
ADD AX, CX                ; AX = prev * 10
ADD AX, BX
INC DI
JMP ParseInt
    
    ; parsear parte decimal
ParseDecimal:
INC DI                    ; saltar el '.'
XOR DX, DX                ; DX = parte decimal
MOV CX, 5                 ; max 5 dígitos
MOV BX, 1                 ; multiplica lugar del decimal

ParseFrac:
CMP CX, 0
JE EndParse
MOV AL, [DI]
CMP AL, '$'
JE EndParse
CMP AL, '0'
JB EndParse
CMP AL, '9'
JA EndParse

SUB AL, '0'
MOV AH, 0
MUL BX
ADD DX, AX
MOV AX, BX
MOV BX, 10
MUL BX
MOV BX, AX

INC DI
DEC CX
JMP ParseFrac

EndParse:
POP DI
POP CX
POP BX
POP SI
RET
GetNotaFromRecords ENDP
           
;======== ALGORITMO BURBUJA ==========  
Burbuja PROC 
;guardar registros de uso
PUSH AX   
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DI

;iniciar indices de los estudiantes 
MOV CL, [student_count]
MOV CH, 0
XOR SI, SI 
MOV AL, 1 
      
;inicializar arreglo index_estudiante 
InitLoop:                      
MOV AX, SI
MOV AL, AL             
MOV [index_estudiante + SI], AL
INC SI
CMP SI, CX
JL InitLoop
MOV CL, [student_count]
DEC CL   
XOR CH, CH      
    
CICLO1:
XOR SI, SI     ; recorre index_estudiante desde 0
MOV BL, CL     ; comparaciones pasadas
      
CICLO2:  
         
; obtener nota 1
MOV AL, [index_estudiante + SI]   
MOV cID, AL
CALL GetNotaFromRecords
MOV [nota1_l], ax
MOV [nota1_h], dx
   
; obtener nota 2 
MOV AL, [index_estudiante + SI + 1]
MOV cID, AL
CALL GetNotaFromRecords
MOV [nota2_l], AX
MOV [nota2_h], DX  

; comparar entera                                                                   
MOV AX, [nota1_l]
CMP AX, [nota2_l]
JA mayor1
JB menor1

; comparar decimal
MOV AX, [nota1_h]
CMP AX, [nota2_h]
JA mayor1
JB menor1 


JMP skip   ; iguales
    
mayor1:
CMP op,1          ; 1 = ascendente => se quedan
JE skip 
jmp Intercambio    

menor1:           ; 2 = decendente => se quedan
CMP op,2
JE  skip
JMP Intercambio         

Intercambio:  
; intercambiar los indices
MOV AL, [index_estudiante + SI] 
MOV AH, [index_estudiante + SI+ 1]
MOV [index_estudiante + SI], AH
MOV [index_estudiante + SI+ 1], AL

skip:
INC SI
DEC BL
JNZ CICLO2 
DEC CL
JNZ CICLO1 

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
    ; Mostrar prompt otra vez si hace falta
    mov ah, 1       ; leer una tecla
    int 21h

    ; convertir ASCII a número
    sub al, '0'

    ; validar si es 1 o 2
    cmp al, 1
    je Valid
    cmp al, 2
    je Valid

    ; si no es válido
    mov dx, offset msjinv
    mov ah, 9
    int 21h

    ; CRLF
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    jmp ReadAgain

Valid:
    mov op, al

    ; salto de línea final
    mov ah, 2
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
    INC AL
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