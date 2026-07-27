#!/bin/bash

listar_usuarios() {

    echo ""
    echo "===== USUARIOS DEL SISTEMA ====="

    cut -d: -f1 /etc/passwd

}

listar_grupos() {

    echo ""
    echo "===== GRUPOS DEL SISTEMA ====="

    cut -d: -f1 /etc/group

}

ver_grupos_usuario() {

    read -p "Ingrese el nombre del usuario: " usuario

    if id "$usuario" &>/dev/null; then

        echo ""
        echo "Grupos pertenecientes al usuario:"
        groups "$usuario"

    else

        echo "El usuario no existe."

    fi

}

menu_listar() {

    while true; do

        echo ""
        echo "===== CONSULTAS ====="
        echo "1. Ver usuarios"
        echo "2. Ver grupos"
        echo "3. Ver grupos de un usuario"
        echo "4. Volver"

        read -p "Seleccione una opción: " opcion

        case $opcion in

            1)
                listar_usuarios
                ;;

            2)
                listar_grupos
                ;;

            3)
                ver_grupos_usuario
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

menu_listar
