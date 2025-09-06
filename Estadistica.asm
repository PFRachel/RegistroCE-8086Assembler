; =========================================================
; Estadistica.asm 
; Calculos sobre records (15 slots x 64 bytes c/u)
; Estructura: "Nombre Apellido [Apellido2] Nota$" en cada slot de 64 bytes
; =========================================================

; =========================================================
; Procedimiento principal: MostrarEstadisticas
; =========================================================

ExtractValue100000 PROC
    push bx
    push cx
    push si
    push di
    push bp

    ; 1) Buscar '$' dentro de los 64 bytes
    mov di, si
    mov cx, 64
E5_find_dollar:
    cmp BYTE PTR [di], '$'
    je  E5_dollar_found
    inc di
    loop E5_find_dollar
    xor ax, ax
    xor dx, dx
    jmp E5_out

E5_dollar_found:
    ; 2) Retroceder espacios
    dec di
E5_skip_spaces:
    cmp di, si
    jb  E5_zero
    cmp BYTE PTR [di], ' '
    jne E5_have_tail
    dec di
    jmp E5_skip_spaces

E5_have_tail:
    ; 3) Hallar inicio del ultimo token
    mov bp, di                 ; BP = fin inclusive
E5_find_start:
    cmp di, si
    je  E5_start_ok
    dec di
    cmp BYTE PTR [di], ' '
    jne E5_find_start
    inc di
E5_start_ok:

    ; 4) Parsear con precisión de 32-bit
    xor ax, ax                 ; Parte baja del acumulador
    xor dx, dx                 ; Parte alta del acumulador
    xor bx, bx                 ; BH=vistoPunto, BL=decimalesContados

E5_parse:
    cmp di, bp
    ja  E5_finalize
    push dx                    ; Guardar parte alta
    mov dl, [di]

    ; si es punto
    cmp dl, '.'
    jne E5_check_digit
    mov bh, 1
    pop dx
    jmp E5_next

E5_check_digit:
    cmp dl, '0'
    jb  E5_invalid_digit
    cmp dl, '9'
    ja  E5_invalid_digit
    sub dl, '0'                ; DL = 0..9

    ; Contar decimales (máximo 5)
    cmp bh, 0
    je  E5_multiply
    cmp bl, 5
    jae E5_invalid_digit       ; Ignorar más de 5 decimales
    inc bl

E5_multiply:
    ; DX:AX = DX:AX * 10 + DL (aritmética de 32-bit)
    pop cx                     ; CX = parte alta anterior
    
    ; Multiplicar por 10 usando shifts y sumas
    ; DX:AX * 10 = DX:AX * 8 + DX:AX * 2
    
    ; Guardar valor original
    push ax                    ; Guardar AX original
    push cx                    ; Guardar DX original
    
    ; AX * 2
    shl ax, 1
    rcl cx, 1                  ; Propagar carry a parte alta
    
    ; Guardar resultado *2
    mov si, ax
    mov di, cx
    
    ; Recuperar original para *8
    pop cx
    pop ax
    
    ; AX * 8 (shift 3 veces)
    shl ax, 1
    rcl cx, 1
    shl ax, 1  
    rcl cx, 1
    shl ax, 1
    rcl cx, 1
    
    ; Sumar: (original*8) + (original*2) = original*10
    add ax, si
    adc cx, di
    
    ; Sumar el dígito
    xor dh, dh                 ; DH = 0, DL = dígito
    add ax, dx
    adc cx, 0
    
    mov dx, cx                 ; Restaurar DX
    jmp E5_next

E5_invalid_digit:
    pop dx
E5_next:
    inc di
    jmp E5_parse

E5_finalize:
    ; Escalar a *100000 según decimales encontrados
    mov cl, 5                  ; Necesitamos 5 posiciones decimales
    cmp bh, 0
    je  E5_scale_all           ; Sin punto = escalar todas las 5 posiciones
    
    sub cl, bl                 ; cl = posiciones a escalar
    
E5_scale_loop:
    test cl, cl
    jz   E5_done
    
    ; DX:AX = DX:AX * 10
    mov si, ax
    mov di, dx
    
    ; AX * 10 = AX * 8 + AX * 2
    shl ax, 1
    rcl dx, 1                  ; *2
    
    push ax
    push dx
    
    mov ax, si
    mov dx, di
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1  
    shl ax, 1
    rcl dx, 1                  ; *8
    
    pop di
    pop si
    add ax, si
    adc dx, di                 ; *10
    
    dec cl
    jmp E5_scale_loop

E5_scale_all:
    ; Multiplicar por 100000 = 10^5
    mov cl, 5
    jmp E5_scale_loop

E5_done:
    jmp E5_out

E5_zero:
    xor ax, ax
    xor dx, dx

E5_out:
    pop bp
    pop di
    pop si
    pop cx
    pop bx
    ret
ExtractValue100000 ENDP

; =========================================================
; PrintValue5Decimals - Imprime DX:AX (valor*100000) con 5 decimales
; =========================================================
PrintValue5Decimals PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Dividir DX:AX por 100000 para separar entero de decimales
    ; Como 100000 > 65535, usar división por etapas
    
    ; Primero dividir por 10000
    mov bx, 10000
    div bx                     ; AX = parte_entera, DX = resto
    
    ; Imprimir parte entera
    push dx                    ; Guardar resto para decimales
    call PrintWordDec
    
    ; Verificar si hay decimales
    pop ax                     ; AX = resto (0-99999)
    test ax, ax
    jz   P5D_no_decimals
    
    ; Imprimir punto
    mov ah, 2
    mov dl, '.'
    int 21h
    
    ; Imprimir exactamente 5 decimales
    call Print5DigitsFixed
    jmp P5D_done

P5D_no_decimals:
P5D_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintValue5Decimals ENDP

; =========================================================
; Print5DigitsFixed - Imprime AX (0-99999) como exactamente 5 dígitos
; =========================================================
Print5DigitsFixed PROC
    push ax
    push bx
    push cx
    push dx
    push si

    ; Construir los 5 dígitos en buffer
    mov si, offset buffer2
    add si, 4                  ; Empezar desde posición 4 (último dígito)
    mov cx, 5                  ; Exactamente 5 dígitos

P5F_build:
    mov bx, 10
    xor dx, dx
    div bx                     ; AX = AX/10, DX = último dígito
    add dl, '0'                ; Convertir a ASCII
    mov [si], dl               ; Guardar dígito
    dec si
    loop P5F_build

    ; Imprimir los 5 dígitos
    mov si, offset buffer2
    mov cx, 5

P5F_print:
    mov ah, 2
    mov dl, [si]
    int 21h
    inc si
    loop P5F_print

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
Print5DigitsFixed ENDP

; =========================================================
; VERSIÓN SIMPLIFICADA - ExtractValue mantiene compatibilidad 
; pero internamente procesa 5 decimales
; =========================================================
ExtractValue100_With5Dec PROC
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    ; Llamar al extractor de 5 decimales
    call ExtractValue100000
    
    ; Convertir DX:AX (valor*100000) a AX (valor*100)
    ; Dividir por 1000
    mov bx, 1000
    div bx                     ; AX = valor*100, DX = resto
    
    ; AX ahora contiene valor*100 compatible con tu sistema
    
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
ExtractValue100_With5Dec ENDP 

PrintValue100 PROC
    push ax
    push bx 
    push cx
    push dx

    mov bx, 100
    xor dx, dx
    div bx                      ; AX=entero, DX=decimales

    ; Imprimir parte entera
    push dx                     ; Guardar decimales
    call PrintWordDec
    
    ; Imprimir punto
    mov ah, 2
    mov dl, '.'
    int 21h
    
    ; Imprimir decimales con ceros a la izquierda
    pop ax                      ; AX = decimales (0-99)
    mov bl, 10  
    xor ah, ah
    div bl                      ; AL=decenas, AH=unidades 
   
    ; CORREGIDO: Imprimir AMBOS dígitos
    ; Primero las decenas
    mov dl, al                  ; AL = decenas
    add dl, '0'
    mov ah, 2
    int 21h 
    
    ; Después las unidades  
    mov dl, ah                  ; AH = unidades (de la división anterior)
    add dl, '0'
    mov ah, 2
    int 21h
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintValue100 ENDP

;--------------------------------------------------------------
MostrarEstadisticas PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Sincronizar conteo desde memoria
    call SyncCountFromRecords

    ; Titulo
    mov dx, offset msj_est_tit
    mov ah, 9
    int 21h

    ; --- Inicializar estado ---
    xor ax, ax
    mov apr_cnt, al
    mov rep_cnt, al
    mov max100, ax
    mov ax, 0FFFFh
    mov min100, ax

    ; --- Acumulador 32-bit local para PROMEDIO:  sum = DX:DI ---
    xor dx, dx              ; sum_hi = 0
    xor di, di              ; sum_lo = 0

    ; --- N local (slots ocupados) ---
    xor bx, bx              ; BX = N_local

    ; --- Escanear SIEMPRE todos los slots ---
    mov si, offset records
    mov cx, MAX_STUDENTS

ms_scan:
    cmp BYTE PTR [si], '$'  ; '$' => slot vacío
    je  ms_next

    inc bx                  ; N_local++

    ; AX := nota*100
    push si
    call ExtractValue100_With5Dec 
    pop  si

    ; sum += AX  (DX:DI += AX)
    add di, ax
    adc dx, 0

    ; Maximo
    cmp ax, max100
    jbe ms_chk_min
    mov max100, ax
ms_chk_min:
    ; Minimo
    cmp ax, min100
    jae ms_chk_apr
    mov min100, ax
ms_chk_apr:
    ; Aprobado si >= 70.00 (7000)
    cmp ax, 7000
    jb  ms_rep
    inc apr_cnt
    jmp ms_next
ms_rep:
    inc rep_cnt

ms_next:
    add si, SLOT_LEN
    loop ms_scan

    ; --- Sin datos ---
    cmp bx, 0              ; N_local == 0 ?
    jne ms_avg
    mov dx, offset msjnoreg
    mov ah, 9
    int 21h
    call PrintCRLF
    jmp ms_out

ms_avg:
    ; --- PROMEDIO = (DX:DI) / N_local  -> AX = promedio*100 ---
    mov ax, di             ; low word
    ; DX ya tiene la high word
    mov cx, bx             ; divisor = N_local
    div cx                 ; AX = promedio*100

    ; === Guarda AX antes de imprimir la etiqueta ===
    push ax
    mov dx, offset msj_prom_lbl
    mov ah, 9
    int 21h
    pop ax
    call PrintValue100
    call PrintCRLF

    ; Mostrar maximo
    mov dx, offset msj_max_lbl
    mov ah, 9
    int 21h
    mov ax, max100         ; recarga AX después de imprimir etiqueta
    call PrintValue100
    call PrintCRLF

    ; Mostrar minimo
    mov dx, offset msj_min_lbl
    mov ah, 9
    int 21h
    mov ax, min100         ; recarga AX después de imprimir etiqueta
    call PrintValue100
    call PrintCRLF
    ; --- Calculo de porcentajes ---
    ; Aprobados
    mov dx, offset msj_apr_lbl
    mov ah, 9
    int 21h
    mov al, apr_cnt
    call PrintByteDec
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h

    ; % aprob = apr_cnt * 100.00 / student_count
    xor ax, ax
    mov al, apr_cnt
    mov bx, 10000
    mul bx                      ; DX:AX = apr_cnt * 10000
    mov cl, [student_count]
    xor ch, ch
    div cx                      ; AX = porcentaje*100
    call PrintValue100
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    ; Reprobados
    mov dx, offset msj_rep_lbl
    mov ah, 9
    int 21h
    mov al, rep_cnt
    call PrintByteDec
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h

    ; % rep = rep_cnt * 100.00 / student_count
    xor ax, ax
    mov al, rep_cnt
    mov bx, 10000
    mul bx                      ; DX:AX = rep_cnt * 10000
    mov cl, [student_count]
    xor ch, ch
    div cx                      ; AX = porcentaje*100
    call PrintValue100
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    call PrintCRLF

ms_out:
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
lPrintValue100 PROC
    push ax
    push bx 
    push cx
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
    pop ax 
    mov bl, 10  
    xor ah, ah
    div bl                      ; AL=decenas, AH=unidades 
   
    ; Guardar ambos resultados
    mov cl, al                  ; CL = decenas
    mov ch, ah                  ; CH = unidades
    
     mov dl, ch
    add dl, '0'
    mov ah, 2
    int 21h 
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
lPrintValue100 ENDP

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