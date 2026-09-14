#!/bin/bash
# =============================================================================
#  grupos.sh - Gestion de grupos del sistema
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
# =============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"

# -----------------------------------------------------------------------------
# CREAR GRUPO
# -----------------------------------------------------------------------------
crear_grupo() {
    local grupo

    read -r -p "Ingrese el nombre del grupo: " grupo || return

    if [ -z "$grupo" ]; then
        echo "El nombre no puede estar vacio."
        return
    fi

    if ! nombre_valido "$grupo"; then
        echo "Nombre invalido. Use solo minusculas, numeros, guion y guion bajo."
        return
    fi

    if grupo_existe "$grupo"; then
        echo "El grupo ya existe."
        return
    fi

    if sudo groupadd "$grupo"; then
        echo "Grupo '$grupo' creado correctamente."
    else
        echo "Error: no se pudo crear el grupo."
    fi
}

# -----------------------------------------------------------------------------
# MODIFICAR (RENOMBRAR) GRUPO
# -----------------------------------------------------------------------------
modificar_grupo() {
    local grupo nuevo

    read -r -p "Ingrese el nombre actual del grupo: " grupo || return

    if ! grupo_existe "$grupo"; then
        echo "El grupo no existe."
        return
    fi

    # Proteccion: los grupos del sistema (GID < 1000) sostienen servicios.
    # Renombrar 'docker' o 'wheel' rompe permisos en todo el servidor.
    if es_grupo_del_sistema "$grupo"; then
        echo "ERROR: '$grupo' es un grupo del sistema (GID < $UID_MINIMO)."
        echo "       Renombrarlo puede dejar servicios sin funcionar."
        return
    fi

    read -r -p "Ingrese el nuevo nombre: " nuevo || return

    if ! nombre_valido "$nuevo"; then
        echo "Nombre invalido."
        return
    fi

    if grupo_existe "$nuevo"; then
        echo "Ya existe un grupo llamado '$nuevo'."
        return
    fi

    if sudo groupmod -n "$nuevo" "$grupo"; then
        echo "Grupo renombrado: '$grupo' -> '$nuevo'."
    else
        echo "Error: no se pudo renombrar el grupo."
    fi
}

# -----------------------------------------------------------------------------
# ELIMINAR GRUPO
# -----------------------------------------------------------------------------
eliminar_grupo() {
    local grupo miembros

    read -r -p "Ingrese el grupo a eliminar: " grupo || return

    if ! grupo_existe "$grupo"; then
        echo "El grupo no existe."
        return
    fi

    # PROTECCION CRITICA
    if es_grupo_del_sistema "$grupo"; then
        echo "ERROR: '$grupo' es un grupo del sistema (GID < $UID_MINIMO)."
        echo "       Eliminarlo dejaria servicios sin funcionar."
        return
    fi

    # Informamos quienes quedarian afectados antes de borrar.
    # El cuarto campo de /etc/group son los miembros secundarios.
    miembros=$(getent group "$grupo" | cut -d: -f4)

    if [ -n "$miembros" ]; then
        echo "AVISO: el grupo tiene estos miembros: $miembros"
        echo "       Perderan los permisos asociados a este grupo."
    fi

    if confirmar "Confirma eliminar el grupo '$grupo'?"; then
        # groupdel falla si el grupo es primario de algun usuario.
        # Antes el script decia 'eliminado correctamente' igual; ahora no.
        if sudo groupdel "$grupo"; then
            echo "Grupo '$grupo' eliminado correctamente."
        else
            echo "Error: no se pudo eliminar el grupo."
            echo "Causa habitual: es el grupo primario de algun usuario."
            echo "Verifique con: getent passwd | awk -F: '\$4 == GID'"
        fi
    else
        echo "Operacion cancelada."
    fi
}

# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_grupos() {
    local opcion

    while true; do
        echo ""
        echo "===== GESTION DE GRUPOS ====="
        echo "1. Crear grupo"
        echo "2. Modificar grupo"
        echo "3. Eliminar grupo"
        echo "4. Volver"
        echo ""

        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) crear_grupo ;;
            2) modificar_grupo ;;
            3) eliminar_grupo ;;
            4) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_grupos
