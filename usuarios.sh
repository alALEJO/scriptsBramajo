#!/bin/bash

crear_usuario() {
    read -p "Ingrese el nombre del nuevo usuario: " usuario

    if id "$usuario" &>/dev/null; then
        echo "El usuario ya existe."
        return
    fi

    sudo useradd -m -s /bin/bash "$usuario"

    if [ $? -eq 0 ]; then
        echo "Usuario creado correctamente."
        sudo passwd "$usuario"
    else
        echo "Error al crear el usuario."
    fi
}

modificar_usuario() {
    read -p "Ingrese el usuario a modificar: " usuario

    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    read -p "Ingrese el nuevo nombre del usuario: " nuevo_nombre

    sudo usermod -l "$nuevo_nombre" "$usuario"

    echo "Usuario modificado correctamente."
}

eliminar_usuario() {
    read -p "Ingrese el usuario a eliminar: " usuario

    if ! id "$usuario" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    read -p "¿Está seguro de eliminar $usuario? (s/n): " confirmacion

    if [ "$confirmacion" = "s" ]; then
        sudo userdel -r "$usuario"
        echo "Usuario eliminado correctamente."
    else
        echo "Operación cancelada."
    fi
}

menu_usuarios() {

    while true; do

        echo ""
        echo "===== GESTIÓN DE USUARIOS ====="
        echo "1. Crear usuario"
        echo "2. Modificar usuario"
        echo "3. Eliminar usuario"
        echo "4. Volver"

        read -p "Seleccione una opción: " opcion

        case $opcion in

            1)
                crear_usuario
                ;;

            2)
                modificar_usuario
                ;;

            3)
                eliminar_usuario
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

menu_usuarios
