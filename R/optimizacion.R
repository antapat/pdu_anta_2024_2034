# Preparacion compartida por proceso; los analisis usan siempre capas originales.
pdu_firma_insumos <- function() {
  archivos <- sort(unique(c(
    list.files("data", pattern = "\\.(shp|shx|dbf|prj|cpg)$", full.names = TRUE, ignore.case = TRUE),
    list.files("normativa", recursive = TRUE, full.names = TRUE),
    "R/local_data.R", "R/reglamento_utils.R", "R/estilos_territoriales.R",
    "R/optimizacion.R"
  )))
  archivos <- archivos[file.exists(archivos) & !dir.exists(archivos)]
  tools::md5sum(archivos)
}

pdu_cache_vigente <- function(cache, firma = pdu_firma_insumos()) {
  if (!is.list(cache) || is.null(cache$firma)) return(FALSE)
  omitidos <- setdiff(names(cache$firma), names(firma))
  # Solo los shapefiles pueden faltar en el paquete cloud; la normativa no.
  omision_valida <- !length(omitidos) ||
    (!dir.exists("data") && all(startsWith(omitidos, "data/")))
  omision_valida && identical(cache$version, 1L) &&
    is.list(cache$datos$capas) &&
    all(names(firma) %in% names(cache$firma)) &&
    identical(unname(cache$firma[names(firma)]), unname(firma))
}

pdu_leer_cache <- function(ruta = "data_pdu/pdu_preparado.rds") {
  if (!file.exists(ruta)) return(NULL)
  cache <- tryCatch(readRDS(ruta), error = function(e) NULL)
  if (pdu_cache_vigente(cache)) return(cache$datos)
  aviso <- "Cache PDU desactualizada: regenerar con scripts/preparar_cache_pdu.R"
  if (!file.exists("data/P_080301_Zonificacion_urbana.shp")) stop(aviso, call. = FALSE)
  warning(aviso)
  NULL
}

pdu_capas_visualizacion <- function(capas, tolerancia_m = 0.5) {
  campos <- list(
    ambito = "NOM_AI",
    alta_tension_buffer = c("TENS_NOMIN", "NOM_EMPRES"),
    alta_tension = c("NOM_EMPRES", "NOM_LINEA", "TENS_NOMIN"),
    ferrocarril_buffer = character(),
    ferrocarril = c("NOM_FERR", "TRAMO_FERR", "ADM_FERR"),
    zonificacion = c("COLOR_MAPA", "COD_S_ZONA", "NOMBRE_COMPLETO", "POPUP_MAPA")
  )
  lapply(names(campos), function(nombre) {
    x <- capas[[nombre]]
    x <- x[, intersect(campos[[nombre]], names(x)), drop = FALSE]
    if (nrow(x)) {
      original <- sf::st_geometry(x)
      metrico <- sf::st_transform(original, 32718)
      ligero <- sf::st_simplify(metrico, dTolerance = tolerancia_m, preserveTopology = TRUE)
      valido <- sf::st_is_valid(ligero)
      conservar <- sf::st_is_empty(ligero) | is.na(valido) | !valido
      # GEOS puede superar la tolerancia en anillos: restaurar esas entidades.
      candidatos <- which(!conservar)
      if (length(candidatos)) {
        error <- as.numeric(sf::st_distance(metrico[candidatos], ligero[candidatos],
                                           by_element = TRUE, which = "Hausdorff", par = 0.25))
        conservar[candidatos[!is.finite(error) | error > tolerancia_m]] <- TRUE
      }
      ligero[conservar] <- metrico[conservar]
      sf::st_geometry(x) <- sf::st_transform(ligero, 4326)
    }
    x
  }) |> stats::setNames(names(campos))
}
