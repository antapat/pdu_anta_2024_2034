# Guía de Despliegue y Conexión con Posit Connect Cloud y Supabase

Esta guía detalla los pasos para publicar y operar el **GeoVisor PDU Anta (2024 - 2034)** en **Posit Connect Cloud** bajo la cuenta **`https://connect.posit.cloud/patantampa`**, conectado a la base de datos en la nube **Supabase**.

---

## 1. Arquitectura de la Solución

El proyecto está preparado para ejecutarse tanto en entornos Cloud como en estaciones de trabajo locales:
- **`app.R`**: Interfaz Shiny moderna con diseño institucional (`bslib` Bootstrap 5), mapa Leaflet con capas interactivas y generación de constancias.
- **`R/supabase_utils.R`**: Módulo de conexión híbrida a Supabase (PostgreSQL nativo con `RPostgres` y REST con `httr2`), con tolerancia a fallos (Modo Autónomo Local si no hay internet o credenciales).
- **`supabase_schema.sql`**: Esquema SQL con tablas para auditoría de consultas (`consultas_pdu`), buzón ciudadano (`reportes_ciudadanos`) y comunicados oficiales (`avisos_municipales`).
- **`manifest.json`**: Manifiesto precalculado con todas las 96 dependencias exactas para despliegue automatizado sin fallos de compilación en Linux.
- **`constancia_pdu_template.qmd`**: Plantilla Quarto con compilación directa en **Typst** (nativa en Posit Connect Cloud sin requerir Chrome ni LaTeX pesado).

---

## 2. Configuración de Variables de Entorno en Posit Connect Cloud

Para que la aplicación interactúe con tu proyecto de Supabase en Posit Connect Cloud:

1. Ingresa a tu panel en [Posit Connect Cloud (`patantampa`)](https://connect.posit.cloud/patantampa).
2. Abre la aplicación publicada (ej. `geovisorpdu` o `geovisor-pdu-anta`).
3. Ve a la pestaña **«Settings»** -> **«Environment Variables»**.
4. Agrega las siguientes variables:

### Opción A (Recomendada: PostgreSQL Directo con PostGIS):
| Variable | Descripción | Ejemplo / Valor |
|---|---|---|
| `SUPABASE_HOST` | Host de base de datos Supabase | `aws-0-sa-east-1.pooler.supabase.com` |
| `SUPABASE_DB` | Base de datos | `postgres` |
| `SUPABASE_PORT` | Puerto de conexión | `5432` o `6543` |
| `SUPABASE_USER` | Usuario Postgres | `postgres.biosgkmmkjylceckzmcu` |
| `SUPABASE_PASSWORD` | Contraseña de Supabase | *(tu contraseña secreta)* |

### Opción B (API REST PostgREST):
| Variable | Descripción | Ejemplo / Valor |
|---|---|---|
| `SUPABASE_URL` | URL de tu proyecto Supabase | `https://biosgkmmkjylceckzmcu.supabase.co` |
| `SUPABASE_ANON_KEY` | Llave anónima pública de Supabase | *(llave anon de Project Settings -> API)* |

> **Nota de Seguridad:** Si no se configuran estas variables, la aplicación **no arrojará errores**; entrará automáticamente en **Modo Autónomo Local**, permitiendo que todas las consultas territoriales y descargas de PDF funcionen sin interrupción.

---

## 3. Despliegue desde GitHub (Git-Backed) a `connect.posit.cloud/patantampa`

Posit Connect Cloud sincroniza automáticamente el código desde tu repositorio de GitHub:

1. Ve a [Posit Connect Cloud](https://connect.posit.cloud/patantampa).
2. Haz clic en **«Publish Content»** y selecciona **«From a Git Repository»**.
3. Conecta el repositorio del GeoVisor (`geovisorpdu`).
4. Selecciona:
   - **Branch:** `main` (o tu rama activa).
   - **Deployment Type:** Shiny Application.
   - **Primary Document:** `app.R` (o detección automática vía `manifest.json`).
5. Haz clic en **«Deploy»**.
6. Cada `git push` a tu repositorio actualizará la versión pública automáticamente.

---

## 4. Despliegue Manual desde R con `rsconnect`

Si prefieres desplegar directamente desde tu sesión local de RStudio o PowerShell:

```r
library(rsconnect)

# Configurar tu cuenta patantampa (obtén el token desde tu perfil en connect.posit.cloud)
rsconnect::setAccountInfo(
  name   = "patantampa",
  token  = "<tu-token-de-posit-cloud>",
  secret = "<tu-secret-de-posit-cloud>",
  server = "posit.cloud"
)

# Desplegar la app
rsconnect::deployApp(
  appDir        = ".",
  appName       = "geovisor-pdu-anta",
  appTitle      = "GeoVisor PDU Anta 2024-2034",
  appPrimaryDoc = "app.R",
  forceUpdate   = TRUE
)
```

---

## 5. Mantenimiento del Manifiesto de Dependencias

Si agregas nuevos paquetes de R al proyecto, actualiza el manifiesto ejecutando:

```r
source("scripts/generate_manifest.R")
```

Esto garantiza que el entorno Linux de Posit Connect Cloud instale exactamente las versiones requeridas.
