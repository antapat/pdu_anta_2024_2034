# [DEPRECADO - MIGRACIÓN A NEON PENDIENTE]
# Aplica las migraciones SQL idempotentes del GeoVisor a Supabase.
# NOTA: Supabase está en proceso de deprecación. Consulte NEON_MIGRACION.md.
# Las credenciales se leen exclusivamente desde variables de entorno.

paquetes <- c("DBI", "RPostgres")
faltantes <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltantes)) {
  stop("Instale primero estos paquetes: ", paste(faltantes, collapse = ", "))
}

requeridas <- c(
  "SUPABASE_HOST", "SUPABASE_PORT", "SUPABASE_DB",
  "SUPABASE_USER", "SUPABASE_PASSWORD", "SUPABASE_PROJECT_REF"
)
faltan_vars <- requeridas[!nzchar(Sys.getenv(requeridas))]
if (length(faltan_vars)) {
  stop("Faltan variables de entorno: ", paste(faltan_vars, collapse = ", "))
}
if (Sys.getenv("SUPABASE_PROJECT_REF") != "psteqbwnyavrmwdiiaht") {
  stop("SUPABASE_PROJECT_REF no corresponde al proyecto esperado.")
}

archivos <- sort(list.files(
  file.path("supabase", "migrations"),
  pattern = "^[0-9]+_.*\\.sql$",
  full.names = TRUE
))
if (!length(archivos)) stop("No se encontraron migraciones SQL.")

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
on.exit(DBI::dbDisconnect(con), add = TRUE)

for (archivo in archivos) {
  sql <- paste(readLines(archivo, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  message("Aplicando ", basename(archivo), "...")
  DBI::dbExecute(con, sql, immediate = TRUE)
}

message("Migraciones de Supabase aplicadas correctamente.")
