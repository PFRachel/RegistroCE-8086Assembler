; ================================================
; IngresoCalificaciones.asm
; Ingreso de datos y acceso por indice (1..N)
; ================================================

; ---- Mostrar mensaje de insercion
MensajeIngreso PROC
    mov dx, offset msjinsert
    mov ah, 9
    int 21h
    ret
MensajeIngreso ENDP

; ---- Ingreso con validacion estricta:
;   - Min 3 tokens: Nombre + Apellido + Nota (Apellido2 opcional)
;   - Nota: ultimo token numerico, max UN '.', y max 5 decimales
;   - '9' como unico caracter -> termina ingreso
InputsIngresar PROC
InputLoop:
    ; Leer cadena en buffer (AH=0Ah, DS:DX -> buffer)
    mov dx, offset buffer
    mov ah, 0Ah
    int 21h

    ; SI = buffer, CL = longitud ingresada (sin CR)
    mov si, offset buffer
    xor cx, cx
    mov cl, BYTE PTR [si+1]

    ; Salir si es '9' y nada mas
    cmp cl, 1
    jne NotExit
    mov al, BYTE PTR [si+2]
    cmp al, '9'
    je  EndInput

NotExit:
    ; === VALIDACION DE ENTRADA ===
    ; base = buffer+2
    lea si, [buffer+2]
    ; end = base + len  (guardar en BP)
    mov bx, si
    mov al, BYTE PTR [buffer+1]
    xor ah, ah
    add bx, ax
    mov bp, bx                   ; BP = end ptr (NO tocar luego)

    ; Contar tokens (transiciones espacio->no-espacio)
    ; CH = token_count, DL = inword(0/1), DI = inicio del ultimo token
    xor ch, ch
    xor dl, dl
    mov di, si

ScanTokens:
    cmp si, bp
    jae TokensDone
    mov al, BYTE PTR [si]
    cmp al, ' '
    je  IsSpace
    cmp dl, 0
    jne InWord
    inc ch
    mov di, si                   ; inicio del ultimo token
    mov dl, 1
InWord:
    inc si
    jmp ScanTokens

IsSpace:
    mov dl, 0
    inc si
    jmp ScanTokens

TokensDone:
    ; Requiere >= 3 tokens
    cmp ch, 3
    jb  BadInput

    ; Validar ultimo token numerico con max 5 decimales
    mov si, di; SI -> inicio del ultimo token
    xor bh, bh; BH = dot_flag (0/1)
    xor bl, bl; BL = digit_count total
    xor dh, dh; DH = postdot_count (0..5)

ValidateLast:
    cmp si, bp
    jae LastDone
    mov al, BYTE PTR [si]
    cmp al, ' '
    je  LastDone

    cmp al, '.'
    je  MaybeDot

    ; debe ser '0'..'9'
    cmp al, '0'
    jb  BadInput
    cmp al, '9'
    ja  BadInput

    inc bl                       ; suma un digito total
    cmp bh, 0
    je  AfterChkDone
    inc dh                       ; estamos despues del '.'
    cmp dh, 5
    ja  BadInput                 ; mas de 5 decimales -> invalido
AfterChkDone:
    inc si
    jmp ValidateLast

MaybeDot:
    cmp bh, 0
    jne BadInput                 ; segundo punto -> invalido
    mov bh, 1
    inc si
    jmp ValidateLast
LastDone:
    ; Debe haber al menos 1 digito
    cmp bl, 1
    jb  BadInput

    ; No permitir que termine en '.' o ','
    ; SI (de ValidateLast) quedó apuntando al final del token -> usar BX temporal
    mov bx, si
    dec bx
    mov al, [bx]
    cmp al, '.'
    je  BadInput
    cmp al, ','
    je  BadInput

    ; --- Parsear la PARTE ENTERA desde DI (inicio del último token) ---
    mov si, di        ; SI = inicio del último token (DI fue fijado en ScanTokens)
    xor ax, ax        ; AX = acumulador de la parte entera

ParseIntLoop:
    cmp si, bp
    jae AfterInt
    mov dl, [si]
    cmp dl, ' '
    je  AfterInt
    cmp dl, '.'
    je  AfterInt
    cmp dl, ','
    je  AfterInt

    ; convertir caracter -> 0..9
    sub dl, '0'
    jb  BadInput
    cmp dl, 9
    ja  BadInput

    ; AX = AX*10 + DL  (multiplicar por 10 con shift-add, luego sumar DL)
    mov cx, ax
    shl ax, 1
    shl cx, 3
    add ax, cx
    xor dh, dh        ; asegurar DH = 0
    add ax, dx        ; sumar DL (está en DL, DX alto=DH=0)

    cmp ax, 100
    ja  BadInput       ; si la parte entera ya >100 -> inválido

    inc si
    jmp ParseIntLoop

AfterInt:
    ; Si la parte entera < 100, está OK (cualquier decimal es <100)
    cmp ax, 100
    jb  AcceptNumber

    ; AX == 100 -> aceptar solo si NO hay decimales o si TODOS los decimales son '0'
    cmp si, bp
    jae AcceptNumber    ; llegó al final -> no decimales -> OK
    mov dl, [si]
    cmp dl, '.'
    je  CheckFrac
    cmp dl, ','
    je  CheckFrac
    ; si aquí hay algo distinto (espacio por ejemplo), OK
    jmp AcceptNumber

CheckFrac:
    inc si              ; pasar al primer dígito decimal

CheckFracLoop:
    cmp si, bp
    jae AcceptNumber
    mov dl, [si]
    cmp dl, ' '
    je  AcceptNumber
    cmp dl, '0'
    jne BadInput        ; si algún decimal != '0' => >100 => inválido
    inc si
    jmp CheckFracLoop

AcceptNumber:
    ; --- Sincroniza contador, por seguridad ---
    call SyncCountFromRecords

    ; === Detectar primer slot libre (llenamos huecos si los hubiera) ===
    mov di, offset records
    mov cx, MAX_STUDENTS
    xor bx, bx                   ; BX = indice de slot (0..14)
    
IntDone:
    ; --- Sincroniza contador, por seguridad ---
    call SyncCountFromRecords

    ; === Detectar primer slot libre (llenamos huecos si los hubiera) ===
    mov di, offset records
    mov cx, MAX_STUDENTS
    xor bx, bx
FindFree:
    mov al, [di]
    cmp al, '$'
    je  SlotFound
    add di, SLOT_LEN
    inc bx
    loop FindFree

    ; Sin espacio: avisar y seguir leyendo hasta '9'
    mov dx, offset msjlleno
    mov ah, 9
    int 21h
    jmp InputLoop

SlotFound:
    ; Copiar min(len, SLOT_LEN-1) bytes a records[slot]
    lea si, [buffer+2]
    xor cx, cx
    mov cl, BYTE PTR [buffer+1]
    cmp cx, (SLOT_LEN-1)
    jbe CopyLenOk
    mov cx, (SLOT_LEN-1)
CopyLenOk:
    cld                           ; SIEMPRE copiar hacia adelante
    rep movsb                     ; DS:SI -> ES:DI

    mov BYTE PTR [di], '$'        ; terminar en '$'

    ; Actualiza student_count = max(student_count, slot_index+1)
    mov al, bl
    inc al                        ; 1..15
    cmp al, student_count
    jbe NoBump
    mov student_count, al
NoBump:
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    mov dx, offset msjinsert
    mov ah, 9
    int 21h

    jmp InputLoop

BadInput:
    mov dx, offset msjincomp
    mov ah, 9
    int 21h
    ; CRLF
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    jmp InputLoop

EndInput:
    ; CRLF de cortesia y volver al menu
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret
InputsIngresar ENDP


; ---- Pedir indice (1..N) usando AH=0Ah con idxbuf, valida 1..15 y <= student_count
MensajePos PROC
AskIndex:
    ; Sincroniza el contador con lo que hay en memoria real
    call SyncCountFromRecords

    ; Mostrar cuantos registros hay
    mov dx, offset msjreg
    mov ah, 9
    int 21h
    mov al, BYTE PTR student_count
    call PrintByteDec
    call PrintCRLF

    ; Prompt
    mov dx, offset msjpos
    mov ah, 9
    int 21h

    ; Si no hay registros, salir
    cmp BYTE PTR student_count, 0
    jne  ContinueAsk
    mov dx, offset msjinv
    mov ah, 9
    int 21h
    ret

ContinueAsk:
    ; Leer linea en idxbuf => [idxbuf] = max (=3), [idxbuf+1] = len, [idxbuf+2...] = datos
    mov dx, offset idxbuf
    mov ah, 0Ah
    int 21h

    ; CL = longitud
    mov cl, BYTE PTR [idxbuf+1]
    cmp cl, 0
    je  BadShow

    ; SI -> primer char, AX=0 acumulara el numero
    lea si, [idxbuf+2]
    xor ax, ax

ParseDigits:
    mov bl, BYTE PTR [si]
    ; solo '0'..'9'
    cmp bl, '0'
    jb  BadShow
    cmp bl, '9'
    ja  BadShow

    ; AX = AX*10 + (bl-'0')   (shift-add: 10x = 2x + 8x)
    mov dl, bl
    sub dl, '0'
    mov bx, ax
    shl ax, 1
    shl bx, 3
    add ax, bx
    xor bx, bx
    mov bl, dl
    add ax, bx

    inc si
    dec cl
    jnz ParseDigits

    ; validar 1..15
    cmp ax, 1
    jb  BadShow
    cmp ax, 15
    ja  BadShow

    ; validar <= student_count (byte)
    mov bl, BYTE PTR student_count
    cmp al, bl
    ja  BadShow

    mov id, al
    call PrintCRLF
    ret

BadShow:
    mov dx, offset msjinv
    mov ah, 9
    int 21h
    call PrintCRLF
    jmp AskIndex
MensajePos ENDP


; ---- Mostrar por posicion (1..student_count)
MostrarPorIndice PROC
    mov al, id
    cmp al, 1
    jb  BadIndex
    cmp al, BYTE PTR student_count
    ja  BadIndex

    ; index = id-1  -> offset = records + index*64
    dec al
    xor bx, bx
    mov bl, al
    shl bx, 6
    mov dx, offset records
    add dx, bx
    mov ah, 9
    int 21h

    call PrintCRLF
    ret

BadIndex:
    mov dx, offset msjinv
    mov ah, 9
    int 21h
    call PrintCRLF
    ret
MostrarPorIndice ENDP
