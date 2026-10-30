# ==============================================================================
# GENERADOR DE MANIFEST.JSON PARA POSIT CONNECT CLOUD / SHINYAPPS
# GDUR - MUNICIPALIDAD PROVINCIAL DE ANTA
# ==============================================================================

# Fijar directorio de trabajo en la raíz del proyecto
directorio_raiz <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/")
    dirname(dirname(script_path))
  } else {
    getwd()
  }
}, error = function(e) getwd())

if (file.exists(file.path(directorio_raiz, "app.R"))) {
  setwd(directorio_raiz)
} else if (file.exists("app.R")) {
  directorio_raiz <- getwd()
} else if (file.exists("pdu_anta_2024_2034/app.R")) {
  setwd("pdu_anta_2024_2034")
  directorio_raiz <- getwd()
}

suppressPackageStartupMessages({
  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    install.packages("rsconnect", repos = "https://cloud.r-project.org")
  }
  library(rsconnect)
})

cat("Generando manifest.json optimizado para Posit Connect Cloud en:", getwd(), "\n")

app_files <- c(
  "app.R",
  "DESCRIPTION",
  "constancia_pdu_template.qmd",
  "R/spatial_utils.R",
  "R/estilos_territoriales.R",
  "R/local_data.R",
  "R/optimizacion.R",
  "R/reporte_cartografico_utils.R",
  "R/reglamento_utils.R",
  "R/supabase_utils.R",
  "R/mod_privacidad.R",
  "R/mod_acceso_dni.R",
  "R/mod_informacion_pdu.R",
  "R/mod_catalogo_zonas.R",
  "data_pdu/pdu_preparado.rds",
  "www/custom.css",
  "www/escudo_muni_anta.png",
  "www/pdu_actualizado_sf.png"
)

# El despliegue requiere una cache vigente; nunca publicar un RDS antiguo.
source("scripts/preparar_cache_pdu.R", encoding = "UTF-8")
app_files <- unique(c(app_files, list.files("normativa", recursive = TRUE, full.names = TRUE),
                     list.files("aprobacion", recursive = TRUE, full.names = TRUE)))
app_files_exist <- app_files[file.exists(app_files)]

rsconnect::writeManifest(
  appDir = ".",
  appPrimaryDoc = "app.R",
  appFiles = app_files_exist,
  appMode = "shiny"
)

cat("Manifest generado exitosamente. Existe manifest.json:", file.exists("manifest.json"), "\n")
