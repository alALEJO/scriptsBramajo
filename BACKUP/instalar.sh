#!/bin/bash
# =============================================================================
#  instalar.sh - Instalacion de los scripts de mantenimiento de Bramajo
#
#  Proyecto:    SGDM Bramajo - Empresa BoomeRam
#  Asignatura:  Administracion de Sistemas Operativos
#
#  Que hace: deja el servidor listo para la operacion automatica.
#            Copia los scripts, crea las carpetas, guarda las contrasenas
#            con permisos restringidos y programa las tareas en cron.
#
#  Uso:  sudo ./instalar.sh
#  Se ejecuta UNA sola vez, al preparar el servidor.
# =============================================================================

set -euo pipefail

DIR_SCRIPTS="/opt/bramajo/scripts"
DIR_CONFIG="/etc/bramajo"
DIR_RESPALDOS="/var/backups/bramajo"

# -----------------------------------------------------------------------------
# PASO 0 - COMPROBAR QUE SE EJECUTA COMO ROOT
# -----------------------------------------------------------------------------
# $EUID es el identificador del usuario que ejecuta el script. El 0 es root.
# Necesitamos root porque escribimos en /etc, /opt y /var.
# -----------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: este script debe ejecutarse con sudo."
    echo "Uso: sudo $0"
    exit 1
fi

echo "=== Instalacion de los scripts de Bramajo ==="

# Nos paramos en la carpeta donde esta este script, para que las rutas
# relativas funcionen aunque se lo invoque desde otro directorio.
cd "$(dirname "$0")"

# -----------------------------------------------------------------------------
# PASO 1 - CREAR LAS CARPETAS
# -----------------------------------------------------------------------------
echo "[1/5] Creando carpetas..."
mkdir -p "$DIR_SCRIPTS" "$DIR_CONFIG" "$DIR_RESPALDOS"

# La carpeta de configuracion contiene contrasenas: solo root puede entrar.
# 700 = lectura, escritura y acceso solo para el dueno (root).
chmod 700 "$DIR_CONFIG"

# La carpeta de respaldos tambien se restringe: contiene todos los datos.
chmod 700 "$DIR_RESPALDOS"

# -----------------------------------------------------------------------------
# PASO 2 - COPIAR LOS SCRIPTS Y DARLES PERMISO DE EJECUCION
# -----------------------------------------------------------------------------
echo "[2/5] Instalando scripts en ${DIR_SCRIPTS}..."
cp backup.sh restaurar.sh mantenimiento.sh "$DIR_SCRIPTS/"

# 750 = el dueno (root) puede leer, escribir y ejecutar; el grupo solo leer y
#       ejecutar; el resto de los usuarios, nada.
chmod 750 "$DIR_SCRIPTS"/*.sh

# -----------------------------------------------------------------------------
# PASO 3 - CREAR LOS ARCHIVOS DE CONTRASENA
# -----------------------------------------------------------------------------
# Los scripts leen las contrasenas de archivos en lugar de tenerlas escritas
# adentro. Asi el codigo puede subirse al repositorio sin filtrar credenciales,
# que es lo que exige la politica de seguridad del proyecto.
#
# chmod 600 = solo root puede leer y escribir el archivo. Nadie mas lo ve.
# -----------------------------------------------------------------------------
echo "[3/5] Configurando archivos de contrasena..."

crear_archivo_pass() {
    local ruta="$1"
    local descripcion="$2"
    local valor

    if [ -f "$ruta" ]; then
        echo "      ${ruta} ya existe, se conserva."
        return
    fi

    # read -s oculta lo que se escribe, para que la contrasena no quede
    # visible en la pantalla ni en el historial de la terminal.
    read -r -s -p "      Contrasena de ${descripcion}: " valor
    echo ""
    printf '%s' "$valor" > "$ruta"
    chmod 600 "$ruta"
    echo "      ${ruta} creado con permisos 600."
}

crear_archivo_pass "${DIR_CONFIG}/backup.pass" "bramajo_backup (usuario de respaldo)"
crear_archivo_pass "${DIR_CONFIG}/app.pass"    "bramajo_app (usuario de la aplicacion)"
crear_archivo_pass "${DIR_CONFIG}/root.pass"   "root de MySQL (solo para restaurar)"

# -----------------------------------------------------------------------------
# PASO 4 - PREPARAR LOS ARCHIVOS DE REGISTRO
# -----------------------------------------------------------------------------
echo "[4/5] Preparando archivos de log..."
touch /var/log/bramajo-backup.log /var/log/bramajo-mantenimiento.log
chmod 640 /var/log/bramajo-*.log

# Rotacion de logs: sin esto los archivos crecen sin limite.
# logrotate ya viene instalado en AlmaLinux; solo hay que darle la regla.
cat > /etc/logrotate.d/bramajo <<'FIN'
/var/log/bramajo-*.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
    create 640 root root
}
FIN
echo "      Rotacion de logs configurada (8 semanas)."

# -----------------------------------------------------------------------------
# PASO 5 - PROGRAMAR LAS TAREAS EN CRON
# -----------------------------------------------------------------------------
# Se crea un archivo en /etc/cron.d/ en lugar de usar 'crontab -e'.
# Ventaja: queda versionado en el repositorio y es reproducible. Si hay que
# reinstalar el servidor, se copia el archivo y listo.
#
# Formato de cada linea:
#   minuto  hora  dia_del_mes  mes  dia_de_semana  usuario  comando
#
#   0  2  * * *   -> todos los dias a las 02:00
#   0  *  * * *   -> todos los dias, en el minuto 0 de cada hora
# -----------------------------------------------------------------------------
echo "[5/5] Programando tareas en cron..."

cat > /etc/cron.d/bramajo <<'FIN'
# Tareas automaticas del sistema Bramajo
# El PATH es necesario porque cron se ejecuta con un entorno minimo
# y no encontraria los comandos docker, gzip, etc. sin esta linea.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Respaldo completo de la base, todos los dias a las 02:00
0 2 * * *  root  /opt/bramajo/scripts/backup.sh

# Mantenimiento (tokens vencidos y bloqueos expirados), cada hora
0 * * * *  root  /opt/bramajo/scripts/mantenimiento.sh
FIN

chmod 644 /etc/cron.d/bramajo

# En AlmaLinux el servicio se llama crond.
systemctl restart crond

echo ""
echo "=== Instalacion completada ==="
echo ""
echo "Tareas programadas:"
echo "  - Respaldo:      todos los dias a las 02:00"
echo "  - Mantenimiento: cada hora en punto"
echo ""
echo "Para probar el respaldo ahora mismo:"
echo "  sudo ${DIR_SCRIPTS}/backup.sh"
echo ""
echo "Para ver el registro:"
echo "  tail -f /var/log/bramajo-backup.log"

exit 0
