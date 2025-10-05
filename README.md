# 🖥️ SISOPS - Proyecto Final

## Grupo:

- Gabriel Escobar
- Vanessa Sanchez


## 📘 Descripción General

Este proyecto tiene como objetivo facilitar las labores del **administrador de un data center**, mediante la creación de dos herramientas de administración del sistema:

- 🧩 **admin_datacenter.ps1** → Script en **PowerShell** (para entornos Windows)
- 🐧 **admin_datacenter.sh** → Script en **Bash** (para entornos Linux/Unix)

Cada herramienta ofrece un **menú interactivo** que permite ejecutar tareas de monitoreo y mantenimiento del sistema de forma rápida, automatizada y amigable.

---

## 🚀 Funcionalidades

### 1️⃣ Usuarios del sistema
Muestra todos los usuarios creados en el sistema junto con la **fecha y hora de su último inicio de sesión (login)**.  
Ideal para auditorías y control de actividad.

---

### 2️⃣ Discos y filesystems
Despliega los **filesystems o discos conectados** a la máquina, incluyendo:
- Tamaño total (en bytes)
- Espacio libre disponible (en bytes)

Permite conocer rápidamente el estado del almacenamiento del sistema.

---

### 3️⃣ Archivos más grandes
Muestra los **10 archivos más grandes** almacenados en un disco o filesystem especificado por el usuario.  
La salida incluye:
- Nombre del archivo  
- Tamaño  
- Trayectoria completa (ruta absoluta)

Perfecto para detectar archivos pesados y optimizar espacio.

---

### 4️⃣ Memoria y swap
Muestra información en tiempo real sobre:
- **Cantidad de memoria libre**
- **Espacio de swap en uso**
  
Tanto en **bytes** como en **porcentaje**, para evaluar el rendimiento del sistema.

---

### 5️⃣ Copia de seguridad (Backup)
Permite realizar una **copia de seguridad** de un directorio especificado hacia una **unidad USB**.  
Además, genera un **catálogo (log)** con:
- Nombres de los archivos respaldados  
- Fecha de última modificación  

Una herramienta esencial para proteger la información crítica.

---

## ⚙️ Requisitos

### 🧩 PowerShell
- Windows PowerShell 5.1 o PowerShell Core 7+
- Permisos de ejecución habilitados (`Set-ExecutionPolicy RemoteSigned`)

### 🐧 Bash
- Bash 4.0+
- Utilidades estándar de GNU (`df`, `du`, `ls`, `free`, `awk`, `grep`, `rsync`, etc.)
- Permisos de ejecución (`chmod +x admin_datacenter.sh`)

---

## 💻 Ejecución

### En Windows (PowerShell)
```powershell
.\admin_datacenter.ps1
```

### En linux (bash)
```bash
./admin_datacenter.sh
```