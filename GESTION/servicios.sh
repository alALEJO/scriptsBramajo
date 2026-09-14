#!/bin/bash
# =============================================================================
#  servicios.sh - Administracion de servicios del sistema
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
#
#  Que es un servicio:
#     Un programa que corre de fondo, sin ventana, esperando pedidos.
#     Ejemplos en nuestro servidor:
#        sshd      -> permite conectarse por SSH
#        docker    -> corre los contenedores de la aplicacion
#        firewalld -> el cortafuegos
#        crond     -> ejecuta las tareas programadas (los respaldos)
#
#  En AlmaLinux los servicios se manejan con el comando 'systemctl'.
# =============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
source "$DIR/comun.sh"


# -----------------------------------------------------------------------------
# SERVICIOS QUE NO SE PUEDEN DETENER
# -----------------------------------------------------------------------------
# Si detenemos sshd nos quedamos sin acceso al servidor y hay que ir
# fisicamente hasta la maquina (o entrar por la consola de Proxmox).
# Por eso el script los protege.
#
# Esto es una lista (array): se escribe entre parentesis y los elementos
# van separados por espacios.
# -----------------------------------------------------------------------------
SERVICIOS_PROTEGIDOS=("sshd" "systemd-journald" "dbus")


# -----------------------------------------------------------------------------
# es_servicio_protegido <nombre>
# -----------------------------------------------------------------------------
# Recorre la lista de arriba comparando con el nombre recibido.
# "${SERVICIOS_PROTEGIDOS[@]}" significa "todos los elementos de la lista".
# -----------------------------------------------------------------------------
es_servicio_protegido() {
    local servicio
    for servicio in "${SERVICIOS_PROTEGIDOS[@]}"; do
        if [ "$1" = "$servicio" ]; then
            return 0      # 0 = si, esta protegido
        fi
    done
    return 1              # 1 = no esta en la lista
}


# -----------------------------------------------------------------------------
# servicio_existe <nombre>
# -----------------------------------------------------------------------------
# 'systemctl list-unit-files' lista todos los servicios instalados.
# Buscamos el nombre exacto seguido de ".service".
# -----------------------------------------------------------------------------
servicio_existe() {
    systemctl list-unit-files --type=service | grep -q "^$1.service"
}


# -----------------------------------------------------------------------------
# VER ESTADO DE UN SERVICIO
# -----------------------------------------------------------------------------
# Un servicio tiene dos estados distintos que conviene no confundir:
#
#   ACTIVO   -> esta corriendo ahora        (systemctl is-active)
#   HABILITADO -> arranca solo al prender el servidor  (systemctl is-enabled)
#
# Un servicio puede estar activo pero no habilitado: funciona ahora, pero si
# reinician el servidor no vuelve a arrancar. Es un error comun.
# -----------------------------------------------------------------------------
ver_estado() {
    local servicio

    read -r -p "Ingrese el nombre del servicio: " servicio

    if ! servicio_existe "$servicio"; then
        echo "El servicio '$servicio' no existe en este sistema."
        return
    fi

    echo ""
    echo "===== ESTADO DE '$servicio' ====="

    if systemctl is-active --quiet "$servicio"; then
        echo "Corriendo ahora:     SI"
    else
        echo "Corriendo ahora:     NO"
    fi

    if systemctl is-enabled --quiet "$servicio" 2>/dev/null; then
        echo "Arranca al prender:  SI"
    else
        echo "Arranca al prender:  NO"
    fi

    echo ""
    echo "--- Detalle ---"
    systemctl status "$servicio" --no-pager --lines=5
}


# -----------------------------------------------------------------------------
# LISTAR SERVICIOS ACTIVOS
# -----------------------------------------------------------------------------
listar_activos() {
    echo ""
    echo "===== SERVICIOS CORRIENDO AHORA ====="

    # --type=service  solo servicios (systemd maneja otras cosas ademas)
    # --state=running solo los que estan corriendo
    # --no-pager      que imprima todo de una, sin pausas
    systemctl list-units --type=service --state=running --no-pager

    echo ""
    echo "Total: $(systemctl list-units --type=service --state=running --no-legend | wc -l)"
}


# -----------------------------------------------------------------------------
# INICIAR UN SERVICIO
# -----------------------------------------------------------------------------
iniciar_servicio() {
    local servicio

    read -r -p "Ingrese el servicio a iniciar: " servicio

    if ! servicio_existe "$servicio"; then
        echo "El servicio no existe."
        return
    fi

    if systemctl is-active --quiet "$servicio"; then
        echo "El servicio '$servicio' ya esta corriendo."
        return
    fi

    if sudo systemctl start "$servicio"; then
        echo "Servicio '$servicio' iniciado correctamente."
    else
        echo "Error: no se pudo iniciar el servicio."
        echo "Vea el detalle con: systemctl status $servicio"
    fi
}


# -----------------------------------------------------------------------------
# DETENER UN SERVICIO
# -----------------------------------------------------------------------------
detener_servicio() {
    local servicio

    read -r -p "Ingrese el servicio a detener: " servicio

    if ! servicio_existe "$servicio"; then
        echo "El servicio no existe."
        return
    fi

    # PROTECCION: sin esto se puede perder el acceso al servidor
    if es_servicio_protegido "$servicio"; then
        echo "ERROR: '$servicio' es un servicio critico y no se puede detener"
        echo "       desde este script."
        echo "       Detener sshd, por ejemplo, cortaria la conexion SSH y"
        echo "       habria que entrar por la consola de Proxmox."
        return
    fi

    if ! systemctl is-active --quiet "$servicio"; then
        echo "El servicio '$servicio' ya esta detenido."
        return
    fi

    if confirmar "Confirma detener '$servicio'?"; then
        if sudo systemctl stop "$servicio"; then
            echo "Servicio '$servicio' detenido."
        else
            echo "Error: no se pudo detener el servicio."
        fi
    else
        echo "Operacion cancelada."
    fi
}


# -----------------------------------------------------------------------------
# REINICIAR UN SERVICIO
# -----------------------------------------------------------------------------
# Reiniciar es detener y volver a iniciar. Se usa despues de cambiar la
# configuracion de un servicio, para que tome los cambios.
# -----------------------------------------------------------------------------
reiniciar_servicio() {
    local servicio

    read -r -p "Ingrese el servicio a reiniciar: " servicio

    if ! servicio_existe "$servicio"; then
        echo "El servicio no existe."
        return
    fi

    if confirmar "Confirma reiniciar '$servicio'?"; then
        if sudo systemctl restart "$servicio"; then
            echo "Servicio '$servicio' reiniciado correctamente."
        else
            echo "Error: no se pudo reiniciar el servicio."
        fi
    else
        echo "Operacion cancelada."
    fi
}


# -----------------------------------------------------------------------------
# HABILITAR O DESHABILITAR EL ARRANQUE AUTOMATICO
# -----------------------------------------------------------------------------
# 'enable' hace que el servicio arranque solo cuando se prende el servidor.
# Es distinto de 'start', que lo arranca ahora pero no queda configurado.
# -----------------------------------------------------------------------------
configurar_arranque() {
    local servicio opcion

    read -r -p "Ingrese el nombre del servicio: " servicio

    if ! servicio_existe "$servicio"; then
        echo "El servicio no existe."
        return
    fi

    echo ""
    echo "1. Habilitar (que arranque solo al prender el servidor)"
    echo "2. Deshabilitar (que NO arranque solo)"
    read -r -p "Seleccione: " opcion

    case "$opcion" in
        1)
            if sudo systemctl enable "$servicio"; then
                echo "'$servicio' arrancara automaticamente al iniciar el servidor."
            else
                echo "Error: no se pudo habilitar."
            fi
            ;;
        2)
            if es_servicio_protegido "$servicio"; then
                echo "ERROR: '$servicio' es critico, no se puede deshabilitar."
                return
            fi
            if sudo systemctl disable "$servicio"; then
                echo "'$servicio' ya no arrancara automaticamente."
            else
                echo "Error: no se pudo deshabilitar."
            fi
            ;;
        *)
            echo "Opcion invalida."
            ;;
    esac
}


# -----------------------------------------------------------------------------
# SERVICIOS DEL PROYECTO BRAMAJO
# -----------------------------------------------------------------------------
# Muestra de un vistazo si esta todo lo que nuestro sistema necesita.
# Sirve como captura para la entrega.
# -----------------------------------------------------------------------------
estado_bramajo() {
    local servicio

    echo ""
    echo "===== SERVICIOS DEL PROYECTO BRAMAJO ====="
    echo ""

    for servicio in sshd docker firewalld crond; do
        printf "%-14s" "$servicio"

        if ! servicio_existe "$servicio"; then
            echo "NO INSTALADO"
        elif systemctl is-active --quiet "$servicio"; then
            echo "corriendo"
        else
            echo "DETENIDO"
        fi
    done

    echo ""
    echo "===== CONTENEDORES DE LA APLICACION ====="

    # 'command -v docker' verifica si el comando existe antes de usarlo
    if command -v docker &>/dev/null; then
        docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null \
            || echo "(no se pudo consultar Docker, verifique permisos)"
    else
        echo "Docker no esta instalado."
    fi
}


# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
menu_servicios() {
    local opcion

    while true; do
        echo ""
        echo "===== GESTION DE SERVICIOS ====="
        echo "1. Ver estado de un servicio"
        echo "2. Listar servicios activos"
        echo "3. Iniciar un servicio"
        echo "4. Detener un servicio"
        echo "5. Reiniciar un servicio"
        echo "6. Configurar arranque automatico"
        echo "7. Estado de los servicios de Bramajo"
        echo "8. Volver"
        echo ""

        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            return
        fi

        case "$opcion" in
            1) ver_estado ;;
            2) listar_activos ;;
            3) iniciar_servicio ;;
            4) detener_servicio ;;
            5) reiniciar_servicio ;;
            6) configurar_arranque ;;
            7) estado_bramajo ;;
            8) return ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

menu_servicios
