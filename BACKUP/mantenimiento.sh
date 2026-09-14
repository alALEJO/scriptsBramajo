#!/bin/bash
# =============================================================================
#  mantenimiento.sh - Limpieza periodica de la base de datos Bramajo
#
#  Proyecto:    SGDM Bramajo - Empresa BoomeRam
#  Asignatura:  Administracion de Sistemas Operativos
#
#  Que hace: dos tareas de higiene que surgen directamente de los requisitos
#            de seguridad del sistema.
#
#    1) Borra los tokens de recuperacion de contrasena ya vencidos.
#       Requisito RF-USR-04: el token vale 30 minutos. Pasado ese tiempo no
#       sirve para nada, y si no se borran la tabla crece indefinidamente.
#
#    2) Libera las cuentas cuyo bloqueo temporal ya expiro.
#       Requisito RF-USR-06: 5 intentos fallidos bloquean 15 minutos.
#       La aplicacion tambien lo verifica al iniciar sesion, pero dejar los
#       registros limpios evita confusiones al consultar la tabla.
#
#  Uso:   ./mantenimiento.sh
#  Cron:  cada hora (ver instalar-cron.sh)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURACION
# -----------------------------------------------------------------------------
CONTENEDOR_DB="bramajo_db"
BASE="bramajo"
USUARIO_BD="bramajo_app"                      # necesita permisos de UPDATE y DELETE
ARCHIVO_PASS="/etc/bramajo/app.pass"
LOG="/var/log/bramajo-mantenimiento.log"

registrar() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

trap 'registrar "ERROR: el mantenimiento fallo en la linea $LINENO"' ERR

# -----------------------------------------------------------------------------
# FUNCION AUXILIAR
# -----------------------------------------------------------------------------
# Ejecuta una consulta SQL dentro del contenedor y devuelve el resultado.
#   --skip-column-names : no imprime el encabezado, solo el valor
#   --batch             : salida en texto plano, sin bordes de tabla
# -----------------------------------------------------------------------------
consultar() {
    docker exec -e MYSQL_PWD="$PASS" "$CONTENEDOR_DB" \
        mysql --user="$USUARIO_BD" --skip-column-names --batch \
              --execute="$1" "$BASE"
}

# -----------------------------------------------------------------------------
# VERIFICACIONES PREVIAS
# -----------------------------------------------------------------------------
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTENEDOR_DB}$"; then
    registrar "ERROR: el contenedor ${CONTENEDOR_DB} no esta corriendo."
    exit 1
fi

PASS=$(cat "$ARCHIVO_PASS")

registrar "===== Inicio del mantenimiento ====="

# -----------------------------------------------------------------------------
# TAREA 1 - TOKENS DE RECUPERACION VENCIDOS
# -----------------------------------------------------------------------------
# Primero contamos cuantos hay (para poder registrarlo) y despues los borramos.
# Se eliminan tanto los vencidos como los que ya fueron usados: en ambos casos
# son inservibles y solo ocupan espacio.
# -----------------------------------------------------------------------------
TOKENS=$(consultar "SELECT COUNT(*) FROM TokenRecuperacion WHERE fecha_expiracion < NOW() OR usado = 1;")

if [ "$TOKENS" -gt 0 ]; then
    consultar "DELETE FROM TokenRecuperacion WHERE fecha_expiracion < NOW() OR usado = 1;"
    registrar "Tokens de recuperacion eliminados: ${TOKENS}"
else
    registrar "No habia tokens vencidos para eliminar."
fi

# -----------------------------------------------------------------------------
# TAREA 2 - LIBERAR BLOQUEOS EXPIRADOS
# -----------------------------------------------------------------------------
# Buscamos las cuentas con bloqueado_hasta en el pasado y las liberamos,
# reiniciando ademas el contador de intentos fallidos.
# -----------------------------------------------------------------------------
BLOQUEADOS=$(consultar "SELECT COUNT(*) FROM Usuario WHERE bloqueado_hasta IS NOT NULL AND bloqueado_hasta < NOW();")

if [ "$BLOQUEADOS" -gt 0 ]; then
    consultar "UPDATE Usuario SET bloqueado_hasta = NULL, intentos_fallidos = 0 WHERE bloqueado_hasta IS NOT NULL AND bloqueado_hasta < NOW();"
    registrar "Cuentas liberadas por vencimiento del bloqueo: ${BLOQUEADOS}"
else
    registrar "No habia cuentas con bloqueo vencido."
fi

# -----------------------------------------------------------------------------
# TAREA 3 - INFORME DE ESTADO
# -----------------------------------------------------------------------------
# Deja en el log algunos numeros utiles para el monitoreo y para demostrar
# en la defensa que el sistema esta vivo y siendo mantenido.
# -----------------------------------------------------------------------------
USUARIOS=$(consultar "SELECT COUNT(*) FROM Usuario WHERE activo = 1;")
TORNEOS=$(consultar "SELECT COUNT(*) FROM Torneo;")
BLOQUEOS_ACTIVOS=$(consultar "SELECT COUNT(*) FROM Usuario WHERE bloqueado_hasta IS NOT NULL AND bloqueado_hasta >= NOW();")

registrar "Estado: ${USUARIOS} usuarios activos | ${TORNEOS} torneos | ${BLOQUEOS_ACTIVOS} cuentas bloqueadas ahora"
registrar "===== Mantenimiento finalizado ====="

exit 0
