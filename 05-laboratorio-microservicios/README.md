# 🧪 Laboratorio Final: Microservicios con Docker (Quarkus + PostgreSQL)

Este es el ejercicio de cierre del curso. El objetivo es tomar un proyecto real —una aplicación con **backend en Quarkus**, **base de datos PostgreSQL** y **3 microservicios (frontend/backend)**— y aplicar todo lo visto: Dockerfiles, volúmenes, redes, variables de entorno, Docker Compose y publicación en Docker Hub.

No se trata de escribir la aplicación desde cero: se asume que ya tienes el proyecto (o los proyectos) de Quarkus y los microservicios front/back. Aquí lo que se practica es **contenerizarlos y orquestarlos**.

---

## 🎯 Objetivos del laboratorio

1. Crear un `Dockerfile` por cada servicio (cada microservicio y el frontend).
2. Levantar todo el stack (PostgreSQL + microservicios + frontend) con un único `docker-compose.yml`.
3. Conectar los servicios entre sí por red interna de Docker (no por `localhost`).
4. Persistir los datos de PostgreSQL con un volumen.
5. Configurar cada servicio mediante variables de entorno (sin credenciales hardcodeadas).
6. Construir, etiquetar y **subir las imágenes a Docker Hub**.

---

## 📂 Estructura sugerida

Copia o referencia aquí tu proyecto existente, respetando una carpeta por servicio:

```text
05-laboratorio-microservicios/
├── postgres/                  # (opcional) scripts de inicialización de la BD
│   └── init.sql
├── backend-quarkus/            # Microservicio principal (Quarkus)
│   └── Dockerfile
├── microservicio-2/             # Segundo microservicio backend
│   └── Dockerfile
├── microservicio-3/             # Tercer microservicio backend
│   └── Dockerfile
├── frontend/                   # Aplicación frontend
│   └── Dockerfile
├── docker-compose.yml          # Orquesta todo el stack
└── README.md                   # (este archivo)
```

> Ajusta los nombres de las carpetas a los de tu proyecto real; lo importante es que cada servicio tenga su propio `Dockerfile`.

---

## 1️⃣ Dockerfile por servicio

### Backend Quarkus (ejemplo)

Quarkus genera un jar ejecutable (`quarkus-run.jar`) tras `./mvnw package`. Un `Dockerfile` típico en modo JVM:

```dockerfile
FROM eclipse-temurin:21-jre

WORKDIR /app
COPY target/quarkus-app/ /app/

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/quarkus-run.jar"]
```

### Microservicios / frontend

Sigue el mismo patrón: imagen base acorde a la tecnología, copiar el artefacto ya compilado (jar, build de node, etc.), exponer el puerto y definir el comando de arranque. Revisa [01-documentation/01.-init.md](../01-documentation/01.-init.md) para la estructura básica de un Dockerfile.

---

## 2️⃣ docker-compose.yml del stack

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: labdb
      POSTGRES_USER: lab
      POSTGRES_PASSWORD: labpass
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  backend-quarkus:
    build: ./backend-quarkus
    environment:
      QUARKUS_DATASOURCE_JDBC_URL: jdbc:postgresql://postgres:5432/labdb
      QUARKUS_DATASOURCE_USERNAME: lab
      QUARKUS_DATASOURCE_PASSWORD: labpass
    depends_on:
      - postgres
    ports:
      - "8080:8080"

  microservicio-2:
    build: ./microservicio-2
    depends_on:
      - postgres
    ports:
      - "8081:8080"

  microservicio-3:
    build: ./microservicio-3
    depends_on:
      - postgres
    ports:
      - "8082:8080"

  frontend:
    build: ./frontend
    depends_on:
      - backend-quarkus
    ports:
      - "3000:3000"

volumes:
  pgdata:
```

Puntos clave a repasar antes de escribir el tuyo:

- **Red**: todos los servicios de un mismo `docker-compose.yml` se ven entre sí por su *nombre de servicio* (`postgres`, no `localhost`). Ver [01-documentation/04.-manager-network.md](../01-documentation/04.-manager-network.md).
- **Volumen**: `pgdata` evita perder los datos de Postgres cada vez que se recrea el contenedor. Ver [01-documentation/03.-manager-volumen.md](../01-documentation/03.-manager-volumen.md).
- **Variables de entorno**: nunca hardcodear usuario/password en el Dockerfile; van en `environment:` o en un `.env`. Ver [01-documentation/06.-manager-env-variables.md](../01-documentation/06.-manager-env-variables.md).

---

## 3️⃣ Levantar y probar el stack

```bash
docker compose up -d --build   # construye las imágenes y levanta todo
docker compose ps              # verifica que todos los servicios estén "healthy"/"running"
docker compose logs -f backend-quarkus   # revisar logs de un servicio puntual
docker compose down            # detener y limpiar
```

Checklist de validación:

- [ ] El backend Quarkus conecta correctamente a PostgreSQL.
- [ ] Los 3 microservicios responden en sus puertos.
- [ ] El frontend consume el/los backend(s) sin errores de red.
- [ ] Si se elimina y recrea el contenedor de Postgres, los datos persisten (gracias al volumen).

---

## 4️⃣ Publicar las imágenes en Docker Hub

Repite estos pasos por cada servicio que quieras publicar (backend, microservicios, frontend):

```bash
docker login

docker build -t tu_usuario/lab-backend-quarkus:1.0 ./backend-quarkus
docker tag tu_usuario/lab-backend-quarkus:1.0 tu_usuario/lab-backend-quarkus:latest

docker push tu_usuario/lab-backend-quarkus:1.0
docker push tu_usuario/lab-backend-quarkus:latest
```

Guía paso a paso completa (crear cuenta, `docker login`, `tag`, `push`, verificación) en [01-documentation/05.-manager-dockerhub.md](../01-documentation/05.-manager-dockerhub.md).

---

## ✅ Resultado esperado

Al finalizar deberías tener:

- Un `Dockerfile` funcional por cada servicio (Quarkus, 2 microservicios, frontend).
- Un `docker-compose.yml` que levanta todo el stack con un solo comando.
- Datos de PostgreSQL persistidos en un volumen.
- Las imágenes de cada servicio publicadas en tu cuenta de Docker Hub, listas para hacer `docker pull` desde cualquier máquina.
