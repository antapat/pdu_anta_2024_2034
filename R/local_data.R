# ==============================================================================
# CARGA DE DATOS LOCALES - GEOVISOR PDU ANTA (2024 - 2034)
# Fuente local explícita desde Shapefiles en data/; no requiere bases externas.
# ==============================================================================

if (file.exists("R/estilos_territoriales.R")) {
  source("R/estilos_territoriales.R", local = TRUE)
}

pdu_cargar_datos <- function() {
  fuente <- tolower(Sys.getenv("PDU_DATA_SOURCE", ""))
  
  # 1. Si se configuró explícitamente Neon o DATABASE_URL está presente
  if (fuente == "neon" || nzchar(Sys.getenv("DATABASE_URL")) || nzchar(Sys.getenv("NEON_HOST"))) {
    tryCatch({
      if (file.exists("R/neon_utils.R")) source("R/neon_utils.R", local = TRUE)
      return(neon_cargar_datos_espaciales())
    }, error = function(e) {
      warning("Fallo al conectar a Neon PostgreSQL, recurriendo a respaldo local: ", conditionMessage(e), call. = FALSE)
    })
  }
  
  # 2. Si se solicitó supabase legado
  if (fuente == "supabase") {
    warning("[DEPRECADO] La conexión directa a Supabase está marcada como obsoleta. Se migrará a Neon.", call. = FALSE)
    return(supabase_cargar_datos_espaciales())
  }
  
  # 3. Modo local explícito: si existen los shapefiles en data/
  if (fuente %in% c("local", "offline", "") && file.exists("data/P_080301_Zonificacion_urbana.shp")) {
    return(pdu_cargar_datos_locales())
  }
  
  # 4. Datos optimizados en data_pdu/ (para Posit Connect Cloud y GitHub)
  for (cand in c("data_pdu/pdu_capas.rds", "../../data_pdu/pdu_capas.rds", "../data_pdu/pdu_capas.rds")) {
    if (file.exists(cand)) {
      d <- readRDS(cand)
      return(d)
    }
  }
  
  # 5. Fallback a Neon si no hay datos locales en disco
  tryCatch({
    if (file.exists("R/neon_utils.R")) source("R/neon_utils.R", local = TRUE)
    return(neon_cargar_datos_espaciales())
  }, error = function(e) {
    pdu_cargar_datos_locales()
  })
}

pdu_cargar_datos_locales <- function(directorio = "data") {
  if (!dir.exists(directorio)) {
    if (dir.exists(file.path("..", "..", directorio))) {
      directorio <- file.path("..", "..", directorio)
    } else if (dir.exists(file.path("..", directorio))) {
      directorio <- file.path("..", directorio)
    }
  }

  archivos <- c(
    zonificacion = "P_080301_Zonificacion_urbana.shp",
    vias = "P_080301_Sistema_vial.shp",
    alta_tension = "D_080301_Red_electrica.shp",
    alta_tension_buffer = "D_080301_Red_electrica_servidumbre.shp",
    ferrocarril = "B_080301_Red_ferroviaria.shp",
    ferrocarril_buffer = "B_080301_Red_ferroviaria_zif.shp"
  )
  leer <- function(archivo) {
    ruta <- file.path(directorio, archivo)
    if (!file.exists(ruta)) stop("Falta el archivo local: ", ruta)
    x <- sf::st_read(ruta, quiet = TRUE)
    if (is.na(sf::st_crs(x))) stop("Capa sin CRS: ", ruta)
    if (!nrow(x)) stop("Capa vacía: ", ruta)
    if (any(sf::st_is_empty(x)) || any(is.na(sf::st_geometry(x)))) {
      stop("Geometrías vacías o nulas: ", ruta)
    }
    sf::st_transform(sf::st_make_valid(x), 4326)
  }
  capas <- lapply(archivos, leer)
  raiz <- dirname(normalizePath(directorio, winslash = "/"))
  source(file.path(raiz, "R/reglamento_utils.R"), local = environment(), encoding = "UTF-8")
  reglamento <- pdu_leer_reglamento(file.path(raiz, "normativa"))
  parametros <- reglamento$parametros
  z <- pdu_vincular_reglamento(capas$zonificacion, reglamento)
  z$SUB_ZONA <- trimws(z$SCLAS_ZONI)
  z$ZONA <- trimws(z$NOM_ZONI)

  idx_p <- match(z$COD_S_ZONA, parametros$COD_S_ZONA)
  z$NOMBRE_COMPLETO <- ifelse(!is.na(idx_p) & nzchar(parametros$NOMBRE_COMPLETO[idx_p]), parametros$NOMBRE_COMPLETO[idx_p], z$SUB_ZONA)
  z$DENSIDAD_NETA_MAX <- ifelse(!is.na(idx_p), parametros$DENSIDAD_NETA_MAX[idx_p], "")
  z$LOTE_MINIMO <- ifelse(!is.na(idx_p), parametros$LOTE_MINIMO[idx_p], "")
  z$ALTURA_MAXIMA <- ifelse(!is.na(idx_p), parametros$ALTURA_MAXIMA[idx_p], "")
  z$AREA_LIBRE_MIN <- ifelse(!is.na(idx_p), parametros$AREA_LIBRE_MIN[idx_p], "")
  z$USOS_PERMITIDOS <- ifelse(!is.na(idx_p), parametros$USOS_PERMITIDOS[idx_p], "")

  # Códigos de macrozona de riesgo usan el mismo color de su macrozona.
  paleta <- if (exists("pdu_colores_zonas", mode = "function")) pdu_colores_zonas() else supabase_colores_zonas()
  z$COLOR_HEX <- unname(paleta[z$COD_ZONA])
  z$COLOR_HEX[is.na(z$COLOR_HEX)] <- "#C5CCC8"
  z$COLOR_MAPA <- z$COLOR_HEX
  z$POPUP_MAPA <- pdu_construir_popups_zonificacion(z)
  capas$zonificacion <- z
  v <- capas$vias
  v$COD_VIA_PR <- ifelse(is.na(v$COD_VIA) | !nzchar(trimws(v$COD_VIA)), "Sin código", trimws(v$COD_VIA))
  v$SIS_VIAL <- trimws(v$VIA_PROP)
  
  # Clasificación vial oficial mediante CATEG_VIA (simplificación de leyenda y estilos)
  categ_crudo <- if ("CATEG_VIA" %in% names(v)) trimws(as.character(v$CATEG_VIA)) else "LOCAL"
  v$CATEG_VIA <- ifelse(is.na(categ_crudo) | !nzchar(categ_crudo), "LOCAL", categ_crudo)
  
  paleta_categ <- if (exists("pdu_colores_categ_vias", mode = "function")) {
    pdu_colores_categ_vias()
  } else {
    c(
      "RED VIAL NACIONAL"       = "#C0392B",
      "RED VIAL DEPARTAMENTAL"  = "#D97706",
      "RED VIAL VECINAL"        = "#2E7D32",
      "LOCAL"                   = "#5B7083"
    )
  }
  
  colores_v <- paleta_categ[v$CATEG_VIA]
  colores_v[is.na(colores_v)] <- "#5B7083"
  v$COLOR_MAPA <- v$COLOR_VIA <- unname(colores_v)
  
  pesos_v <- if (exists("pdu_pesos_categ_vias", mode = "function")) {
    pdu_pesos_categ_vias()
  } else {
    c("RED VIAL NACIONAL" = 2.8, "RED VIAL DEPARTAMENTAL" = 2.2, "RED VIAL VECINAL" = 1.8, "LOCAL" = 1.4)
  }
  pesos_asignados <- pesos_v[v$CATEG_VIA]
  pesos_asignados[is.na(pesos_asignados)] <- 1.4
  v$PESO_MAPA <- unname(pesos_asignados)
  
  trazos_v <- if (exists("pdu_trazos_categ_vias", mode = "function")) {
    pdu_trazos_categ_vias()
  } else {
    c("RED VIAL NACIONAL" = "", "RED VIAL DEPARTAMENTAL" = "", "RED VIAL VECINAL" = "7,5", "LOCAL" = "")
  }
  trazos_asignados <- trazos_v[v$CATEG_VIA]
  trazos_asignados[is.na(trazos_asignados)] <- ""
  v$TRAZO_MAPA <- unname(trazos_asignados)
  
  capas$vias <- v
  # Carga de ámbito de intervención y distritos
  archivo_ambito <- if (file.exists(file.path(directorio, "D_080301_Ambito_intervencion.shp"))) {
    "D_080301_Ambito_intervencion.shp"
  } else if (file.exists(file.path(directorio, "ambito.shp"))) {
    "ambito.shp"
  } else {
    NULL
  }
  if (!is.null(archivo_ambito)) {
    capas$ambito <- leer(archivo_ambito)
  } else {
    capas$ambito <- sf::st_sf(NOM_AI = character(), geometry = sf::st_sfc(crs = 4326))
  }
  capas$distritos <- sf::st_sf(NOMBDIST = character(), geometry = sf::st_sfc(crs = 4326))
  if (file.exists(file.path(directorio, "distritos.shp"))) {
    capas$distritos <- leer("distritos.shp")
  }
  capas$colores_zonas <- paleta
  capas$colores_subzonas <- stats::setNames(z$COLOR_HEX[!duplicated(z$COD_S_ZONA)], z$COD_S_ZONA[!duplicated(z$COD_S_ZONA)])
  tipos <- unique(v$SIS_VIAL)
  colores_tipos <- stats::setNames(rep(c("#9A6B1F", "#A23E3A", "#2E6B57", "#6B5A88"), length.out = length(tipos)), tipos)
  capas$colores_vias <- c(paleta_categ, colores_tipos)
  capas$colores_categ_vias <- paleta_categ
  # No aplicar el fallback de parámetros por macrozona a descripciones sin conciliar.
  list(capas = capas, parametros = parametros, origen = "Archivos locales (data)",
       conteos = vapply(capas[names(archivos)], nrow, integer(1)),
       aviso = NULL)
}
