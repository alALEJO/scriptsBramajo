#!/bin/bash

RUTA_BRAMAJO="/var/www/bramajo"

verificar_ruta() {

    if [ ! -e "$1" ]; then
        echo "El archivo o directorio no existe."
        return 1
    fi

    return 0
}

ver_permisos() {

    read -p "Ingrese la ruta del archivo: " archivo

    if verificar_ruta "$archivo"; then
        ls -l "$archivo"
    fi
}

cambiar_propietario() {

    read -p "Ingrese la ruta: " archivo
    read -p "Ingrese el nuevo propietario: " usuario

    if verificar_ruta "$archivo"; then
        sudo chown "$usuario" "$archivo"
        echo "Propietario modificado."
    fi
}

cambiar_grupo() {

    read -p "Ingrese la ruta: " archivo
    read -p "Ingrese el nuevo grupo: " grupo

    if verificar_ruta "$archivo"; then
        sudo chgrp "$grupo" "$archivo"
        echo "Grupo modificado."
    fi
}

cambiar_permisos() {

    read -p "Ingrese la ruta: " archivo
    read -p "Ingrese los permisos en formato octal: " permisos

    if verificar_ruta "$archivo"; then
        sudo chmod "$permisos" "$archivo"
        echo "Permisos modificados."
    fi
}

while true; do

    echo ""
    echo "================================"
    echo "       GESTIÓN DE PERMISOS"
    echo "================================"

    echo "1. Ver permisos"
    echo "2. Cambiar propietario"
    echo "3. Cambiar grupo"
    echo "4. Cambiar permisos"
    echo "5. Salir"

    read -p "Seleccione una opción: " opcion

    case $opcion in

        1)
            ver_permisos
            ;;

        2)
            cambiar_propietario
            ;;

        3)
            cambiar_grupo
            ;;

        4)
            cambiar_permisos
            ;;

        5)
            echo "Saliendo..."
            exit 0
            ;;

        *)
            echo "Opción inválida."
            ;;

    esac

done
