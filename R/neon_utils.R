# ==============================================================================
# MÓDULO DE INTEGRACIÓN CON NEON SERVERLESS POSTGRESQL (POSTGIS)
# GEOVISOR PDU ANTA (2024 - 2034) - GDUR MUNICIPALIDAD PROVINCIAL DE ANTA
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

if (file.exists("R/estilos_territoriales.R")) {
  source("R/estilos_territoriales.R", local = TRUE)
}

#' Establecer conexión con Neon Serverless PostgreSQL
#' Utiliza DATABASE_URL si está presente, o parámetros individuales NEON_*
#' @return Conexión DBI a PostgreSQL o NULL si no es posible conectar
neon_conectar <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RPostgres", quietly = TRUE)) {
    return(NULL)
  }
  
  # 1. Intentar por variables de entorno
  db_url <- Sys.getenv("DATABASE_URL", "")
  host <- Sys.getenv("NEON_HOST", "")
  user <- Sys.getenv("NEON_USER", "")
  password <- Sys.getenv("NEON_PASSWORD", "")
  dbname <- Sys.getenv("NEON_DB", "neondb")
  port <- as.integer(Sys.getenv("NEON_PORT", "5432"))
  
  # Si no hay variables de entorno, usar la configuración oficial del proyecto Neon
  if (!nzchar(db_url) && !nzchar(host)) {
    host <- "ep-dark-leaf-ar15e2f4-pooler.c-4.us-west-2.aws.neon.tech"
    user <- "neondb_owner"
    password <- "npg_9sGhLlAai3RB"
    dbname <- "neondb"
    port <- 5432
  }
  
  tryCatch({
    if (nzchar(host) && nzchar(user) && nzchar(password)) {
      DBI::dbConnect(
        RPostgres::Postgres(),
        host = host,
        port = port,
        dbname = dbname,
        user = user,
        password = password,
        sslmode = "require",
        connect_timeout = 10
      )
    } else if (nzchar(db_url)) {
      # Parsear URL o conectar directamente
      DBI::dbConnect(RPostgres::Postgres(), dbname = db_url)
    } else {
      NULL
    }
  }, error = function(e) {
    warning("Error al conectar a Neon PostgreSQL: ", conditionMessage(e), call. = FALSE)
    NULL
  })
}

#' Verificar disponibilidad de Neon PostgreSQL
#' @return TRUE si la base de datos responde rápidamente, FALSE en caso contrario
neon_disponible <- function() {
  con <- neon_conectar()
  if (is.null(con)) return(FALSE)
  on.exit(tryCatch(DBI::dbDisconnect(con), error = function(e) NULL), add = TRUE)
  tryCatch({
    res <- DBI::dbGetQuery(con, "SELECT 1 AS alive;")
    isTRUE(res$alive[1] == 1)
  }, error = function(e) FALSE)
}

#' Cargar capas espaciales oficiales y parámetros desde Neon PostgreSQL
#' @return Lista con capas espaciales (sf), parámetros normativos y metadatos
neon_cargar_datos_espaciales <- function() {
  con <- neon_conectar()
  if (is.null(con)) {
    stop("No se pudo conectar a la base de datos Neon PostgreSQL.")
  }
  on.exit(tryCatch(DBI::dbDisconnect(con), error = function(e) NULL), add = TRUE)
  
  tablas_espaciales <- c(
    "zonificacion", "vias", "ambito",
    "alta_tension", "alta_tension_buffer",
    "ferrocarril", "ferrocarril_buffer"
  )
  
  capas <- list()
  for (tabla in tablas_espaciales) {
    consulta <- sprintf("SELECT * FROM public.%s;", tabla)
    capa <- suppressWarnings(sf::st_read(con, query = consulta, quiet = TRUE))
    if (!inherits(capa, "sf") || nrow(capa) == 0) {
      warning("La tabla Neon '", tabla, "' no contiene datos espaciales válidos.")
      next
    }
    capas[[tabla]] <- sf::st_transform(capa, 4326)
  }
  
  # Cargar parámetros urbanísticos normativos
  parametros <- DBI::dbReadTable(con, DBI::Id(schema = "public", table = "parametros_urbanisticos"))
  
  # Asegurar paletas de colores y estilos territoriales
  paleta_zonas <- if (exists("pdu_colores_zonas", mode = "function")) pdu_colores_zonas() else c()
  paleta_categ_vias <- if (exists("pdu_colores_categ_vias", mode = "function")) pdu_colores_categ_vias() else c()
  
  if (!is.null(capas$zonificacion)) {
    z <- capas$zonificacion
    if (!"COLOR_HEX" %in% names(z) || all(is.na(z$COLOR_HEX))) {
      z$COLOR_HEX <- unname(paleta_zonas[z$COD_ZONA])
      z$COLOR_HEX[is.na(z$COLOR_HEX)] <- "#C5CCC8"
    }
    z$COLOR_MAPA <- z$COLOR_HEX
    if (!"POPUP_MAPA" %in% names(z) && exists("pdu_construir_popups_zonificacion", mode = "function")) {
      z$POPUP_MAPA <- pdu_construir_popups_zonificacion(z)
    }
    capas$zonificacion <- z
    
    # Paleta por subzona
    subzonas_unicas <- unique(z$COD_S_ZONA)
    colores_unicos <- z$COLOR_HEX[!duplicated(z$COD_S_ZONA)]
    capas$colores_subzonas <- stats::setNames(colores_unicos, subzonas_unicas)
  }
  
  if (!is.null(capas$vias)) {
    v <- capas$vias
    if (!"CATEG_VIA" %in% names(v)) {
      v$CATEG_VIA <- "LOCAL"
    }
    colores_v <- paleta_categ_vias[v$CATEG_VIA]
    colores_v[is.na(colores_v)] <- "#5B7083"
    v$COLOR_MAPA <- v$COLOR_VIA <- unname(colores_v)
    
    pesos_v <- if (exists("pdu_pesos_categ_vias", mode = "function")) pdu_pesos_categ_vias() else c("LOCAL" = 1.4)
    v$PESO_MAPA <- unname(ifelse(!is.na(pesos_v[v$CATEG_VIA]), pesos_v[v$CATEG_VIA], 1.4))
    
    trazos_v <- if (exists("pdu_trazos_categ_vias", mode = "function")) pdu_trazos_categ_vias() else c("LOCAL" = "")
    v$TRAZO_MAPA <- unname(ifelse(!is.na(trazos_v[v$CATEG_VIA]), trazos_v[v$CATEG_VIA], ""))
    
    capas$vias <- v
    capas$colores_categ_vias <- paleta_categ_vias
  }
  
  capas$colores_zonas <- paleta_zonas
  capas$distritos <- sf::st_sf(NOMBDIST = character(), geometry = sf::st_sfc(crs = 4326))
  
  list(
    capas = capas,
    parametros = parametros,
    origen = "Neon Serverless PostgreSQL (PostGIS)"
  )
}

#' Registrar visita de usuario en Neon
neon_registrar_visita <- function(navegador = NULL, ip = NULL) {
  tryCatch({
    con <- neon_conectar()
    if (is.null(con)) return(FALSE)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(con, "SELECT public.registrar_visita($1, $2);", params = list(navegador, ip))
    TRUE
  }, error = function(e) FALSE)
}

#' Registrar constancia descargada en Neon
neon_registrar_constancia <- function(codigo_consulta, tipo = "punto", distrito = NULL) {
  tryCatch({
    con <- neon_conectar()
    if (is.null(con)) return(FALSE)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(con, "SELECT public.registrar_constancia($1, $2, $3);",
                   params = list(codigo_consulta, tipo, distrito))
    TRUE
  }, error = function(e) FALSE)
}

#' Obtener métricas consolidadas desde Neon
neon_obtener_metricas <- function() {
  tryCatch({
    con <- neon_conectar()
    if (is.null(con)) stop("Sin conexión a Neon")
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    res <- DBI::dbGetQuery(con, "SELECT public.get_metricas_geovisor() AS json;")
    if (nrow(res) > 0 && !is.na(res$json[1])) {
      return(jsonlite::fromJSON(res$json[1]))
    }
    list(visitas_total = 0, constancias_total = 0)
  }, error = function(e) {
    list(visitas_total = 0, constancias_total = 0)
  })
}

#' Registrar consulta territorial en Neon
neon_registrar_consulta <- function(tipo_consulta, coordenadas, distrito = NULL,
                                    en_ambito = TRUE, zona_principal = NULL, metadata = list()) {
  tryCatch({
    con <- neon_conectar()
    if (is.null(con)) return(FALSE)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    meta_json <- jsonlite::toJSON(metadata, auto_unbox = TRUE)
    DBI::dbExecute(
      con,
      "INSERT INTO public.consultas_pdu (tipo_consulta, coordenadas, distrito, en_ambito, zona_principal, metadata)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb);",
      params = list(tipo_consulta, coordenadas, distrito, en_ambito, zona_principal, meta_json)
    )
    TRUE
  }, error = function(e) FALSE)
}
