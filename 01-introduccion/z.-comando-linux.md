
# Guía Comando docker mas usados 
## Uso del Comando `ps aux | grep proxy`

El comando `ps aux | grep proxy` se utiliza para buscar procesos relacionados con la palabra clave `proxy` que se están ejecutando en el sistema.

Ayuda al mapeo de puertos que usa docker con ayuda de linux (proxy)

## Desglose del Comando

- `ps aux`: Lista todos los procesos en ejecución con información detallada.
- `grep proxy`: Filtra los resultados para mostrar solo aquellos que contienen la palabra `proxy`.


## 🐳 Comandos Linux comunes al usar `docker exec`

Cuando ingresas a un contenedor con `docker exec -it <container> /bin/bash` o `/bin/sh`, estos son los comandos más utilizados para navegación, inspección y administración básica dentro del contenedor.

| Comando                        | Descripción breve |
|-------------------------------|-------------------|
| `ls`                          | Lista archivos y carpetas del directorio actual. |
| `cd`                          | Cambia de directorio. |
| `pwd`                         | Muestra la ruta actual. |
| `cat <archivo>`               | Muestra el contenido de un archivo. |
| `tail -f <archivo>`           | Muestra en tiempo real el final de un archivo (útil para logs). |
| `head <archivo>`              | Muestra las primeras líneas de un archivo. |
| `touch <archivo>`             | Crea un archivo vacío. |
| `mkdir <directorio>`          | Crea un nuevo directorio. |
| `rm <archivo>`                | Elimina un archivo. |
| `cp <origen> <destino>`       | Copia archivos o carpetas. |
| `mv <origen> <destino>`       | Mueve o renombra archivos o carpetas. |
| `ps aux`                      | Muestra los procesos en ejecución dentro del contenedor. |
| `top`                         | Muestra el uso de recursos (CPU, memoria) en tiempo real. |
| `netstat -tulpn`              | Lista puertos abiertos y servicios escuchando (si está disponible). |
| `env`                         | Muestra las variables de entorno del contenedor. |
| `echo $VARIABLE`              | Muestra el valor de una variable de entorno. |
| `apk add <paquete>`           | Instala paquetes en contenedores Alpine. |
| `apt update && apt install`   | Actualiza e instala paquetes (Debian/Ubuntu). |
| `exit`                        | Sale de la sesión dentro del contenedor. |
