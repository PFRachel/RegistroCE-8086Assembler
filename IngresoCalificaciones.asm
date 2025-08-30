; ================================================
; IngresoCalificaciones.asm
; Ingreso de datos y acceso por indice (1..N)
; ================================================
; NOTAS:
; - Este archivo se INCLUYE en RegistroCE.asm
; - 'buffer', 'records', 'student_count', 'id' y mensajes existen en RegistroCE.asm
; - Ejecuta SOLO RegistroCE.asm en EMU8086

; ---- Mostrar mensaje de insercion
MensajeIngreso PROC
    mov dx, offset msjinsert
    mov ah, 9
    int 21h
    ret
MensajeIngreso ENDP


; ---- Ingreso con validacion estricta:
; Reglas para ACEPTAR:
;   - Minimo 3 tokens: Nombre + Apellido + Nota   (Apellido2 es opcional)
;   - El ULTIMO token debe ser NUMERICO: digitos y, como mucho, UN solo '.'.
;   - '9' como unico caracter -> termina ingreso.
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
    ; end = base + len  ? GUARDAR en BP (¡no en BX!)
    mov bx, si
    mov al, BYTE PTR [buffer+1]
    xor ah, ah
    add bx, ax                   ; BX = end ptr temporal
    mov bp, bx                   ; BP = end ptr DEFINITIVO (NO toques BP después)

    ; Contar tokens (transiciones espacio->no-espacio)
    ; CH = token_count, DL = inword(0/1), DI = inicio del ultimo token
    xor ch, ch
    xor dl, dl
    mov di, si

ScanTokens:
    cmp si, bp                   ; usar BP como fin
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

    ; Validar que el ULTIMO token sea numerico (digitos + a lo sumo UN '.')
    mov si, di                   ; SI -> inicio del ultimo token
    xor bh, bh                   ; BH = dot_flag (0 = ninguno visto)
    xor bl, bl                   ; BL = digit_count

ValidateLast:
    cmp si, bp                   ; usar BP como fin SIEMPRE
    jae LastDone
    mov al, BYTE PTR [si]
    cmp al, ' '
    je  LastDone

    cmp al, '.'
    je  MaybeDot
    cmp al, '0'
    jb  BadInput
    cmp al, '9'
    ja  BadInput
    inc bl                       ; suma un digito
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

    ; No permitir que termine en '.'
    mov di, si
    dec di
    mov al, BYTE PTR [di]
    cmp al, '.'
    je  BadInput

    ; === Cupo disponible? ===
    mov al, student_count
    cmp al, MAX_STUDENTS
    jb  HasSpace

    ; Lista llena
    mov dx, offset msjlleno
    mov ah, 9
    int 21h
    jmp InputLoop

HasSpace:
    ; DI = destino = records + (student_count * 64)
    xor bx, bx
    mov bl, student_count        ; BL = i
    shl bx, 6                    ; i * 64
    mov di, offset records
    add di, bx

    ; Copiar min(len, SLOT_LEN-1) bytes a records[i]
    lea si, [buffer+2]
    xor cx, cx
    mov cl, BYTE PTR [buffer+1]
    cmp cx, (SLOT_LEN-1)
    jbe CopyLenOk
    mov cx, (SLOT_LEN-1)
CopyLenOk:
    rep movsb                    ; DS:SI -> ES:DI  (ES=DS en main)

    mov BYTE PTR [di], '$'       ; terminar en '$'

    inc student_count            ; AQUI ya contamos el alumno

    ; CRLF + volver a pedir
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
    ; Mensaje de dato incompleto/nota invalida
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


; ---- Pedir indice (1..N) con AH=01h (acepta 1..15), repregunta hasta ser valido
; ---- Pedir indice (1..N) con AH=01h (acepta 1..15), repregunta hasta ser valido
; ---- Pedir indice (1..N) con AH=01h (acepta 1..15), repregunta hasta ser valido
; Deja definido en RegistroCE.asm: student_count, id, msjpos, msjinv
; ---- Pedir indice (1..N) usando AH=0Ah con idxbuf, valida 1..15 y <= student_count
MensajePos PROC
AskIndex:  
    ; Sincroniza el contador con lo que hay en memoria
    call SyncCountFromRecords
    ; Mostrar cuántos registros hay (útil para confirmar que se guardó)
    mov dx, offset msjreg          ; "Registros cargados: $"
    mov ah, 9
    int 21h
    mov al, BYTE PTR student_count
    call PrintByteDec              ; (esta rutina ya está en RegistroCE.asm)
    call PrintCRLF

    ; Prompt
    mov dx, offset msjpos
    mov ah, 9
    int 21h

    ; Si no hay registros, salir
    cmp BYTE PTR student_count, 0
    jne  ContinueAsk
    mov dx, offset msjinv          ; "Indice invalido."
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

    ; SI -> primer char, AX=0 acumulará el número
    lea si, [idxbuf+2]
    xor ax, ax

ParseDigits:
    mov bl, BYTE PTR [si]          ; leer char
    ; aceptar solo '0'..'9'
    cmp bl, '0'
    jb  BadShow
    cmp bl, '9'
    ja  BadShow

    ; AX = AX*10 + (bl-'0')   (shift-add: 10x = 2x + 8x)
    mov dl, bl
    sub dl, '0'
    mov bx, ax
    shl ax, 1                      ; 2*old
    shl bx, 3                      ; 8*old
    add ax, bx                     ; 10*old
    xor bx, bx
    mov bl, dl
    add ax, bx                     ; + digit

    inc si
    dec cl
    jnz ParseDigits

    ; validar 1..15
    cmp ax, 1
    jb  BadShow
    cmp ax, 15
    ja  BadShow

    ; validar <= student_count (comparación en byte)
    mov bl, BYTE PTR student_count
    cmp al, bl
    ja  BadShow

    mov id, al                     ; OK
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
    shl bx, 6                      ; *64
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

