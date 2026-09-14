#!/bin/bash
# =============================================================================
#  registrar_grupo.sh - Asignacion de usuarios a grupos
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
# =============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"

# -----------------------------------------------------------------------------
# AGREGAR USUARIO A UN GRUPO
# -----------------------------------------------------------------------------
agregar_usuario_grupo() {
    local usuario grupo

    read -r -p "Ingrese el usuario: " usuario || return
    read -r -p "Ingrese el grupo: " grupo || return

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    if ! grupo_existe "$grupo"; then
        echo "El grupo no existe."
        return
    fi

    # Si ya pertenece, no tiene sentido ejecutar el comando.
    if pertenece_al_grupo "$usuario" "$grupo"; then
        echo "El usuario '$usuario' ya pertenece al grupo '$grupo'."
        return
    fi

    # -a (append) es imprescindible: sin esa opcion, -G REEMPLAZA todos los
    # grupos secundarios del usuario en lugar de agregar uno.
    if sudo usermod -aG "$grupo" "$usuario"; then
        echo "Usuario '$usuario' agregado al grupo '$grupo'."
        echo "AVISO: debe cerrar y reabrir sesion para que tome efecto."
    else
        echo "Error: no se pudo agregar el usuario al grupo."
    fi
}

# -----------------------------------------------------------------------------
# QUITAR USUARIO DE UN GRUPO
# -----------------------------------------------------------------------------
quitar_usuario_grupo() {
    local usuario grupo grupo_primario

    read -r -p "Ingrese el usuario: " usuario || return
    read -r -p "Ingrese el grupo: " grupo || return

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    # En la version anterior faltaba esta comprobacion: se verificaba el
    # usuario pero no el grupo, y gpasswd fallaba con un mensaje confuso.
    if ! grupo_existe "$grupo"; then
        echo "El grupo no existe."
        return
    fi

    # No se puede quitar a alguien de su grupo primario con gpasswd.
    # Detectarlo aca evita un error incomprensible para el operador.
    grupo_primario=$(id -gn "$usuario")
    if [ "$grupo" = "$grupo_primario" ]; then
        echo "ERROR: '$grupo' es el grupo primario de '$usuario'."
        echo "       Para cambiarlo use: sudo usermod -g <otro_grupo> $usuario"
        return
    fi

    # Verificamos que efectivamente pertenezca
    if ! pertenece_al_grupo "$usuario" "$grupo"; then
        echo "El usuario '$usuario' no pertenece al grupo '$grupo'."
        return
    fi

    if sudo gpasswd -d "$usuario" "$grupo"; then
        echo "Usuario '$usuario' quitado del grupo '$grupo'."
    else
        echo "Error: no se pudo quitar el usuario del grupo."
    fi
}

# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_registro() {
    local opcion

    while true; do
        echo ""
        echo "===== ASIGNACION DE GRUPOS ====="
        echo "1. Agregar usuario a grupo"
        echo "2. Quitar usuario de grupo"
        echo "3. Volver"
        echo ""

        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) agregar_usuario_grupo ;;
            2) quitar_usuario_grupo ;;
            3) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_registro
