# Almacén de Deprecación: Conexiones y Recursos Supabase
**GeoVisor PDU Anta (2024 - 2034)**  
**Municipalidad Provincial de Anta - GDUR**

> ⚠️ **ESTADO:** DEPRECADO (Octubre 2026)  
> **ESTADO ACTUAL DEL PROYECTO:** Operación en **MODO LOCAL AUTÓNOMO** (`PDU_DATA_SOURCE=local`).  
> **PRÓXIMA INFRAESTRUCTURA CLOUD:** **Neon Serverless PostgreSQL + PostGIS**.

---

## 1. Motivos de la Deprecación de Supabase

1. **Desacoplamiento Tecnológico:**  
   Supabase implementaba capas adicionales orientadas a JAMstack / BaaS (PostgREST, Auth GoTrue, API keys publicables/secretas, endpoints REST) que no son necesarias para una aplicación espacial R/Shiny institucional.
2. **Eliminación de la Dependencia de Keep-Alive:**  
   En los planes gratuitos de Supabase, las bases de datos entran en pausa tras inactividad, lo que requería workflows periódicos como `keep-supabase-alive.yml`. Neon maneja el escalado a cero (*scale-to-zero*) y reactivación instantánea sin necesidad de pings artificiales.
3. **Migración a Estándar PostgreSQL Puro (Neon):**  
   Neon ofrece PostgreSQL serverless con soporte nativo de PostGIS, branching instantáneo para pruebas y connection pooling integrado estándar (`sslmode=require`), simplificando la conexión directa mediante `DBI` / `RPostgres`.
4. **Fase de Ajustes en Local:**  
   Antes de desplegar a Neon, la aplicación se opera y prueba íntegramente en local con los Shapefiles oficiales ubicados en `data/` y parámetros consolidados en `R/parametros_locales.R`.

---

## 2. Inventario de Recursos Deprecados en este Directorio

| Archivo Archivado | Función Original | Motivo de Deprecación |
| :--- | :--- | :--- |
| `supabase_utils.legacy.R` | Módulo original de conexión dual (Postgres/REST) y RPCs de Supabase. | Reemplazado por adaptador con deprecación formal en `R/` y emuladores locales. |
| `03_aplicar_migraciones_supabase.R` | Script de aplicación de migraciones SQL al proyecto Supabase. | Se adaptará para Neon en `scripts/neon/`. |
| `04_cargar_supabase.R` | Carga de capas RDS a tablas PostGIS en Supabase. | Se adaptará para Neon en `scripts/neon/`. |
| `05_verificar_supabase.R` | Verificación de conteos de tablas en Supabase. | Se adaptará para Neon en `scripts/neon/`. |
| `config.toml` | Configuración local del CLI de Supabase (`project_id`). | No aplica en arquitectura Neon. |
| `keep-supabase-alive.yml` | GitHub Action para evitar la pausa por inactividad de Supabase. | Obsoleto; Neon despierta en milisegundos bajo demanda. |
| `supabase_schema.sql` | Esquema monolítico inicial de Supabase. | Migrado a scripts SQL universales PostGIS en `supabase/migrations/` portables a Neon. |

---

## 3. Plan de Migración a Neon PostgreSQL

Para consultar la guía técnica de migración y la arquitectura prevista con Neon, consulte [`NEON_MIGRACION.md`](file:///d:/plataformas_gdur/pdu_anta_2024_2034/NEON_MIGRACION.md).
