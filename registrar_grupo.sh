#!/bin/bash

agregar_usuario_grupo() {

    read -p "Ingrese el usuario: " usuario
    read -p "Ingrese el grupo: " grupo

    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    if ! getent group "$grupo" &>/dev/null; then
        echo "El grupo no existe."
        return
    fi

    sudo usermod -aG "$grupo" "$usuario"

    echo "Usuario agregado al grupo correctamente."
}

quitar_usuario_grupo() {

    read -p "Ingrese el usuario: " usuario
    read -p "Ingrese el grupo: " grupo

    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

   if ! getent group "$grupo" &>/dev/null; then
        echo "El grupo no existe."
        return
    fi

    sudo gpasswd -d "$usuario" "$grupo"

    echo "Usuario eliminado del grupo."
}

menu_registro() {

    while true; do

        echo ""
        echo "===== ASIGNACIÓN DE GRUPOS ====="
        echo "1. Agregar usuario a grupo"
        echo "2. Quitar usuario de grupo"
        echo "3. Volver"

        read -p "Seleccione una opción: " opcion

        case $opcion in

            1)
                agregar_usuario_grupo
                ;;

            2)
                quitar_usuario_grupo
                ;;

            3)
                break
                ;;

            *)
                echo "Opción inválida."
                ;;

        esac

    done
}

menu_registro
