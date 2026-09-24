# 🧪 Laboratorio Final: Deployar `poc-credit-evaluation` con Docker

Este es el ejercicio de cierre del curso, y a diferencia de las carpetas anteriores (que son píldoras de un solo tema), aquí vamos a **aprender haciendo, paso a paso**, aplicando todo el curso sobre un proyecto real tuyo:

🔗 [https://github.com/edzamo/poc-credit-evaluation](https://github.com/edzamo/poc-credit-evaluation)

👉 Para seguirlo como clase, con analogía de manzanas y explicación de cada paso, empieza por [GUIA-CONTENERIZACION-MICROSERVICIOS.md](GUIA-CONTENERIZACION-MICROSERVICIOS.md).

📚 Material de estudio sobre la tecnología del proyecto (no es de Docker): [ARQUITECTURA-QUARKUS.md](ARQUITECTURA-QUARKUS.md).

No vamos a escribir código de aplicación: el proyecto ya existe y ya trae sus `Dockerfile` y `docker-compose.yml`. Lo que vamos a practicar es el **flujo completo de un DevOps/desarrollador con Docker**: clonar → entender la arquitectura → compilar los artefactos → construir imágenes → levantar el stack → versionar y publicar en Docker Hub. Ese es el objetivo real del laboratorio: recorrer ese flujo una vez, entendiendo cada paso, no solo copiar comandos.

El siguiente paso natural después de este laboratorio (fuera del alcance de este curso de Docker) es tomar esas mismas imágenes publicadas en Docker Hub y desplegarlas en **Minikube** — lo dejamos anotado al final como continuación.

---

## 🏗️ Qué vamos a deployar

`poc-credit-evaluation` es un ecosistema de 3 proyectos + base de datos:

| Servicio | Carpeta | Tecnología | Puerto |
|---|---|---|---|
| Frontend | `mms-ux-credit-evaluation` | Angular 21 servido por Nginx | 4200 |
| Orquestador | `ms-orchestrator-credit-evaluation` | Quarkus 3.8 / Java 21 (Arquitectura Hexagonal) | 8080 |
| Mock de riesgo | `ms-risk-mock-credit-evaluation` | Quarkus 3.8 / Java 21 | 8081 |
| Base de datos | `postgres:16-alpine` | PostgreSQL | 5433 |

Flujo: el **Frontend** llama al **Orquestador**, el **Orquestador** valida la cédula, consulta en paralelo al **Mock de riesgo** (score y deudas) y persiste el resultado en **PostgreSQL**.

Cada microservicio Quarkus ya trae su propio `Dockerfile.jvm` (multi-stage: build con Maven + runtime JRE liviano), y el frontend trae un `Dockerfile` (multi-stage: build con Node + servir con Nginx). El `docker-compose.yml` del repo ya conecta todo por una red interna (`credit-network`) y persiste Postgres en un volumen (`postgres-data`).

---

## Paso 0 — Prerrequisitos

- Docker 24+ y Docker Compose v2+ (`docker compose version`)
- Java 21 y Maven (instalables con SDKMAN; el repo **no trae** el wrapper `./mvnw`)
- Cuenta en [Docker Hub](https://hub.docker.com/signup)
- Git

---

## Paso 1 — Clonar el proyecto

```bash
git clone https://github.com/edzamo/poc-credit-evaluation.git
cd poc-credit-evaluation
```

---

## Paso 2 — Entender la arquitectura antes de tocar nada

Antes de compilar, lee el `README.md` del propio repo: trae diagramas de arquitectura (ecosistema completo, hexagonal del orquestador, capas del mock) y la regla de negocio. Fíjate especialmente en:

- `docker-compose.yml`: cómo cada servicio se conecta a los demás **por nombre de servicio** (`ms-risk-mock`, `postgres`), no por `localhost`. Repasa [01-documentation/04.-manager-network.md](../01-documentation/04.-manager-network.md) si no te queda claro por qué.
- Las variables `DB_URL`, `DB_USERNAME`, `RISK_SERVICE_URL`, etc. definidas en `environment:` de cada servicio. Repasa [01-documentation/06.-manager-env-variables.md](../01-documentation/06.-manager-env-variables.md).
- El volumen `postgres-data`, que evita perder los datos si se recrea el contenedor. Repasa [01-documentation/03.-manager-volumen.md](../01-documentation/03.-manager-volumen.md).

---

## Paso 3 — Compilar los artefactos de los microservicios Quarkus

Los Dockerfiles de este proyecto compilan dentro de la imagen (multi-stage), pero para aprender el flujo completo, primero compila y corre los tests localmente:

```bash
cd ms-risk-mock-credit-evaluation
mvn package -DskipTests
cd ..

cd ms-orchestrator-credit-evaluation
mvn package -DskipTests
cd ..
```

> El frontend necesita un `package-lock.json` que el repo no trae; el detalle de cómo generarlo con un contenedor descartable está en [GUIA-CONTENERIZACION-MICROSERVICIOS.md](GUIA-CONTENERIZACION-MICROSERVICIOS.md).

Esto genera `target/quarkus-app/` en cada microservicio (el `quarkus-run.jar` + dependencias). Es exactamente lo que la etapa de build del `Dockerfile.jvm` de cada servicio vuelve a hacer dentro del contenedor.

---

## Paso 4 — Construir las imágenes Docker

Puedes construir cada imagen individualmente (para entender qué hace cada `Dockerfile`) o dejar que Compose lo haga todo:

```bash
# Individualmente, por ejemplo el mock de riesgo:
docker build -t poc/ms-risk-mock-credit-evaluation:1.0.0 \
  -f ms-risk-mock-credit-evaluation/src/main/docker/Dockerfile.jvm \
  ms-risk-mock-credit-evaluation

# O todas de una vez con Compose (recomendado):
docker compose build
```

Revisa `ms-orchestrator-credit-evaluation/src/main/docker/Dockerfile.jvm` y `mms-ux-credit-evaluation/Dockerfile`: ambos son **multi-stage builds** (una etapa compila, otra solo copia el artefacto final a una imagen mínima). Compáralo con lo visto en [01-documentation/01.-init.md](../01-documentation/01.-init.md).

---

## Paso 5 — Levantar el stack completo y probarlo

```bash
docker compose up -d --build
docker compose ps          # todos deben quedar "healthy"
docker compose logs -f ms-orchestrator
```

Verifica en el navegador / con `curl`:

| Servicio | URL |
|---|---|
| Frontend | [http://localhost:4200](http://localhost:4200) |
| Swagger Orquestador | [http://localhost:8080/swagger-ui](http://localhost:8080/swagger-ui) |
| Swagger Mock de riesgo | [http://localhost:8081/swagger-ui](http://localhost:8081/swagger-ui) |

Checklist de validación:

- [ ] `docker compose ps` muestra los 4 servicios (`postgres`, `ms-risk-mock`, `ms-orchestrator`, `mms-ux`) en estado healthy/running.
- [ ] El frontend en `:4200` carga el formulario de evaluación de crédito.
- [ ] Enviar una solicitud desde el formulario devuelve APROBADO/RECHAZADO (confirma que Orquestador → Mock → Postgres funciona de punta a punta).
- [ ] Si corres `docker compose down && docker compose up -d`, los datos previos en Postgres siguen ahí (gracias al volumen `postgres-data`).

```bash
docker compose down   # detener y limpiar cuando termines
```

---

## Paso 6 — Versionar: la versión vive en el código, no en el tag

La versión de cada servicio se define **una sola vez, en su archivo de proyecto**, y el tag de la imagen se deriva de ahí:

| Servicio | Dónde se define la versión |
|---|---|
| Backends Quarkus | `pom.xml` (`<version>`) — y `quarkus.application.version` en `application.properties` debe coincidir |
| Frontend Angular | `package.json` (`"version"`) |

Para publicar la versión `1.0.1`, edita esos archivos (sin `-SNAPSHOT`), regenera el `package-lock.json` del frontend y reconstruye. Esto evita que el tag de la imagen diga una cosa y el artefacto otra. El razonamiento y las prácticas de industria están en [GUIA-CONTENERIZACION-MICROSERVICIOS.md](GUIA-CONTENERIZACION-MICROSERVICIOS.md).

**Convención de nombres** (Docker Hub gratuito solo permite `cuenta/repositorio`, así que la clasificación va como prefijo en el nombre):

```text
<usuario-dockerhub>/austro-<servicio>:<versión>
edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
```

---

## Paso 7 — Construir y publicar en Docker Hub con el script

```bash
docker login                                   # una vez; usa un access token de Docker Hub
./scripts/publicar-imagenes.sh                 # solo construye (prueba en seco)
./scripts/publicar-imagenes.sh --push          # construye y publica las 3 imágenes
```

El script [scripts/publicar-imagenes.sh](scripts/publicar-imagenes.sh):

- Lee la versión de cada `pom.xml` / `package.json`.
- Se detiene si la versión es `-SNAPSHOT`, si `pom.xml` y `application.properties` no coinciden, o si el tag ya existe en el registro.
- Construye cada imagen con labels OCI (versión, commit, fuente, fecha).
- Publica y muestra el **digest** (`sha256:...`) de cada imagen.

Variables opcionales: `DOCKER_USER` (por defecto `edzamo13`) y `PREFIX` (por defecto `austro`).

Verifica en [hub.docker.com](https://hub.docker.com) → **Repositories**, o desde la terminal:

```bash
curl -s https://hub.docker.com/v2/repositories/edzamo13/austro-ms-orchestrator-credit-evaluation/tags/
docker pull edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
```

Guía general de Docker Hub (cuenta, `login`, `tag`, `push`) en [01-documentation/05.-manager-dockerhub.md](../01-documentation/05.-manager-dockerhub.md).

---

## ✅ Resultado esperado

- Entendiste y corriste localmente el ecosistema `poc-credit-evaluation` (Angular + 2 microservicios Quarkus + PostgreSQL) con Docker Compose.
- Compilaste los artefactos Quarkus y viste cómo el `Dockerfile.jvm` los empaqueta en una imagen mínima (multi-stage build).
- Versionaste y publicaste las 3 imágenes en tu cuenta de Docker Hub, listas para hacer `docker pull` desde cualquier máquina.

---

## 🚀 Próximo paso: llevarlo a Minikube (fuera de este curso de Docker)

Una vez las imágenes están en Docker Hub, el siguiente salto natural es orquestarlas con Kubernetes en local:

```bash
minikube start
kubectl create deployment ms-risk-mock --image=edzamo13/austro-ms-risk-mock-credit-evaluation:1.0.1
kubectl create deployment ms-orchestrator --image=edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
kubectl create deployment mms-ux --image=edzamo13/austro-mms-ux-credit-evaluation:1.0.1
kubectl expose deployment mms-ux --type=NodePort --port=80
minikube service mms-ux
```

Esto ya no es parte de este curso de Docker (es un curso aparte de Kubernetes), pero vale la pena anotarlo: como las imágenes ya están versionadas y publicadas en Docker Hub, Minikube (o cualquier clúster) puede simplemente hacer `pull` de ellas por nombre y tag — que es justo el valor de haber hecho bien los pasos 6 y 7.

Dos puntos a resolver en esa etapa: PostgreSQL se descarga directo como `postgres:16-alpine` (no hay imagen propia), y el frontend trae `apiBaseUrl: http://localhost:8080` fijo al compilar, que dentro de Kubernetes requerirá un proxy o un Ingress.
