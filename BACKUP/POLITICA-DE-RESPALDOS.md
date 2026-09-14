# Política de respaldos — Sistema Bramajo

**Empresa:** BoomeRam · **Asignatura:** Administración de Sistemas Operativos
**Servidor:** VM AlmaLinux sobre Proxmox (servidor institucional)

Este documento cubre el entregable *"Política de respaldos: tipos de respaldos a utilizar y cronograma de respaldo definido"*.

---

## 1. Qué se respalda y por qué

| Elemento | ¿Se respalda? | Justificación |
|---|---|---|
| Base de datos MySQL | **Sí, a diario** | Es el único dato irrecuperable. Torneos, resultados y usuarios no se pueden regenerar |
| Código fuente | **No por script** | Ya está versionado en Git. Respaldarlo sería duplicar |
| Archivos de configuración (`.env`, contraseñas) | **Sí, en el snapshot de VM** | No están en Git por seguridad, pero son necesarios para levantar el sistema |
| Imágenes de Docker | **No** | Se reconstruyen con `docker compose build` a partir del Dockerfile versionado |
| Sistema operativo | **Sí, semanal** | Snapshot de VM, para recuperar el servidor completo ante un desastre |

El criterio es simple: **se respalda lo que no se puede regenerar**. Todo lo que se puede reconstruir desde el repositorio no ocupa espacio de respaldo.

---

## 2. Tipos de respaldo utilizados

Se implementan dos niveles complementarios.

### Nivel 1 — Respaldo completo de la base de datos (diario)

- **Tipo:** completo (*full backup*)
- **Herramienta:** `mysqldump` + `gzip`, mediante el script `backup.sh`
- **Frecuencia:** diaria, 02:00
- **Retención:** 14 días
- **Ubicación:** `/var/backups/bramajo/`

**Por qué completo y no incremental.** Un respaldo incremental solo guarda lo cambiado desde el anterior, lo que ahorra espacio pero obliga a encadenar varios archivos para restaurar: si uno de la cadena se corrompe, se pierde todo lo posterior. Para el volumen de este sistema —torneos amateur, base de pocos MB comprimidos— el ahorro de espacio es irrelevante frente al riesgo. Un respaldo completo diario permite restaurar con **un solo archivo**, que es lo que importa cuando algo falló y hay que actuar rápido.

Si el sistema creciera a decenas de GB, la decisión debería revisarse hacia un esquema completo semanal + incremental diario.

### Nivel 2 — Snapshot de la máquina virtual (semanal)

- **Tipo:** imagen completa de la VM
- **Herramienta:** sistema de backup integrado de Proxmox
- **Frecuencia:** semanal, domingos
- **Retención:** 4 semanas

Recupera **el servidor entero**: sistema operativo, Docker, configuración, certificados y archivos de contraseñas. Es el que se usa ante una falla grave de hardware o una corrupción del sistema, no ante la pérdida de un dato puntual.

### Por qué dos niveles

Responden a escenarios distintos:

| Escenario | Nivel que se usa | Tiempo de recuperación |
|---|---|---|
| Se borró un torneo por error | Nivel 1 | Minutos |
| La base se corrompió | Nivel 1 | Minutos |
| Falló el disco del servidor | Nivel 2 | Horas |
| Hay que migrar a otro hardware | Nivel 2 | Horas |

---

## 3. Cronograma

| Tarea | Frecuencia | Horario | Automatización | Retención |
|---|---|---|---|---|
| Respaldo completo de la base | Diaria | 02:00 | `cron` → `backup.sh` | 14 días |
| Mantenimiento de la base | Cada hora | Minuto 0 | `cron` → `mantenimiento.sh` | — |
| Snapshot de la VM | Semanal | Domingo 03:00 | Proxmox | 4 semanas |
| Rotación de logs | Semanal | — | `logrotate` | 8 semanas |
| **Prueba de restauración** | **Mensual** | Manual | `restaurar.sh` | — |

Las 02:00 se eligieron por ser el horario de menor actividad esperada. El snapshot va a las 03:00 para que no se solape con el respaldo de la base.

**La prueba de restauración mensual no es opcional.** Un respaldo que nunca se restauró es una suposición, no un respaldo. Es la parte que la mayoría de los proyectos omite y la que conviene poder mostrar en la defensa.

---

## 4. Los scripts

| Script | Qué hace | Cuándo corre |
|---|---|---|
| `backup.sh` | Genera, verifica y rota los respaldos de la base | Automático, diario |
| `restaurar.sh` | Restaura un respaldo, con confirmación y respaldo previo de seguridad | Manual |
| `mantenimiento.sh` | Borra tokens vencidos y libera bloqueos expirados | Automático, cada hora |
| `instalar.sh` | Deja el servidor configurado. Se ejecuta una sola vez | Manual, en la instalación |

### Instalación

```bash
sudo ./instalar.sh
```

Crea las carpetas, pide las contraseñas y las guarda con permisos `600`, configura `logrotate` y programa las tareas en `/etc/cron.d/bramajo`.

### Prueba manual

```bash
sudo /opt/bramajo/scripts/backup.sh
tail -20 /var/log/bramajo-backup.log
ls -lh /var/backups/bramajo/
```

### Restauración

```bash
sudo /opt/bramajo/scripts/restaurar.sh /var/backups/bramajo/bramajo_2026-09-14_020000.sql.gz
```

Pide escribir `RESTAURAR` para confirmar, y antes de sobrescribir genera un respaldo del estado actual con prefijo `PREVIO_`, por si hubo que volver atrás.

---

## 5. Decisiones de seguridad aplicadas

Cada una responde a un requisito del proyecto:

**Las contraseñas no están en los scripts.** Viven en `/etc/bramajo/*.pass` con permisos `600` (solo root). Así los scripts pueden versionarse en Git sin filtrar credenciales, como exige la política de desarrollo seguro.

**El respaldo usa un usuario de solo lectura.** `bramajo_backup` tiene únicamente `SELECT`, `LOCK TABLES` y `SHOW VIEW`. Si el script se viera comprometido, no podría modificar ni borrar datos. Aplica el principio de mínimo privilegio (RNF-11).

**La contraseña se pasa por variable de entorno, no por línea de comandos.** Usar `mysqldump -pCLAVE` deja la contraseña visible para cualquier usuario que ejecute `ps` mientras corre el respaldo. Con `MYSQL_PWD` eso no ocurre.

**Las carpetas de respaldo y configuración son `700`.** Los respaldos contienen todos los datos del sistema, incluidos los hash de contraseñas: merecen la misma protección que la base.

**`--single-transaction`.** Toma una foto consistente sin bloquear las tablas, de modo que la aplicación sigue respondiendo durante el respaldo.

**Cada respaldo se verifica.** Se comprueba integridad del archivo comprimido (`gzip -t`) y tamaño mínimo. Si algo falla, el archivo se elimina y queda registrado el error, para no acumular respaldos inservibles.

---

## 6. Cómo demostrarlo en la entrega

Evidencia a adjuntar como anexo:

1. Captura de `/etc/cron.d/bramajo` mostrando las tareas programadas
2. Captura de `ls -lh /var/backups/bramajo/` con varios respaldos de días distintos
3. Extracto de `/var/log/bramajo-backup.log` con ejecuciones exitosas
4. Captura de una **restauración completa** ejecutada y verificada
5. Captura de la configuración de backup de la VM en Proxmox
6. Salida de `ls -l /etc/bramajo/` mostrando los permisos `600`

El punto 4 es el que diferencia una política real de una declarativa.

---

## 7. Pendientes reconocidos

Conviene documentarlos: mostrar que se conocen los límites de la solución suma más que ocultarlos.

- **Los respaldos están en el mismo servidor que la base.** Si se pierde el disco, se pierden ambos. La mitigación actual es el snapshot de Proxmox, que sí vive fuera de la VM. Un paso siguiente sería copiarlos a un almacenamiento externo.
- **No hay cifrado del archivo de respaldo.** Está protegido por permisos del sistema de archivos, pero no cifrado en reposo. Para datos personales sería recomendable agregar `gpg`.
- **No hay alerta automática ante fallo.** Si el respaldo falla, queda en el log pero nadie se entera hasta que alguien lo mira. Se resuelve integrándolo con el sistema de monitoreo (Zabbix) que se implementa en esta misma entrega.
