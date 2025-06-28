# 🐳 Introducción a Docker

Este repositorio contiene una introducción práctica a **Docker**, ideal para quienes están comenzando a trabajar con contenedores.

---

## 📦 ¿Qué es Docker?

Docker es una plataforma que permite desarrollar, enviar y ejecutar aplicaciones dentro de contenedores ligeros y portables.  
Estos contenedores incluyen todo lo necesario para ejecutar una aplicación: código, dependencias, entorno, etc.

---

## 🧱 Estructura Básica de un Dockerfile

Un `Dockerfile` es un archivo de texto que contiene instrucciones para construir una imagen de Docker.  
A continuación, se presentan las instrucciones más comunes:

### 🔹 `FROM`

Define la imagen base desde la cual se construirá la nueva imagen.

```Dockerfile
FROM ubuntu:20.04
```

> En este caso, la imagen se basará en Ubuntu 20.04.

---

### 🔹 `RUN`

Ejecuta comandos durante la construcción de la imagen. Es útil para instalar paquetes o configurar el sistema.

```Dockerfile
RUN apt update && apt install -y nginx
```

---

### 🔹 `CMD`

Define el comando por defecto que se ejecutará cuando el contenedor se inicie.

```Dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

> Este comando mantiene el servidor Nginx corriendo en primer plano.

---

## 🛠️ Comandos Básicos de Docker

Aquí tienes algunos de los comandos esenciales para trabajar con Docker:

### 📥 Crear y ejecutar un contenedor

```bash
docker run -it ubuntu              # Ejecuta un contenedor Ubuntu de forma interactiva
docker run -d -p 8080:80 nginx     # Ejecuta Nginx en segundo plano y expone el puerto 80 al 8080 local
```

### 📄 Listar contenedores

```bash
docker ps                          # Lista contenedores activos
docker ps -a                       # Lista todos los contenedores (activos y detenidos)
```

### ❌ Detener y eliminar contenedores

```bash
docker stop <container_id>         # Detiene un contenedor
docker rm <container_id>           # Elimina un contenedor
```

### 📦 Trabajar con imágenes

```bash
docker images                      # Lista las imágenes descargadas
docker rmi <image_id>              # Elimina una imagen
```

### 🔨 Crear una imagen desde Dockerfile

```bash
docker build -t miapp:v1 .         # Construye una imagen con nombre y versión
```

---

## 📁 Ejemplo de Dockerfile completo

```Dockerfile
# Imagen base
FROM node:18

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar archivos al contenedor
COPY . .

# Instalar dependencias
RUN npm install

# Comando por defecto al iniciar el contenedor
CMD ["npm", "start"]
```

---

## ✅ Requisitos

- Docker instalado en tu sistema
- Terminal / línea de comandos básica


