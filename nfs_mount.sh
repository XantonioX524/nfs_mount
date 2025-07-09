#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes con colores
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Función para verificar si el comando existe
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "El comando '$1' no está disponible. Por favor, instala el paquete nfs-utils o nfs-common."
        exit 1
    fi
}

# Función para verificar si el host está disponible
check_host() {
    local host=$1
    print_info "Verificando conectividad con $host..."
    
    if ping -c 1 -W 3 "$host" &> /dev/null; then
        print_success "Host $host es alcanzable"
        return 0
    else
        print_error "No se puede alcanzar el host $host"
        return 1
    fi
}

# Función para obtener recursos compartidos NFS
get_nfs_exports() {
    local host=$1
    local port=$2
    local exports_output
    local showmount_cmd="showmount -e $host"
    
    # Añadir puerto si se especifica
    if [ -n "$port" ]; then
        showmount_cmd="showmount -e $host --port=$port"
        print_info "Obteniendo recursos compartidos NFS de $host:$port..."
    else
        print_info "Obteniendo recursos compartidos NFS de $host..."
    fi
    
    if exports_output=$(eval "$showmount_cmd" 2>/dev/null); then
        echo "$exports_output"
        return 0
    else
        if [ -n "$port" ]; then
            print_error "No se pudieron obtener los recursos compartidos de $host:$port"
        else
            print_error "No se pudieron obtener los recursos compartidos de $host"
        fi
        print_error "Posibles causas:"
        print_error "  - El servicio NFS no está ejecutándose"
        print_error "  - El host no permite conexiones desde esta IP"
        print_error "  - Firewall bloqueando la conexión"
        if [ -n "$port" ]; then
            print_error "  - Puerto $port incorrecto o no disponible"
        fi
        return 1
    fi
}

# Función para parsear y mostrar las opciones de montaje
parse_exports() {
    local exports_output="$1"
    local -a export_paths=()
    
    # Extraer solo las rutas de exportación (primera columna)
    while IFS= read -r line; do
        if [[ "$line" =~ ^/.*[[:space:]] ]]; then
            export_path=$(echo "$line" | awk '{print $1}')
            export_paths+=("$export_path")
        fi
    done <<< "$exports_output"
    
    echo "${export_paths[@]}"
}

# Función para montar el recurso NFS
mount_nfs() {
    local host=$1
    local export_path=$2
    local port=$3
    local mount_point="/tmp/nfs_mount"
    local nfs_server="$host"
    
    # Construir la dirección del servidor con puerto si se especifica
    if [ -n "$port" ]; then
        nfs_server="$host"
        mount_options="nolock,port=$port"
        mount_options_v3="vers=3,nolock,port=$port"
    else
        mount_options="nolock"
        mount_options_v3="vers=3,nolock"
    fi
    
    # Crear directorio de montaje
    print_info "Creando directorio de montaje: $mount_point"
    mkdir -p "$mount_point"
    
    # Verificar si ya hay algo montado
    if mountpoint -q "$mount_point"; then
        print_warning "Ya hay algo montado en $mount_point"
        print_info "Desmontando..."
        sudo umount "$mount_point" 2>/dev/null
    fi
    
    if [ -n "$port" ]; then
        print_info "Intentando montar $host:$port:$export_path en $mount_point"
    else
        print_info "Intentando montar $host:$export_path en $mount_point"
    fi
    
    # Primer intento: montaje estándar
    print_info "Intento 1: Montaje NFS estándar"
    if sudo mount -t nfs "$nfs_server:$export_path" "$mount_point" -o "$mount_options" 2>/dev/null; then
        print_success "Montaje exitoso con configuración estándar"
        return 0
    else
        print_warning "Montaje estándar falló, intentando con NFSv3..."
    fi
    
    # Segundo intento: NFSv3 para compatibilidad
    print_info "Intento 2: Montaje NFS v3 para compatibilidad"
    if sudo mount -t nfs -o "$mount_options_v3" "$nfs_server:$export_path" "$mount_point" 2>/dev/null; then
        print_success "Montaje exitoso con NFSv3"
        return 0
    else
        print_error "Ambos intentos de montaje fallaron"
        return 1
    fi
}

# Función para mostrar información del montaje
show_mount_info() {
    local mount_point="/tmp/nfs_mount"
    
    print_success "Recurso NFS montado correctamente en: $mount_point"
    echo ""
    print_info "Información del montaje:"
    df -h "$mount_point" 2>/dev/null || echo "No se pudo obtener información de espacio"
    echo ""
    print_info "Contenido del directorio:"
    ls -la "$mount_point" 2>/dev/null || echo "No se pudo listar el contenido"
    echo ""
    print_warning "Para desmontar el recurso, ejecuta:"
    echo -e "    ${YELLOW}sudo umount $mount_point${NC}"
    echo ""
}

# Función principal
main() {
    local host=""
    local port=""
    local input=""
    
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    Script de Montaje NFS${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # Verificar dependencias
    check_command "showmount"
    check_command "mount"
    check_command "ping"
    
    # Obtener la IP del host y puerto opcional
    if [ $# -eq 0 ]; then
        read -p "Ingresa la IP del servidor NFS (formato: IP o IP:puerto): " input
    else
        input=$1
    fi
    
    # Validar que se proporcionó un host
    if [ -z "$input" ]; then
        print_error "Debes proporcionar la IP del servidor NFS"
        exit 1
    fi
    
    # Parsear IP y puerto
    if [[ "$input" == *":"* ]]; then
        host=$(echo "$input" | cut -d':' -f1)
        port=$(echo "$input" | cut -d':' -f2)
        
        # Validar que el puerto sea numérico
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            print_error "El puerto debe ser un número válido"
            exit 1
        fi
        
        print_info "Host: $host, Puerto: $port"
    else
        host="$input"
        print_info "Host: $host (puerto por defecto)"
    fi
    
    # Verificar conectividad
    if ! check_host "$host"; then
        exit 1
    fi
    
    # Obtener recursos compartidos
    local exports_output
    if ! exports_output=$(get_nfs_exports "$host" "$port"); then
        exit 1
    fi
    
    echo ""
    print_success "Recursos compartidos encontrados:"
    echo "$exports_output"
    echo ""
    
    # Parsear las rutas de exportación
    local export_paths=($(parse_exports "$exports_output"))
    
    if [ ${#export_paths[@]} -eq 0 ]; then
        print_error "No se encontraron rutas de exportación válidas"
        exit 1
    fi
    
    # Mostrar opciones y permitir selección
    echo "Selecciona el recurso que deseas montar:"
    echo ""
    for i in "${!export_paths[@]}"; do
        echo "  $((i+1))) ${export_paths[i]}"
    done
    echo ""
    
    # Leer selección del usuario
    local selection
    while true; do
        read -p "Ingresa el número de tu selección (1-${#export_paths[@]}): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#export_paths[@]} ]; then
            break
        else
            print_error "Selección inválida. Ingresa un número entre 1 y ${#export_paths[@]}"
        fi
    done
    
    # Obtener la ruta seleccionada
    local selected_path="${export_paths[$((selection-1))]}"
    print_info "Seleccionaste: $selected_path"
    echo ""
    
    # Montar el recurso
    if mount_nfs "$host" "$selected_path" "$port"; then
        show_mount_info
    else
        print_error "No se pudo montar el recurso NFS"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"