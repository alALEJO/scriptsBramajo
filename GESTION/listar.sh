#!/bin/bash
# =============================================================================
#  listar.sh - Consultas sobre usuarios y grupos del sistema
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
#
#  IMPORTANTE (para la defensa):
#     Los usuarios que se muestran aca son usuarios del SISTEMA OPERATIVO,
#     guardados en el archivo /etc/passwd.
#     NO son los roles de la aplicacion Bramajo (Participante, Organizador,
#     Administrador): esos viven en la tabla Usuario de la base MySQL.
#     Son dos cosas distintas que se llaman igual.
# =============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"


# -----------------------------------------------------------------------------
# COMO SE LEE /etc/passwd
# -----------------------------------------------------------------------------
# Cada linea del archivo tiene 7 campos separados por ":"
#
#   bruno : x : 1001 : 1001 : Bruno Sena : /home/bruno : /bin/bash
#     1     2    3      4        5             6            7
#
#   campo 1 = nombre de usuario
#   campo 3 = UID (numero del usuario)
#   campo 6 = directorio personal
#   campo 7 = shell
#
# 'awk' recorre el archivo linea por linea.
#   -F:              usar ":" como separador
#   '$3 >= 1000'     quedarse solo con las lineas cuyo campo 3 sea >= 1000
#   {print $1, $3}   imprimir esos campos
#
# 'column -t' despues acomoda todo en columnas parejas.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# USUARIOS HUMANOS
# -----------------------------------------------------------------------------
# Son las personas reales: UID 1000 o mayor.
# Se excluye el 65534 ("nobody"), que pese al numero alto es del sistema.
# -----------------------------------------------------------------------------
listar_usuarios_humanos() {
    echo ""
    echo "===== USUARIOS HUMANOS ====="

    {
        echo "USUARIO UID DIRECTORIO SHELL"
        awk -F: '$3 >= 1000 && $3 != 65534 {print $1, $3, $6, $7}' /etc/passwd
    } | column -t

    echo ""
    echo "Total: $(awk -F: '$3 >= 1000 && $3 != 65534' /etc/passwd | wc -l)"
}


# -----------------------------------------------------------------------------
# CUENTAS DE SERVICIO
# -----------------------------------------------------------------------------
# Las crea el sistema al instalar programas. No son personas.
# Casi todas tienen /sbin/nologin como shell, que significa
# "esta cuenta no puede iniciar sesion".
# -----------------------------------------------------------------------------
listar_usuarios_sistema() {
    echo ""
    echo "===== CUENTAS DE SERVICIO ====="

    {
        echo "USUARIO UID SHELL"
        awk -F: '$3 < 1000 {print $1, $3, $7}' /etc/passwd
    } | column -t

    echo ""
    echo "Total: $(awk -F: '$3 < 1000' /etc/passwd | wc -l)"
    echo ""
    echo "Estas cuentas no se modifican ni se eliminan:"
    echo "sostienen los servicios del servidor."
}


# -----------------------------------------------------------------------------
# GRUPOS
# -----------------------------------------------------------------------------
# El archivo /etc/group tiene 4 campos:
#
#   docker : x : 988 : bruno,joaquin
#     1      2    3         4
#
#   campo 1 = nombre del grupo
#   campo 3 = GID (numero del grupo)
#   campo 4 = miembros
# -----------------------------------------------------------------------------
listar_grupos() {
    echo ""
    echo "===== GRUPOS CREADOS POR LOS ADMINISTRADORES ====="

    {
        echo "GRUPO GID MIEMBROS"
        awk -F: '$3 >= 1000 {print $1, $3, $4}' /etc/group
    } | column -t

    echo ""
    echo "(los grupos con GID menor a 1000 son del sistema y no se listan)"
}


# -----------------------------------------------------------------------------
# GRUPOS DE UN USUARIO
# -----------------------------------------------------------------------------
listar_grupos_de_usuario() {
    local usuario

    read -r -p "Ingrese el nombre del usuario: " usuario

    if ! usuario_existe "$usuario"; then
        echo "El usuario no existe."
        return
    fi

    echo ""
    echo "===== GRUPOS DE '$usuario' ====="
    echo "UID:              $(id -u "$usuario")"
    echo "Grupo primario:   $(id -gn "$usuario")"
    echo "Todos sus grupos: $(id -nG "$usuario")"

    if es_cuenta_del_sistema "$usuario"; then
        echo ""
        echo "AVISO: esta es una cuenta del sistema, no una persona."
    fi
}


# -----------------------------------------------------------------------------
# RESUMEN
# -----------------------------------------------------------------------------
# Vista rapida del servidor. Sirve como captura para el anexo de la entrega.
# -----------------------------------------------------------------------------
resumen() {
    echo ""
    echo "===== RESUMEN DEL SERVIDOR ====="
    echo "Equipo: $(hostname)"
    echo "Fecha:  $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "Usuarios humanos:    $(awk -F: '$3 >= 1000 && $3 != 65534' /etc/passwd | wc -l)"
    echo "Cuentas de servicio: $(awk -F: '$3 < 1000' /etc/passwd | wc -l)"
    echo "Grupos propios:      $(awk -F: '$3 >= 1000' /etc/group | wc -l)"
    echo ""
    echo "Sesiones abiertas ahora:"
    who
}


# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_listar() {
    local opcion

    while true; do
        echo ""
        echo "===== CONSULTAS ====="
        echo "1. Ver usuarios humanos"
        echo "2. Ver cuentas de servicio"
        echo "3. Ver grupos"
        echo "4. Ver grupos de un usuario"
        echo "5. Resumen del servidor"
        echo "6. Volver"
        echo ""

        # Si la entrada se termina (Ctrl+D), 'read' falla y salimos.
        # Sin esto el menu se repetiria para siempre.
        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) listar_usuarios_humanos ;;
            2) listar_usuarios_sistema ;;
            3) listar_grupos ;;
            4) listar_grupos_de_usuario ;;
            5) resumen ;;
            6) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_listar
