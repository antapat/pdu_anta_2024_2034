# Preparar Supabase (sin conectar todavía)

El proyecto conserva sus RDS como fuente local. La integración existente en
`R/supabase_utils.R` registra consultas y reportes; esta preparación añade una
carga administrativa para las capas espaciales y la matriz urbanística.

## Recursos preparados

- `supabase/migrations/001_postgis_pdu.sql`: activa PostGIS y mantiene las
  tablas geográficas fuera del acceso público de la API.
- `scripts/04_cargar_supabase.R`: carga las ocho capas espaciales y
  `parametros_urbanisticos.rds` a `public` mediante PostgreSQL con SSL.
- `.env` y `.Renviron` están excluidos de Git.

## Cuando se autorice la conexión

1. En Supabase, proyecto `psteqbwnyavrmwdiiaht`, abrir **SQL Editor** y ejecutar
   `supabase/migrations/001_postgis_pdu.sql`.
2. Obtener los datos de conexión en **Project Settings → Database → Connect**.
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

3. Desde la raíz del proyecto, ejecutar `source("scripts/04_cargar_supabase.R")`.

El importador borra y vuelve a crear únicamente las tablas de capas listadas y
la tabla de parámetros; no toca consultas, reportes ni avisos. La cadena de
confirmación es obligatoria. Las credenciales nunca deben guardarse en GitHub,
`app.R` ni en el archivo de ejemplo.

La aplicación sigue usando los RDS locales. Este cambio prepara la carga a
PostGIS; la lectura en vivo de capas desde Supabase se implementará aparte una
vez verificada la carga y definida la estrategia de acceso de solo lectura.
