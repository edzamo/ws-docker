# 🏛️ Arquitectura de Quarkus para arquitectos de soluciones

Documento de estudio sobre **Quarkus**, apoyado en un caso real: el proyecto [poc-credit-evaluation](https://github.com/edzamo/poc-credit-evaluation) (Quarkus 3.8.4, Java 21), que se usa en el [laboratorio de contenerización](GUIA-CONTENERIZACION-MICROSERVICIOS.md).

Cada sección sigue el mismo patrón: **concepto → cómo se ve en este proyecto → decisión de arquitectura**. Los datos que aparecen (tamaños, extensiones, configuración, código) se tomaron del proyecto compilado, no son genéricos.

**Índice:** 1. Qué problema resuelve · 2. Build time vs run time · 3. Extensiones · 4. Anatomía del artefacto · 5. Modelo de ejecución · 6. Inyección de dependencias · 7. Configuración · 8. Persistencia · 9. Comunicación entre servicios · 10. Observabilidad · 11. Empaquetado y contenedor · 12. JVM vs nativo · 13. Quarkus vs Spring Boot · 14. Camino a Kubernetes · 15. Ejercicios

---

## 1. Qué problema resuelve

Java nació para servidores grandes y de larga vida: arrancar lento y consumir memoria era aceptable. En una arquitectura de contenedores y Kubernetes, los procesos se crean y destruyen constantemente y se pagan por memoria, así que esos costos importan.

Quarkus es un framework Java diseñado para ese entorno:

- **Arranque rápido y poca memoria** (por el trabajo que mueve a la compilación, ver sección 2).
- **Configuración orientada a contenedores**: todo se puede inyectar por variables de entorno.
- **Experiencia de desarrollo**: `mvn quarkus:dev` recarga el código en caliente y ofrece una consola de desarrollo.
- **Estándares conocidos**: usa Jakarta REST, CDI, JPA/Hibernate y MicroProfile, por lo que el código se parece al Java empresarial habitual.

---

## 2. Build time vs run time: la idea que lo explica todo

Un framework tradicional descubre y conecta los componentes **cada vez que arranca**: escanea clases, resuelve inyección de dependencias, interpreta configuración, prepara el mapeo de rutas REST. Eso cuesta tiempo y memoria en cada arranque.

Quarkus hace ese trabajo **una sola vez, al compilar** (fase llamada *augmentation*) y guarda el resultado. Al arrancar solo carga lo ya calculado.

```text
mvn package                                           java -jar quarkus-run.jar
┌───────────────────────────────────────┐             ┌───────────────────────────┐
│ 1. compila tu código                  │             │ carga el resultado ya     │
│ 2. augmentation: analiza anotaciones, │  artefacto  │ calculado                 │
│    resuelve inyección, prepara rutas, │  ─────────► │ abre el puerto y atiende  │
│    valida configuración               │             │ peticiones                │
│ 3. guarda el resultado en quarkus/    │             │                           │
└───────────────────────────────────────┘             └───────────────────────────┘
   BUILD: una vez (etapa 1 del Dockerfile)              RUN: cada arranque (etapa 2)
```

**Decisión de arquitectura:** el costo se traslada del arranque (que ocurre miles de veces en producción) a la compilación (que ocurre una vez por versión). Esto es lo que hace viable escalar y reiniciar pods con frecuencia.

**Consecuencia práctica:** algunas propiedades de configuración quedan *fijas al compilar* (por ejemplo `quarkus.datasource.db-kind`, que decide qué driver se incluye) y cambiarlas en runtime no tiene efecto. Otras, como la URL o las credenciales, sí se pueden cambiar al arrancar. La documentación de Quarkus marca cuáles son de cada tipo.

---

## 3. Extensiones: el modelo de módulos

Quarkus se compone de **extensiones**. Cada capacidad (REST, base de datos, health checks) es una extensión que agregas al `pom.xml`.

Cada extensión tiene dos partes:

| Módulo | Cuándo actúa | Va en la imagen final |
|---|---|---|
| `runtime` | Mientras la aplicación corre | Sí |
| `deployment` | Durante la compilación (augmentation) | No |

Esto explica algo que viste al compilar: Maven descargó artefactos terminados en `-deployment` (por ejemplo `quarkus-wiremock-deployment`). Son los módulos que trabajan en la compilación y desaparecen del artefacto final.

**El BOM de la plataforma.** En el `pom.xml` aparece `quarkus.platform.version = 3.8.4` y el `quarkus-bom`. El BOM fija las versiones compatibles de cientos de librerías, así que no declaras la versión de cada dependencia: subes la versión de la plataforma y todo el conjunto se actualiza de forma coherente.

### Extensiones reales de cada microservicio

| Capacidad | Extensión | Orquestador | Mock |
|---|---|---|---|
| API REST con JSON | `resteasy-reactive-jackson` | ✔ | ✔ |
| Inyección de dependencias | `arc` | ✔ | ✔ |
| Health checks | `smallrye-health` | ✔ | ✔ |
| Documentación de la API | `smallrye-openapi` | ✔ | ✔ |
| Logs en formato JSON | `logging-json` | — | ✔ |
| Driver PostgreSQL | `jdbc-postgresql` | ✔ | — |
| ORM con Panache | `hibernate-orm-panache` | ✔ | — |
| Migraciones de BD | `flyway` | ✔ | — |
| Validación | `hibernate-validator` | ✔ | — |
| Cliente HTTP hacia el mock | `rest-client-reactive-jackson` | ✔ | — |

**Decisión de arquitectura:** cada extensión suma peso a la imagen y superficie de ataque. Agrega solo las que el servicio necesita. Las extensiones de prueba (`junit5`, `wiremock`, `jdbc-h2`) no forman parte de lo que se despliega.

---

## 4. Anatomía del artefacto

Tras `mvn package`, la carpeta `target/quarkus-app/` (formato *fast-jar*, el predeterminado) contiene todo lo que necesita la imagen:

| Pieza | Contenido | Orquestador | Mock |
|---|---|---|---|
| `quarkus-run.jar` | Lanzador diminuto (unos 700 bytes) que arranca lo demás | ✔ | ✔ |
| `app/` | **Tu código** compilado | 44 KB | 20 KB |
| `lib/boot/` | Librerías de arranque de Quarkus | ✔ | ✔ |
| `lib/main/` | Extensiones y librerías de terceros | ✔ | ✔ |
| `quarkus/` | Resultado de la augmentation: `generated-bytecode.jar`, `transformed-bytecode.jar`, `quarkus-application.dat` | 2.0 MB | 1.7 MB |
| `lib/` (total) | | 42 MB | 18 MB |

**Lectura del cuadro:** tu lógica de negocio pesa kilobytes; las dependencias pesan megabytes. Casi todo el peso de un microservicio son librerías, y por eso elegir bien las extensiones (sección 3) es la palanca real para adelgazar una imagen.

**Por qué este formato:** separar `app/` (cambia en cada versión) de `lib/` (cambia poco) permite que Docker cachee las capas de `lib/` y solo reconstruya `app/`, agilizando builds y descargas.

---

## 5. Modelo de ejecución: event loop y hilos de trabajo

Por debajo, Quarkus usa **Vert.x/Netty**, un modelo *reactivo*: pocos hilos "event loop" atienden muchas conexiones sin bloquearse. Si una petición hace algo lento y bloqueante (esperar una respuesta HTTP, consultar la BD), bloquear un event loop degrada todo el servicio.

Por eso RESTEasy Reactive decide en qué hilo ejecuta cada endpoint:

| El método devuelve… | Se ejecuta en… |
|---|---|
| `Uni`, `Multi`, `CompletionStage` (tipos reactivos) | Event loop (no debe bloquear) |
| Un objeto normal o `void` | Hilo de trabajo (*worker*), donde se puede bloquear |

Además, desde Java 21 existe la opción `@RunOnVirtualThread`, que permite código bloqueante y sencillo con el costo de un hilo virtual.

### Cómo se ve en este proyecto

Ambos microservicios usan estilo **imperativo y bloqueante** (métodos que devuelven objetos normales, sin `Uni`). Es una decisión razonable para una PoC: el código es simple y Quarkus lo ejecuta en hilos de trabajo. El mock simula latencia con `Thread.sleep` (2 s para el score, 1.5 s para las deudas), lo cual es seguro precisamente porque corre en un worker.

### Hallazgo: las llamadas al mock son secuenciales

El README del repositorio y su diagrama de secuencia indican que el orquestador consulta score y deudas **en paralelo**. Sin embargo, en `RiskAdapter.getRiskData` las dos llamadas se hacen una tras otra:

```java
RiskScoreResponse scoreResponse = riskServiceClient.getRiskScore(cedula);      // ~2 s
CustomerDebtsResponse debtsResponse = riskServiceClient.getCustomerDebts(cedula); // ~1.5 s
```

Con las latencias simuladas, la evaluación tarda cerca de **3.5 s** en vez de los ~2 s que tendría en paralelo. Es un buen caso de estudio: la diferencia entre lo que la documentación afirma y lo que el código hace se detecta midiendo, y por eso conviene validar con métricas y no solo con diagramas. Está propuesto como ejercicio en la sección 15.

---

## 6. Inyección de dependencias con ArC

Quarkus usa **ArC**, una implementación de CDI (`@ApplicationScoped`, `@Inject`) que trabaja en *build time*. Dos consecuencias:

- **Los errores de inyección aparecen al compilar**, no al arrancar en producción (por ejemplo, una dependencia sin implementación).
- **Elimina los beans que nadie usa**, reduciendo memoria.

ArC implementa un subconjunto de CDI (sin extensiones portables), a cambio de ser mucho más liviano.

En el proyecto, casi todos los componentes son `@ApplicationScoped` (una instancia compartida). El propio código lo comenta: `RiskAdapter` usa inyección por campo con `@RestClient` porque los calificadores CDI no se pueden expresar en constructores generados por Lombok.

---

## 7. Configuración

### Orden de prioridad de las fuentes

De mayor a menor prioridad:

1. Propiedades de sistema (`-Dquarkus.http.port=9090`)
2. **Variables de entorno**
3. Archivo `.env`
4. `application.properties`

Por eso una variable de entorno siempre gana sobre lo que está escrito en el archivo.

### Mapeo de nombres

Una propiedad se puede sobrescribir con una variable de entorno en mayúsculas y con guiones bajos: `quarkus.http.port` ↔ `QUARKUS_HTTP_PORT`. Es lo que hace el `docker-compose.yml` del proyecto.

### Valores por defecto con `${}`

```properties
quarkus.datasource.jdbc.url=${DB_URL:jdbc:postgresql://localhost:5433/credit_evaluation_db}
quarkus.rest-client.risk-service.url=${RISK_SERVICE_URL:http://localhost:8081}
```

`${VARIABLE:por_defecto}` significa "usa la variable; si no existe, usa este valor". Un mismo artefacto sirve para tres contextos sin recompilar:

| Contexto | Quién aporta los valores |
|---|---|
| Tu máquina (`mvn quarkus:dev`) | Los valores por defecto (`localhost`) |
| Docker Compose | `environment:` del compose |
| Kubernetes | `ConfigMap` y `Secret` |

Es el principio *build once, run anywhere*: se construye **una** imagen y solo cambia la configuración inyectada.

### Perfiles

Quarkus distingue `dev` (con `quarkus:dev`), `test` (en pruebas) y `prod` (el resto). Se pueden dar valores por perfil con prefijo: `%dev.quarkus.log.level=DEBUG`.

**Decisión de arquitectura:** las credenciales no deberían tener valores por defecto en el código. En este proyecto `application.properties` incluye `austro_user` y `austro_pass` como valores por defecto, y el compose los repite en texto plano. Para producción, mover esos valores a un `Secret` y quitar los defaults.

---

## 8. Persistencia y migraciones

El orquestador combina tres piezas:

| Pieza | Rol | Configuración del proyecto |
|---|---|---|
| Hibernate ORM + Panache | Mapeo objeto-relacional | `quarkus.hibernate-orm.database.generation=none` |
| Flyway | Versiona el esquema con scripts SQL | `migrate-at-start=true`, script `V1__create_credit_evaluations_table.sql` |
| PostgreSQL | Almacenamiento | Imagen oficial, con volumen |

**Buena práctica ya aplicada:** `database.generation=none` deja que **solo Flyway** modifique el esquema. Hibernate no toca la estructura, así que cada cambio queda como un script versionado y auditable.

**Decisión de arquitectura sobre `migrate-at-start`:** cada pod que arranca intenta migrar. Flyway usa un bloqueo sobre su tabla de historial, así que dos pods no aplican la misma migración a la vez y es seguro. Aun así, muchos equipos prefieren ejecutar las migraciones en un `Job` o `initContainer` separado cuando escalan a varias réplicas, para que el arranque de la aplicación no dependa de ellas.

### Segundo hallazgo: transacción alrededor de llamadas remotas

`EvaluateCreditUseCaseImpl.evaluate` está anotado con `@Transactional`, y dentro de ese método se hacen las llamadas HTTP al mock (~3.5 s) antes de guardar. La transacción queda abierta durante todo ese tiempo de espera de red. Normalmente la conexión JDBC se toma al primer acceso a la BD, así que no se retiene desde el inicio, pero la práctica recomendada es acotar la transacción a lo que realmente toca la base de datos (el `save`), dejando la consulta remota fuera. Está propuesto como ejercicio.

---

## 9. Comunicación entre servicios

El orquestador llama al mock mediante **MicroProfile REST Client**: una interfaz declarativa que actúa como contrato tipado.

```java
@RegisterRestClient(configKey = "risk-service")
@Path("/v1")
public interface RiskServiceClient {
    @GET @Path("/risk-score/{cedula}")
    RiskScoreResponse getRiskScore(@PathParam("cedula") String cedula);
}
```

La URL no está en el código, sino en la configuración (`quarkus.rest-client.risk-service.url`), enlazada por el `configKey`. El proyecto también define timeouts explícitos: `connect-timeout=3000` y `read-timeout=10000` milisegundos. Definir timeouts es imprescindible: sin ellos, un servicio lento puede dejar hilos esperando indefinidamente.

**Lo que falta (siguiente nivel de madurez):** hoy un fallo del mock se captura en `RiskAdapter` y se convierte en `RiskServiceUnavailableException`. No hay reintentos ni circuit breaker. La extensión `smallrye-fault-tolerance` los añade con anotaciones:

| Anotación | Qué resuelve |
|---|---|
| `@Timeout` | Corta la espera por encima de un límite |
| `@Retry` | Reintenta ante fallos transitorios |
| `@CircuitBreaker` | Deja de llamar a un servicio caído para no agravar el problema |
| `@Fallback` | Define una respuesta alternativa |

El repositorio documenta que eligió REST sobre gRPC; esa justificación está en su README.

---

## 10. Observabilidad y operación

| Endpoint | Extensión | Para qué sirve |
|---|---|---|
| `/q/health` | `smallrye-health` | Estado general (usado por los healthchecks del compose) |
| `/q/health/live` | `smallrye-health` | *Liveness*: ¿el proceso está vivo? |
| `/q/health/ready` | `smallrye-health` | *Readiness*: ¿puede recibir tráfico? |
| `/q/health/started` | `smallrye-health` | *Startup*: ¿terminó de arrancar? |
| `/swagger-ui` | `smallrye-openapi` | Documentación interactiva de la API |
| `/q/dev-ui` | (solo modo dev) | Consola de desarrollo con extensiones, configuración y más |

En Kubernetes, `live` y `ready` se mapean directamente a las *liveness* y *readiness probes*.

**Qué no tiene el proyecto todavía:** métricas (extensión `micrometer`) y trazas distribuidas (`opentelemetry`). Con tres servicios encadenados, poder ver cuánto tarda cada salto (frontend → orquestador → mock → BD) es lo que permitiría detectar el hallazgo de la sección 5 sin leer el código. El mock ya usa `logging-json`, un formato apto para agregadores de logs.

---

## 11. Empaquetado y contenedor

### Formas de empaquetar

| Formato | Resultado | Uso |
|---|---|---|
| **fast-jar** (predeterminado) | Carpeta `quarkus-app/` | El de este proyecto; arranque rápido y capas cacheables |
| uber-jar | Un único jar con todo | Distribución simple, sin optimizar caché |
| Nativo | Binario ejecutable (GraalVM) | Ver sección 12 |

### Formas de construir la imagen

| Enfoque | Cómo |
|---|---|
| Dockerfile propio (el de este proyecto) | `docker build`, multi-stage con Maven dentro |
| Plantillas de Quarkus | Genera `Dockerfile.jvm`, `Dockerfile.legacy-jar`, `Dockerfile.native`, `Dockerfile.native-micro` en `src/main/docker/` |
| Extensión de imagen | `quarkus-container-image-jib` o `-docker`: construye la imagen desde Maven, sin escribir Dockerfile |

El nombre `Dockerfile.jvm` viene de esa convención: indica que empaqueta el resultado del modo JVM. Es un Dockerfile normal.

### Observación sobre el Dockerfile del proyecto

Define `ENV JAVA_OPTS_APPEND=...` pero arranca con `ENTRYPOINT ["java", "-jar", ...]`. `JAVA_OPTS_APPEND` es interpretada por el script de arranque (`run-java.sh`) de las imágenes base de Red Hat, no por la JVM, así que con `java -jar` directo esa línea no tiene efecto. El servicio funciona igual porque en producción Quarkus ya escucha en `0.0.0.0` por defecto. Si se quisiera pasar opciones a la JVM en este esquema, la variable adecuada es `JAVA_TOOL_OPTIONS`.

### Memoria de la JVM en contenedores

La JVM moderna respeta los límites del contenedor, y por defecto usa como heap máximo un 25 % de la memoria disponible. Se ajusta con `-XX:MaxRAMPercentage`. En Kubernetes, define `requests` y `limits` de memoria y **mide** antes de decidir los valores.

---

## 12. JVM vs nativo

| Criterio | JVM (el del proyecto) | Nativo (GraalVM) |
|---|---|---|
| Arranque | Rápido | El más rápido |
| Memoria | Baja para ser Java | La más baja |
| Tiempo de compilación | Corto | Largo |
| Compatibilidad de librerías | Total | Requiere validar reflexión y librerías |
| Complejidad del pipeline | Simple | Mayor (GraalVM, más recursos) |
| Rendimiento sostenido bajo carga | Muy bueno (JIT optimiza con el tiempo) | Bueno, sin optimización dinámica |
| Cuándo elegirlo | Punto de partida por defecto | Escalado a cero, funciones efímeras o arranque instantáneo crítico |

**Decisión:** para esta PoC, JVM es la correcta. Pasar a nativo se justifica con datos (métricas de arranque y memoria que demuestren el beneficio), no por moda.

---

## 13. Quarkus vs Spring Boot

Comparación honesta, sin ganador absoluto:

| Aspecto | Quarkus | Spring Boot |
|---|---|---|
| Trabajo pesado | Principalmente en compilación | Principalmente en arranque (con opción AOT/nativo en versiones recientes) |
| Modelo de DI | CDI (ArC) | Contenedor propio de Spring |
| Desarrollo | Dev mode con recarga en caliente y Dev UI | DevTools |
| Ecosistema | Amplio y creciendo | Mucho mayor y más antiguo |
| Curva de aprendizaje del equipo | Menor si ya conocen Jakarta EE/CDI/JPA | Menor si ya conocen Spring |
| Ajuste a contenedores | Diseñado para ello desde el inicio | Adaptado con el tiempo |

**Decisión:** el mayor peso lo suele tener el conocimiento del equipo y el ecosistema existente, más que el rendimiento bruto.

---

## 14. Camino a Kubernetes

Preguntas a resolver antes de llevar estos servicios a Minikube:

1. **¿Es sin estado?** El orquestador y el mock no guardan estado local, por lo que se pueden escalar a varias réplicas. El estado vive en PostgreSQL, que sí requiere un volumen persistente.
2. **¿Dónde van las credenciales?** En un `Secret`, no en el compose ni como defaults en `application.properties`.
3. **¿Qué URLs cambian?** `DB_URL` y `RISK_SERVICE_URL` deben apuntar a los nombres de los `Service` de Kubernetes, y los orígenes CORS (hoy `localhost`) al dominio real del frontend.
4. **¿Cómo sabe Kubernetes que está sano?** Con `/q/health/live` y `/q/health/ready` como probes.
5. **¿Cuánta memoria pedir?** Definir `requests` y `limits`, y medir.
6. **¿Qué versión corre en cada ambiente?** Por eso se versionan las imágenes (`1.0.0`, `1.0.1`…) en lugar de depender de `latest`.
7. **¿Cómo se migra el esquema con varias réplicas?** Ver la nota sobre Flyway en la sección 8.

---

## 15. Ejercicios prácticos sobre este proyecto

Ordenados de menor a mayor esfuerzo. Cada uno refuerza una sección.

| # | Ejercicio | Sección | Cómo |
|---|---|---|---|
| 1 | Explorar el modo desarrollo | 1, 10 | `mvn quarkus:dev` en el mock; abrir `/q/dev-ui` y `/swagger-ui` |
| 2 | Abrir el artefacto | 4 | `unzip -l target/quarkus-app/quarkus/generated-bytecode.jar` para ver qué generó la augmentation |
| 3 | Probar una imagen antes de publicarla | 11 | `docker run --rm -p 8081:8081 austro/ms-risk-mock-credit-evaluation:1.0.0` y `curl localhost:8081/q/health/ready` |
| 4 | Cambiar configuración sin recompilar | 7 | Repetir el ejercicio 3 con `-e QUARKUS_HTTP_PORT=9090` y mapear el puerto 9090 |
| 5 | Medir el hallazgo de las llamadas secuenciales | 5 | Enviar una evaluación y medir el tiempo total con `curl -w "%{time_total}"` (esperado ~3.5 s) |
| 6 | Paralelizar las dos consultas | 5 | Modificar `RiskAdapter` para lanzarlas a la vez y volver a medir (esperado ~2 s) |
| 7 | Acotar la transacción | 8 | Quitar `@Transactional` del caso de uso y aplicarla solo al guardado |
| 8 | Añadir resiliencia | 9 | Agregar `smallrye-fault-tolerance` y anotar `RiskServiceClient` con `@Timeout` y `@Retry` |
| 9 | Añadir métricas | 10 | Agregar `micrometer-registry-prometheus` y revisar `/q/metrics` |
| 10 | Comparar con nativo (opcional) | 12 | `mvn package -Dnative -Dquarkus.native.container-build=true` y comparar arranque y memoria |

---

## Referencias

- Documentación oficial: [quarkus.io/guides](https://quarkus.io/guides/)
- Referencia de configuración (indica qué propiedades son de *build time*): [quarkus.io/guides/all-config](https://quarkus.io/guides/all-config)
- Laboratorio práctico: [GUIA-CONTENERIZACION-MICROSERVICIOS.md](GUIA-CONTENERIZACION-MICROSERVICIOS.md)
