# Verifica que Supabase/PostGIS esté listo para iniciar el GeoVisor.

Sys.setenv(PDU_DATA_SOURCE = "supabase")
source("R/supabase_utils.R", local = TRUE)

datos <- supabase_cargar_datos_espaciales()

cat("Fuente:", datos$origen, "\n")
cat("Tablas cargadas:\n")
for (tabla in names(datos$conteos)) {
  cat(" -", tabla, ":", datos$conteos[[tabla]], "filas\n")
}
cat("Validación correcta: la aplicación puede consumir Supabase/PostGIS.\n")
