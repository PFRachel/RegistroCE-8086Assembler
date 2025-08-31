; ================================================
; RegistroCE.asm
; Sistema de gestión de calificaciones en 8086
; ================================================

.model small  ; memoria, entra a un segmento
.stack 100h  ;reserve    100h = 256 bytes

.data
; ---------- CONSTANTES ----------
MAX_STUDENTS    EQU 15; Max de registro
SLOT_LEN        EQU 64; 64 bytes por registro

do_clear    db 0;flag limpiar pantalla

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
msjincomp   db 13,10,"Dato incompleto o nota invalida. Formato: Nombre Apellido [Apellido2] Nota (hasta 5 decimales).",13,10,"$"
msjcnt      db "Guardados: $"
msjreg      db "Registros cargados: $"
msjprom     db 13,10,'Promedio general: $'
msjnoreg    db 13,10,'No hay registros cargados.$'

; === Mensajes de Estadistica ===
msj_est_tit    db 13,10,'=== Estadisticas ===',13,10,'$'
msj_prom_lbl   db 'Promedio general: $'
msj_max_lbl    db 'Nota maxima: $'
msj_min_lbl    db 'Nota minima: $'
msj_apr_lbl    db 'Aprobados: $'
msj_rep_lbl    db 'Reprobados: $'
msj_spc_pct    db ' (','$'
msj_pct_close  db '%)',13,10,'$'

; === Variables temporales de Estadistica ===
tot_lo   dw 0
tot_hi   dw 0
max100   dw 0
min100   dw 0
apr_cnt  db 0
rep_cnt  db 0

; ---------- VARIABLES ----------
opcion          db 0; (1..5 opcion del menu)
student_count   db 0; (0..15 cant registros en memoria)
id              db 0; (1..N indice solicitado)

; ---------- ALMACENAMIENTO en memoria ----------
; 15 * 64 bytes: cada registro es la linea completa ingresada
records     db MAX_STUDENTS*SLOT_LEN dup('$') ;La idea de trabajarlo con records fue gracias a la base de Chat GPT. 

; ---------- BUFFERS ----------
; AH=0Ah: byte0 = tam max, byte1 = longitud, bytes siguientes = datos
buffer      db (SLOT_LEN-1), 0, (SLOT_LEN-1) dup(?)
idxbuf      db 3, 0, 3 dup(?)      ; buffer de indice en opcion 3

.code

; ---- IMPORTAR ARCHIVOS EXTERNOS ---
include "IngresoCalificaciones.asm"
include "Estadistica.asm"
include "Ordenamiento.asm"

; ----------limpiar pantalla----------
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

; ---------- salto de linea ----------
PrintCRLF PROC
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret
PrintCRLF ENDP

; ----------imprime AL (0..99) en decimal ----------
PrintByteDec PROC
    ; entrada: AL = 0..99
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

; ---------- Recuenta mirando TODOS los slots ----------
; cuenta los 15 slots de 64 bytes 
SyncCountFromRecords PROC
    push ax
    push bx
    push cx
    push si

    mov si, offset records; SI-inicio arreglo registro
    mov cx, MAX_STUDENTS;cuenta slots
    xor bl, bl; BL = ultimo_indice (0 = ninguno)
    mov al, 1 ; i = 1..inidice que guarda en BL

scan_all:
    mov dl, [si]; primer byte del slot i
    cmp dl, '$'; dollar= slot vacio
    je  next_slot; '$' => vacio, solo seguir
    mov bl, al; guarda i como ultimo ocupado
next_slot:
    add si, SLOT_LEN ;siguiente slot
    inc al ; sigue al otro indice 
    loop scan_all;repite 15 v

    mov student_count, bl; guarda el indice

    pop si
    pop cx
    pop bx
    pop ax
    ret
SyncCountFromRecords ENDP


main proc
    ; Inicializar DS y ES e ingrese en data
    mov ax, @data
    mov ds, ax
    push ds
    pop  es; ES=DS para rep movsb en ingreso

; ---------- BUCLE PRINCIPAL DEL MENÚ ----------
menu_principal:
    call ClearScreen;limpia si es 1

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
    call MensajeIngreso ;(ingresoCalificaciones.asm)
    call InputsIngresar ; lee linea
    jmp menu_principal  ; vuelve menu

buscar_estudiante:
    call MensajePos;pide un indice
    call MostrarPorIndice; imprime el registro con AH=09
    jmp menu_principal

ordenar_calificaciones:
    call MensajeOrden;(0rdenamiento.asm)
    call InputsOrden
    jmp menu_principal 
     
mostrar_estadisticas:
    call MostrarEstadisticas
    jmp menu_principal
; ---------- SALIDA ----------
salir_programa:
    mov dx, offset despedida
    mov ah, 9
    int 21h; imprime mensaje de salida

    mov ah, 4Ch;INT 21h/AH=4Ch: terminar programa a DOS
    int 21h

main endp
end main
