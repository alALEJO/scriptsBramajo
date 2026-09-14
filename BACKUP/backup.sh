#!/bin/bash
# =============================================================================
#  backup.sh - Respaldo automatico de la base de datos de Bramajo
#
#  Proyecto:    SGDM Bramajo - Empresa BoomeRam
#  Asignatura:  Administracion de Sistemas Operativos
#  Servidor:    VM AlmaLinux sobre Proxmox
#
#  Que hace: genera un respaldo completo y comprimido de la base MySQL que
#            corre dentro del contenedor Docker, lo verifica, y borra los
#            respaldos mas viejos que el periodo de retencion definido.
#
#  Uso:      ./backup.sh
#  Cron:     todos los dias a las 02:00 (ver instalar-cron.sh)
# =============================================================================

# -----------------------------------------------------------------------------
# MODO ESTRICTO
# -----------------------------------------------------------------------------
# Estas tres opciones hacen que el script se detenga ante cualquier problema,
# en lugar de seguir adelante y dejar un respaldo a medias (que es peor que
# no tener respaldo, porque da falsa seguridad).
#
#   -e  : si un comando falla, el script termina inmediatamente
#   -u  : usar una variable que no fue definida es un error
#   -o pipefail : en una tuberia (a | b), si falla cualquiera de las dos, falla todo
# -----------------------------------------------------------------------------
set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURACION
# -----------------------------------------------------------------------------
CONTENEDOR_DB="bramajo_db"                    # nombre del contenedor de MySQL
BASE="bramajo"                                # nombre de la base de datos
USUARIO_BD="bramajo_backup"                   # usuario de MySQL de solo lectura
ARCHIVO_PASS="/etc/bramajo/backup.pass"       # archivo con la contrasena (chmod 600)
DIR_RESPALDOS="/var/backups/bramajo"          # donde se guardan los respaldos
DIAS_RETENCION=14                             # cuantos dias se conservan
LOG="/var/log/bramajo-backup.log"             # archivo de registro

# Nombre del archivo: incluye fecha y hora para no pisar respaldos anteriores.
# Formato: bramajo_2026-09-14_020000.sql.gz
FECHA=$(date +%Y-%m-%d_%H%M%S)
ARCHIVO_DESTINO="${DIR_RESPALDOS}/bramajo_${FECHA}.sql.gz"

# -----------------------------------------------------------------------------
# FUNCION DE REGISTRO
# -----------------------------------------------------------------------------
# Escribe cada mensaje con fecha y hora, tanto en pantalla como en el log.
# Esto es lo que permite despues demostrar que el respaldo se ejecuto.
# -----------------------------------------------------------------------------
registrar() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# Si el script falla en cualquier punto, esta linea deja constancia en el log.
# 'trap' captura la senal ERR, que se dispara cuando un comando devuelve error.
trap 'registrar "ERROR: el respaldo fallo en la linea $LINENO"' ERR

registrar "===== Inicio del respaldo ====="

# -----------------------------------------------------------------------------
# PASO 1 - VERIFICACIONES PREVIAS
# -----------------------------------------------------------------------------
# Antes de intentar respaldar comprobamos que todo lo necesario exista.
# Es preferible fallar aca con un mensaje claro que a mitad del proceso.
# -----------------------------------------------------------------------------

# El contenedor de la base tiene que estar corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTENEDOR_DB}$"; then
    registrar "ERROR: el contenedor ${CONTENEDOR_DB} no esta corriendo."
    exit 1
fi

# El archivo con la contrasena tiene que existir
if [ ! -f "$ARCHIVO_PASS" ]; then
    registrar "ERROR: no se encuentra el archivo de contrasena ${ARCHIVO_PASS}"
    exit 1
fi

# Creamos la carpeta de respaldos si no existe. -p evita error si ya existe.
mkdir -p "$DIR_RESPALDOS"

# -----------------------------------------------------------------------------
# PASO 2 - GENERAR EL RESPALDO
# -----------------------------------------------------------------------------
# mysqldump se ejecuta DENTRO del contenedor (docker exec), porque el motor
# MySQL vive ahi. La salida viaja por la tuberia hacia gzip, que la comprime
# en el servidor. Nunca se escribe el .sql sin comprimir en disco.
#
# Opciones de mysqldump:
#   --single-transaction : toma una foto consistente de la base sin bloquearla,
#                          asi la aplicacion sigue funcionando durante el respaldo
#   --routines           : incluye procedimientos y funciones almacenadas
#   --events             : incluye eventos programados
#
# Sobre la contrasena: se pasa como variable de entorno MYSQL_PWD al contenedor
# en lugar de usar la opcion -p, porque -p deja la contrasena visible para
# cualquiera que ejecute 'ps' mientras corre el respaldo.
# -----------------------------------------------------------------------------
registrar "Generando respaldo de la base '${BASE}'..."

PASS=$(cat "$ARCHIVO_PASS")

docker exec -e MYSQL_PWD="$PASS" "$CONTENEDOR_DB" \
    mysqldump \
        --user="$USUARIO_BD" \
        --single-transaction \
        --routines \
        --events \
        "$BASE" \
    | gzip > "$ARCHIVO_DESTINO"

# -----------------------------------------------------------------------------
# PASO 3 - VERIFICAR EL RESPALDO
# -----------------------------------------------------------------------------
# Un respaldo que no se verifica no es un respaldo. Comprobamos dos cosas:
#
#   1) Que el archivo comprimido no este corrupto  ->  gzip -t
#
#   2) Que el volcado este COMPLETO. mysqldump escribe al final de su salida
#      una linea que dice "-- Dump completed on ...". Si esa linea esta, el
#      volcado llego hasta el final; si no esta, se corto a la mitad (por
#      ejemplo si se lleno el disco o se cayo la conexion con la base).
#
#      Esta comprobacion es mejor que mirar el tamano del archivo, porque un
#      respaldo legitimo de una base con pocos datos puede pesar muy poco y
#      aun asi ser perfectamente valido.
# -----------------------------------------------------------------------------
registrar "Verificando el archivo generado..."

# 1) Integridad del comprimido
if ! gzip -t "$ARCHIVO_DESTINO"; then
    registrar "ERROR: el archivo comprimido esta corrupto. Se elimina."
    rm -f "$ARCHIVO_DESTINO"
    exit 1
fi

# 2) Marca de volcado completo
#    zcat descomprime hacia la salida; tail -5 mira solo las ultimas lineas;
#    grep -q busca el texto sin imprimir nada (-q = modo silencioso).
if ! zcat "$ARCHIVO_DESTINO" | tail -5 | grep -q "Dump completed"; then
    registrar "ERROR: el volcado esta incompleto (falta la marca final). Se elimina."
    rm -f "$ARCHIVO_DESTINO"
    exit 1
fi

TAMANO_LEGIBLE=$(du -h "$ARCHIVO_DESTINO" | cut -f1)
registrar "Respaldo verificado correctamente: ${ARCHIVO_DESTINO} (${TAMANO_LEGIBLE})"

# -----------------------------------------------------------------------------
# PASO 4 - ROTACION: BORRAR RESPALDOS VIEJOS
# -----------------------------------------------------------------------------
# Sin esto el disco se llena con el tiempo y el servidor deja de funcionar.
#
#   find  DIRECTORIO  -name PATRON  -mtime +N  -delete
#
#   -mtime +14  significa "modificado hace mas de 14 dias"
#   -delete     los borra
# -----------------------------------------------------------------------------
registrar "Eliminando respaldos con mas de ${DIAS_RETENCION} dias..."

CANTIDAD_BORRADOS=$(find "$DIR_RESPALDOS" -name "bramajo_*.sql.gz" -mtime +"$DIAS_RETENCION" | wc -l)
find "$DIR_RESPALDOS" -name "bramajo_*.sql.gz" -mtime +"$DIAS_RETENCION" -delete

registrar "Respaldos eliminados: ${CANTIDAD_BORRADOS}"

# -----------------------------------------------------------------------------
# PASO 5 - RESUMEN
# -----------------------------------------------------------------------------
CANTIDAD_TOTAL=$(find "$DIR_RESPALDOS" -name "bramajo_*.sql.gz" | wc -l)
ESPACIO_TOTAL=$(du -sh "$DIR_RESPALDOS" | cut -f1)

registrar "Respaldos disponibles: ${CANTIDAD_TOTAL} - Espacio ocupado: ${ESPACIO_TOTAL}"
registrar "===== Respaldo finalizado con exito ====="

exit 0
