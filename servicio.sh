#!/bin/bash

verificar_servicio() {

    servicio=$1

    if ! systemctl list-unit-files | grep -q "^$servicio"; then
        echo "El servicio $servicio no existe o no está instalado."
        return 1
    fi

    return 0
}

ver_estado() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        systemctl status "$servicio" --no-pager
    fi
}

iniciar_servicio() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        sudo systemctl start "$servicio"
        echo "Servicio iniciado."
    fi
}

detener_servicio() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        sudo systemctl stop "$servicio"
        echo "Servicio detenido."
    fi
}

reiniciar_servicio() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        sudo systemctl restart "$servicio"
        echo "Servicio reiniciado."
    fi
}

habilitar_servicio() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        sudo systemctl enable "$servicio"
        echo "El servicio se iniciará automáticamente con Linux."
    fi
}

deshabilitar_servicio() {

    read -p "Ingrese el nombre del servicio: " servicio

    if verificar_servicio "$servicio"; then
        sudo systemctl disable "$servicio"
        echo "El inicio automático del servicio fue deshabilitado."
    fi
}

while true; do

    echo ""
    echo "================================"
    echo "     GESTIÓN DE SERVICIOS"
    echo "================================"
    echo "1. Ver estado"
    echo "2. Iniciar servicio"
    echo "3. Detener servicio"
    echo "4. Reiniciar servicio"
    echo "5. Habilitar inicio automático"
    echo "6. Deshabilitar inicio automático"
    echo "7. Salir"

    read -p "Seleccione una opción: " opcion

    case $opcion in

        1)
            ver_estado
            ;;

        2)
            iniciar_servicio
            ;;

        3)
            detener_servicio
            ;;

        4)
            reiniciar_servicio
            ;;

        5)
            habilitar_servicio
            ;;

        6)
            deshabilitar_servicio
            ;;

        7)
            echo "Saliendo..."
            exit 0
            ;;

        *)
            echo "Opción inválida."
            ;;

    esac

done
