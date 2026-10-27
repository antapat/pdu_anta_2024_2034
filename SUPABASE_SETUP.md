> ⚠️ **DOCUMENTO DEPRECADO (HISTÓRICO)**  
> Las conexiones y despliegues hacia Supabase han sido declaradas **obsoletas**.  
> **Estado Actual:** El GeoVisor opera en **MODO LOCAL AUTÓNOMO** (`PDU_DATA_SOURCE=local`).  
> **Próxima Migración:** Neon Serverless PostgreSQL + PostGIS (ver [NEON_MIGRACION.md](file:///d:/plataformas_gdur/pdu_anta_2024_2034/NEON_MIGRACION.md)).  
> Los scripts y recursos originales de Supabase han sido archivados en [deprecated/supabase/](file:///d:/plataformas_gdur/pdu_anta_2024_2034/deprecated/supabase/).

# Supabase (DEPRECADO) - Historial de Configuración y Migración

Las capas espaciales se almacenaban históricamente en Supabase/PostGIS.
Actualmente el proyecto trabaja en local y se prepara para migrar a Neon PostgreSQL.

## Recursos preparados

- `supabase/migrations/001_postgis_pdu.sql`: activa PostGIS y mantiene las
  tablas geográficas fuera del acceso público de la API.
- `supabase/migrations/002_metricas_geovisor.sql`: crea los contadores de
  visitas y constancias mediante funciones RPC seguras, y cierra la inserción
  anónima del antiguo buzón ciudadano.
- `supabase/config.toml`: vincula la configuración local del CLI con el
  proyecto `psteqbwnyavrmwdiiaht` para que la integración del repositorio
  detecte y aplique las migraciones.
- `scripts/04_cargar_supabase.R`: carga las ocho capas espaciales y
  `parametros_urbanisticos.rds` a `public` mediante una transacción PostgreSQL
  con SSL, crea índices espaciales GiST y valida los conteos.
- `scripts/05_verificar_supabase.R`: verifica que todas las tablas tengan datos
  y que Shiny pueda leerlas antes del despliegue.
- `scripts/03_aplicar_migraciones_supabase.R`: aplica en orden las migraciones
  SQL usando la misma conexión segura, sin depender del SQL Editor.
- `.env` y `.Renviron` están excluidos de Git.

## Cuando se autorice la conexión

1. Obtener los datos de conexión en **Project Settings → Database → Connect**.
   Guardarlos localmente como variables de entorno, sin subirlos al repositorio:

   ```text
   SUPABASE_PROJECT_REF=psteqbwnyavrmwdiiaht
   SUPABASE_HOST=<host mostrado en Connect>
   SUPABASE_PORT=5432
   SUPABASE_DB=postgres
   SUPABASE_USER=<usuario mostrado en Connect>
   SUPABASE_PASSWORD=<contraseña de base de datos>
   SUPABASE_IMPORT_CONFIRM=REEMPLAZAR_CAPAS_PDU
   ```

2. Desde la raíz del proyecto, ejecutar:

   ```r
   source("scripts/03_aplicar_migraciones_supabase.R")
   source("scripts/04_cargar_supabase.R")
   source("scripts/05_verificar_supabase.R")
   ```

El importador borra y vuelve a crear únicamente las tablas de capas listadas y
la tabla de parámetros; no toca consultas, reportes ni avisos. La cadena de
confirmación es obligatoria. Las credenciales nunca deben guardarse en GitHub,
`app.R` ni en el archivo de ejemplo.

Las mismas cinco variables PostgreSQL deben configurarse como secretos en
Posit Connect. No se debe publicar la contraseña en GitHub. La URL y la llave
anónima REST pueden configurarse adicionalmente para métricas, pero no
reemplazan la conexión PostgreSQL requerida para cargar las geometrías.

Las visitas se deduplican por navegador y día con un identificador aleatorio
transformado a SHA-256 dentro de la base de datos; no se guarda la dirección IP
ni datos personales.

Supabase actúa como base de datos, PostGIS y API. El proceso R/Shiny continúa
ejecutándose en Posit Connect; Supabase no es un runtime para aplicaciones R.
