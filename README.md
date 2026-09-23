# 🚢 Curso de Docker

Bienvenido/a al **Curso de Docker**.
Este repositorio contiene todo el material necesario para aprender Docker desde cero hasta un nivel intermedio: contenedores, imágenes, Dockerfiles, volúmenes, redes, Docker Compose y un laboratorio final con microservicios.

Ideal para desarrolladores, DevOps y cualquier persona interesada en contenerización y despliegue de aplicaciones modernas.

---

## 📘 Contenido del Curso

- Introducción a Docker
- Instalación de Docker
- Imágenes y Contenedores
- Dockerfiles
- Volúmenes y Redes
- Variables de entorno
- Docker Compose
- Docker Hub (subir/publicar imágenes)
- Laboratorio final: microservicios con Docker

---

## 🏗️ Arquitectura básica de Docker

Para entender el curso conviene tener claro cómo se relacionan las piezas:

```text
Dockerfile  --(docker build)-->  Imagen  --(docker run)-->  Contenedor
                                    |
                                    └──(docker push/pull)──> Docker Hub (registro)

docker-compose.yml --(docker compose up)--> orquesta varios contenedores
                                             (servicios + red + volúmenes)
```

- **Dockerfile**: receta de texto que describe cómo construir una imagen (paso a paso: base, dependencias, código, comando de arranque).
- **Imagen**: paquete inmutable generado a partir del Dockerfile (código + dependencias + configuración).
- **Contenedor**: instancia en ejecución de una imagen, aislada del resto del sistema.
- **Volumen**: mecanismo para persistir datos fuera del ciclo de vida del contenedor.
- **Red (network)**: permite que los contenedores se comuniquen entre sí y con el exterior.
- **Docker Compose**: define y levanta **varios** contenedores (servicios) juntos, con sus redes y volúmenes, usando un solo archivo YAML.
- **Docker Hub**: registro remoto donde se suben (`push`) y descargan (`pull`) imágenes.

---

## ⚡ Guía rápida: crear una imagen y levantarla con Compose

### 1. Crear una imagen a partir de un Dockerfile

```bash
docker build -t miimagen:1.0 .        # construye la imagen "miimagen" con tag 1.0
docker run -d -p 8080:80 miimagen:1.0 # la ejecuta como contenedor, mapeando el puerto 8080 -> 80
```

Ver el detalle completo (buenas prácticas, `EXPOSE`, `CMD`, etc.) en [02-dockerfiles/](02-dockerfiles/) y en [01-documentation/01.-init.md](01-documentation/01.-init.md).

### 2. Levantar varios servicios con Docker Compose

```yaml
# docker-compose.yml
version: "3.9"

services:
  app:
    build: .
    ports:
      - "8080:80"
  redis:
    image: "redis"
```

```bash
docker compose up -d      # levanta todos los servicios en segundo plano
docker compose ps         # ver el estado de los servicios
docker compose down       # detener y eliminar los servicios
```

Detalle completo en [01-documentation/07.- docker_compose.md](<01-documentation/07.- docker_compose.md>) y ejemplo real en [04-docker-compose/docker-compose.yml](04-docker-compose/docker-compose.yml).

---

## 🛠️ Comandos básicos de Docker

| Categoría | Comando | Descripción |
|---|---|---|
| Info | `docker --version` | Ver versión instalada |
| Info | `docker info` | Ver información del sistema Docker |
| Imágenes | `docker pull nginx` | Descargar una imagen desde Docker Hub |
| Imágenes | `docker images` | Listar imágenes descargadas |
| Imágenes | `docker rmi nginx` | Eliminar una imagen |
| Contenedores | `docker run -it ubuntu bash` | Crear y entrar a un contenedor interactivo |
| Contenedores | `docker ps` / `docker ps -a` | Ver contenedores en ejecución / todos |
| Contenedores | `docker stop <id>` | Detener un contenedor |
| Contenedores | `docker rm <id>` | Eliminar un contenedor |
| Dockerfile | `docker build -t miimagen .` | Crear una imagen desde un Dockerfile |
| Compose | `docker compose up -d` | Levantar los servicios definidos en `docker-compose.yml` |
| Compose | `docker compose down` | Detener y eliminar los servicios |
| Volúmenes | `docker volume create mi_volumen` | Crear un volumen |
| Volúmenes | `docker volume ls` | Listar volúmenes |
| Docker Hub | `docker login` | Iniciar sesión en Docker Hub |
| Docker Hub | `docker tag miapp usuario/miapp:latest` | Etiquetar una imagen para subirla |
| Docker Hub | `docker push usuario/miapp:latest` | Subir la imagen a Docker Hub |

> Lista completa y explicada de comandos Linux/Docker en [01-documentation/z.-comando-linux.md](01-documentation/z.-comando-linux.md).

---

## 📚 Profundizar por tema

Cada tema tiene su propia guía detallada dentro de [01-documentation/](01-documentation/):

| Tema | Guía |
|---|---|
| Introducción a Docker y Dockerfile | [01.-init.md](01-documentation/01.-init.md) |
| Crear, ejecutar e inspeccionar contenedores | [02.-manager.md](01-documentation/02.-manager.md) |
| Volúmenes (persistencia de datos) | [03.-manager-volumen.md](01-documentation/03.-manager-volumen.md) |
| Redes (networking) | [04.-manager-network.md](01-documentation/04.-manager-network.md) |
| Docker Hub (publicar imágenes) | [05.-manager-dockerhub.md](01-documentation/05.-manager-dockerhub.md) |
| Variables de entorno | [06.-manager-env-variables.md](01-documentation/06.-manager-env-variables.md) |
| Docker Compose | [07.- docker_compose.md](<01-documentation/07.- docker_compose.md>) |
| Comandos Linux útiles con Docker | [z.-comando-linux.md](01-documentation/z.-comando-linux.md) |

---

## 📂 Estructura del Repositorio

```text
/
├── 01-documentation/       # Guías por tema (init, volúmenes, redes, env vars, compose, dockerhub...)
├── 02-dockerfiles/         # Ejemplos de Dockerfile
├── 03-volumenes-redes/     # Ejercicios prácticos de volúmenes y redes
├── 04-docker-compose/      # Ejemplo de docker-compose.yml
├── 05-laboratorio-microservicios/  # Laboratorio final: Quarkus + Postgres + microservicios
└── README.md
```

---

## 🧪 Laboratorio final: microservicios con Docker

En [05-laboratorio-microservicios/](05-laboratorio-microservicios/) vas a aprender **paso a paso** a deployar un proyecto real propio: [poc-credit-evaluation](https://github.com/edzamo/poc-credit-evaluation) (Angular + 2 microservicios Quarkus + PostgreSQL). El flujo: clonar, entender la arquitectura, compilar los artefactos, construir las imágenes, levantar el stack con Docker Compose, versionarlas y publicarlas en Docker Hub (con nota final sobre el siguiente paso: llevarlas a Minikube). Ver el detalle en el README de esa carpeta.

---

## ✅ Requisitos

- Tener Docker y Docker Compose instalados
- Ganas de aprender 💪

---

## 🧑‍💻 Autor

**edzamo**
📧 edzamo13@gmail.com

---

## 📜 Licencia

Este curso es de código abierto bajo la licencia MIT.

---

¡Si te sirve este curso, no olvides darle ⭐ al repositorio!
