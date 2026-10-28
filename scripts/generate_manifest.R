# ==============================================================================
# GENERADOR DE MANIFEST.JSON PARA POSIT CONNECT CLOUD / SHINYAPPS
# GDUR - MUNICIPALIDAD PROVINCIAL DE ANTA
# ==============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    install.packages("rsconnect", repos = "https://cloud.r-project.org")
  }
  library(rsconnect)
})

cat("Generando manifest.json optimizado para Posit Connect Cloud...\n")

app_files <- c(
  "app.R",
  "DESCRIPTION",
  "constancia_pdu_template.qmd",
  "R/spatial_utils.R",
  "R/estilos_territoriales.R",
  "R/local_data.R",
  "R/reporte_cartografico_utils.R",
  "R/reglamento_utils.R",
  "R/supabase_utils.R",
  "R/mod_privacidad.R",
  "R/mod_informacion_pdu.R",
  "R/mod_catalogo_zonas.R",
  "data_pdu/pdu_capas.rds",
  "www/custom.css",
  "www/escudo_muni_anta.png",
  "www/pdu_actualizado_sf.png"
)

app_files_exist <- app_files[file.exists(app_files)]

rsconnect::writeManifest(
  appDir = ".",
  appPrimaryDoc = "app.R",
  appFiles = app_files_exist,
  appMode = "shiny"
)

cat("Manifest generado exitosamente. Existe manifest.json:", file.exists("manifest.json"), "\n")
