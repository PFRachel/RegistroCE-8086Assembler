# RegistroCE  Tarea 1 de Paradigmas de Programación  (CE 1106)

## 🎯 Objetivos del Proyecto  

- Reafirmar el conocimiento del lenguaje **Ensamblador 8086**.  
- Diseñar e implementar un sistema interactivo en bajo nivel.  
- Utilizar instrucciones de entrada y salida (INT 21h).  
- Usar operaciones matemáticas básicas, ciclos y comparaciones.  
- Implementar un algoritmo de ordenamiento (Burbuja o Selección).  

---

## 🖥️ Funcionalidades  

El sistema presenta un **menú principal interactivo** con las siguientes opciones:  

1. **Ingresar calificaciones**  
   - Hasta 15 estudiantes (Nombre, Apellido1, Apellido2, Nota).  
   - Validación de notas (0–100, hasta 5 decimales).  

2. **Mostrar estadísticas**  
   - Promedio general.  
   - Nota máxima y mínima.  
   - Cantidad y porcentaje de aprobados (≥70).  
   - Cantidad y porcentaje de reprobados (<70).  

3. **Buscar estudiante por índice**  
   - Permite consultar un estudiante ingresando su posición en la lista.  

4. **Ordenar calificaciones**  
   - Ascendente o descendente.  
   - Ordenamiento implementado con **Burbuja** o **Selección**.  

5. **Salir**  
   - Finaliza el programa mostrando el mensaje:  
     ```
     ===============================================
     Gracias por usar Registro CE
     ===============================================
     ```

---

## ⚙️ Requisitos Técnicos  

- Lenguaje: **Ensamblador 8086**.  
- Compilador recomendado: **MASM** o **TASM** en DOSBox.  
- Uso de subrutinas con `CALL` y `RET`.  
- Uso de ciclos (`LOOP`), comparaciones (`CMP`, `Jxx`).  
- Manejo de entrada/salida con **INT 21h** y control de pantalla con **INT 10h**.  

---