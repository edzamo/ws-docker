# 🚢 Curso de Docker

Bienvenido/a al **Curso de Docker**.  
Este repositorio contiene todo el material necesario para aprender Docker desde cero hasta un nivel intermedio.  
Ideal para desarrolladores, DevOps y cualquier persona interesada en contenerización y despliegue de aplicaciones modernas.

---

## 📘 Contenido del Curso


- Introducción a Docker  
- Instalación de Docker  
- Imágenes y Contenedores  
- Dockerfiles  
- Volúmenes y Redes  
- Docker Compose  
- Buenas prácticas  
- Introducción a Docker
- Instalación de Docker
- Imágenes y Contenedores
- Dockerfiles
- Volúmenes y Redes
- Docker Compose
- Buenas prácticas
- Casos reales y ejercicios prácticos

---

## 🛠️ Comandos Básicos de Docker

Aquí tienes una lista con los comandos más utilizados en Docker, con ejemplos prácticos:

### 🔍 Información general

```bash
docker --version                  # Ver versión instalada
docker info                       # Ver información del sistema Docker
```

### 📦 Imágenes

```bash
docker pull nginx                 # Descargar una imagen desde Docker Hub
docker images                     # Listar imágenes descargadas
docker rmi nginx                  # Eliminar una imagen
```

### 🧱 Contenedores

```bash
docker run -it ubuntu bash        # Crear un contenedor interactivo
docker ps                         # Ver contenedores en ejecución
docker ps -a                      # Ver todos los contenedores
docker stop <id>                  # Detener un contenedor
docker rm <id>                    # Eliminar un contenedor
```

### 🧾 Dockerfiles

```bash
docker build -t miimagen .        # Crear imagen desde un Dockerfile
```

### 🔄 Docker Compose

```bash
docker-compose up                 # Levantar servicios definidos en docker-compose.yml
docker-compose down               # Detener y eliminar servicios
```

### 📂 Volúmenes

```bash
docker volume create mi_volumen  # Crear un volumen
docker volume ls                 # Listar volúmenes
```

---

## 📂 Estructura del Repositorio

```
/
├── 01-introduccion/
├── 02-imagenes-contenedores/
├── 03-dockerfiles/
├── 04-volumenes-redes/
├── 05-docker-compose/
├── ejercicios/
└── README.md
```

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



