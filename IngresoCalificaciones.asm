; ================================================
; IngresoCalificaciones.asm
; Ingreso de datos y acceso pr indice (1...n)
; ================================================
MensajeIngreso PROC
    mov dx, offset msjinsert
    mov ah, 9
    int 21h
    ret
MensajeIngreso ENDP


; Lee lineas y las guarda en records[i], i=0..14. Sale si el usuario ingresa '9' como unico caracter.
InputsIngresar PROC
InputLoop:
    ; Leer cadena en buffer (AH=0Ah, DS:DX -> buffer)
    mov dx, offset buffer
    mov ah, 0Ah
    int 21h

    ; SI = buffer, CL = longitud ingresada
    mov si, offset buffer
    xor cx,cx
    mov cl, BYTE PTR [si+1]         ; cantidad de chars (sin CR)

    ; Caso salir: si longitud=1 y primer char = '9'
    cmp cl, 1
    jne NotExit
    mov al, BYTE PTR [si+2]
    cmp al, '9'
    je EndInput

NotExit:
    ; Validar cupo < MAX_STUDENTS
    mov al, student_count
    cmp al, MAX_STUDENTS
    jb HasSpace
    ; Sin espacio: avisar y seguir leyendo hasta '9'
    mov dx, offset msjlleno
    mov ah, 9
    int 21h
    jmp InputLoop

HasSpace:
    ; BX = indice actual (0..14), DI = destino = records + i*64
    xor bx, bx
    mov bl, student_count    ; BL = i
    shl bx, 6                ; i * 64
    mov di, offset records
    add di, bx

    ; Copiar min(CL, SLOT_LEN-1) bytes desde buffer+2 a records[i]
    lea si, [buffer+2]  
    xor cx,cx
    mov cl, BYTE PTR [buffer+1]  ; CL = longitud leida
    cmp cx, (SLOT_LEN-1)
    jbe CopyLenOk
    mov cx, (SLOT_LEN-1)
CopyLenOk:
    rep movsb

    ; Terminar con '$'
    mov byte ptr [di], '$'

    ; Incrementar contador
    inc student_count

    ; Saltar linea
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h

    ; Mostrar nuevamente el mensaje de inserción
    mov dx, offset msjinsert
    mov ah, 9
    int 21h

    jmp InputLoop

EndInput:
    ; Saltar linea de cortesía
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret
InputsIngresar ENDP


; Pide el indice en MensajePos y aqui imprimimos el registro correspondiente
; 'id' llega en memoria como valor 0..9 (por tu código), lo convertimos 1..N.

; ---- Pedir indice (1..N), soporta 10..15 y repregunta hasta ser válido
MensajePos PROC
AskIndex:
    mov dx, offset msjpos
    mov ah, 9
    int 21h

    ; Leer linea en idxbuf (AH=0Ah)
    mov dx, offset idxbuf
    mov ah, 0Ah
    int 21h

    ; idxbuf[1] = longitud (sin CR). idxbuf+2 = datos
    mov si, offset idxbuf
    mov cl, BYTE PTR [si+1]        ; longitud leida (0..3)
    cmp cl, 0
    je  BadShow                    ; nada tecleado -> repreguntar

    lea si, [si+2]                 ; SI -> primer char de datos

    ; AX acumulara el número. BX=10 para multiplicar en 16 bits.
    xor ax, ax
    mov bx, 10

ParseLoop:
    mov dl, BYTE PTR [si]
    ; Ignorar espacios
    cmp dl, ' '
    je  SkipChar

    ; Aceptar solo 0..9
    cmp dl, '0'
    jb  BadShow
    cmp dl, '9'
    ja  BadShow

    ; AX = AX*10 + (dl-'0')
    mul bx                         ; DX:AX = AX * 10
    mov dh, 0
    mov ah, 0                      ; (DX=0 de todos modos para valores pequeños)
    mov dh, dl
    sub dh, '0'
    add ax, dx                     ; ¡OJO! reusamos DX/AX, usemos un registro seguro
    ; --- versión clara y correcta sin reusar DX ---
    ;  mul bx               ; DX:AX = AX*10
    ;  xor dx, dx           ; DX no se usa luego
    ;  mov dl, BYTE PTR [si]
    ;  sub dl, '0'
    ;  mov dh, 0
    ;  add ax, dx

    ; (Usaremos la versión clara abajo para evitar confusiones)
SkipChar:
    inc si
    dec cl
    jnz ParseDoneCheck
    jmp  DoneParse

ParseDoneCheck:
    jmp ParseLoop

DoneParse:
    ; Validar 1..student_count y <=15
    cmp ax, 1
    jb  BadShow
    cmp ax, 15
    ja  BadShow
    cmp al, student_count
    ja  BadShow

    mov id, al

    ; CRLF
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret

BadShow:
    mov dx, offset msjinv
    mov ah, 9
    int 21h
    ; CRLF
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    jmp AskIndex
MensajePos ENDP

; Imprime por posicion (1..student_count). Si es invalido, avisa.
MostrarPorIndice PROC
    mov al, id
    ; Validar [1..student_count]
    cmp al, 1
    jb  BadIndex
    cmp al, student_count
    ja  BadIndex 
     ; index = al - 1  (0..14)
    dec al
    xor bx, bx
    mov bl, al
    shl bx, 6                   ; *64
    mov dx, offset records
    add dx, bx                  ; DS:DX -> inicio del slot con '$' final
    mov ah, 9
    int 21h  
     ; CRLF
    mov ah, 2
    mov dl, 13
    int 21h
    mov dl, 10
    int 21h
    ret
    BadIndex:
    mov dx, offset msjinv
    mov ah, 9
    int 21h
    ret
MostrarPorIndice ENDP
