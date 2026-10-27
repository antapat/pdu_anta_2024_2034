# [DEPRECADO - MIGRACIÓN A NEON PENDIENTE]
# Carga manual de capas del PDU a Supabase/PostGIS.
# NOTA: Supabase está en proceso de deprecación. Consulte NEON_MIGRACION.md.
# Requiere ejecutar primero supabase/migrations/001_postgis_pdu.sql.
# Este script reemplaza las tablas espaciales indicadas; exige confirmación.

paquetes <- c("DBI", "RPostgres", "sf")
faltantes <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes)) {
  stop("Instale primero estos paquetes: ", paste(faltantes, collapse = ", "))
}

requeridas <- c(
  "SUPABASE_HOST", "SUPABASE_PORT", "SUPABASE_DB",
  "SUPABASE_USER", "SUPABASE_PASSWORD", "SUPABASE_PROJECT_REF",
  "SUPABASE_IMPORT_CONFIRM"
)
faltan_vars <- requeridas[!nzchar(Sys.getenv(requeridas))]
if (length(faltan_vars)) {
  stop("Faltan variables de entorno: ", paste(faltan_vars, collapse = ", "))
}
if (Sys.getenv("SUPABASE_PROJECT_REF") != "psteqbwnyavrmwdiiaht") {
  stop("SUPABASE_PROJECT_REF no corresponde al proyecto esperado.")
}
if (Sys.getenv("SUPABASE_IMPORT_CONFIRM") != "REEMPLAZAR_CAPAS_PDU") {
  stop("Para reemplazar las capas, establezca SUPABASE_IMPORT_CONFIRM=REEMPLAZAR_CAPAS_PDU.")
}

archivo_capas <- "data/pdu_capas_optimizadas.rds"
archivo_parametros <- "data/parametros_urbanisticos.rds"
if (!file.exists(archivo_capas) || !file.exists(archivo_parametros)) {
  stop("No encuentro los RDS. Ejecute el script desde la raíz del proyecto.")
}

capas <- readRDS(archivo_capas)
parametros <- readRDS(archivo_parametros)
capas_destino <- c(
  ambito = "ambito",
  distritos = "distritos",
  zonificacion = "zonificacion",
  vias = "vias",
  alta_tension = "alta_tension",
  alta_tension_buffer = "alta_tension_buffer",
  ferrocarril = "ferrocarril",
  ferrocarril_buffer = "ferrocarril_buffer"
)

if (!all(names(capas_destino) %in% names(capas))) {
  stop("El RDS no contiene todas las capas esperadas: ",
       paste(setdiff(names(capas_destino), names(capas)), collapse = ", "))
}
if (!inherits(parametros, "data.frame")) {
  stop("parametros_urbanisticos.rds no contiene una tabla.")
}

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = Sys.getenv("SUPABASE_HOST"),
  port = as.integer(Sys.getenv("SUPABASE_PORT")),
  dbname = Sys.getenv("SUPABASE_DB"),
  user = Sys.getenv("SUPABASE_USER"),
  password = Sys.getenv("SUPABASE_PASSWORD"),
  sslmode = "require",
  connect_timeout = 10
)
tryCatch({
  if (!isTRUE(DBI::dbGetQuery(con, "SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') AS disponible")$disponible[[1]])) {
    stop("PostGIS no está habilitado. Ejecute la migración SQL primero.")
  }
  if (!DBI::dbExistsTable(con, DBI::Id(schema = "public", table = "pdu_importaciones"))) {
    stop("No existe public.pdu_importaciones. Ejecute la migración 001 antes de cargar datos.")
  }

  DBI::dbWithTransaction(con, {
    commit_fuente <- Sys.getenv("GITHUB_SHA", unset = NA_character_)
    for (clave in names(capas_destino)) {
      objeto <- capas[[clave]]
      if (!inherits(objeto, "sf")) stop("La capa '", clave, "' no es un objeto sf.")
      objeto <- sf::st_transform(objeto, 4326)
      tabla <- unname(capas_destino[[clave]])
      tabla_id <- DBI::Id(schema = "public", table = tabla)
      identificador <- as.character(DBI::dbQuoteIdentifier(con, tabla_id))
      indice <- as.character(DBI::dbQuoteIdentifier(con, paste0(tabla, "_geometry_gix")))
      geometria <- as.character(DBI::dbQuoteIdentifier(con, attr(objeto, "sf_column")))

      DBI::dbExecute(con, paste("DROP TABLE IF EXISTS", identificador))
      sf::st_write(objeto, con, layer = tabla_id, quiet = TRUE)
      DBI::dbExecute(con, paste("CREATE INDEX", indice, "ON", identificador, "USING GIST", paste0("(", geometria, ")")))
      DBI::dbExecute(con, paste("ALTER TABLE", identificador, "ENABLE ROW LEVEL SECURITY"))
      DBI::dbExecute(con, paste("REVOKE ALL ON TABLE", identificador, "FROM anon, authenticated"))
      DBI::dbExecute(con, paste("ANALYZE", identificador))
      DBI::dbExecute(
        con,
        "INSERT INTO public.pdu_importaciones (conjunto, filas, commit_fuente) VALUES ($1, $2, $3)",
        params = list(tabla, nrow(objeto), commit_fuente)
      )
      message("Cargada ", tabla, ": ", nrow(objeto), " filas")
    }

    parametros_id <- DBI::Id(schema = "public", table = "parametros_urbanisticos")
    DBI::dbWriteTable(con, parametros_id, parametros, overwrite = TRUE, row.names = FALSE)
    tabla_parametros <- as.character(DBI::dbQuoteIdentifier(con, parametros_id))
    indice_parametros <- as.character(DBI::dbQuoteIdentifier(con, "parametros_urbanisticos_cod_s_zona_idx"))
    codigo_subzona <- as.character(DBI::dbQuoteIdentifier(con, "COD_S_ZONA"))
    DBI::dbExecute(con, paste("CREATE INDEX", indice_parametros, "ON", tabla_parametros, paste0("(", codigo_subzona, ")")))
    DBI::dbExecute(con, paste("ALTER TABLE", tabla_parametros, "ENABLE ROW LEVEL SECURITY"))
    DBI::dbExecute(con, paste("REVOKE ALL ON TABLE", tabla_parametros, "FROM anon, authenticated"))
    DBI::dbExecute(con, paste("ANALYZE", tabla_parametros))
    DBI::dbExecute(
      con,
      "INSERT INTO public.pdu_importaciones (conjunto, filas, commit_fuente) VALUES ($1, $2, $3)",
      params = list("parametros_urbanisticos", nrow(parametros), commit_fuente)
    )
  })
  message("Carga terminada y validada. Supabase/PostGIS es la fuente espacial de la aplicación.")
}, finally = DBI::dbDisconnect(con))

