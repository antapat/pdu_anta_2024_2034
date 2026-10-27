# ==============================================================================
# MIGRACIÓN OFICIAL DE DATOS PDU ANTA (2024-2034) A NEON SERVERLESS POSTGRESQL
# ==============================================================================
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(sf)
})

cat("=== 1. Conectando a Neon Serverless PostgreSQL ===\n")
con <- dbConnect(
  Postgres(),
  host = "ep-dark-leaf-ar15e2f4-pooler.c-4.us-west-2.aws.neon.tech",
  port = 5432,
  dbname = "neondb",
  user = "neondb_owner",
  password = "npg_9sGhLlAai3RB",
  sslmode = "require",
  connect_timeout = 15
)

# 1. Extensiones requeridas
cat("=== 2. Habilitando extensiones PostGIS y UUID ===\n")
dbExecute(con, "CREATE EXTENSION IF NOT EXISTS postgis;")
dbExecute(con, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";")

# 2. Cargar capas preparadas con todas sus columnas y atributos oficiales
cat("=== 3. Procesando capas locales del PDU ===\n")
source("R/local_data.R")
datos_locales <- pdu_cargar_datos_locales()
capas <- datos_locales$capas
parametros <- datos_locales$parametros

# 3. Mapeo de tablas de destino
tablas_espaciales <- list(
  zonificacion        = capas$zonificacion,
  vias                = capas$vias,
  alta_tension        = capas$alta_tension,
  alta_tension_buffer = capas$alta_tension_buffer,
  ferrocarril         = capas$ferrocarril,
  ferrocarril_buffer  = capas$ferrocarril_buffer,
  ambito              = capas$ambito
)

if (!is.null(capas$distritos) && nrow(capas$distritos) > 0) {
  tablas_espaciales$distritos <- capas$distritos
}

cat("=== 4. Creando tabla de auditoría e importaciones ===\n")
dbExecute(con, "
CREATE TABLE IF NOT EXISTS public.pdu_importaciones (
    id SERIAL PRIMARY KEY,
    conjunto VARCHAR(100) NOT NULL,
    filas INTEGER NOT NULL,
    fecha TIMESTAMPTZ DEFAULT NOW()
);")

# 4. Migrar cada capa espacial
cat("=== 5. Subiendo capas espaciales a Neon PostgreSQL ===\n")
for (nom_tabla in names(tablas_espaciales)) {
  obj <- tablas_espaciales[[nom_tabla]]
  if (!inherits(obj, "sf")) next
  
  cat(sprintf("  -> Subiendo '%s' (%d filas)... ", nom_tabla, nrow(obj)))
  
  # Asegurar CRS EPSG:4326
  obj_4326 <- st_transform(st_make_valid(obj), 4326)
  
  # Eliminar tabla previa si existe
  dbExecute(con, sprintf("DROP TABLE IF EXISTS public.%s CASCADE;", nom_tabla))
  
  # Escribir con sf::st_write
  st_write(obj_4326, con, layer = nom_tabla, quiet = TRUE)
  
  # Identificar nombre de la columna geométrica
  geom_col <- attr(obj_4326, "sf_column")
  
  # Crear índice espacial GIST optimizado
  idx_geom <- sprintf("idx_%s_%s_gist", nom_tabla, geom_col)
  dbExecute(con, sprintf("CREATE INDEX IF NOT EXISTS %s ON public.%s USING GIST (%s);",
                         idx_geom, nom_tabla, geom_col))
  
  # Índices adicionales para consultas rápidas
  if (nom_tabla == "zonificacion") {
    dbExecute(con, 'CREATE INDEX IF NOT EXISTS idx_zonif_cod_s_zona ON public.zonificacion ("COD_S_ZONA");')
    dbExecute(con, 'CREATE INDEX IF NOT EXISTS idx_zonif_cod_zona ON public.zonificacion ("COD_ZONA");')
  } else if (nom_tabla == "vias") {
    dbExecute(con, 'CREATE INDEX IF NOT EXISTS idx_vias_categ_via ON public.vias ("CATEG_VIA");')
    dbExecute(con, 'CREATE INDEX IF NOT EXISTS idx_vias_sis_vial ON public.vias ("SIS_VIAL");')
  }
  
  # Ejecutar ANALYZE para estadísticas del optimizador de Postgres
  dbExecute(con, sprintf("ANALYZE public.%s;", nom_tabla))
  
  dbExecute(con, "INSERT INTO public.pdu_importaciones (conjunto, filas) VALUES ($1, $2);",
            params = list(nom_tabla, nrow(obj)))
  
  cat("LISTO con índice GIST.\n")
}

# 5. Migrar tabla de parámetros urbanísticos
cat("=== 6. Subiendo tabla de parámetros urbanísticos ===\n")
dbExecute(con, "DROP TABLE IF EXISTS public.parametros_urbanisticos CASCADE;")
dbWriteTable(con, "parametros_urbanisticos", parametros, overwrite = TRUE, row.names = FALSE)
dbExecute(con, 'CREATE INDEX IF NOT EXISTS idx_param_cod_s_zona ON public.parametros_urbanisticos ("COD_S_ZONA");')
dbExecute(con, "ANALYZE public.parametros_urbanisticos;")
dbExecute(con, "INSERT INTO public.pdu_importaciones (conjunto, filas) VALUES ($1, $2);",
          params = list("parametros_urbanisticos", nrow(parametros)))
cat(sprintf("  -> Subidos %d parámetros urbanísticos normativos.\n", nrow(parametros)))

# 6. Tablas de métricas y consultas
cat("=== 7. Creando tablas de métricas y consultas ciudadanas ===\n")
dbExecute(con, "
CREATE TABLE IF NOT EXISTS public.visitas_geovisor (
    id SERIAL PRIMARY KEY,
    fecha_hora TIMESTAMPTZ DEFAULT NOW(),
    cliente_ip TEXT,
    navegador TEXT
);
CREATE INDEX IF NOT EXISTS idx_visitas_fecha ON public.visitas_geovisor (fecha_hora DESC);

CREATE TABLE IF NOT EXISTS public.constancias_geovisor (
    id SERIAL PRIMARY KEY,
    fecha_hora TIMESTAMPTZ DEFAULT NOW(),
    codigo_consulta TEXT,
    tipo TEXT,
    distrito TEXT
);
CREATE INDEX IF NOT EXISTS idx_constancias_fecha ON public.constancias_geovisor (fecha_hora DESC);

CREATE TABLE IF NOT EXISTS public.consultas_pdu (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_consulta VARCHAR(50) NOT NULL,
    coordenadas TEXT NOT NULL,
    distrito VARCHAR(100),
    en_ambito BOOLEAN DEFAULT TRUE,
    zona_principal VARCHAR(100),
    metadata JSONB DEFAULT '{}'::jsonb,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_consultas_fecha ON public.consultas_pdu (creado_en DESC);
")

# Funciones almacenadas de métricas
dbExecute(con, "
CREATE OR REPLACE FUNCTION public.registrar_visita(p_nav TEXT DEFAULT NULL, p_ip TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.visitas_geovisor (navegador, cliente_ip) VALUES (p_nav, p_ip);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.registrar_constancia(p_cod TEXT, p_tipo TEXT, p_dist TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.constancias_geovisor (codigo_consulta, tipo, distrito)
    VALUES (p_cod, p_tipo, p_dist);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_metricas_geovisor()
RETURNS JSONB AS $$
DECLARE
    v_visitas BIGINT;
    v_constancias BIGINT;
BEGIN
    SELECT count(*) INTO v_visitas FROM public.visitas_geovisor;
    SELECT count(*) INTO v_constancias FROM public.constancias_geovisor;
    RETURN jsonb_build_object(
        'visitas_total', v_visitas,
        'constancias_total', v_constancias
    );
END;
$$ LANGUAGE plpgsql;
")

cat("=== 8. Verificación y validación de tablas en Neon ===\n")
res <- dbGetQuery(con, "
SELECT table_name, 
       (xpath('/row/cnt/text()', xml_count))[1]::text::int as row_count
FROM (
  SELECT table_name, 
         query_to_xml(format('select count(*) as cnt from %I.%I', table_schema, table_name), false, true, '') as xml_count
  FROM information_schema.tables
  WHERE table_schema = 'public' 
    AND table_name NOT IN ('spatial_ref_sys', 'geography_columns', 'geometry_columns')
) t
ORDER BY table_name;
")
print(res)

dbDisconnect(con)
cat("\n¡MIGRACIÓN A NEON POSTGRESQL COMPLETADA EXITOSAMENTE!\n")
