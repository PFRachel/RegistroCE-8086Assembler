; ================================================
; RegistroCE.asm  
; Codigo principal  
; Sistema de gesti�n de calificaciones en 8086
; ================================================
.model small
.stack 100h

.data
; ---------- MENSAJES ----------
titulo      db 13,10,"===============================================",13,10,"Bienvenidos a RegistroCE",13,10,"===============================================",13,10,13,10,"$"
menu1       db "Digite:",13,10,"$"
op1a db "1. Ingresar calificaciones (hasta 15 estudiantes",13,10,"$"
op1b db "   - Nombre Apellido1 Apellido2 Nota -).",13,10,"$"
op2         db "2. Mostrar estadisticas.",13,10,"$"
op3         db "3. Buscar estudiante por posicion (indice).",13,10,"$"
op4         db "4. Ordenar calificaciones (ascendente/descendente).",13,10,"$"
op5         db "5. Salir.",13,10,"$"
prompt      db 13,10,"Opcion: $"

despedida   db 13,10,"===============================================",13,10,"Gracias por usar Registro CE",13,10,"===============================================",13,10,"$"

; ---------- VARIABLES DE ENTRADA ----------
opcion db ?        ; aqu� se guardar� la opci�n elegida por el usuario (1-5)

.code
main proc
    ; Inicializar segmento de datos
    mov ax, @data
    mov ds, ax

; ---------- BUCLE PRINCIPAL DEL MEN� ----------
menu_principal:
    ; limpiar pantalla (scroll up)
    mov ah, 06h      ; funcion scroll up
    mov al, 0        ; borrar todas las lineas
    mov bh, 07h      ; atributo (blanco sobre negro)
    mov cx, 0        ; esquina sup izq
    mov dx, 184Fh    ; esquina inf der (80x25)
    int 10h

    ; Mostrar t�tulo
    mov dx, offset titulo
    mov ah, 9
    int 21h

    ; Mostrar opciones
    mov dx, offset menu1
    mov ah, 9
    int 21h

    mov dx, offset op1a
    mov ah, 9
    int 21h

    mov dx, offset op1b
    mov ah, 9
    int 21h


    mov dx, offset op2
    mov ah, 9
    int 21h

    mov dx, offset op3
    mov ah, 9
    int 21h

    mov dx, offset op4
    mov ah, 9
    int 21h

    mov dx, offset op5
    mov ah, 9
    int 21h

    ; Mostrar prompt
    mov dx, offset prompt
    mov ah, 9
    int 21h

    ; Leer una tecla (la opci�n del men�)
    mov ah, 1       ; funcion int 21h para leer un caracter
    int 21h
    sub al, '0'     ; convertir de ASCII a n�mero (ej: '1' -> 1)
    mov opcion, al  ; guardar opci�n

    ; Comparar opciones
    cmp opcion, 1
    je ingresar_calificaciones

    cmp opcion, 2
    je mostrar_estadisticas

    cmp opcion, 3
    je buscar_estudiante

    cmp opcion, 4
    je ordenar_calificaciones

    cmp opcion, 5
    je salir_programa

    ; Si no es v�lida, volver al men�
    jmp menu_principal


; ---------- OPCIONES DEL MEN� (POR AHORA VAC�AS) ----------
ingresar_calificaciones:
    ; Aqu� ir� la l�gica de ingreso (fase 2)
    jmp menu_principal

mostrar_estadisticas:
    ; Aqu� ir� la l�gica de estad�sticas (fase 3)
    jmp menu_principal

buscar_estudiante:
    ; Aqu� ir� la l�gica de b�squeda (fase 4)
    jmp menu_principal

ordenar_calificaciones:
    ; Aqu� ir� la l�gica de ordenamiento (fase 5)
    jmp menu_principal

; ---------- SALIDA DEL PROGRAMA ----------
salir_programa:
    mov dx, offset despedida
    mov ah, 9
    int 21h          ; imprime mensaje de salida

    mov ah, 4Ch      ; terminar programa
    int 21h

main endp
end main
