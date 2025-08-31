; =========================================================
; Estadistica.asm 
; Calculos sobre records (15 slots x 64 bytes c/u)
; Estructura: "Nombre Apellido [Apellido2] Nota$" en cada slot de 64 bytes
; =========================================================

; =========================================================
; Procedimiento principal: MostrarEstadisticas
; =========================================================
MostrarEstadisticas PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Sincronizar conteo desde memoria
    call SyncCountFromRecords

    cmp BYTE PTR student_count, 0
    jne ms_continuar
    mov dx, offset msjnoreg
    mov ah, 9
    int 21h
    call PrintCRLF
    jmp ms_salir

ms_continuar:
    mov dx, offset msj_est_tit
    mov ah, 9
    int 21h

        ; Inicializar variables
    xor ax, ax
    mov tot_lo, ax
    mov tot_hi, ax
    mov apr_cnt, al
    mov rep_cnt, al
    mov max100, ax

    mov ax, 0FFFFh              ; valor muy grande (65535)
    mov min100, ax              ; garantiza que el primer registro lo sobreescriba

    ; Procesar todos los registros
    mov si, offset records      ; SI = inicio de records
    mov cl, [student_count]     ; CL = numero de estudiantes
    xor ch, ch                  ; CX = numero de estudiantes

ms_bucle:
    push cx                     ; Guardar contador
    push si                     ; Guardar posicion actual
    
    ; Extraer nota del registro actual
    call ExtractValue100        ; AX = nota * 100
    
    ; Actualizar sumatoria (32 bits)
    add tot_lo, ax
    adc tot_hi, 0
    
    ; Actualizar maximo
    cmp ax, max100
    jbe ms_chk_min
    mov max100, ax
    
ms_chk_min:
    ; Actualizar minimo
    cmp ax, min100
    jae ms_chk_aprobado
    mov min100, ax
    
ms_chk_aprobado:
    ;Verificar si aprobo (>=70.00 = >=7000)
    cmp ax, 7000
    jb  ms_reprobado
    inc apr_cnt
    jmp ms_siguiente
    
ms_reprobado:
    inc rep_cnt
    
ms_siguiente:
    pop si                      ; Recuperar posición
    pop cx                      ; Recuperar contador
    add si, 64                  ; Siguiente registro (64 bytes por slot)
    loop ms_bucle

    ; Calcular promedio = total / cantidad
    mov ax, tot_lo
    mov dx, tot_hi  
    mov cl, [student_count]
    xor ch, ch
    div cx                      ; AX = promedio * 100

    ; Mostrar promedio
    mov dx, offset msj_prom_lbl
    mov ah, 9
    int 21h
    call PrintValue100
    call PrintCRLF

    ; Mostrar maximo
    mov dx, offset msj_max_lbl
    mov ah, 9
    int 21h
    mov ax, max100
    call PrintValue100
    call PrintCRLF

    ; Mostrar minimo  
    mov dx, offset msj_min_lbl
    mov ah, 9
    int 21h
    mov ax, min100
    call PrintValue100
    call PrintCRLF

    ; Mostrar aprobados
    mov dx, offset msj_apr_lbl
    mov ah, 9
    int 21h
    mov al, apr_cnt
    call PrintByteDec
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h
    
    ; Calcular porcentaje aprobados
    xor ax, ax
    mov al, apr_cnt
    mov bx, 10000
    mul bx                      ; DX:AX = aprobados * 10000
    mov cl, [student_count]
    xor ch, ch
    div cx                      ; AX = porcentaje * 100
    call PrintValue100
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    ; Mostrar reprobados
    mov dx, offset msj_rep_lbl
    mov ah, 9
    int 21h
    mov al, rep_cnt
    call PrintByteDec
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h
    
    ; Calcular porcentaje reprobados
    xor ax, ax
    mov al, rep_cnt
    mov bx, 10000
    mul bx                      ; DX:AX = reprobados * 10000
    mov cl, [student_count]
    xor ch, ch
    div cx                      ; AX = porcentaje * 100
    call PrintValue100
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    call PrintCRLF

ms_salir:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MostrarEstadisticas ENDP

; ---------------------------------------------------------
; ExtractValue100 — AX := (última nota del slot) * 100
; Formatos válidos: "90", "70.0", "56.983" (trunca a 2 decimales)
; IN : SI -> inicio del slot de 64 bytes  ("... Nota$")
; OUT: AX = valor * 100  (WORD, 0..10000 esperado)
; ---------------------------------------------------------
ExtractValue100 PROC
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    ; 1) Buscar '$' dentro de los 64 bytes
    mov di, si
    mov cx, 64
EV_find_dollar:
    cmp BYTE PTR [di], '$'
    je  EV_dollar_found
    inc di
    loop EV_find_dollar
    xor ax, ax
    jmp EV_out                 ; slot vacio o corrupto

EV_dollar_found:
    ; 2) Retroceder espacios
    dec di
EV_skip_spaces:
    cmp di, si
    jb  EV_zero
    cmp BYTE PTR [di], ' '
    jne EV_have_tail
    dec di
    jmp EV_skip_spaces

EV_have_tail:
    ; 3) Hallar inicio del ultimo token (número)
    mov bp, di                 ; BP = fin inclusive
EV_find_start:
    cmp di, si
    je  EV_start_ok
    dec di
    cmp BYTE PTR [di], ' '
    jne EV_find_start
    inc di
EV_start_ok:
    ; DI = inicio del numero, BP = fin inclusive

    ; 4) Parsear izquierda?derecha con escala a *100
    ; AX = acumulador (base 10)
    ; BH = 0/1 vistoPunto, BL = decsContados (0..2 max contados)
    xor ax, ax
    xor bx, bx                 ; BH=0, BL=0
    ; CX y DX temporales; SI tambien temporal

EV_parse:
    cmp di, bp
    ja  EV_finalize
    mov dl, [di]

    ; si es punto
    cmp dl, '.'
    jne EV_check_digit
    mov bh, 1
    jmp EV_next

EV_check_digit:
    cmp dl, '0'
    jb  EV_next
    cmp dl, '9'
    ja  EV_next
    sub dl, '0'                ; DL = 0..9

    ; Si ya vimos punto y BL >= 2 -> ignorar digitos extra (truncar)
    cmp bh, 0
    je  EV_muladd
    cmp bl, 2
    jae EV_next

EV_muladd:
    ; AX = AX*10 + DL  (10x = 2x + 8x)
    mov cx, ax                 ; CX = old
    shl ax, 1                  ; 2x
    mov si, cx
    shl si, 3                  ; 8x
    add ax, si                 ; 10x
    mov dh, 0                  ; DX = 00..DL
    ; DL ya tiene el dígito
    add ax, dx                 ; +dígito

    ; contar decimales si ya hubo punto
    cmp bh, 0
    je  EV_next
    inc bl                     ; BL = decs contados (máx 2)

EV_next:
    inc di
    jmp EV_parse

EV_finalize:
    ; 5) Completar escala a *100:
    ;    - sin punto: BL=0,BH=0 -> ×100
    ;    - con 1 decimal: BL=1 -> ×10
    ;    - con >=2: nada
    cmp bh, 0
    jne EV_have_dot
    ; no hubo punto -> ×100
    mov si, ax
    shl ax, 1                  ; *2
    shl si, 3                  ; *8
    add ax, si                 ; *10
    ; de nuevo *10 (total *100)
    mov si, ax
    shl ax, 1
    shl si, 3
    add ax, si
    jmp EV_done

EV_have_dot:
    cmp bl, 1
    jne EV_done
    ; solo 1 decimal -> ×10
    mov si, ax
    shl ax, 1
    shl si, 3
    add ax, si

EV_done:
    jmp EV_out

EV_zero:
    xor ax, ax

EV_out:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
ExtractValue100 ENDP


; =========================================================
; PrintValue100 — imprime AX (valor*100) como ddd.dd
; =========================================================
PrintValue100 PROC
    push ax
    push bx
    push dx

    mov bx, 100
    xor dx, dx
    div bx                      ; AX=entero, DX=decimales

    ; Imprimir parte entera
    push dx
    call PrintWordDec
    
    ; Imprimir punto
    mov ah, 2
    mov dl, '.'
    int 21h
    
    ; Imprimir decimales con ceros a la izquierda
    pop dx
    mov al, dl
    xor ah, ah
    mov bl, 10
    div bl                      ; AL=decenas, AH=unidades
    
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    
    mov dl, ah
    add dl, '0'
    mov ah, 2
    int 21h

    pop dx
    pop bx
    pop ax
    ret
PrintValue100 ENDP

; =========================================================
; PrintWordDec — imprime AX en decimal
; =========================================================
PrintWordDec PROC
    push ax
    push bx
    push cx
    push dx

    cmp ax, 0
    jne pwd_no_cero
    mov ah, 2
    mov dl, '0'
    int 21h
    jmp pwd_fin

pwd_no_cero:
    mov cx, 0
    mov bx, 10

pwd_dividir:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne pwd_dividir

    mov ah, 2
pwd_imprimir:
    pop dx
    add dl, '0'
    int 21h
    loop pwd_imprimir

pwd_fin:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintWordDec ENDP