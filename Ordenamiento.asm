;Ordenamiento.asm 
;Ascendente/Descendente  

Max_estudiantes EQU 15
slot_len EQU 64   

DATOS SEGMENT                         
;========== VARIABLES==========

op db ? ;aquí se guardará la opción elegida por el usuario (1/2)
 
index_estudiante DB Max_estudiantes dup(?)  ;[MODIFICAR] Lista donde se toma los datos de los estudiantes

DATOS ENDS
;===============================


CODIGOPRINCIPAL SEGMENT     
    
GetNota PROC
    PUSH SI 
    PUSH DI 
    PUSH AX
    PUSH BX
    PUSH CX
    MOV SI, OFFSET records
    MOV AX, BX
    MOV CX, slot_len
    MUL CX
    ADD SI, AX ; si apunta al registro
    ADD SI, slot_len
    DEC SI

HayEspacio:
    CMP byte ptr [si], " "
    JE AquiNota
    DEC SI
    JMP HayEspacio  

AquiNota:
    INC SI ;donde está la nota
    MOV AL, [SI]
    SUB AL,"0"
    MOV AH, 10
    MUL AH ;decena
    INC SI
    MOV AH, [SI]
    SUB AH, "0"
    ADD AL, AH
    POP DI 
    POP SI
    RET       
    
GetNota ENDP
           
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
XOR SI, SI  
MOV CL, student_count ; Variable  

InitLoop:                      
MOV AX, SI
MOV AL, AL  
MOV [index_estudiante + SI], AL 
INC BL
INC SI
LOOP InitLoop


; Indice para recorrer N-1 veces el algoritmo
MOV Cl, student_count  
MOV CH, 0 
DEC CX 

CICLO1: 
MOV SI, 0
XOR DX, CX ; Segundo Indice para comparar otro elemento
         
         
CICLO2:  
; Cargar indices1 y 2
MOV AL, [index_estudiante + SI]   

; Obtener notas
MOV BX, AX
CALL GetNota
MOV DL, AL

MOV BH, 0
CALL GetNota
MOV DH, AL 

; Ver si es asc o des
CMP op, 1
JE o_asc

CMP op, 2
JE o_des
JMP skip

o_asc:
CMP DL, DH
JG Intercambio ; Si la nota anterior es menor al actual, se inserta
JMP skip   

o_des:                                                                    
CMP DH, DL
JL Intercambio ; Si la nota anterior es mayor al actual, se inserta
JMP skip

Intercambio:  
; intercambiar los indices
MOV AL, [index_estudiante + SI] 
MOV AH, [index_estudiante + SI+ 1]
MOV [index_estudiante + SI], AH
MOV [index_estudiante + SI+ 1], AL

skip:
INC SI
DEC DX
JNZ CICLO2 
DEC CX
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
    
RET                           
                                  
InputsOrden ENDP  