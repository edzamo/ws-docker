#!/usr/bin/env bash
# Construye (y con --push, publica) las 3 imágenes del laboratorio.
# La versión de cada imagen se LEE del código fuente (pom.xml / package.json): esa es la única fuente de verdad.
#
# Uso:   ./scripts/publicar-imagenes.sh            # solo construye
#        ./scripts/publicar-imagenes.sh --push     # construye y publica en Docker Hub
# Variables opcionales: DOCKER_USER (por defecto edzamo13), PREFIX (por defecto austro), PROJECT_DIR
set -euo pipefail

DOCKER_USER="${DOCKER_USER:-edzamo13}"
PREFIX="${PREFIX:-austro}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT_DIR:-$HERE/poc-credit-evaluation}"
SOURCE_URL="https://github.com/edzamo/poc-credit-evaluation"
SERVICES=(ms-risk-mock-credit-evaluation ms-orchestrator-credit-evaluation mms-ux-credit-evaluation)
PUSH=false
[[ "${1:-}" == "--push" ]] && PUSH=true

fail() { echo "ERROR: $*" >&2; exit 1; }

pom_version() {
  python3 - "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
v = root.find('{http://maven.apache.org/POM/4.0.0}version')
if v is None:
    v = root.find('version')
print(v.text.strip())
PY
}

json_version() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$1"; }

[[ -d "$PROJECT" ]] || fail "No existe el proyecto en $PROJECT (clónalo primero)"

REVISION="$(git -C "$PROJECT" rev-parse --short HEAD)"
if [[ -n "$(git -C "$PROJECT" status --porcelain)" ]]; then
  REVISION="$REVISION-dirty"
  echo "AVISO: hay cambios sin commitear en el proyecto; el label de revisión será $REVISION."
  echo "       En un pipeline real, publica solo desde un commit limpio y etiquetado (git tag vX.Y.Z)."
fi
CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

SUMMARY=()
for svc in "${SERVICES[@]}"; do
  dir="$PROJECT/$svc"
  if [[ -f "$dir/pom.xml" ]]; then
    version="$(pom_version "$dir/pom.xml")"
    dockerfile="$dir/src/main/docker/Dockerfile.jvm"
    app_v="$(grep -m1 '^quarkus.application.version=' "$dir/src/main/resources/application.properties" | cut -d= -f2 || true)"
    [[ -z "$app_v" || "$app_v" == "$version" ]] || fail "$svc: pom.xml dice $version pero application.properties dice $app_v"
  else
    version="$(json_version "$dir/package.json")"
    dockerfile="$dir/Dockerfile"
  fi

  [[ "$version" != *-SNAPSHOT ]] || fail "$svc: la versión $version es SNAPSHOT; publica solo versiones release"
  image="$DOCKER_USER/$PREFIX-$svc"

  if $PUSH && docker manifest inspect "$image:$version" >/dev/null 2>&1; then
    fail "$image:$version ya existe en el registro; los tags publicados son inmutables (sube la versión)"
  fi

  echo "==> Construyendo $image:$version"
  docker build -q \
    --label "org.opencontainers.image.title=$PREFIX-$svc" \
    --label "org.opencontainers.image.version=$version" \
    --label "org.opencontainers.image.revision=$REVISION" \
    --label "org.opencontainers.image.source=$SOURCE_URL" \
    --label "org.opencontainers.image.created=$CREATED" \
    -t "$image:$version" -f "$dockerfile" "$dir" >/dev/null

  if $PUSH; then
    echo "==> Publicando $image:$version"
    docker push -q "$image:$version" >/dev/null
    SUMMARY+=("$(docker inspect --format '{{index .RepoDigests 0}}' "$image:$version")")
  else
    SUMMARY+=("$image:$version (solo local)")
  fi
done

echo
echo "Resultado (imagen@digest si se publicó):"
printf '  %s\n' "${SUMMARY[@]}"
