#!/bin/bash

# ============================================
# Herramienta de Administración Data Center
# Bash Version
# ============================================

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para mostrar el menú
show_menu() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  HERRAMIENTA DE ADMINISTRACIÓN DATA CENTER${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "1. Usuarios y último ingreso"
    echo "2. Filesystems y espacio disponible"
    echo "3. Top 10 archivos más grandes"
    echo "4. Memoria y Swap"
    echo "5. Backup de directorio a USB"
    echo "6. Salir"
    echo ""
}

# Función 1: Usuarios y último ingreso
show_users() {
    echo -e "\n${GREEN}========== USUARIOS Y ÚLTIMO INGRESO ==========${NC}\n"
    
    # Obtener usuarios del sistema con shell válido
    while IFS=: read -r username _ uid _ _ home shell; do
        # Filtrar usuarios del sistema (UID >= 1000 o UID = 0)
        if [ "$uid" -ge 1000 ] || [ "$uid" -eq 0 ]; then
            echo -e "${YELLOW}Usuario: $username${NC}"
            
            # Obtener último login desde lastlog
            last_login=$(lastlog -u "$username" 2>/dev/null | tail -n 1 | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')
            
            if [ -z "$last_login" ] || echo "$last_login" | grep -q "Never logged in"; then
                echo "  Último ingreso: Nunca"
            else
                echo "  Último ingreso: $last_login"
            fi
            echo ""
        fi
    done < /etc/passwd
    
    echo -e "\nPresione Enter para continuar..."
    read
}

# Función 2: Filesystems y discos
show_filesystems() {
    echo -e "\n${GREEN}========== FILESYSTEMS Y DISCOS ==========${NC}\n"
    
    # Usar df para obtener información de filesystems
    df -B1 | tail -n +2 | while read filesystem blocks used available percent mounted; do
        # Calcular tamaño total en bytes
        total_bytes=$blocks
        free_bytes=$available
        
        # Convertir a GB para mostrar
        total_gb=$(echo "scale=2; $total_bytes / 1073741824" | bc)
        free_gb=$(echo "scale=2; $free_bytes / 1073741824" | bc)
        
        echo -e "${YELLOW}Filesystem: $filesystem${NC}"
        echo "  Montado en: $mounted"
        echo "  Tamaño total: $total_bytes bytes ($total_gb GB)"
        echo "  Espacio libre: $free_bytes bytes ($free_gb GB)"
        echo ""
    done
    
    echo -e "\nPresione Enter para continuar..."
    read
}

# Función 3: Top 10 archivos más grandes 
show_largest_files() {
    echo -e "\n${GREEN}========== TOP 10 ARCHIVOS MÁS GRANDES ==========${NC}\n"
    
    read -p "Ingrese la ruta del filesystem a analizar (ej: /home): " path
    
    if [ ! -d "$path" ]; then
        echo -e "${RED}El directorio especificado no existe.${NC}"
        echo -e "\nPresione Enter para continuar..."
        read
        return
    fi
    
    echo -e "\n${YELLOW}Buscando archivos más grandes en $path...${NC}"
    echo "Esto puede tomar algunos minutos..."
    echo ""

    # Rutas a ignorar
    EXCLUDES=(
        "/proc"
        "/sys"
        "/run"
        "/dev"
        "/tmp"
        "/var/lib/snapd"
        "/snap"
    )

    exclude_args=()
    for ex in "${EXCLUDES[@]}"; do
        exclude_args+=(-path "$ex" -prune -o)
    done

    # Buscar los 10 archivos más grandes (ignorando las rutas anteriores)
    counter=1
    find "$path" "${exclude_args[@]}" -type f -printf '%s %p\n' 2>/dev/null \
        | sort -nr | head -10 | while read -r line; do
        
        size=$(echo "$line" | awk '{print $1}')
        filepath=$(echo "$line" | cut -d' ' -f2-)

        # Calcular tamaño legible
        if (( size >= 1073741824 )); then
            size_h=$(echo "scale=2; $size / 1073741824" | bc)
            unit="GB"
        elif (( size >= 1048576 )); then
            size_h=$(echo "scale=2; $size / 1048576" | bc)
            unit="MB"
        elif (( size >= 1024 )); then
            size_h=$(echo "scale=2; $size / 1024" | bc)
            unit="KB"
        else
            size_h=$size
            unit="bytes"
        fi

	echo -e "${YELLOW}$counter.${NC} ${YELLOW}Archivo: $filepath${NC}"
        echo "   Tamaño: $size bytes (${size_h} ${unit})"
        echo ""
        counter=$((counter + 1))
    done
    
    echo -e "\nPresione Enter para continuar..."
    read
}


# Función 4: Memoria y Swap
show_memory() {
    echo -e "\n${GREEN}========== MEMORIA Y SWAP ==========${NC}\n"

    export LC_NUMERIC=C  # Evita comas decimales

    # Leer datos de /proc/meminfo (en KB)
    total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail_mem_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    used_mem_kb=$(awk -v t="$total_mem_kb" -v a="$avail_mem_kb" 'BEGIN {print t - a}')

    # Calcular porcentaje y convertir a GB
    mem_percent=$(awk -v u="$used_mem_kb" -v t="$total_mem_kb" 'BEGIN {printf "%.2f", (u*100)/t}')
    total_mem_gb=$(awk -v t="$total_mem_kb" 'BEGIN {printf "%.2f", t/1048576}')
    used_mem_gb=$(awk -v u="$used_mem_kb" 'BEGIN {printf "%.2f", u/1048576}')
    free_mem_gb=$(awk -v a="$avail_mem_kb" 'BEGIN {printf "%.2f", a/1048576}')

    echo -e "${YELLOW}MEMORIA RAM:${NC}"
    echo "  Total: ${total_mem_gb} GB"
    echo "  Libre: ${free_mem_gb} GB"
    echo "  En uso: ${used_mem_gb} GB (${mem_percent}%)"
    echo ""

    # Leer datos de swap (en KB)
    total_swap_kb=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    free_swap_kb=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
    used_swap_kb=$(awk -v t="$total_swap_kb" -v f="$free_swap_kb" 'BEGIN {print t - f}')

    if [ "$total_swap_kb" -gt 0 ]; then
        swap_percent=$(awk -v u="$used_swap_kb" -v t="$total_swap_kb" 'BEGIN {printf "%.2f", (u*100)/t}')
        total_swap_gb=$(awk -v t="$total_swap_kb" 'BEGIN {printf "%.2f", t/1048576}')
        used_swap_gb=$(awk -v u="$used_swap_kb" 'BEGIN {printf "%.2f", u/1048576}')

        echo -e "${YELLOW}SWAP:${NC}"
        echo "  Total: ${total_swap_gb} GB"
        echo "  En uso: ${used_swap_gb} GB (${swap_percent}%)"
    else
        echo -e "${YELLOW}No se detectó espacio de Swap configurado.${NC}"
    fi

    echo -e "\nPresione Enter para continuar..."
    read
}

# Función 5: Backup a USB
do_backup() {
    echo -e "\n${GREEN}========== BACKUP A USB ==========${NC}\n"
    
    read -p "Ingrese la ruta completa del directorio a respaldar: " source_dir
    
    if [ ! -d "$source_dir" ]; then
        echo -e "${RED}El directorio especificado no existe.${NC}"
        echo -e "\nPresione Enter para continuar..."
        read
        return
    fi
    
    # Mostrar dispositivos USB disponibles
    echo -e "\n${YELLOW}Dispositivos removibles disponibles:${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "sd[b-z]|usb" | grep -v "├─\|└─" || {
        echo "No se detectaron dispositivos USB montados."
        echo ""
    }
    
    # Mostrar puntos de montaje
    echo -e "\n${YELLOW}Puntos de montaje disponibles:${NC}"
    mount | grep -E "/media|/mnt" | awk '{print "  - " $3}'
    echo ""
    
    read -p "Ingrese la ruta de montaje del USB (ej: /media/usb): " usb_path
    
    if [ ! -d "$usb_path" ]; then
        echo -e "${RED}La ruta especificada no existe o no está montada.${NC}"
        echo -e "\nPresione Enter para continuar..."
        read
        return
    fi
    
    # Crear directorio de backup con timestamp
    backup_dir="$usb_path/Backup_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "\n${YELLOW}Creando backup en $backup_dir...${NC}"
    
    # Crear directorio de destino
    mkdir -p "$backup_dir"
    
    # Copiar archivos
    cp -r "$source_dir"/* "$backup_dir/" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Archivos copiados exitosamente.${NC}"
    else
        echo -e "${RED}Hubo algunos errores al copiar archivos.${NC}"
    fi
    
    # Crear catálogo
    catalog_file="$backup_dir/catalogo.txt"
    
    echo "CATÁLOGO DE BACKUP" > "$catalog_file"
    echo "Fecha de backup: $(date '+%Y-%m-%d %H:%M:%S')" >> "$catalog_file"
    echo "Directorio origen: $source_dir" >> "$catalog_file"
    echo "================================================================================" >> "$catalog_file"
    echo "" >> "$catalog_file"
    
    # Generar lista de archivos con fechas de modificación
    find "$source_dir" -type f | while read -r file; do
        relative_path="${file#$source_dir}"
        mod_date=$(stat -c "%y" "$file" 2>/dev/null || stat -f "%Sm" "$file" 2>/dev/null)
        file_size=$(stat -c "%s" "$file" 2>/dev/null || stat -f "%z" "$file" 2>/dev/null)
        
        echo "Archivo: $relative_path" >> "$catalog_file"
        echo "  Última modificación: $mod_date" >> "$catalog_file"
        echo "  Tamaño: $file_size bytes" >> "$catalog_file"
        echo "" >> "$catalog_file"
    done
    
    echo -e "\n${GREEN}¡Backup completado exitosamente!${NC}"
    echo "Ubicación: $backup_dir"
    echo "Catálogo generado: $catalog_file"
    
    echo -e "\nPresione Enter para continuar..."
    read
}

# ============================================
# PROGRAMA PRINCIPAL
# ============================================

while true; do
    show_menu
    read -p "Seleccione una opción (1-6): " option
    
    case $option in
        1) show_users ;;
        2) show_filesystems ;;
        3) show_largest_files ;;
        4) show_memory ;;
        5) do_backup ;;
        6)
            echo -e "\n${CYAN}Saliendo del programa...${NC}"
            sleep 1
            exit 0
            ;;
        *)
            echo -e "\n${RED}Opción inválida.${NC}"
            sleep 2
            ;;
    esac
done