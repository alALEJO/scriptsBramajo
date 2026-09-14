#!/bin/bash
# =============================================================================
#  comun.sh - Funciones que usan todos los demas scripts
#
#  Proyecto:   SGDM Bramajo - Empresa BoomeRam
#  Asignatura: Administracion de Sistemas Operativos
#
#  Este archivo no se ejecuta solo. Los otros scripts lo cargan asi:
#      source "$DIR/comun.sh"
#
#  Sirve para no repetir las mismas comprobaciones en los cinco archivos.
# =============================================================================


# -----------------------------------------------------------------------------
# UID_MINIMO
# -----------------------------------------------------------------------------
# En Linux cada usuario tiene un numero (UID).
#   - Menor a 1000  -> cuenta del sistema (root, mysql, apache...)
#   - 1000 o mayor  -> persona real
#
# Guardamos ese numero en una variable para poder comparar mas abajo.
# -----------------------------------------------------------------------------
UID_MINIMO=1000


# -----------------------------------------------------------------------------
# usuario_existe <nombre>
# -----------------------------------------------------------------------------
# El comando 'id' devuelve informacion de un usuario.
# Si el usuario no existe, 'id' falla.
# &>/dev/null oculta la salida: solo nos interesa si funciono o no.
# -----------------------------------------------------------------------------
usuario_existe() {
    id "$1" &>/dev/null
}


# -----------------------------------------------------------------------------
# grupo_existe <nombre>
# -----------------------------------------------------------------------------
# 'getent group' busca un grupo en el sistema. Si no lo encuentra, falla.
# -----------------------------------------------------------------------------
grupo_existe() {
    getent group "$1" &>/dev/null
}


# -----------------------------------------------------------------------------
# es_cuenta_del_sistema <usuario>
# -----------------------------------------------------------------------------
# Sirve para NO dejar que se borre root, mysql o apache por error.
#
#   id -u usuario   ->  devuelve el numero (UID) de ese usuario
#   [ $uid -lt 1000 ]  ->  "-lt" significa "menor que" (less than)
# -----------------------------------------------------------------------------
es_cuenta_del_sistema() {
    local uid
    uid=$(id -u "$1")
    [ "$uid" -lt "$UID_MINIMO" ]
}


# -----------------------------------------------------------------------------
# es_grupo_del_sistema <grupo>
# -----------------------------------------------------------------------------
# Igual que la anterior pero con grupos.
#
# 'getent group docker' devuelve una linea asi:   docker:x:988:bruno
# Los campos van separados por ":" y el numero del grupo (GID) es el tercero.
# Con 'cut -d: -f3' nos quedamos con ese tercer campo.
# -----------------------------------------------------------------------------
es_grupo_del_sistema() {
    local gid
    gid=$(getent group "$1" | cut -d: -f3)
    [ "$gid" -lt "$UID_MINIMO" ]
}


# -----------------------------------------------------------------------------
# pertenece_al_grupo <usuario> <grupo>
# -----------------------------------------------------------------------------
#   id -nG usuario   ->  lista los grupos del usuario separados por espacios
#   grep -qw grupo   ->  busca esa palabra completa
#                        -w = palabra entera (para que "admin" no coincida
#                             con "administradores")
#                        -q = silencioso, no imprime nada
# -----------------------------------------------------------------------------
pertenece_al_grupo() {
    id -nG "$1" | grep -qw "$2"
}


# -----------------------------------------------------------------------------
# nombre_valido <nombre>
# -----------------------------------------------------------------------------
# Linux solo acepta nombres de usuario en minusculas, sin espacios ni acentos.
# Si no validamos esto, 'useradd' falla con un mensaje confuso.
#
# El patron  ^[a-z][a-z0-9_-]*$  significa:
#   ^          empieza
#   [a-z]      con una letra minuscula
#   [a-z0-9_-]* y sigue con minusculas, numeros, guion bajo o guion
#   $          y ahi termina
# -----------------------------------------------------------------------------
nombre_valido() {
    [[ "$1" =~ ^[a-z][a-z0-9_-]*$ ]]
}


# -----------------------------------------------------------------------------
# confirmar <pregunta>
# -----------------------------------------------------------------------------
# Pide confirmacion antes de borrar algo.
# Devuelve exito solo si la respuesta es "s" o "S".
# -----------------------------------------------------------------------------
confirmar() {
    local respuesta
    read -r -p "$1 (s/n): " respuesta
    [ "$respuesta" = "s" ] || [ "$respuesta" = "S" ]
}
