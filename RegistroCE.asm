; ================================================
; RegistroCE.asm
; Sistema de gestión de calificaciones en 8086
; ================================================

; ================================================
; RegistroCE.asm
; Sistema de gestión de calificaciones en 8086
; ================================================

.model small
.stack 100h

.data
; ---------- CONSTANTES ----------
MAX_STUDENTS    EQU 15
SLOT_LEN        EQU 64                 ; 64 bytes por registro (linea + '$')

; 0 = NO limpiar pantalla en cada vuelta del menu
; 1 = limpiar pantalla
do_clear    db 0

; ---------- MENSAJES ----------
titulo      db 13,10,"===============================================",13,10,"Bienvenidos a RegistroCE",13,10,"===============================================",13,10,13,10,"$"
menu1       db "Digite:",13,10,"$"
op1a        db "1. Ingresar calificaciones (hasta 15 estudiantes",13,10,"$"
op1b        db "   - Nombre Apellido1 Apellido2 Nota -).",13,10,"$"
op2         db "2. Mostrar estadisticas.",13,10,"$"
op3         db "3. Buscar estudiante por posicion (indice).",13,10,"$"
op4         db "4. Ordenar calificaciones (ascendente/descendente).",13,10,"$"
op5         db "5. Salir.",13,10,"$"
prompt      db 13,10,"Opcion: $"

despedida   db 13,10,"===============================================",13,10,"Gracias por usar Registro CE",13,10,"===============================================",13,10,"$"
msjinsert   db "Por favor ingrese su estudiante o digite 9 para salir al menu principal",13,10,"$"
msjpos      db "Que estudiante desea mostrar",13,10,"$"
msjorden    db "Como desea ordenar las calificaciones",13,10,"$"
orden1      db "1. Asc",13,10,"$"
orden2      db "2. Des",13,10,"$"

; ---------- MENSAJES EXTRA ----------
msjlleno    db 13,10,"Lista llena (max 15). Presione 9 para volver al menu.",13,10,"$"
msjinv      db 13,10,"Indice invalido.",13,10,"$"
msjincomp   db 13,10,"Dato incompleto o nota invalida. Formato: Nombre Apellido [Apellido2] Nota",13,10,"$"

; (mensajes de ayuda/debug opcionales)
msjcnt      db "Guardados: $"
msjreg      db "Registros cargados: $"

; ---------- VARIABLES ----------
opcion          db 0               ; (1..5)
student_count   db 0               ; (0..15)
id              db 0               ; (1..N)

; ---------- ALMACENAMIENTO ----------
; 15 * 64 bytes: cada registro es la linea completa ingresada + '$'
records     db MAX_STUDENTS*SLOT_LEN dup('$')

; ---------- BUFFERS ----------
; AH=0Ah: byte0 = tam max, byte1 = longitud, bytes siguientes = datos
buffer      db (SLOT_LEN-1), 0, (SLOT_LEN-1) dup(?)
idxbuf      db 3, 0, 3 dup(?)      ; *** USADO POR MensajePos (opcion 3) ***

.code

; ---- IMPORTAR ARCHIVOS EXTERNOS ---
include "IngresoCalificaciones.asm"
include "Estadistica.asm"
include "Ordenamiento.asm"

; ---------- UTIL: limpiar pantalla opcional ----------
ClearScreen PROC
    cmp do_clear, 0
    je  cs_exit
    mov ah, 06h
    mov al, 0
    mov bh, 07h
    mov cx, 0
    mov dx, 184Fh
    int 10h
cs_exit:
    ret
ClearScreen ENDP

; ---------- UTIL: salto de linea ----------
PrintCRLF PROC
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret
PrintCRLF ENDP

; ---------- UTIL: imprime AL (0..99) en decimal ----------
PrintByteDec PROC
    ; entrada: AL = 0..99
    ; destruye AX, BX, DX
    xor ah, ah        ; AX = AL
    mov bl, 10
    div bl            ; AL = decenas, AH = unidades
    cmp al, 0
    je  only_units
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
only_units:
    mov dl, ah
    add dl, '0'
    mov ah, 2
    int 21h
    ret
PrintByteDec ENDP


main proc
    ; Inicializar DS y ES
    mov ax, @data
    mov ds, ax
    push ds
    pop  es           ; ES=DS para rep movsb en ingreso

; ---------- BUCLE PRINCIPAL DEL MENÚ ----------
menu_principal:
    call ClearScreen

    ; titulo
    mov dx, offset titulo
    mov ah, 9
    int 21h

    ; opciones
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

    ; prompt
    mov dx, offset prompt
    mov ah, 9
    int 21h

    ; leer opcion
    mov ah, 1
    int 21h
    sub al, '0'
    mov opcion, al

    ; CRLF
    call PrintCRLF

    ; ruteo
    cmp opcion, 1
    je  ingresar_calificaciones
    cmp opcion, 2
    je  mostrar_estadisticas
    cmp opcion, 3
    je  buscar_estudiante
    cmp opcion, 4
    je  ordenar_calificaciones
    cmp opcion, 5
    je  salir_programa

    jmp menu_principal

; ---------- OPCIONES ----------
ingresar_calificaciones:
    call MensajeIngreso
    call InputsIngresar
    jmp menu_principal

mostrar_estadisticas:
    ; (stub por ahora)
    ; call CalcularYMostrarEstadisticas
    jmp menu_principal

buscar_estudiante:
    call MensajePos         ; lee índice usando idxbuf (AH=0Ah) y valida 1..student_count
    call MostrarPorIndice   ; imprime el registro
    jmp menu_principal

ordenar_calificaciones:
    call MensajeOrden
    call InputsOrden
    jmp menu_principal
; --- Recalcula student_count escaneando records ---
; Cuenta slots ocupados: un slot vacio tiene '$' en su primer byte
SyncCountFromRecords PROC
    push ax
    push bx
    push cx
    push si

    mov si, offset records
    mov cx, MAX_STUDENTS
    xor bl, bl                 ; bl = real_count

next_slot:
    mov al, [si]               ; primer char del slot
    cmp al, '$'
    je  done_count             ; '$' => vacio => terminamos
    inc bl
    add si, SLOT_LEN
    loop next_slot

done_count:
    mov student_count, bl

    pop si
    pop cx
    pop bx
    pop ax
    ret
SyncCountFromRecords ENDP

; ---------- SALIDA ----------
salir_programa:
    mov dx, offset despedida
    mov ah, 9
    int 21h

    mov ah, 4Ch
    int 21h

main endp
end main
