# Guía de contenerización de microservicios: del código a Docker Hub

Guía del laboratorio [poc-credit-evaluation](https://github.com/edzamo/poc-credit-evaluation) (Angular + 2 microservicios Quarkus + PostgreSQL). Cada paso explica **qué** hacemos y **por qué**, con una analogía de manzanas para quien empieza desde cero. Para profundizar en cómo funciona Quarkus por dentro, ver [ARQUITECTURA-QUARKUS.md](ARQUITECTURA-QUARKUS.md).

**Contenido:** la analogía · Pasos 0 al 7 (herramientas, clonar, compilar, construir, versionar, publicar) · Prácticas de industria · Lo que sigue

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

- **Namespace** (`austro`): en Docker Hub es tu usuario u organización. Para publicar se usa tu usuario más un prefijo de proyecto (ver Pasos 6 y 7 más abajo).
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

## Paso 5 — Poner la mesa (opcional en esta guía)

`docker compose up -d` levanta los 4 contenedores juntos. En este laboratorio ya se había probado el stack, así que se omitió; el detalle está en el [README](README.md).

## Paso 6 — Versionar: ¿en el tag o en el artefacto?

**En ambos, pero con una fuente única de verdad: el código fuente.** El tag de la imagen se *deriva* de la versión del proyecto, nunca al revés.

```text
git tag v1.0.1  →  pom.xml / package.json = 1.0.1  →  artefacto 1.0.1  →  imagen :1.0.1
   (decisión)          (fuente de verdad)                (jar / estáticos)    (etiqueta derivada)
```

### Lo que encontramos: la versión estaba en 4 lugares y no coincidían

| Dónde | Valor antes |
|---|---|
| `pom.xml` (cada backend) | `1.0.0-SNAPSHOT` |
| `application.properties` (cada backend) | `1.0.0` |
| `package.json` (frontend) | `1.0.0` |
| Tag en `docker-compose.yml` | `1.0.0` |

Si solo se hace `docker tag ...:1.0.1` sobre la imagen `1.0.0`, la etiqueta miente: el contenido es el mismo y por dentro sigue diciendo 1.0.0. Por eso se cambió la versión **en el código** y se reconstruyó:

| Archivo | Cambio |
|---|---|
| `ms-*/pom.xml` (línea 9) | `1.0.0-SNAPSHOT` → `1.0.1` |
| `ms-*/src/main/resources/application.properties` | `quarkus.application.version=1.0.1` |
| `mms-ux-credit-evaluation/package.json` | `"version": "1.0.1"` |
| `mms-ux-credit-evaluation/package-lock.json` | Regenerado con el contenedor `node:20-alpine` |

> Mejora pendiente: `quarkus.application.version` duplica la versión del `pom.xml`. Quarkus ya toma la del `pom.xml` por defecto, así que lo ideal es eliminar esa línea y tener un solo lugar.

### Cómo llamar a las imágenes

Docker Hub gratuito solo permite dos niveles, `cuenta/repositorio`, sin carpetas intermedias, y las organizaciones pueden requerir un plan de pago. Por eso la clasificación por proyecto va como **prefijo en el nombre del repositorio**:

```text
<usuario>/austro-<servicio>:<versión>
edzamo13/austro-ms-risk-mock-credit-evaluation:1.0.1
edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
edzamo13/austro-mms-ux-credit-evaluation:1.0.1
```

En un registro corporativo (Harbor, ECR, ACR) la clasificación sería por niveles: `registry.austro.com/credit-evaluation/ms-orchestrator:1.0.1`. El nombre y el tag no cambian; solo el prefijo.

## Paso 7 — Construir y publicar con el script

Todo lo anterior está automatizado en [scripts/publicar-imagenes.sh](scripts/publicar-imagenes.sh):

```bash
docker login                                 # una vez (mejor con un access token)
./scripts/publicar-imagenes.sh               # prueba en seco: solo construye
./scripts/publicar-imagenes.sh --push        # construye y publica
```

Lo que hace por cada servicio:

1. Lee la versión de su `pom.xml` o `package.json`.
2. **Se detiene** si la versión es `-SNAPSHOT`, si `pom.xml` y `application.properties` discrepan, o si ese tag ya existe en el registro.
3. Ejecuta `docker build` con labels OCI: `version`, `revision` (commit), `source` (repo), `created` (fecha) y `title`.
4. Con `--push`, ejecuta `docker push` y muestra el digest.

### Resultado real de la publicación (1.0.1)

| Imagen | Digest |
|---|---|
| `edzamo13/austro-ms-risk-mock-credit-evaluation:1.0.1` | `sha256:d2fd5c780f98ab60dd56113fcdb1ffe7c50c8209094a1f99102e7c75808e1fb4` |
| `edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1` | `sha256:799ed5833887a2c8093474b02741613dd57b6dab7e869483e2abe136d617c3da` |
| `edzamo13/austro-mms-ux-credit-evaluation:1.0.1` | `sha256:7f2639224b17b7c1bcd5b612cdc824df4a0fb5e0ded01b82a080e896157659b8` |

Verificación independiente (sin fiarse del script):

```bash
curl -s https://hub.docker.com/v2/repositories/edzamo13/austro-ms-orchestrator-credit-evaluation/tags/
docker inspect --format '{{json .Config.Labels}}' edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
```

## Prácticas de industria regulada vs. este laboratorio

| Práctica (banca, salud) | Qué se hizo aquí | Brecha |
|---|---|---|
| Versión en el código y tag derivado | Sí: `pom.xml` / `package.json` → tag, con script | Ninguna |
| Sin `-SNAPSHOT` en releases | El script lo exige | Ninguna |
| Tags inmutables | El script rechaza un tag existente | El registro no lo impide en Docker Hub gratuito; es una protección del lado del cliente |
| Trazabilidad (labels OCI, commit) | Sí | El commit salió como `-dirty`: los cambios de versión no estaban commiteados. En un pipeline real se publica desde un commit limpio con `git tag v1.0.1` |
| Sin `latest` | No se publicó `latest` | Ninguna |
| Desplegar por digest | Se registraron los digests | En Kubernetes se referenciaría `imagen@sha256:...` |
| Construir una vez y promover | Una imagen, configuración externa | Falta el pipeline de promoción entre ambientes |
| Registro privado | **No**: repositorios públicos en Docker Hub gratuito | Aceptable para un mock de laboratorio; inaceptable con código o datos reales |
| Escaneo de vulnerabilidades, SBOM y firma | No se hizo | Pendiente (Trivy o Docker Scout, cosign) |
| Base images fijadas y lockfile | El lockfile no existía y se generó | Las bases (`node:20-alpine`, `nginx:1.27-alpine`) siguen flotantes; fijarlas por digest |
| Secretos fuera de imagen y compose | No | `DB_PASSWORD` sigue en texto plano; usar `Secret` en Kubernetes |

## Nota sobre el uso de IA

Este laboratorio se ejecutó con asistencia de IA (Claude Code). Para que sea reproducible sin ella, todo lo hecho queda como comandos y como el script de esta carpeta. Un buen criterio al trabajar así: verificar los resultados de forma independiente, como se hizo aquí al consultar la API pública de Docker Hub para confirmar que las imágenes existían, y no dar por hecho lo que la IA o un script afirman.

## Lo que sigue

- Llevar estas imágenes a **Minikube** (los comandos base están en el [README](README.md)).
- Cerrar las brechas de la tabla: escaneo, fijar imágenes base, secretos y publicación desde un commit limpio.

Para entender la tecnología detrás de los microservicios, ver la [arquitectura de Quarkus](ARQUITECTURA-QUARKUS.md).
