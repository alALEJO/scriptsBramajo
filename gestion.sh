#!/bin/bash

while true; do

    echo ""
    echo "===================================="
    echo " SISTEMA DE GESTIÓN DEL SERVIDOR"
    echo "            BRAMAJO"
    echo "===================================="

    echo "1. Gestión de usuarios"
    echo "2. Gestión de grupos"
    echo "3. Asignación de grupos"
    echo "4. Consultar usuarios y grupos"
    echo "5. Salir"

    read -p "Seleccione una opción: " opcion

    case $opcion in

        1)
            bash ./usuarios.sh
            ;;

        2)
            bash ./grupos.sh
            ;;

        3)
            bash ./registrar_grupo.sh
            ;;

        4)
            bash ./listar.sh
            ;;

        5)
            echo "Saliendo del sistema..."
            exit 0
            ;;

        *)
            echo "Opción inválida."
            ;;

    esac

done
