# ==============================================================================
# GENERACIÓN DE DATOS ESPACIALES OPTIMIZADOS PARA GITHUB Y CLOUD
# ==============================================================================
suppressPackageStartupMessages({
  library(sf)
  library(jsonlite)
})

cat("=== 1. Creando directorio data_pdu ===\n")
dir_out <- "data_pdu"
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

cat("=== 2. Cargando capas preprocesadas ===\n")
source("R/local_data.R")
d <- pdu_cargar_datos_locales()

cat("=== 3. Exportando data_pdu/pdu_capas.rds (ultra-ligero y rápido para R) ===\n")
saveRDS(d, file.path(dir_out, "pdu_capas.rds"), compress = "xz")
cat(sprintf("  -> pdu_capas.rds: %.2f MB\n", file.info(file.path(dir_out, "pdu_capas.rds"))$size / 1e6))

cat("=== 4. Exportando GeoJSONs optimizados ===\n")
capas <- d$capas

# Zonificación
if (!is.null(capas$zonificacion)) {
  st_write(capas$zonificacion, file.path(dir_out, "zonificacion.geojson"), delete_dsn = TRUE, quiet = TRUE)
  cat(sprintf("  -> zonificacion.geojson: %.2f MB\n", file.info(file.path(dir_out, "zonificacion.geojson"))$size / 1e6))
}

# Vías
if (!is.null(capas$vias)) {
  st_write(capas$vias, file.path(dir_out, "vias.geojson"), delete_dsn = TRUE, quiet = TRUE)
  cat(sprintf("  -> vias.geojson: %.2f MB\n", file.info(file.path(dir_out, "vias.geojson"))$size / 1e6))
}

# Ámbito
if (!is.null(capas$ambito) && nrow(capas$ambito) > 0) {
  st_write(capas$ambito, file.path(dir_out, "ambito.geojson"), delete_dsn = TRUE, quiet = TRUE)
}

# Alta tensión
if (!is.null(capas$alta_tension) && nrow(capas$alta_tension) > 0) {
  st_write(capas$alta_tension, file.path(dir_out, "alta_tension.geojson"), delete_dsn = TRUE, quiet = TRUE)
}

# Ferrocarril
if (!is.null(capas$ferrocarril) && nrow(capas$ferrocarril) > 0) {
  st_write(capas$ferrocarril, file.path(dir_out, "ferrocarril.geojson"), delete_dsn = TRUE, quiet = TRUE)
}

# Parámetros urbanísticos
write.csv(d$parametros, file.path(dir_out, "parametros_urbanisticos.csv"), row.names = FALSE)

cat("=== 5. Exportando GeoPackage unificado (data_pdu/pdu_capas.gpkg) ===\n")
gpkg_path <- file.path(dir_out, "pdu_capas.gpkg")
if (file.exists(gpkg_path)) unlink(gpkg_path)

st_write(capas$zonificacion, gpkg_path, layer = "zonificacion", quiet = TRUE)
st_write(capas$vias, gpkg_path, layer = "vias", quiet = TRUE)
st_write(capas$ambito, gpkg_path, layer = "ambito", quiet = TRUE)
st_write(capas$alta_tension, gpkg_path, layer = "alta_tension", quiet = TRUE)
st_write(capas$alta_tension_buffer, gpkg_path, layer = "alta_tension_buffer", quiet = TRUE)
st_write(capas$ferrocarril, gpkg_path, layer = "ferrocarril", quiet = TRUE)
st_write(capas$ferrocarril_buffer, gpkg_path, layer = "ferrocarril_buffer", quiet = TRUE)

cat(sprintf("  -> pdu_capas.gpkg: %.2f MB\n", file.info(gpkg_path)$size / 1e6))
cat("\n¡DATOS OPTIMIZADOS GENERADOS EXITOSAMENTE EN data_pdu/!\n")
