;Ordenamiento.asm 
;Ascendente/Descendente 
;Referencia: La Ruta Dev (Youtube)

DATOS SEGMENT                         
;========== VARIABLES==========

op db ? ;aquí se guardará la opción elegida por el usuario (1/2)
 
array_burbuja DB 15, 79, 90, 59,70  ;[MODIFICAR] Lista donde se toma los datos de las calificaciones
A DB 5


DATOS ENDS
;===============================

PILA SEGMENT   
    
    DB 64 DUP(0)

PILA ENDS

CODIGOPRINCIPAL SEGMENT

INICIO PROC FAR
    
ASSUME DS:DATOS, CS:CODIGOPRINCIPAL, SS:PILA
PUSH DS
MOV AX,0
PUSH AX
; Inicializar segmentos
MOV AX,DATOS
MOV DS,AX
MOV ES,AX

CALL InputsOrden

CALL Burbuja             

INICIO ENDP
            
;======== ALGORITMO BURBUJA ==========  
Burbuja PROC

MOV CX,5 ;[MODIFICAR] Cantidad de comparaciones/repeticiones del algoritmo
MOV SI,0 ;Limpiar registros indice (por si acaso)
MOV DI,0 
                                                 
CICLO1:
PUSH CX ;poner en pila el valor de CX                                                           
MOV SI, OFFSET array_burbuja ;pasar direccion efectiva del arreglo a SI 
MOV DI,SI ;pasarlo a DI  

; Ver seleccion Asc/Des
MOV AL, [op]
CMP AL,1 
JE o_asc

CMP AL,2
JE o_des

POP CX
JMP InputsOrden                                            

o_asc:                                                                    
INC DI ;incrementar el indice DI para comparar el proximo elemento    
MOV AL,[SI] ;pasar la el valor en la direccion SI a AL
CMP AL, [DI] ;comparar con el valor de DI
JG INTERCAMBIO ;salta a etiqueta, cambiar si AL es mayor que DI
JB MENOR ;salta a etiqueta  

o_des:                                                                    
INC DI ;incrementar el indice DI para comparar el proximo elemento    
MOV AL,[SI] ;pasar la el valor en la direccion SI a AL
CMP AL, [DI] ;comparar con el valor de DI
JL INTERCAMBIO ;salta a etiqueta, cambiar si AL es menor que DI
JB MENOR ;salta a etiqueta

INTERCAMBIO:    
MOV AH,[DI] ;mover el valor de DI a AH
MOV [DI],AL ;mover el valor de AL a DI
MOV [SI],AH ;pasar el valor de AH a SI

MENOR:
INC SI ;incrementar indice del segundo numero
;la funcion de LOOP permite que al terminar el ciclo este pase a 
;POP que es reducir el indice para que se vuelva a comparar con todos, denuevo
POP CX ;decrementar el conteo del ciclo
LOOP CICLO1 ;entrar en ciclo con otro indice, compara los numeros y los intercambia

EXIT:
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

