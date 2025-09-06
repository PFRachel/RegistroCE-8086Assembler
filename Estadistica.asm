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

    ; Reconstruye conteo real e indices ocupados
    call RebuildIndexFromRecords

    ; Hay registros?
    cmp student_count, 0
    jne ms_hay_datos
    mov dx, offset msjnoreg
    mov ah, 9
    int 21h
    jmp ms_out

ms_hay_datos:
    mov dx, offset msj_est_tit
    mov ah, 9
    int 21h

    ; Ordenar ASC 
    mov op, 1
    call Burbuja

    ; ---------- Inicializaciones ----------
    mov apr_cnt, 0
    mov rep_cnt, 0
    mov sum_entera, 0
    mov WORD PTR sum_decimal, 0

    ; Min/Max
    mov min_entera, 999
    mov WORD PTR min_decimal, 65535
    mov max_entera, 0
    mov WORD PTR max_decimal, 0
    mov word ptr min_slot, 0FFFFh
    mov word ptr max_slot, 0FFFFh

    ; ---------- Escaneo de TODOS los slots ----------
    mov si, offset records
    mov cx, MAX_STUDENTS
    xor bp, bp              ; contador de registros validos 

ms_scan_loop:
    cmp BYTE PTR [si], '$'
    je  ms_next_slot

    ; Extraer valor normalizado (BX=entera, DX=decimal 0..99999)
    push cx
    push si
    call ExtractValue_Fixed
    pop  si
    pop  cx

    ; Acumular para promedio
    mov ax, [sum_entera]
    add ax, bx
    mov [sum_entera], ax

    mov ax, WORD PTR [sum_decimal]
    add ax, dx
    mov WORD PTR [sum_decimal], ax

    inc bp

    ; Contar aprobado/reprobado (>= 70.00000)
    cmp bx, 70
    jb  ms_reprobado
    inc apr_cnt
    jmp ms_check_minmax

ms_reprobado:
    inc rep_cnt

; ---------- Min/Max por comparación (bx,dx) ----------
ms_check_minmax:
    ; MAX
    mov ax, [max_entera]
    cmp bx, ax
    ja  upd_max
    jb  skip_max
    mov ax, WORD PTR [max_decimal]
    cmp dx, ax
    jbe skip_max
upd_max:
    mov [max_entera], bx
    mov WORD PTR [max_decimal], dx
    ; slot actual = (SI - records) / 64  (shift 6)
    push ax
    push dx
    mov ax, si
    sub ax, offset records
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    mov [max_slot], ax
    pop dx
    pop ax
skip_max:

    ; MIN
    mov ax, [min_entera]
    cmp bx, ax
    jb  upd_min
    ja  skip_min
    mov ax, WORD PTR [min_decimal]
    cmp dx, ax
    jae skip_min
upd_min:
    mov [min_entera], bx
    mov WORD PTR [min_decimal], dx
    push ax
    push dx
    mov ax, si
    sub ax, offset records
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    shr ax, 1
    mov [min_slot], ax
    pop dx
    pop ax
skip_min:

ms_next_slot:
    add si, SLOT_LEN
    loop ms_scan_loop

    ; Guardar el total valido en memoria para no depender de BP
    mov [valid_cnt], bp

    ; ---------- Mostrar resultados ----------
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


; ---------------------------------------------------------
; Reconstruir lista index_estudiante (slots ocupados base-0)
; y fijar student_count con la cantidad REAL de registros.
; ---------------------------------------------------------
RebuildIndexFromRecords PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, offset records
    xor bx, bx                 ; BX = slot (0..14)
    xor di, di                 ; DI = posición en index_estudiante
    mov cx, MAX_STUDENTS

rb_scan:
    cmp BYTE PTR [si], '$'
    je  rb_next
    mov al, bl
    mov [index_estudiante + di], al
    inc di
rb_next:
    add si, SLOT_LEN
    inc bl
    loop rb_scan

    mov ax, di
    mov student_count, al

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
RebuildIndexFromRecords ENDP


; ---------------------------------------------------------
; Mostrar resultados
; - Usa valid_cnt para promedio/porcentajes (no depende de BP)
; - Max/Min: imprime la nota textual desde el slot ganador.
; ---------------------------------------------------------
MostrarResultados PROC
    push ax
    push bx
    push cx
    push dx

    ; Calcular y mostrar promedio
    mov dx, offset msj_prom_lbl
    mov ah, 9
    int 21h
    
    ; Promedio entera
    mov ax, [sum_entera]
    xor dx, dx
    mov cx, [valid_cnt]
    div cx
    mov bx, ax

    ; Parte decimal
    mov ax, WORD PTR [sum_decimal]
    xor dx, dx
    mov cx, [valid_cnt]
    div cx
    mov dx, ax

    call PrintValue_Simple
    call PrintCRLF

    ; Mostrar maximo 
    mov dx, offset msj_max_lbl
    mov ah, 9
    int 21h
    mov bx, [max_slot]
    call PrintNotaFromSlot     ; preserva BP
    call PrintCRLF

    ; Mostrar minimo
    mov dx, offset msj_min_lbl
    mov ah, 9
    int 21h
    mov bx, [min_slot]
    call PrintNotaFromSlot     ; preserva BP
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
    mul bx
    mov cx, [valid_cnt]
    div cx
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
    mul bx
    mov cx, [valid_cnt]
    div cx
    call PrintWordDec
    mov dx, offset msj_pct_close
    mov ah, 9
    int 21h

    call PrintCRLF

    pop dx
    pop cx
    pop bx
    pop ax
    ret
MostrarResultados ENDP


; ---------------------------------------------------------
; PrintNotaFromSlot
;  Entrada: BX = slot base-0 (0..14)
;  Efecto : imprime la nota (último token) con EXACTAMENTE 5 decimales.
;  IMPORTANTE: preserva BP para no romper cálculos posteriores.
; ---------------------------------------------------------
PrintNotaFromSlot PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp                   ; preservar BP

    ; SI = base del slot = records + BX*64
    mov si, offset records
    mov ax, bx
    shl ax, 6
    add si, ax

    ; Buscar el ultimo espacio en el registro
    mov di, si
    mov cx, SLOT_LEN
    mov bp, si
pns_find_last_space:
    mov al, [di]
    cmp al, '$'
    je  pns_stop
    cmp al, ' '
    jne pns_cont
    mov bp, di
pns_cont:
    inc di
    loop pns_find_last_space
pns_stop:
    mov di, bp
    inc di          ; inicio del token de nota

    ; Imprimir normalizando a 5 decimales
    xor bh, bh      ; dot_seen
    xor bl, bl      ; dec_count

pns_loop:
    mov al, [di]
    cmp al, ' '
    je  pns_end
    cmp al, '$'
    je  pns_end
    cmp al, 0
    je  pns_end

    cmp al, '.'
    jne pns_notdot
    mov bh, 1
    mov bl, 0
    mov ah, 2
    mov dl, al
    int 21h
    inc di
    jmp pns_loop

pns_notdot:
    cmp bh, 1
    jne pns_print
    cmp bl, 5
    jae pns_skip
    inc bl
pns_print:
    mov ah, 2
    mov dl, al
    int 21h
    inc di
    jmp pns_loop

pns_skip:
    inc di
    jmp pns_loop

pns_end:
    cmp bh, 1
    je  pns_have_dot
    mov ah, 2
    mov dl, '.'
    int 21h
    mov bl, 0
pns_have_dot:
    cmp bl, 5
    jae pns_done
pns_pad:
    mov ah, 2
    mov dl, '0'
    int 21h
    inc bl
    cmp bl, 5
    jb  pns_pad
pns_done:
    pop bp                   ; restaurar BP
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
PrintNotaFromSlot ENDP


; ================= Utilidades existentes =================

; Extrae valor numurico (BX=entera, DX=decimal 0..99999) desde SI
ExtractValue_Fixed PROC
    push cx
    push si
    push di
    mov di, si
    add di, SLOT_LEN
    dec di
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
    inc di   ; DI apunta al inicio de la nota
    jmp ev_start_parse
ev_no_space_found:
    mov di, si
ev_start_parse:
    xor bx, bx
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
    inc di
    xor dx, dx
    mov cx, 5
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

; Imprimir valor con formato XXX.DDDDD (BX=entera, DX=decimal)
PrintValue_Simple PROC
    push ax
    push cx
    push dx
    mov ax, bx
    call PrintWordDec
    mov ah, 2
    mov dl, '.'
    int 21h
    mov ax, dx
    mov bx, 10000
    xor dx, dx
    div bx
    push dx
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    mov bx, 1000
    xor dx, dx
    div bx
    push dx
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    mov bx, 100
    xor dx, dx
    div bx
    push dx
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    mov bl, 10
    xor ah, ah
    div bl
    push ax
    mov dl, al
    add dl, '0'
    mov ah, 2
    int 21h
    pop ax
    mov dl, ah
    add dl, '0'
    mov ah, 2
    int 21h
    pop dx
    pop cx
    pop ax
    ret
PrintValue_Simple ENDP 

; Imprimir AX en decimal (sin ceros a la izquierda)
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

; -------- variables internas --------
min_slot  dw 0FFFFh
max_slot  dw 0FFFFh
valid_cnt dw 0
