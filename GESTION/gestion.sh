#!/bin/bash
# =============================================================================
#  gestion.sh - Menu principal de gestion del servidor Bramajo
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
#  Servidor:   VM AlmaLinux sobre Proxmox
#
#  Uso:  ./gestion.sh
#
#  Este script es solo el menu: cada opcion delega en un script especializado.
#  Esa separacion permite ejecutar cualquier modulo por separado si hace falta.
# =============================================================================

# -----------------------------------------------------------------------------
# UBICACION DE LOS SCRIPTS
# -----------------------------------------------------------------------------
# La version anterior usaba './usuarios.sh', que solo funciona si uno esta
# parado exactamente en la carpeta del proyecto. Con readlink -f obtenemos la
# ruta real de este archivo y desde ahi ubicamos a los demas, sin importar
# desde donde se lo invoque ni si se lo llamo a traves de un enlace simbolico.
# -----------------------------------------------------------------------------
DIR="$(dirname "$(readlink -f "$0")")"

source "$DIR/comun.sh"

# -----------------------------------------------------------------------------
# VERIFICACION DE DEPENDENCIAS
# -----------------------------------------------------------------------------
# Comprobamos al arrancar que esten todos los modulos. Es preferible avisar
# ahora y no cuando el operador elija una opcion que no va a funcionar.
# -----------------------------------------------------------------------------
verificar_modulos() {
    local faltantes=0
    local modulo

    for modulo in usuarios.sh grupos.sh registrar_grupo.sh listar.sh \
                  servicios.sh permisos.sh comun.sh; do
        if [ ! -f "$DIR/$modulo" ]; then
            echo "ERROR: falta el archivo '$modulo' en $DIR"
            faltantes=1
        fi
    done

    if [ "$faltantes" -eq 1 ]; then
        echo ""
        echo "Los cinco archivos deben estar en la misma carpeta."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# MENU PRINCIPAL
# -----------------------------------------------------------------------------
menu_principal() {
    local opcion

    while true; do
        echo ""
        echo "===================================="
        echo "  SISTEMA DE GESTION DEL SERVIDOR"
        echo "             BRAMAJO"
        echo "===================================="
        echo " Equipo: $(hostname)   Operador: $(whoami)"
        echo "===================================="
        echo "--- Usuarios y grupos ---"
        echo "1. Gestion de usuarios"
        echo "2. Gestion de grupos"
        echo "3. Asignacion de grupos"
        echo "4. Consultar usuarios y grupos"
        echo ""
        echo "--- Sistema ---"
        echo "5. Gestion de servicios"
        echo "6. Gestion de permisos"
        echo ""
        echo "7. Salir"
        echo ""

        # Si la entrada se agota, salimos limpiamente.
        # Sin este control el menu giraba infinitamente al 100% de CPU.
        if ! read -r -p "Seleccione una opcion: " opcion; then
            echo ""
            echo "Entrada finalizada. Saliendo."
            exit 0
        fi

        case "$opcion" in
            1) bash "$DIR/usuarios.sh" ;;
            2) bash "$DIR/grupos.sh" ;;
            3) bash "$DIR/registrar_grupo.sh" ;;
            4) bash "$DIR/listar.sh" ;;
            5) bash "$DIR/servicios.sh" ;;
            6) bash "$DIR/permisos.sh" ;;
            7)
                echo "Saliendo del sistema..."
                exit 0
                ;;
            *) echo "Opcion invalida. Elija un numero del 1 al 7." ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# INICIO
# -----------------------------------------------------------------------------
verificar_modulos
menu_principal
