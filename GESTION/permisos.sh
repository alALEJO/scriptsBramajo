#!/bin/bash
# =============================================================================
#  permisos.sh - Gestion de permisos de archivos y carpetas
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
#
# =============================================================================
#  COMO FUNCIONAN LOS PERMISOS EN LINUX
# =============================================================================
#
#  Cada archivo tiene permisos para TRES tipos de persona:
#
#      dueno  |  grupo  |  otros
#
#  Y para cada uno se define si puede:
#
#      r = leer      (read)     vale 4
#      w = escribir  (write)    vale 2
#      x = ejecutar  (execute)  vale 1
#
#  Los numeros se SUMAN para armar un digito:
#
#      7 = 4+2+1 = leer, escribir y ejecutar
#      6 = 4+2   = leer y escribir
#      5 = 4+1   = leer y ejecutar
#      4 = 4     = solo leer
#      0 =         nada
#
#  Y se ponen tres digitos, uno por cada tipo de persona:
#
#      chmod 750 script.sh
#            |||
#            ||+-- otros:  0 = nada
#            |+--- grupo:  5 = leer y ejecutar
#            +---- dueno:  7 = todo
#
#  Ejemplos que usamos en el proyecto:
#      600  archivo de contrasenas   -> solo el dueno lee y escribe
#      700  carpeta de respaldos     -> solo el dueno entra
#      750  script                   -> el dueno todo, el grupo lo ejecuta
#      644  archivo comun            -> el dueno escribe, los demas leen
#
#  777 es PELIGROSO: cualquiera puede modificar y ejecutar el archivo.
# =============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"


# -----------------------------------------------------------------------------
# CARPETAS QUE NO SE TOCAN
# -----------------------------------------------------------------------------
# Cambiar los permisos de estas carpetas rompe el sistema operativo entero.
# Un 'chmod -R 777 /etc' deja el servidor inutilizable y sin arreglo simple.
# -----------------------------------------------------------------------------
RUTAS_PROTEGIDAS=("/" "/etc" "/bin" "/sbin" "/usr" "/var" "/boot" "/lib" "/lib64" "/root")


# -----------------------------------------------------------------------------
# es_ruta_protegida <ruta>
# -----------------------------------------------------------------------------
es_ruta_protegida() {
    local ruta protegida

    # 'realpath' convierte cosas como "/etc/../etc" o "." en la ruta real.
    # Sin esto alguien podria escribir "/etc/." y saltear la proteccion.
    ruta=$(realpath "$1" 2>/dev/null) || return 1

    for protegida in "${RUTAS_PROTEGIDAS[@]}"; do
        if [ "$ruta" = "$protegida" ]; then
            return 0
        fi
    done
    return 1
}


# -----------------------------------------------------------------------------
# VER PERMISOS DE UN ARCHIVO O CARPETA
# -----------------------------------------------------------------------------
ver_permisos() {
    local ruta

    read -r -p "Ingrese la ruta del archivo o carpeta: " ruta

    # -e verifica que exista (sea archivo o carpeta)
    if [ ! -e "$ruta" ]; then
        echo "La ruta '$ruta' no existe."
        return
    fi

    echo ""
    echo "===== PERMISOS DE '$ruta' ====="

    # stat muestra datos del archivo. El formato que pedimos:
    #   %a = permisos en numero (ej: 644)
    #   %A = permisos en letras (ej: -rw-r--r--)
    #   %U = nombre del dueno
    #   %G = nombre del grupo
    echo "En numero:  $(stat -c '%a' "$ruta")"
    echo "En letras:  $(stat -c '%A' "$ruta")"
    echo "Dueno:      $(stat -c '%U' "$ruta")"
    echo "Grupo:      $(stat -c '%G' "$ruta")"

    # Si es una carpeta, mostramos ademas lo que contiene
    if [ -d "$ruta" ]; then
        echo ""
        echo "--- Contenido ---"
        ls -la "$ruta"
    fi
}


# -----------------------------------------------------------------------------
# CAMBIAR PERMISOS (chmod)
# -----------------------------------------------------------------------------
cambiar_permisos() {
    local ruta permisos

    read -r -p "Ingrese la ruta: " ruta

    if [ ! -e "$ruta" ]; then
        echo "La ruta no existe."
        return
    fi

    # PROTECCION
    if es_ruta_protegida "$ruta"; then
        echo "ERROR: '$ruta' es una carpeta del sistema."
        echo "       Cambiar sus permisos dejaria el servidor inutilizable."
        return
    fi

    echo ""
    echo "Recordatorio:  4=leer  2=escribir  1=ejecutar  (se suman)"
    echo "Ejemplos:  600 = solo el dueno    750 = script    644 = archivo comun"
    echo ""
    read -r -p "Ingrese los permisos (3 numeros, ej: 750): " permisos

    # Validamos que sean exactamente 3 digitos del 0 al 7.
    # El patron [0-7]{3} significa "tres caracteres entre 0 y 7".
    if [[ ! "$permisos" =~ ^[0-7]{3}$ ]]; then
        echo "Formato invalido. Deben ser 3 numeros del 0 al 7. Ejemplo: 750"
        return
    fi

    # Avisamos si eligieron el permiso mas peligroso
    if [ "$permisos" = "777" ]; then
        echo ""
        echo "ADVERTENCIA: 777 permite que CUALQUIER usuario del servidor"
        echo "             modifique y ejecute este archivo."
        if ! confirmar "Esta seguro?"; then
            echo "Operacion cancelada."
            return
        fi
    fi

    echo "Permisos actuales: $(stat -c '%a' "$ruta")"

    if sudo chmod "$permisos" "$ruta"; then
        echo "Permisos cambiados a: $(stat -c '%a' "$ruta")"
    else
        echo "Error: no se pudieron cambiar los permisos."
    fi
}


# -----------------------------------------------------------------------------
# CAMBIAR DUENO (chown)
# -----------------------------------------------------------------------------
cambiar_dueno() {
    local ruta usuario grupo

    read -r -p "Ingrese la ruta: " ruta

    if [ ! -e "$ruta" ]; then
        echo "La ruta no existe."
        return
    fi

    if es_ruta_protegida "$ruta"; then
        echo "ERROR: '$ruta' es una carpeta del sistema."
        return
    fi

    read -r -p "Ingrese el nuevo dueno: " usuario

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    read -r -p "Ingrese el nuevo grupo (Enter para dejar el actual): " grupo

    echo "Dueno actual: $(stat -c '%U:%G' "$ruta")"

    # -z verifica si la variable esta vacia (el operador apreto Enter)
    if [ -z "$grupo" ]; then
        # chown usuario archivo   -> cambia solo el dueno
        if sudo chown "$usuario" "$ruta"; then
            echo "Nuevo dueno: $(stat -c '%U:%G' "$ruta")"
        else
            echo "Error: no se pudo cambiar el dueno."
        fi
    else
        if ! grupo_existe "$grupo"; then
            echo "El grupo no existe."
            return
        fi
        # chown usuario:grupo archivo  -> cambia dueno y grupo
        if sudo chown "$usuario:$grupo" "$ruta"; then
            echo "Nuevo dueno: $(stat -c '%U:%G' "$ruta")"
        else
            echo "Error: no se pudo cambiar el dueno."
        fi
    fi
}


# -----------------------------------------------------------------------------
# BUSCAR ARCHIVOS CON PERMISOS PELIGROSOS
# -----------------------------------------------------------------------------
# Busca archivos con permiso 777, que cualquiera puede modificar.
# Es una revision de seguridad basica.
#
#   find CARPETA -type f -perm 0777
#      -type f    solo archivos (no carpetas)
#      -perm 0777 con exactamente ese permiso
#      2>/dev/null  oculta los errores de "permiso denegado" al recorrer
# -----------------------------------------------------------------------------
buscar_peligrosos() {
    local carpeta

    read -r -p "Carpeta donde buscar (Enter para /home y /opt): " carpeta

    if [ -z "$carpeta" ]; then
        carpeta="/home /opt"
    elif [ ! -d "$carpeta" ]; then
        echo "La carpeta no existe."
        return
    fi

    echo ""
    echo "===== ARCHIVOS CON PERMISO 777 ====="
    echo "Buscando en: $carpeta"
    echo ""

    # shellcheck disable=SC2086
    # (la variable va sin comillas a proposito, para poder pasar dos carpetas)
    local resultado
    resultado=$(find $carpeta -type f -perm 0777 2>/dev/null)

    if [ -z "$resultado" ]; then
        echo "No se encontraron archivos con permisos 777. Correcto."
    else
        echo "$resultado"
        echo ""
        echo "Estos archivos pueden ser modificados por cualquier usuario."
        echo "Conviene bajarles los permisos, por ejemplo a 644 o 750."
    fi
}


# -----------------------------------------------------------------------------
# VERIFICAR LOS PERMISOS DEL PROYECTO BRAMAJO
# -----------------------------------------------------------------------------
# Comprueba que los archivos criticos tengan los permisos que exige nuestra
# propia politica de seguridad. Sirve como evidencia para la entrega.
# -----------------------------------------------------------------------------
verificar_bramajo() {
    echo ""
    echo "===== VERIFICACION DE PERMISOS DEL PROYECTO ====="
    echo ""

    # Cada linea de la lista tiene: ruta|permiso_esperado|descripcion
    # Se separan con "|" y despues los partimos con 'cut'.
    local revisiones=(
        "/etc/bramajo|700|carpeta de configuracion"
        "/etc/bramajo/backup.pass|600|contrasena de respaldo"
        "/etc/bramajo/app.pass|600|contrasena de la aplicacion"
        "/var/backups/bramajo|700|carpeta de respaldos"
    )

    local linea ruta esperado descripcion actual

    for linea in "${revisiones[@]}"; do
        ruta=$(echo "$linea" | cut -d'|' -f1)
        esperado=$(echo "$linea" | cut -d'|' -f2)
        descripcion=$(echo "$linea" | cut -d'|' -f3)

        printf "%-32s" "$descripcion"

        if [ ! -e "$ruta" ]; then
            echo "no existe todavia"
            continue
        fi

        actual=$(stat -c '%a' "$ruta")

        if [ "$actual" = "$esperado" ]; then
            echo "OK ($actual)"
        else
            echo "REVISAR: es $actual y deberia ser $esperado"
        fi
    done

    echo ""
    echo "Los archivos de contrasena deben ser 600: solo root puede leerlos."
    echo "Si alguno figura como REVISAR, corregir con la opcion 2 del menu."
}


# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_permisos() {
    local opcion

    while true; do
        echo ""
        echo "===== GESTION DE PERMISOS ====="
        echo "1. Ver permisos de un archivo o carpeta"
        echo "2. Cambiar permisos (chmod)"
        echo "3. Cambiar dueno (chown)"
        echo "4. Buscar archivos con permisos peligrosos"
        echo "5. Verificar permisos del proyecto Bramajo"
        echo "6. Volver"
        echo ""

        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) ver_permisos ;;
            2) cambiar_permisos ;;
            3) cambiar_dueno ;;
            4) buscar_peligrosos ;;
            5) verificar_bramajo ;;
            6) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_permisos
