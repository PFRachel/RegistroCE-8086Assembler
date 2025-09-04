; =========================================================
; Estadistica.asm
; =========================================================

MostrarEstadisticas PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    ; Recuenta registros
    call SyncCountFromRecords

    ; Verificar si hay registros
    cmp student_count, 0
    jne ms_hay_datos
    mov dx, offset msjnoreg
    mov ah, 9
    int 21h
    jmp ms_out

ms_hay_datos:
    ; Titulo
    mov dx, offset msj_est_tit
    mov ah, 9
    int 21h

    ; Inicializar contadores
    mov apr_cnt, 0
    mov rep_cnt, 0

    ; Inicializar suma
    mov sum_entera, 0
    mov WORD PTR sum_decimal, 0

    ; Inicializar max (empezar en 0)
    mov max_entera, 0
    mov WORD PTR max_decimal, 0

    ; Inicializar min (empezar en maximo)
    mov min_entera, 999
    mov WORD PTR min_decimal, 65535

    ; Escanear registros
    mov si, offset records
    mov cx, MAX_STUDENTS
    xor bp, bp              ; contador de registros validos

ms_scan_loop:
    cmp BYTE PTR [si], '$'
    je  ms_next_slot

    ; Extraer valor del registro actual
    push cx
    push si
    call ExtractValue_Fixed
    pop si
    pop cx

    inc bp                  ; incrementar contador de registros válidos

    ; Acumular para promedio
    mov ax, [sum_entera]
    add ax, bx
    mov [sum_entera], ax

    mov ax, WORD PTR [sum_decimal]
    add ax, dx
    mov WORD PTR [sum_decimal], ax

    ; Actualizar maximo
    call UpdateMax

    ; Actualizar minimo  
    call UpdateMin

    ; Contar aprobados/reprobados (>= 70.0)
    cmp bx, 70
    jb  ms_reprobado
    ja  ms_aprobado
    ; Si es exactamente 70, cualquier decimal >= 0 es aprobado
    jmp ms_aprobado

ms_reprobado:
    inc rep_cnt
    jmp ms_next_slot

ms_aprobado:
    inc apr_cnt

ms_next_slot:
    add si, SLOT_LEN
    loop ms_scan_loop

    ; Mostrar resultados
    call MostrarResultados

ms_out:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
MostrarEstadisticas ENDP

; Actualizar valor maximo
UpdateMax PROC
    push ax
    
    ; Comparar parte entera
    mov ax, [max_entera]
    cmp bx, ax
    ja  um_new_max
    jb  um_exit
    
    ; Partes enteras iguales, comparar decimales
    mov ax, WORD PTR [max_decimal]
    cmp dx, ax
    jbe um_exit

um_new_max:
    mov [max_entera], bx
    mov WORD PTR [max_decimal], dx

um_exit:
    pop ax
    ret
UpdateMax ENDP

; Actualizar valor minimo
UpdateMin PROC
    push ax
    
    ; Comparar parte entera
    mov ax, [min_entera]
    cmp bx, ax
    jb  um2_new_min
    ja  um2_exit
    
    ; Partes enteras iguales, comparar decimales
    mov ax, WORD PTR [min_decimal]
    cmp dx, ax
    jae um2_exit

um2_new_min:
    mov [min_entera], bx
    mov WORD PTR [min_decimal], dx

um2_exit:
    pop ax
    ret
UpdateMin ENDP

; Mostrar todos los resultados calculados
MostrarResultados PROC
    push ax
    push bx
    push dx

    ; Calcular y mostrar promedio
    mov dx, offset msj_prom_lbl
    mov ah, 9
    int 21h
    
    ; Promedio entero
    mov ax, [sum_entera]
    xor dx, dx
    mov cx, bp
    div cx
    mov bx, ax              ; parte entera del promedio

    ; Promedio decimal
    mov ax, WORD PTR [sum_decimal]
    xor dx, dx
    mov cx, bp
    div cx                  ; AX = promedio decimal
    mov dx, ax
    
    call PrintValue_Simple
    call PrintCRLF

    ; Mostrar maximo
    mov dx, offset msj_max_lbl
    mov ah, 9
    int 21h
    mov bx, [max_entera]
    mov dx, WORD PTR [max_decimal]
    call PrintValue_Simple
    call PrintCRLF

    ; Mostrar minimo
    mov dx, offset msj_min_lbl
    mov ah, 9
    int 21h
    mov bx, [min_entera]
    mov dx, WORD PTR [min_decimal]
    call PrintValue_Simple
    call PrintCRLF

    ; Mostrar aprobados
    mov dx, offset msj_apr_lbl
    mov ah, 9
    int 21h
    mov al, apr_cnt
    call PrintByteDec
    
    ; Calcular porcentaje aprobados
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h
    xor ax, ax
    mov al, apr_cnt
    mov bx, 100
    mul bx              ; AX = aprobados * 100
    mov cx, bp
    div cx              ; AX = porcentaje
    call PrintWordDec
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    ; Mostrar reprobados
    mov dx, offset msj_rep_lbl
    mov ah, 9
    int 21h
    mov al, rep_cnt
    call PrintByteDec
    
    ; Calcular porcentaje reprobados
    mov dx, offset msj_spc_pct
    mov ah, 9
    int 21h
    xor ax, ax
    mov al, rep_cnt
    mov bx, 100
    mul bx              ; AX = reprobados * 100
    mov cx, bp
    div cx              ; AX = porcentaje
    call PrintWordDec
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    call PrintCRLF

    pop dx
    pop bx
    pop ax
    ret
MostrarResultados ENDP

; Extractor de valor corregido
ExtractValue_Fixed PROC
    push cx
    push si
    push di

    ; Buscar el ultimo espacio en el registro
    mov di, si
    add di, SLOT_LEN
    dec di                  ; DI apunta al final del slot

ev_find_last_space:
    cmp di, si
    je  ev_no_space_found
    cmp BYTE PTR [di], ' '
    je  ev_space_found
    cmp BYTE PTR [di], '$'
    je  ev_continue_search
    dec di
    jmp ev_find_last_space

ev_continue_search:
    dec di
    jmp ev_find_last_space

ev_space_found:
    inc di                  ; DI apunta al inicio de la nota
    jmp ev_start_parse

ev_no_space_found:
    mov di, si              ; usar inicio si no hay espacio

ev_start_parse:
    ; Parsear parte entera
    xor bx, bx              ; BX = parte entera

ev_parse_integer:
    mov al, [di]
    cmp al, '.'
    je  ev_found_dot
    cmp al, '$'
    je  ev_parse_done
    cmp al, ' '
    je  ev_parse_done
    cmp al, 0
    je  ev_parse_done
    cmp al, '0'
    jb  ev_parse_done
    cmp al, '9'
    ja  ev_parse_done
    
    ; BX = BX * 10 + digit
    sub al, '0'
    mov ah, 0
    push ax
    mov ax, bx
    mov cx, 10
    mul cx
    mov bx, ax
    pop ax
    add bx, ax
    
    inc di
    jmp ev_parse_integer

ev_found_dot:
    inc di                  ; saltar el punto
    xor dx, dx              ; DX = parte decimal
    mov cx, 5               ; maximo 5 digitos

ev_parse_decimal:
    cmp cx, 0
    je  ev_parse_done
    mov al, [di]
    cmp al, '$'
    je  ev_fill_zeros
    cmp al, ' '
    je  ev_fill_zeros
    cmp al, 0
    je  ev_fill_zeros
    cmp al, '0'
    jb  ev_fill_zeros
    cmp al, '9'
    ja  ev_fill_zeros
    
    ; DX = DX * 10 + digit
    sub al, '0'
    mov ah, 0
    push ax
    push cx
    mov ax, dx
    mov cx, 10
    mul cx
    mov dx, ax
    pop cx
    pop ax
    add dx, ax
    
    inc di
    dec cx
    jmp ev_parse_decimal

ev_fill_zeros:
    ; Completar con ceros los digitos faltantes
ev_zero_loop:
    cmp cx, 0
    je  ev_parse_done
    mov ax, dx
    mov dx, 10
    push cx
    mul dx
    mov dx, ax
    pop cx
    dec cx
    jmp ev_zero_loop

ev_parse_done:
    pop di
    pop si
    pop cx
    ret
ExtractValue_Fixed ENDP

; Imprimir valor con formato XXX.DDDDD
PrintValue_Simple PROC
    push ax
    push cx
    push dx
    
    ; Imprimir parte entera (BX) usando funcion existente
    mov ax, bx
    call PrintWordDec
    
    ; Imprimir punto decimal
    mov ah, 2
    mov dl, '.'
    int 21h
    
    ; Imprimir exactamente 5 digitos decimales (DX)
    mov ax, dx              ; parte decimal (0-99999)
    
    ; Asegurar que tenemos exactamente 5 digitos
    ; Digito 1 (10000s)
    mov bx, 10000
    xor dx, dx
    div bx
    push dx                 ; guardar resto
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax                  ; recuperar resto
    
    ; Digito 2 (1000s)
    mov bx, 1000
    xor dx, dx
    div bx
    push dx
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    
    ; Digito 3 (100s)
    mov bx, 100
    xor dx, dx
    div bx
    push dx
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    
    ; Digito 4 (10s)
    mov bl, 10
    xor ah, ah
    div bl
    push ax                 ; AH = unidades, AL = decenas
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    
    ; Digito 5 (1s)
    mov dl, ah
    add dl, '0'
    mov ah, 2
    int 21h
    
    pop dx
    pop cx
    pop ax
    ret
PrintValue_Simple ENDP 

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
    xor cx, cx
    mov bx, 10
pwd_dividir:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz pwd_dividir
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