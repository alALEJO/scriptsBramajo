#!/bin/bash
# =============================================================================
#  restaurar.sh - Restauracion de un respaldo de la base de datos Bramajo
#
#  Proyecto:    SGDM Bramajo - Empresa BoomeRam
#  Asignatura:  Administracion de Sistemas Operativos
#
#  Por que existe este script:
#     Un respaldo que nunca se probo NO es un respaldo. Este script es la
#     otra mitad de la politica: demuestra que los archivos generados por
#     backup.sh efectivamente sirven para recuperar el sistema.
#
#  Uso:  ./restaurar.sh /var/backups/bramajo/bramajo_2026-09-14_020000.sql.gz
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURACION
# -----------------------------------------------------------------------------
CONTENEDOR_DB="bramajo_db"
BASE="bramajo"
USUARIO_BD="root"                             # restaurar requiere permisos de escritura
ARCHIVO_PASS="/etc/bramajo/root.pass"
LOG="/var/log/bramajo-backup.log"

registrar() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# -----------------------------------------------------------------------------
# PASO 1 - VALIDAR EL ARGUMENTO
# -----------------------------------------------------------------------------
# $# es la cantidad de argumentos recibidos. Si no recibimos exactamente uno,
# mostramos como se usa el script y salimos.
# -----------------------------------------------------------------------------
if [ $# -ne 1 ]; then
    echo "Uso: $0 <archivo_de_respaldo.sql.gz>"
    echo ""
    echo "Respaldos disponibles:"
    ls -1sh /var/backups/bramajo/bramajo_*.sql.gz 2>/dev/null || echo "  (ninguno)"
    exit 1
fi

ARCHIVO="$1"

if [ ! -f "$ARCHIVO" ]; then
    echo "ERROR: el archivo '$ARCHIVO' no existe."
    exit 1
fi

# Comprobamos que el archivo comprimido este intacto antes de tocar la base.
if ! gzip -t "$ARCHIVO"; then
    echo "ERROR: el archivo esta corrupto. No se restaura nada."
    exit 1
fi

# -----------------------------------------------------------------------------
# PASO 2 - CONFIRMACION DEL OPERADOR
# -----------------------------------------------------------------------------
# Restaurar SOBRESCRIBE la base actual. Es una operacion destructiva, asi que
# pedimos una confirmacion explicita escrita, no un simple "s/n" que se puede
# apretar sin leer.
# -----------------------------------------------------------------------------
echo "======================================================================"
echo "  ATENCION: esta operacion REEMPLAZA el contenido actual de la base"
echo "            '${BASE}' por el del archivo:"
echo ""
echo "            ${ARCHIVO}"
echo ""
echo "  Todos los datos actuales que no esten en ese respaldo se PIERDEN."
echo "======================================================================"
echo ""
read -r -p "Para continuar escriba exactamente: RESTAURAR > " CONFIRMACION

if [ "$CONFIRMACION" != "RESTAURAR" ]; then
    echo "Operacion cancelada. No se modifico nada."
    exit 0
fi

# -----------------------------------------------------------------------------
# PASO 3 - RESPALDO DE SEGURIDAD ANTES DE RESTAURAR
# -----------------------------------------------------------------------------
# Antes de sobrescribir, guardamos el estado actual. Si la restauracion sale
# mal o el respaldo elegido era el equivocado, todavia se puede volver atras.
# -----------------------------------------------------------------------------
registrar "Restauracion solicitada desde ${ARCHIVO}"
registrar "Generando respaldo de seguridad del estado actual..."

PASS=$(cat "$ARCHIVO_PASS")
RESPALDO_PREVIO="/var/backups/bramajo/PREVIO_$(date +%Y-%m-%d_%H%M%S).sql.gz"

docker exec -e MYSQL_PWD="$PASS" "$CONTENEDOR_DB" \
    mysqldump --user="$USUARIO_BD" --single-transaction "$BASE" \
    | gzip > "$RESPALDO_PREVIO"

registrar "Estado previo guardado en ${RESPALDO_PREVIO}"

# -----------------------------------------------------------------------------
# PASO 4 - RESTAURAR
# -----------------------------------------------------------------------------
# zcat descomprime el archivo y lo envia por la tuberia al cliente mysql que
# corre dentro del contenedor. La opcion -i de docker exec mantiene abierta la
# entrada estandar, que es por donde entra el SQL.
# -----------------------------------------------------------------------------
registrar "Restaurando la base de datos..."

zcat "$ARCHIVO" | docker exec -i -e MYSQL_PWD="$PASS" "$CONTENEDOR_DB" \
    mysql --user="$USUARIO_BD" "$BASE"

registrar "Restauracion completada."

# -----------------------------------------------------------------------------
# PASO 5 - VERIFICACION POSTERIOR
# -----------------------------------------------------------------------------
# Contamos las tablas de la base. Si quedaron en cero, algo salio mal y hay
# que revisar antes de dar la restauracion por buena.
# -----------------------------------------------------------------------------
CANTIDAD_TABLAS=$(docker exec -e MYSQL_PWD="$PASS" "$CONTENEDOR_DB" \
    mysql --user="$USUARIO_BD" --skip-column-names --batch \
    --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${BASE}';")

registrar "Tablas presentes tras la restauracion: ${CANTIDAD_TABLAS}"

if [ "$CANTIDAD_TABLAS" -eq 0 ]; then
    registrar "ERROR: la base quedo vacia. Revisar el respaldo utilizado."
    echo ""
    echo "Puede volver al estado anterior con:"
    echo "  $0 ${RESPALDO_PREVIO}"
    exit 1
fi

echo ""
registrar "===== Restauracion verificada con exito ====="
echo ""
echo "Si el resultado no es el esperado, puede volver atras con:"
echo "  $0 ${RESPALDO_PREVIO}"

exit 0
