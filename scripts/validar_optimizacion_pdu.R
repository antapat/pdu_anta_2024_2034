raiz <- normalizePath(getwd(), winslash = "/")
Sys.setlocale("LC_CTYPE", "English_United States.utf8")
setwd(raiz)
source("scripts/preparar_cache_pdu.R", encoding = "UTF-8")
testthat::test_dir("tests/testthat", filter = "optimizacion|reglamento-final|spatial-utils", stop_on_failure = TRUE)

# Evaluar el arranque completo, sin iniciar un servidor ni publicar.
entorno <- new.env(parent = globalenv())
tiempo <- system.time(sys.source("app.R", envir = entorno))
widget <- entorno$mapa_pdu_compartido
expr <- parse("app.R", encoding = "UTF-8")
es_widget <- vapply(expr, function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
                     identical(x[[2]], as.name("mapa_pdu_compartido")), logical(1))
entorno$capas_mapa <- entorno$capas
original <- eval(expr[[which(es_widget)]], envir = entorno)
bytes_widget <- function(x) nchar(htmlwidgets:::toJSON(x$x), type = "bytes")
antes <- bytes_widget(original)
despues <- bytes_widget(widget)
stopifnot(despues < antes)

# Simular exactamente los archivos del despliegue, sin shapefiles ni secretos.
bundle <- tempfile("pdu-bundle-")
dir.create(bundle)
archivos <- c("app.R", "DESCRIPTION", "R", "normativa", "www", "aprobacion",
              "constancia_pdu_template.qmd")
file.copy(archivos[file.exists(archivos)], bundle, recursive = TRUE)
dir.create(file.path(bundle, "data_pdu"))
file.copy("data_pdu/pdu_preparado.rds", file.path(bundle, "data_pdu"))
setwd(bundle)
stopifnot(!dir.exists("data"), !file.exists(".Renviron"))
stopifnot(pdu_cache_vigente(readRDS("data_pdu/pdu_preparado.rds")))
nube <- new.env(parent = globalenv())
sys.source("app.R", envir = nube)
stopifnot(inherits(nube$mapa_pdu_compartido, "leaflet"))
setwd(raiz)
reporte <- c(
  "Validacion de optimizaciones PDU - 2026-10-28",
  sprintf("Widget original: %d bytes JSON", antes),
  sprintf("Widget optimizado: %d bytes JSON", despues),
  sprintf("Reduccion: %.2f%%", 100 * (1 - despues / antes)),
  sprintf("Arranque con cache: %.2f segundos", tiempo[["elapsed"]]),
  "Pruebas de optimizacion, normativa y utilidades espaciales: aprobadas.",
  "Suite completa: fallo preexistente en test-datos-locales.R; usa mensaje= pero la funcion recibe contenido=.",
  "Arranque de paquete sin data/ ni .Renviron: aprobado.",
  "No se ha publicado ni modificado el servicio remoto.",
  "JSON del widget: no equivale al trafico HTTP comprimido por visita."
)
writeLines(reporte, "documentacion/VALIDACION_OPTIMIZACION_PDU_2026-10-28.txt")
cat(reporte, sep = "\n")
