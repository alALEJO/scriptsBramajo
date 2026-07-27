#!/bin/bash

crear_grupo() {

    read -p "Ingrese el nombre del grupo: " grupo

    if getent group "$grupo" &>/dev/null; then
        echo "El grupo ya existe."
        return
    fi

    sudo groupadd "$grupo"

    if [ $? -eq 0 ]; then
        echo "Grupo creado correctamente."
    else
        echo "Error al crear el grupo."
    fi
}

modificar_grupo() {

    read -p "Ingrese el nombre actual del grupo: " grupo

    if ! getent group "$grupo" &>/dev/null; then
        echo "El grupo no existe."
        return
    fi

    read -p "Ingrese el nuevo nombre del grupo: " nuevo

    sudo groupmod -n "$nuevo" "$grupo"

    echo "Grupo modificado correctamente."
}

eliminar_grupo() {

    read -p "Ingrese el grupo a eliminar: " grupo

    if ! getent group "$grupo" &>/dev/null; then
        echo "El grupo no existe."
        return
    fi

    read -p "¿Está seguro de eliminar el grupo? (s/n): " confirmacion

    if [ "$confirmacion" = "s" ]; then

        sudo groupdel "$grupo"

        echo "Grupo eliminado correctamente."

    else

        echo "Operación cancelada."

    fi
}

menu_grupos() {

    while true; do

        echo ""
        echo "===== GESTIÓN DE GRUPOS ====="
        echo "1. Crear grupo"
        echo "2. Modificar grupo"
        echo "3. Eliminar grupo"
        echo "4. Volver"

        read -p "Seleccione una opción: " opcion

        case $opcion in

            1)
                crear_grupo
                ;;

            2)
                modificar_grupo
                ;;

            3)
                eliminar_grupo
                ;;

            4)
                break
                ;;

            *)
                echo "Opción inválida."
                ;;

        esac

    done
}

menu_grupos
