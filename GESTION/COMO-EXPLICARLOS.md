# Cómo explicar los scripts

Guía para la defensa. No hay que memorizar nada: alcanza con entender estas ideas.

---

## La idea general, en una frase

> "Hicimos un menú que administra usuarios y grupos del servidor. Está separado en cinco archivos: uno es el menú principal y los otros cuatro son los módulos que hacen el trabajo."

Si te piden dibujarlo:

```
gestion.sh  (el menú principal)
    ├── usuarios.sh          crear / renombrar / eliminar usuarios
    ├── grupos.sh            crear / renombrar / eliminar grupos
    ├── registrar_grupo.sh   agregar y quitar usuarios de grupos
    ├── listar.sh            consultas
    ├── servicios.sh         iniciar / detener / reiniciar servicios
    └── permisos.sh          chmod y chown

comun.sh   →  funciones que usan todos (no tiene menú propio)
```

**Por qué en archivos separados y no uno solo:** para poder ejecutar cada módulo por su cuenta y para que el archivo no quede gigante. Si mañana hay que cambiar algo de grupos, se toca un solo archivo.

---

## Los comandos de Linux que usamos

Si entienden estos, entienden todos los scripts.

**Usuarios y grupos**

| Comando | Qué hace |
|---|---|
| `useradd -m -s /bin/bash juan` | Crea el usuario `juan`. `-m` crea su carpeta en `/home`, `-s` le define la shell |
| `usermod` | Modifica un usuario ya existente |
| `userdel -r juan` | Borra el usuario. `-r` borra también su carpeta personal |
| `groupadd` / `groupmod` / `groupdel` | Lo mismo pero con grupos |
| `id juan` | Muestra el número (UID) y los grupos de un usuario |
| `getent group ventas` | Busca un grupo en el sistema |

**Servicios** — todos empiezan con `systemctl`

| Comando | Qué hace |
|---|---|
| `systemctl status docker` | Ver cómo está el servicio |
| `systemctl start` / `stop` / `restart` | Iniciarlo, detenerlo, reiniciarlo |
| `systemctl enable docker` | Que arranque solo al prender el servidor |
| `systemctl is-active docker` | Responde si está corriendo ahora |

**Permisos**

| Comando | Qué hace |
|---|---|
| `chmod 750 script.sh` | Cambia los permisos |
| `chown bruno:bramajo archivo` | Cambia el dueño y el grupo |
| `stat -c '%a' archivo` | Muestra los permisos en número |
| `ls -la` | Lista mostrando permisos y dueño |

---

## Los permisos en números (esto lo van a preguntar)

Cada archivo tiene permisos para **tres tipos de persona**: el dueño, el grupo y los otros. Para cada uno se define si puede leer, escribir o ejecutar:

| Permiso | Letra | Vale |
|---|---|---|
| Leer | `r` | **4** |
| Escribir | `w` | **2** |
| Ejecutar | `x` | **1** |

Los números **se suman** para armar un dígito, y se ponen tres dígitos seguidos:

```
chmod 750 script.sh
      |||
      ||+--- otros:  0 = nada
      |+---- grupo:  5 = 4+1 = leer y ejecutar
      +----- dueño:  7 = 4+2+1 = todo
```

Los cuatro que usamos en el proyecto:

- **600** — archivo de contraseñas. Solo el dueño lo lee. Nadie más.
- **700** — carpeta de respaldos. Solo el dueño entra.
- **750** — un script. El dueño hace todo, el grupo lo ejecuta.
- **644** — archivo común. El dueño escribe, los demás leen.

**777 es peligroso** porque cualquier usuario del servidor puede modificar y ejecutar ese archivo. El script avisa y pide confirmación si eligen ese valor.

---

## Las 3 cosas que arreglamos (y son las que más van a preguntar)

Esta parte es la más valiosa: muestra que probaron el código, no que lo escribieron y ya.

### 1. Antes decía "correctamente" aunque fallara

**El problema:** el script ejecutaba el comando y en la línea siguiente imprimía "Usuario modificado correctamente", sin fijarse si había funcionado.

```bash
sudo usermod -l pedro juan          # esto puede fallar
echo "Usuario modificado correctamente."   # pero esto se imprime igual
```

**Cómo lo arreglamos:** metimos el comando dentro del `if`. En bash, un `if` con un comando adentro pregunta "¿este comando funcionó?".

```bash
if sudo usermod -l pedro juan; then
    echo "Usuario modificado correctamente."
else
    echo "Error: no se pudo modificar el usuario."
fi
```

### 2. Se podía borrar `root`

**El problema:** el script solo verificaba que el usuario existiera. Como `root` existe, lo dejaba borrar. Eso destruye el servidor.

**Cómo lo arreglamos:** en Linux, los usuarios con número (UID) menor a 1000 son cuentas del sistema. Antes de borrar, comprobamos ese número:

```bash
if es_cuenta_del_sistema "$usuario"; then
    echo "ERROR: es una cuenta del sistema."
    return
fi
```

**Si preguntan por qué 1000:** es la convención de Linux. Del 0 al 999 son cuentas de servicio (`root` es el 0), de 1000 en adelante son personas.

### 3. Bucle infinito

**El problema:** si la entrada del teclado se terminaba (por ejemplo con Ctrl+D), el comando `read` fallaba, la variable quedaba vacía, el menú imprimía "Opción inválida" y volvía a empezar. Para siempre.

**Cómo lo probamos:** ejecutamos el script sin entrada y contamos las líneas. Imprimió **170.444 líneas en 2 segundos** con la CPU al 100%.

**Cómo lo arreglamos:** preguntamos si `read` funcionó, y si no, salimos.

```bash
if ! read -r -p "Seleccione una opción: " opcion; then
    exit 0
fi
```

---

## Preguntas probables y cómo responderlas

**¿Qué es `comun.sh` y por qué no tiene menú?**
Es un archivo con las funciones que se repetían en los otros cuatro (verificar si un usuario existe, si es del sistema, pedir confirmación). Los demás lo cargan con `source`. Así, si hay que cambiar una validación, se cambia en un solo lugar.

**¿Qué hace `source`?**
Carga las funciones de otro archivo dentro del actual, como si estuvieran escritas ahí. No es lo mismo que ejecutarlo.

**¿Por qué `$DIR` en vez de `./usuarios.sh`?**
Porque `./` significa "la carpeta desde donde estoy parado". Si ejecutábamos el script desde otra carpeta, no encontraba los módulos. Con `$DIR` obtenemos la carpeta real donde está el archivo.

**¿Por qué las variables van entre comillas, como `"$usuario"`?**
Para que funcione aunque el valor tenga espacios. Sin comillas, un nombre con espacio se interpretaría como dos argumentos distintos.

**¿Por qué `sudo` adentro del script y no ejecutar todo como root?**
Porque así el script se puede correr como usuario normal y solo pide permisos para las operaciones que realmente los necesitan. Es más seguro que trabajar todo el tiempo como root.

**¿Qué diferencia hay entre `usermod -aG` y `usermod -G`?**
`-a` significa *append*, agregar. Sin `-a`, el comando **reemplaza** todos los grupos del usuario por el que le indicás, y le saca todos los demás. Es un error clásico y por eso siempre va `-aG`.

**¿Por qué el listado separa usuarios humanos de cuentas de servicio?**
Porque `/etc/passwd` tiene unos 35 usuarios pero solo 4 son personas. El resto los crea el sistema al instalar programas. Separarlos hace el listado útil.

**¿Los roles de la aplicación (Participante, Organizador, Administrador) son usuarios de Linux?**
No. Son filas en la tabla `Usuario` de MySQL. Los usuarios de Linux son del sistema operativo. Son dos cosas distintas que se llaman igual.

**¿Qué diferencia hay entre `systemctl start` y `systemctl enable`?**
`start` lo arranca **ahora**. `enable` hace que arranque **solo al prender el servidor**. Un servicio puede estar corriendo pero no habilitado: funciona hoy, pero si reinician el servidor no vuelve. Por eso el script muestra los dos estados por separado.

**¿Por qué el script no deja detener `sshd`?**
Porque `sshd` es el servicio que permite conectarse por SSH. Si lo detenemos estando conectados remotamente, perdemos el acceso al servidor y hay que entrar por la consola de Proxmox. Está en una lista de servicios protegidos junto con `systemd-journald` y `dbus`.

**¿Por qué usan `realpath` en el script de permisos?**
Porque alguien podría escribir `/etc/../etc`, que es otra forma de escribir `/etc`. `realpath` convierte cualquier ruta a su forma real, así la protección no se puede esquivar. Lo probamos y funciona.

**¿Qué es un servicio?**
Un programa que corre de fondo, sin ventana, esperando pedidos. En nuestro servidor: `sshd` para conectarse, `docker` para los contenedores, `firewalld` para el cortafuegos y `crond` para las tareas programadas.

---

## Cómo demostrarlo en vivo

Si les piden mostrarlo funcionando, este recorrido cubre todo en 3 minutos:

1. `./gestion.sh` → **4** → **5** → muestra el resumen del servidor
2. Volver → **1** → crear un usuario de prueba
3. **1** → **3** → intentar eliminar `root` → **salta la protección**
4. Eliminar el usuario de prueba → pide confirmación
5. **5** → **7** → estado de los servicios de Bramajo (docker, sshd, firewalld, crond)
6. **5** → **4** → intentar detener `sshd` → **salta la protección**
7. **6** → **5** → verificar los permisos del proyecto (las contraseñas en 600)
8. Salir con **7**

Los pasos 3 y 6 son los que conviene mostrar sí o sí: son los que demuestran que pensaron qué pasa cuando alguien se equivoca.

El paso 7 es el que conecta los scripts con la política de seguridad del proyecto — verifica que los archivos de contraseña tengan permiso 600, tal como lo exige nuestro propio documento de Ciberseguridad.

---

## Si algo no anda

| Síntoma | Causa | Solución |
|---|---|---|
| `Permission denied` al ejecutar | Falta permiso de ejecución | `chmod +x *.sh` |
| `comun.sh: No such file` | Los archivos no están juntos | Los seis van en la misma carpeta |
| `$'\r': command not found` | El archivo se editó en Windows | `dos2unix *.sh` |
| Pide contraseña todo el tiempo | Es normal, es `sudo` | Se puede configurar `sudoers`, pero no hace falta |
