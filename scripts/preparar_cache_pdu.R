if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
# Ejecutar desde la raiz despues de actualizar data/, normativa/ o los cargadores.
source("R/estilos_territoriales.R", encoding = "UTF-8")
source("R/local_data.R", encoding = "UTF-8")
source("R/optimizacion.R", encoding = "UTF-8")
datos <- pdu_cargar_datos_locales()
datos$capas_mapa <- pdu_capas_visualizacion(datos$capas)
dir.create("data_pdu", showWarnings = FALSE)
saveRDS(list(version = 1L, firma = pdu_firma_insumos(), datos = datos),
        "data_pdu/pdu_preparado.rds", compress = "xz")
stopifnot(identical(pdu_leer_cache(), datos))
cat("Cache validada con geometria original y normativa actual.\n")
