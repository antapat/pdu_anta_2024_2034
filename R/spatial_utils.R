# Utilidades espaciales seguras para el GeoVisor PDU Anta.

CRS_GEOGRAFICO <- 4326
CRS_METRICO_ANTA <- 32718
BBOX_VALIDACION_ANTA <- c(xmin = -72.50, ymin = -13.80, xmax = -71.90, ymax = -13.10)

validar_coordenada_punto <- function(lng, lat) {
  valores <- suppressWarnings(as.numeric(c(lng, lat)))
  if (any(!is.finite(valores))) stop("Las coordenadas deben ser valores numéricos finitos.")
  if (valores[1] < BBOX_VALIDACION_ANTA["xmin"] || valores[1] > BBOX_VALIDACION_ANTA["xmax"] ||
      valores[2] < BBOX_VALIDACION_ANTA["ymin"] || valores[2] > BBOX_VALIDACION_ANTA["ymax"]) {
    stop("Las coordenadas se encuentran fuera del entorno geográfico admitido para Anta.")
  }
  invisible(TRUE)
}

normalizar_poligono_predio <- function(objeto_sf, max_entidades = 200, max_area_m2 = 2e8) {
  if (!inherits(objeto_sf, "sf") || nrow(objeto_sf) == 0) stop("El archivo no contiene entidades espaciales.")
  if (nrow(objeto_sf) > max_entidades) stop("El archivo excede el máximo de 200 entidades permitido.")
  if (is.na(sf::st_crs(objeto_sf))) stop("El archivo no declara un sistema de coordenadas (CRS).")
  if (any(sf::st_is_empty(objeto_sf))) objeto_sf <- objeto_sf[!sf::st_is_empty(objeto_sf), , drop = FALSE]
  if (nrow(objeto_sf) == 0) stop("Todas las geometrías del archivo están vacías.")

  objeto_sf <- sf::st_make_valid(objeto_sf)
  tipos <- unique(as.character(sf::st_geometry_type(objeto_sf)))
  if (!all(tipos %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION"))) {
    stop("El archivo debe contener únicamente polígonos o multipolígonos de predios.")
  }

  geom_poligono <- suppressWarnings(sf::st_collection_extract(sf::st_geometry(objeto_sf), "POLYGON"))
  if (length(geom_poligono) == 0 || all(sf::st_is_empty(geom_poligono))) {
    stop("No se encontraron polígonos utilizables en el archivo.")
  }
  geom_unificada <- sf::st_union(geom_poligono)
  predio <- sf::st_sf(id = 1L, geometry = geom_unificada)
  predio <- sf::st_transform(predio, CRS_GEOGRAFICO)

  bb <- sf::st_bbox(predio)
  if (bb["xmax"] < BBOX_VALIDACION_ANTA["xmin"] || bb["xmin"] > BBOX_VALIDACION_ANTA["xmax"] ||
      bb["ymax"] < BBOX_VALIDACION_ANTA["ymin"] || bb["ymin"] > BBOX_VALIDACION_ANTA["ymax"]) {
    stop("El predio se encuentra fuera del entorno geográfico admitido para Anta.")
  }

  area_m2 <- as.numeric(sf::st_area(sf::st_transform(predio, CRS_METRICO_ANTA)))
  if (!is.finite(area_m2) || area_m2 <= 0) stop("El predio debe tener un área mayor que cero.")
  if (area_m2 > max_area_m2) stop("El predio excede el área máxima admitida para una consulta.")
  predio
}

#' Calcula el área de intersección neta (m²) entre un predio y una capa espacial,
#' optimizado mediante filtrado previo por índice espacial (R-tree) para evitar
#' operaciones de unión sobre toda la capa cuando no hay contacto.
area_interseccion_unica_m2 <- function(predio_4326, capa_4326) {
  if (is.null(capa_4326) || nrow(capa_4326) == 0) return(0)
  
  # 1. Filtrado espacial indexado rápido antes de unir geometrías
  idx <- suppressMessages(sf::st_intersects(predio_4326, capa_4326, sparse = TRUE)[[1]])
  if (length(idx) == 0) return(0)
  
  capa_sub <- capa_4326[idx, , drop = FALSE]
  capa_unida <- if (nrow(capa_sub) == 1) {
    sf::st_geometry(capa_sub)
  } else {
    sf::st_union(sf::st_geometry(capa_sub))
  }
  
  inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(predio_4326), capa_unida))
  if (length(inter) == 0 || all(sf::st_is_empty(inter))) return(0)
  sum(as.numeric(sf::st_area(sf::st_transform(inter, CRS_METRICO_ANTA))), na.rm = TRUE)
}

#' Busca vías colindantes a una entidad espacial dentro de una distancia máxima (en metros).
#' Utiliza filtrado espacial indexado con buffer para evitar calcular distancias sobre toda la red vial.
#' @param geom_utm Geometría (punto o polígono) en CRS métrico (32718)
#' @param vias_utm Capa de vías en CRS métrico (32718)
#' @param dist_max_m Distancia máxima de búsqueda en metros (por defecto 25 m)
#' @return Lista con índices de vías cercanas, distancias calculadas, índice mínimo y distancia mínima
pdu_buscar_vias_colindantes <- function(geom_utm, vias_utm, dist_max_m = 25.0) {
  if (is.null(vias_utm) || nrow(vias_utm) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  buf <- sf::st_buffer(geom_utm, dist_max_m)
  candidatos <- suppressMessages(sf::st_intersects(buf, vias_utm)[[1]])
  if (length(candidatos) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  dists_cand <- as.numeric(sf::st_distance(geom_utm, vias_utm[candidatos, , drop = FALSE]))
  validos <- which(dists_cand <= dist_max_m)
  if (length(validos) == 0) {
    return(list(indices = integer(0), distancias = numeric(0), min_idx = NA_integer_, min_dist = Inf))
  }
  indices <- candidatos[validos]
  distancias <- dists_cand[validos]
  idx_min_rel <- which.min(distancias)
  list(
    indices = indices,
    distancias = distancias,
    min_idx = indices[idx_min_rel],
    min_dist = distancias[idx_min_rel]
  )
}

extraer_zip_seguro <- function(archivo_zip, destino, max_archivos = 100, max_descomprimido = 100 * 1024^2) {
  listado <- utils::unzip(archivo_zip, list = TRUE)
  if (nrow(listado) == 0) stop("El archivo ZIP está vacío.")
  if (nrow(listado) > max_archivos) stop("El ZIP contiene demasiados archivos.")
  nombres <- gsub("\\\\", "/", listado$Name)
  inseguro <- grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", nombres)
  if (any(inseguro)) stop("El ZIP contiene rutas no permitidas.")
  if (sum(listado$Length, na.rm = TRUE) > max_descomprimido) stop("El ZIP excede 100 MB descomprimido.")
  dir.create(destino, showWarnings = FALSE, recursive = TRUE)
  utils::unzip(archivo_zip, exdir = destino)
  invisible(destino)
}

ejecutando_en_shinyapps <- function() {
  ruta_trabajo <- gsub("\\\\", "/", normalizePath(getwd(), winslash = "/", mustWork = FALSE))
  nzchar(Sys.getenv("RSCONNECT_APPLICATION")) ||
    grepl("/srv/connect/apps/", ruta_trabajo, fixed = TRUE)
}

quarto_disponible <- function() {
  if (nzchar(Sys.getenv("QUARTO_PATH")) && file.exists(Sys.getenv("QUARTO_PATH"))) {
    return(TRUE)
  }
  es_valido <- tryCatch({
    q_path <- quarto::quarto_path()
    !is.null(q_path) && nzchar(q_path) && file.exists(q_path)
  }, error = function(e) FALSE)
  if (isTRUE(es_valido)) return(TRUE)
  
  en_path <- Sys.which("quarto")
  if (nzchar(en_path) && file.exists(en_path)) {
    Sys.setenv(QUARTO_PATH = normalizePath(en_path, winslash = "/", mustWork = FALSE))
    return(TRUE)
  }
  
  candidatos <- c(
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "quarto.exe"),
    file.path(Sys.getenv("ProgramFiles"), "Quarto", "bin", "quarto.exe"),
    "C:/Program Files/Quarto/bin/quarto.exe",
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe",
    "C:/Program Files/RStudio/bin/quarto/bin/quarto.exe"
  )
  candidatos <- candidatos[nzchar(candidatos) & file.exists(candidatos)]
  if (length(candidatos) > 0) {
    ruta <- normalizePath(candidatos[1], winslash = "/", mustWork = TRUE)
    Sys.setenv(QUARTO_PATH = ruta)
    dir_q <- dirname(ruta)
    p_actual <- Sys.getenv("PATH")
    if (!grepl(dir_q, p_actual, fixed = TRUE)) {
      Sys.setenv(PATH = paste(dir_q, p_actual, sep = ";"))
    }
    return(TRUE)
  }
  
  FALSE
}

chrome_disponible <- function() {
  # La impresión con Chrome puede agotar o detener el contenedor de shinyapps.io.
  if (ejecutando_en_shinyapps()) return(FALSE)
  tryCatch({
    ruta <- pagedown::find_chrome()
    length(ruta) == 1 && !is.na(ruta) && nzchar(ruta) && file.exists(ruta)
  }, error = function(e) FALSE)
}

pdf_motor_disponible <- function() {
  quarto_disponible() || chrome_disponible()
}

