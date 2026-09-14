#!/bin/bash
# =============================================================================
#  usuarios.sh - Gestion de usuarios del sistema
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
# =============================================================================

# Carga las funciones comunes. Usamos la ruta del propio script para que
# funcione aunque se lo invoque desde otro directorio.
DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"

# -----------------------------------------------------------------------------
# CREAR USUARIO
# -----------------------------------------------------------------------------
crear_usuario() {
    local usuario

    read -r -p "Ingrese el nombre del nuevo usuario: " usuario || return

    # Validacion 1: que no venga vacio
    if [ -z "$usuario" ]; then
        echo "El nombre no puede estar vacio."
        return
    fi

    # Validacion 2: que cumpla las reglas de nombres de Linux
    if ! nombre_valido "$usuario"; then
        echo "Nombre invalido. Use solo minusculas, numeros, guion y guion bajo,"
        echo "comenzando con una letra. Ejemplo: bruno_sena"
        return
    fi

    # Validacion 3: que no exista ya
    if usuario_existe "$usuario"; then
        echo "El usuario ya existe."
        return
    fi

    # -m crea el directorio personal, -s define la shell de inicio
    if sudo useradd -m -s /bin/bash "$usuario"; then
        echo "Usuario '$usuario' creado correctamente."
        echo "Defina la contrasena:"

        # Si el operador cancela la asignacion de contrasena, la cuenta queda
        # creada pero bloqueada (useradd la deja asi por defecto). Lo avisamos
        # para que nadie crea que la cuenta ya esta operativa.
        if ! sudo passwd "$usuario"; then
            echo "AVISO: no se definio contrasena. La cuenta queda bloqueada"
            echo "       hasta que se ejecute: sudo passwd $usuario"
        fi
    else
        echo "Error: no se pudo crear el usuario."
    fi
}

# -----------------------------------------------------------------------------
# MODIFICAR (RENOMBRAR) USUARIO
# -----------------------------------------------------------------------------
# Renombrar un usuario en Linux implica tres cambios, no uno:
#   1) el nombre de login          -> usermod -l
#   2) el directorio personal      -> usermod -d ... -m
#   3) el grupo primario homonimo  -> groupmod -n
# Si solo se cambia el primero, el usuario 'pedro' sigue teniendo /home/juan
# y perteneciendo al grupo 'juan', lo que deja el sistema inconsistente.
# -----------------------------------------------------------------------------
modificar_usuario() {
    local usuario nuevo

    read -r -p "Ingrese el usuario a modificar: " usuario || return

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    # Proteccion: no se renombran cuentas del sistema
    if es_cuenta_del_sistema "$usuario"; then
        echo "ERROR: '$usuario' es una cuenta del sistema (UID < $UID_MINIMO)."
        echo "       Renombrarla puede dejar servicios sin funcionar."
        return
    fi

    read -r -p "Ingrese el nuevo nombre: " nuevo || return

    if ! nombre_valido "$nuevo"; then
        echo "Nombre invalido."
        return
    fi

    if usuario_existe "$nuevo"; then
        echo "Ya existe un usuario llamado '$nuevo'."
        return
    fi

    # El usuario no puede tener sesiones abiertas mientras se lo renombra
    # pgrep busca procesos de ese usuario. Si encuentra alguno, tiene la
    # sesion abierta y los comandos usermod/userdel van a fallar.
    if pgrep -u "$usuario" > /dev/null; then
        echo "ERROR: '$usuario' tiene procesos en ejecucion."
        echo "       Cierre su sesion antes de renombrarlo."
        return
    fi

    if sudo usermod -l "$nuevo" -d "/home/$nuevo" -m "$usuario"; then
        echo "Usuario renombrado y directorio personal movido."

        # El grupo primario suele llamarse igual que el usuario.
        # Lo renombramos tambien, si existe.
        if grupo_existe "$usuario"; then
            if sudo groupmod -n "$nuevo" "$usuario"; then
                echo "Grupo primario renombrado a '$nuevo'."
            else
                echo "AVISO: el usuario se renombro pero el grupo primario no."
            fi
        fi

        echo "Modificacion completada: '$usuario' -> '$nuevo'."
    else
        echo "Error: no se pudo modificar el usuario."
    fi
}

# -----------------------------------------------------------------------------
# ELIMINAR USUARIO
# -----------------------------------------------------------------------------
eliminar_usuario() {
    local usuario

    read -r -p "Ingrese el usuario a eliminar: " usuario || return

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    # PROTECCION CRITICA
    # Sin esta comprobacion, escribir 'root' o 'mysql' destruiria el servidor.
    if es_cuenta_del_sistema "$usuario"; then
        echo "ERROR: '$usuario' es una cuenta del sistema (UID < $UID_MINIMO)."
        echo "       Eliminarla dejaria el servidor inutilizable."
        return
    fi

    # Tampoco tiene sentido que el operador se borre a si mismo
    if [ "$usuario" = "$(whoami)" ]; then
        echo "ERROR: no puede eliminar la cuenta con la que esta trabajando."
        return
    fi

    # userdel falla si el usuario tiene procesos activos
    # pgrep busca procesos de ese usuario. Si encuentra alguno, tiene la
    # sesion abierta y los comandos usermod/userdel van a fallar.
    if pgrep -u "$usuario" > /dev/null; then
        echo "ERROR: '$usuario' tiene procesos en ejecucion."
        echo "       Cierre su sesion antes de eliminarlo."
        return
    fi

    echo ""
    echo "Se eliminaran la cuenta y su directorio personal /home/$usuario"

    if confirmar "Confirma eliminar '$usuario'?"; then
        # -r elimina tambien el directorio personal y el correo local
        if sudo userdel -r "$usuario"; then
            echo "Usuario '$usuario' eliminado correctamente."
        else
            echo "Error: no se pudo eliminar el usuario."
        fi
    else
        echo "Operacion cancelada."
    fi
}

# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_usuarios() {
    local opcion

    while true; do
        echo ""
        echo "===== GESTION DE USUARIOS ====="
        echo "1. Crear usuario"
        echo "2. Modificar usuario"
        echo "3. Eliminar usuario"
        echo "4. Volver"
        echo ""

        # Si read falla (entrada agotada), salimos en vez de girar infinitamente
        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) crear_usuario ;;
            2) modificar_usuario ;;
            3) eliminar_usuario ;;
            4) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_usuarios
