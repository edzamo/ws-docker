# Guía de contenerización de microservicios: del código a Docker Hub

Guía del laboratorio [poc-credit-evaluation](https://github.com/edzamo/poc-credit-evaluation) (Angular + 2 microservicios Quarkus + PostgreSQL). Cada paso explica **qué** hacemos y **por qué**, con una analogía de manzanas para quien empieza desde cero. Para profundizar en cómo funciona Quarkus por dentro, ver [ARQUITECTURA-QUARKUS.md](ARQUITECTURA-QUARKUS.md).

**Contenido:** la analogía · Pasos 0 al 4 · Lo que sigue

## 🍎 La analogía

| Concepto Docker | Analogía |
|---|---|
| Código fuente | Las manzanas crudas |
| `Dockerfile` | La **receta** escrita: "pela, licúa, embotella" |
| `docker build` | **Seguir la receta** y embotellar el jugo |
| Imagen | La **botella sellada**: siempre sabe igual, la abras donde la abras |
| `docker run` | **Servir un vaso** de la botella (puedes servir muchos vasos = contenedores) |
| `docker compose` | **Poner la mesa completa**: jugo + pan + mantequilla, coordinados |
| Docker Hub | La **tienda** donde dejas tus botellas para que otros las descarguen (`pull`) |

---

## Paso 0 — Preparar la cocina (herramientas)

Docker y Docker Compose ya deben estar instalados. Java 21 y Maven los instalamos con **SDKMAN**, un "supermercado de herramientas" que permite instalar y cambiar versiones sin ensuciar el sistema.

```bash
docker --version && docker compose version     # verificar Docker
curl -s "https://get.sdkman.io" | bash         # instalar SDKMAN
source "$HOME/.sdkman/bin/sdkman-init.sh"      # activarlo en esta terminal
sdk install java 21.0.12-tem                   # Java 21 (el pom.xml exige la 21)
sdk install maven                              # Maven
java -version && mvn -version                  # verificar
```

> Si el `sdk install java` de tu equipo no ofrece `21.0.12-tem`, usa `sdk list java` y elige cualquier Temurin 21.

## Paso 1 — Traer las manzanas (`git clone`)

```bash
git clone https://github.com/edzamo/poc-credit-evaluation.git
cd poc-credit-evaluation
git pull     # si ya lo tenías clonado, trae los cambios nuevos
```

## Paso 2 — Mirar la cocina antes de cocinar

Son **3 cocinas independientes** bajo un mismo techo, cada una con su receta:

| Carpeta | Qué es | Receta (Dockerfile) |
|---|---|---|
| `ms-risk-mock-credit-evaluation` | Quarkus: simula el score de riesgo | `src/main/docker/Dockerfile.jvm` |
| `ms-orchestrator-credit-evaluation` | Quarkus: decide APROBADO/RECHAZADO | `src/main/docker/Dockerfile.jvm` |
| `mms-ux-credit-evaluation` | Angular + Nginx: lo que ve el usuario | `Dockerfile` |

Más un PostgreSQL, que no se construye: se descarga ya hecho (`postgres:16-alpine`).

## Paso 3 — Exprimir las manzanas (compilar con Maven)

```bash
cd ms-risk-mock-credit-evaluation && mvn package -DskipTests && cd ..
cd ms-orchestrator-credit-evaluation && mvn package -DskipTests && cd ..
```

Genera `target/quarkus-app/quarkus-run.jar`: el "jugo" listo, pero todavía sin botella. `-DskipTests` salta las pruebas para ir más rápido.

> Este repo **no trae `./mvnw`** (aunque su README lo mencione), por eso usamos el `mvn` instalado con SDKMAN.

## Paso 4 — Embotellar: cómo se genera cada imagen

### ¿Cómo se llama cada botella? `namespace/nombre:versión`

En el [docker-compose.yml](poc-credit-evaluation/docker-compose.yml) cada servicio ya trae su nombre y versión separados:

| Servicio | Imagen generada | Namespace | Nombre | Versión (tag) |
|---|---|---|---|---|
| `ms-risk-mock` | `austro/ms-risk-mock-credit-evaluation:1.0.0` | `austro` | `ms-risk-mock-credit-evaluation` | `1.0.0` |
| `ms-orchestrator` | `austro/ms-orchestrator-credit-evaluation:1.0.0` | `austro` | `ms-orchestrator-credit-evaluation` | `1.0.0` |
| `mms-ux` | `austro/mms-ux-credit-evaluation:1.0.0` | `austro` | `mms-ux-credit-evaluation` | `1.0.0` |

- **Namespace** (`austro`): en Docker Hub es tu usuario u organización. Para publicar deberás cambiarlo por el tuyo (Paso 6 del [README](README.md)).
- **Versión** (`1.0.0`): la etiqueta que te permite tener varias versiones de la misma imagen y volver atrás si algo falla.
- No confundir con `version: '3.9'` al inicio del compose: esa línea es de la sintaxis del archivo, hoy es obsoleta y Docker la ignora.

### Opción A: una imagen a la vez (para entender qué pasa)

`docker build -t <nombre:tag> -f <receta> <carpeta de contexto>`: la **carpeta de contexto** es lo que Docker "ve" al construir, y `-f` indica cuál es la receta.

```bash
docker build -t austro/ms-risk-mock-credit-evaluation:1.0.0 \
  -f ms-risk-mock-credit-evaluation/src/main/docker/Dockerfile.jvm \
  ms-risk-mock-credit-evaluation

docker build -t austro/ms-orchestrator-credit-evaluation:1.0.0 \
  -f ms-orchestrator-credit-evaluation/src/main/docker/Dockerfile.jvm \
  ms-orchestrator-credit-evaluation

docker build -t austro/mms-ux-credit-evaluation:1.0.0 \
  mms-ux-credit-evaluation          # usa el Dockerfile de esa carpeta
```

### Opción B: todas de una vez con Compose

```bash
docker compose build
docker images | grep austro          # ver las 3 botellas
```

Compose lee la sección `build:` de cada servicio (contexto + receta) y el campo `image:` (nombre:versión), así que hace exactamente las 3 construcciones de la Opción A.

### Problema real que apareció: el frontend fallaba con `npm ci`

El `Dockerfile` del frontend usa `npm ci`, que exige un `package-lock.json` (la "lista exacta de ingredientes" para que el resultado sea idéntico siempre). Este repo no lo trae. Como no queríamos instalar Node, usamos un **contenedor descartable** con la misma imagen del Dockerfile:

```bash
cd mms-ux-credit-evaluation
docker run --rm -v "$(pwd)":/app -w /app node:20-alpine \
  npm install --legacy-peer-deps --package-lock-only
cd ..
```

Después de eso `docker compose build` termina con `Built` en los 3 servicios.

> Al ser una receta *multi-stage*, los Dockerfiles compilan **dentro** del contenedor. El Paso 3 no es obligatorio para construir la imagen, pero sirve para ver el artefacto "crudo" antes de embotellarlo.

---

## Lo que sigue

- **Paso 5**: poner la mesa (`docker compose up -d`) y probar el sistema completo.
- **Paso 6 y 7**: cambiar el namespace `austro` por tu usuario de Docker Hub, versionar y hacer `docker push`.
- **Después**: usar esas imágenes en Minikube.

Estos pasos están descritos en el [README del laboratorio](README.md). Para entender la tecnología detrás de los microservicios, ver la [arquitectura de Quarkus](ARQUITECTURA-QUARKUS.md).
