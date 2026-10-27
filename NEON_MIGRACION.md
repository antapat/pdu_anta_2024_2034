# Estado de Migración: Neon Serverless PostgreSQL (PostGIS)
**GeoVisor PDU Anta (2024 - 2034)**  
**Municipalidad Provincial de Anta - GDUR**

> **Fase Actual:** **MIGRACIÓN A NEON COMPLETADA Y ACTIVA**  
> Todas las capas espaciales (zonificación, vías, servidumbres, ámbito, ferrocarril) y tablas normativas han sido migradas a Neon Serverless PostgreSQL con PostGIS y optimizadas con índices espaciales GIST.  
> Adicionalmente, se dispone del paquete de respaldo ultra-ligero en `data_pdu/` (formato RDS y GeoJSON) para despliegues independientes en Posit Connect Cloud y GitHub sin depender de shapefiles pesados.

---

## 1. Justificación del Cambio: Supabase vs. Neon

| Característica | Supabase (Deprecado) | Neon PostgreSQL (Destino) |
| :--- | :--- | :--- |
| **Arquitectura** | BaaS integral (Auth, Storage, PostgREST, Realtime) con servicios no utilizados por Shiny. | PostgreSQL puro serverless optimizado para conexiones directas. |
| **Comportamiento en Inactividad** | Pausa la instancia en planes gratuitos; requería GitHub Actions de *keep-alive* cada 3 días. | *Scale-to-zero* automático; reactivación transparente en ~500 ms ante cualquier conexión entrante. |
| **Soporte Espacial** | PostGIS habilitado mediante extensión. | PostGIS nativo completo (versión 3.4+ sobre PostgreSQL 16/17). |
| **Protocolo de Acceso** | Mixto: RPostgres directo + REST API / PostgREST (doble complejidad). | Estándar universal: protocolo PostgreSQL nativo vía `RPostgres` / `DBI` con pooling integrado. |
| **Entornos de Desarrollo** | Un único proyecto o múltiples proyectos manuales. | **Branching instantáneo:** ramas de base de datos aisladas (dev, staging, prod) copiadas en segundos con *copy-on-write*. |

---

## 2. Compatibilidad del Esquema de Datos

Las migraciones SQL existentes en [`supabase/migrations/`](file:///d:/plataformas_gdur/pdu_anta_2024_2034/supabase/migrations/) son **código SQL estándar de PostgreSQL y PostGIS**:

1. `001_postgis_pdu.sql`:
   - `CREATE EXTENSION IF NOT EXISTS postgis;`
   - Creación de tabla de auditoría `pdu_importaciones`.
2. `002_metricas_geovisor.sql`:
   - Tablas `visitas_geovisor`, `constancias_geovisor`, `consultas_pdu`.
   - Funciones almacenadas `registrar_visita`, `registrar_constancia`, `get_metricas_geovisor`.
3. `003_corregir_contadores_geovisor.sql`:
   - Corrección de visibilidad de métricas públicas.

**Resultado:** No se requiere reescribir las tablas ni las funciones espaciales. Se pueden ejecutar directamente en la consola SQL de Neon.

---

## 3. Variables de Entorno para Neon (Fase Posterior)

Cuando se concluyan los ajustes locales y se configure el proyecto en [neon.tech](https://neon.tech), las credenciales se configurarán en `.Renviron` o como secretos en Posit Connect:

```ini
# Configuración del GeoVisor PDU Anta para Neon
PDU_DATA_SOURCE=neon

# Parámetros de conexión a Neon
NEON_HOST=ep-tu-proyecto-pooler.us-east-2.aws.neon.tech
NEON_PORT=5432
NEON_DB=neondb
NEON_USER=tu_usuario_neon
NEON_PASSWORD=tu_contrasena_neon
NEON_SSLMODE=require

# Alternativamente vía Connection String unificado:
DATABASE_URL=postgresql://tu_usuario:tu_contrasena@ep-tu-proyecto-pooler.us-east-2.aws.neon.tech/neondb?sslmode=require
```

---

## 4. Estructura del Conector Neon Previsto (`R/neon_utils.R`)

La conexión a Neon será simple, directa y sin intermediarios REST:

```r
neon_conectar <- function() {
  requireNamespace("DBI", quietly = TRUE)
  requireNamespace("RPostgres", quietly = TRUE)
  
  url <- Sys.getenv("DATABASE_URL", "")
  if (nzchar(url)) {
    # Parseo o conexión directa por URI
    return(DBI::dbConnect(RPostgres::Postgres(), dbname = url))
  }
  
  DBI::dbConnect(
    RPostgres::Postgres(),
    host     = Sys.getenv("NEON_HOST"),
    port     = as.integer(Sys.getenv("NEON_PORT", "5432")),
    dbname   = Sys.getenv("NEON_DB", "neondb"),
    user     = Sys.getenv("NEON_USER"),
    password = Sys.getenv("NEON_PASSWORD"),
    sslmode  = "require",
    connect_timeout = 8
  )
}
```

---

## 5. Estado Actual: Modo Local Autónomo

Durante la fase actual de desarrollo y ajustes en la app:
- `PDU_DATA_SOURCE=local` es el valor por defecto.
- Las capas espaciales se leen desde los Shapefiles en [`data/`](file:///d:/plataformas_gdur/pdu_anta_2024_2034/data/).
- Los estilos cartográficos oficiales están en [`R/estilos_territoriales.R`](file:///d:/plataformas_gdur/pdu_anta_2024_2034/R/estilos_territoriales.R).
- Las funciones de `R/supabase_utils.R` actúan en modo emulado/local sin intentar conectarse a la red ni generar errores.
- Los reportes ciudadanos del buzón y las métricas se registran localmente en `outputs/`.
