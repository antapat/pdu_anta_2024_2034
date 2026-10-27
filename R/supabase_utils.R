# ==============================================================================
# [DEPRECADO] MÓDULO DE INTEGRACIÓN CON SUPABASE - GEOVISOR PDU ANTA (2024 - 2034)
# ESTADO: OBSOLETO / DEPRECATED - MIGRACIÓN A NEON POSTGRESQL PENDIENTE
# GDUR - Municipalidad Provincial de Anta
# ==============================================================================
# AVISO TÉCNICO:
# Las conexiones directas con Supabase (REST API y PostgreSQL) han sido declaradas
# obsoletas. Por el momento el GeoVisor opera en MODO LOCAL AUTÓNOMO (data/).
# Próxima fase: migración a Neon Serverless PostgreSQL (PostGIS estándar).
# Se conservan las funciones de este archivo con decoradores @deprecated y emuladores
# locales para asegurar compatibilidad total sin interrupciones ni errores.
# Para más detalles, consulte: NEON_MIGRACION.md y deprecated/supabase/
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

# Cargar estilos territoriales desacoplados si existen
if (file.exists("R/estilos_territoriales.R")) {
  source("R/estilos_territoriales.R", local = TRUE)
}

# Carga condicional de clientes
supabase_has_rpostgres <- function() {
  requireNamespace("DBI", quietly = TRUE) && requireNamespace("RPostgres", quietly = TRUE)
}

supabase_has_httr2 <- function() {
  requireNamespace("httr2", quietly = TRUE)
}

# Clave pública para llamadas REST legadas desde la aplicación.
# @deprecated Se mantiene exclusivamente por compatibilidad hacia atrás.
supabase_public_api_key <- function() {
  Sys.getenv(
    "SUPABASE_PUBLISHABLE_KEY",
    Sys.getenv("SUPABASE_ANON_KEY", Sys.getenv("SUPABASE_KEY", ""))
  )
}

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DE MODO Y CREDENCIALES
# ------------------------------------------------------------------------------

#' Detectar el modo de conexión disponible
#' @return "local", "postgres", "rest" u "offline"
#' @deprecated La fuente oficial por defecto es "local".
supabase_detect_mode <- function() {
  fuente <- tolower(Sys.getenv("PDU_DATA_SOURCE", "local"))
  if (fuente == "local") return("local")
  
  host <- Sys.getenv("SUPABASE_HOST", "")
  pwd  <- Sys.getenv("SUPABASE_PASSWORD", "")
  user <- Sys.getenv("SUPABASE_USER", "")
  
  if (nzchar(host) && nzchar(pwd) && nzchar(user) && supabase_has_rpostgres()) {
    return("postgres")
  }
  
  url <- Sys.getenv("SUPABASE_URL", "")
  key <- supabase_public_api_key()
  
  if (nzchar(url) && nzchar(key) && supabase_has_httr2()) {
    return("rest")
  }
  
  "offline"
}

#' Verificar si Supabase está activo
#' @deprecated
supabase_is_configured <- function() {
  !supabase_detect_mode() %in% c("offline", "local")
}

# ------------------------------------------------------------------------------
# 2. CONEXIÓN POSTGRESQL NATIVA (RPostgres) - [DEPRECADA]
# ------------------------------------------------------------------------------

#' Conexión PostgreSQL a Supabase (Legada)
#' @deprecated Usar conector Neon en fase posterior
supabase_conectar_pg <- function() {
  if (!supabase_has_rpostgres()) return(NULL)
  
  tryCatch({
    DBI::dbConnect(
      RPostgres::Postgres(),
      dbname   = Sys.getenv("SUPABASE_DB", "postgres"),
      host     = Sys.getenv("SUPABASE_HOST"),
      port     = as.integer(Sys.getenv("SUPABASE_PORT", "5432")),
      user     = Sys.getenv("SUPABASE_USER"),
      password = Sys.getenv("SUPABASE_PASSWORD"),
      sslmode  = "require",
      connect_timeout = 4
    )
  }, error = function(e) {
    NULL
  })
}

# ------------------------------------------------------------------------------
# 3. PALETAS Y ESTILOS TERRITORIALES (DELEGACIÓN A R/estilos_territoriales.R)
# ------------------------------------------------------------------------------

supabase_tablas_espaciales <- function() {
  c(
    "ambito", "distritos", "zonificacion", "vias", "alta_tension",
    "alta_tension_buffer", "ferrocarril", "ferrocarril_buffer"
  )
}

supabase_colores_zonas <- function() {
  if (exists("pdu_colores_zonas", mode = "function")) {
    pdu_colores_zonas()
  } else {
    c(
      ZDA = "#C97876", ZDM = "#D99384", ZDB = "#D8A36C", ZDMB = "#D5C66F",
      ZI = "#8D94AD", `ZSPC-E` = "#8FB5CA", `ZSPC-S` = "#7FB7AE",
      ZRP = "#A8C486", ZOU = "#A6AEB0", ZA = "#DDE7C3", ZPA = "#6FA27A",
      ZRE = "#B47B96", ZM = "#C7BBB3"
    )
  }
}

supabase_colores_vias <- function() {
  if (exists("pdu_colores_vias", mode = "function")) {
    pdu_colores_vias()
  } else {
    c(
      "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "#9A6B1F",
      "SISTEMA VIAL PRIMARIO" = "#A23E3A",
      "SISTEMA VIAL SECUNDARIO" = "#2E6B57",
      "SISTEMA VIAL ESPECIAL" = "#6B5A88"
    )
  }
}

supabase_trazos_vias <- function() {
  if (exists("pdu_trazos_vias", mode = "function")) {
    pdu_trazos_vias()
  } else {
    c(
      "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "12,6",
      "SISTEMA VIAL PRIMARIO" = "9,5",
      "SISTEMA VIAL SECUNDARIO" = "5,5",
      "SISTEMA VIAL ESPECIAL" = "2,5"
    )
  }
}

supabase_paleta_desde_columnas <- function(datos, codigo, color) {
  if (exists("pdu_paleta_desde_columnas", mode = "function")) {
    pdu_paleta_desde_columnas(datos, codigo, color)
  } else {
    if (!all(c(codigo, color) %in% names(datos))) return(character())
    pares <- unique(sf::st_drop_geometry(datos)[, c(codigo, color), drop = FALSE])
    pares <- pares[!is.na(pares[[codigo]]) & !is.na(pares[[color]]) &
                     nzchar(as.character(pares[[codigo]])) & nzchar(as.character(pares[[color]])), , drop = FALSE]
    stats::setNames(as.character(pares[[color]]), as.character(pares[[codigo]]))
  }
}

# ------------------------------------------------------------------------------
# 4. CARGA ESPACIAL DESDE SUPABASE/POSTGIS - [DEPRECADA]
# ------------------------------------------------------------------------------

#' Leer todas las capas oficiales del PDU directamente desde Supabase/PostGIS.
#' @deprecated Utilice modo local o el futuro conector Neon.
supabase_cargar_datos_espaciales <- function() {
  warning(
    "[DEPRECADO] La conexión directa a Supabase está marcada como obsoleta. ",
    "El proyecto se migrará a Neon Serverless PostgreSQL.",
    call. = FALSE
  )
  
  if (supabase_detect_mode() != "postgres") {
    stop(
      "La información espacial requiere conexión PostgreSQL directa a Supabase. ",
      "Configure SUPABASE_HOST, SUPABASE_PORT, SUPABASE_DB, SUPABASE_USER y SUPABASE_PASSWORD. ",
      "La clave publicable o la clave secreta de la API no sustituyen la contraseña de PostgreSQL."
    )
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("El paquete 'sf' es obligatorio para leer las capas PostGIS.")
  }

  con <- supabase_conectar_pg()
  if (is.null(con)) stop("No fue posible conectar con PostgreSQL de Supabase.")
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  requeridas <- c(supabase_tablas_espaciales(), "parametros_urbanisticos")
  requeridas_sql <- paste(DBI::dbQuoteString(con, requeridas), collapse = ", ")
  existentes <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT table_name AS nombre FROM information_schema.tables ",
      "WHERE table_schema = 'public' AND table_name IN (", requeridas_sql, ")"
    )
  )$nombre
  faltantes <- setdiff(requeridas, existentes)
  if (length(faltantes)) {
    stop(
      "Supabase no contiene todas las tablas del GeoVisor. Faltan: ",
      paste(faltantes, collapse = ", "),
      ". Ejecute las migraciones y scripts/04_cargar_supabase.R."
    )
  }

  conteos <- DBI::dbGetQuery(
    con,
    paste(
      vapply(
        requeridas,
        function(tabla) sprintf(
          "SELECT %s AS tabla, count(*)::bigint AS filas FROM %s",
          DBI::dbQuoteString(con, tabla),
          DBI::dbQuoteIdentifier(con, DBI::Id(schema = "public", table = tabla))
        ),
        character(1)
      ),
      collapse = " UNION ALL "
    )
  )
  vacias <- conteos$tabla[conteos$filas == 0]
  if (length(vacias)) {
    stop("Las siguientes tablas de Supabase están vacías: ", paste(vacias, collapse = ", "))
  }

  capas <- stats::setNames(vector("list", length(supabase_tablas_espaciales())), supabase_tablas_espaciales())
  for (tabla in names(capas)) {
    consulta <- paste(
      "SELECT * FROM",
      DBI::dbQuoteIdentifier(con, DBI::Id(schema = "public", table = tabla))
    )
    capa <- suppressWarnings(sf::st_read(con, query = consulta, quiet = TRUE))
    if (!inherits(capa, "sf") || nrow(capa) == 0) {
      stop("La tabla public.", tabla, " no contiene geometrías válidas.")
    }
    if (is.na(sf::st_crs(capa))) {
      stop("La tabla public.", tabla, " no tiene un CRS definido.")
    }
    capas[[tabla]] <- sf::st_transform(capa, 4326)
  }

  parametros <- DBI::dbReadTable(
    con,
    DBI::Id(schema = "public", table = "parametros_urbanisticos")
  )
  if (!inherits(parametros, "data.frame") || nrow(parametros) == 0) {
    stop("public.parametros_urbanisticos está vacía o no es una tabla válida.")
  }

  capas$colores_subzonas <- supabase_paleta_desde_columnas(
    capas$zonificacion, "COD_S_ZONA", "COLOR_HEX"
  )
  capas$colores_zonas <- supabase_colores_zonas()
  capas$colores_vias <- supabase_colores_vias()

  color_zona <- unname(capas$colores_zonas[as.character(capas$zonificacion$COD_ZONA)])
  color_zona[is.na(color_zona)] <- "#C5CCC8"
  capas$zonificacion$COLOR_MAPA <- color_zona

  jerarquia_vial <- as.character(capas$vias$SIS_VIAL)
  color_via <- unname(capas$colores_vias[jerarquia_vial])
  color_via[is.na(color_via)] <- "#52635B"
  trazo_via <- unname(supabase_trazos_vias()[jerarquia_vial])
  trazo_via[is.na(trazo_via)] <- "6,5"
  peso_via <- unname(c(
    "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = 2.2,
    "SISTEMA VIAL PRIMARIO" = 2.0,
    "SISTEMA VIAL SECUNDARIO" = 1.6,
    "SISTEMA VIAL ESPECIAL" = 1.7
  )[jerarquia_vial])
  peso_via[is.na(peso_via)] <- 1.6
  capas$vias$COLOR_MAPA <- color_via
  capas$vias$TRAZO_MAPA <- trazo_via
  capas$vias$PESO_MAPA <- peso_via

  list(
    capas = capas,
    parametros = parametros,
    origen = "Supabase/PostGIS [DEPRECADO]",
    conteos = stats::setNames(as.numeric(conteos$filas), conteos$tabla)
  )
}

# ------------------------------------------------------------------------------
# 5. VERIFICACIÓN DE ESTADO (PING / HEALTH CHECK)
# ------------------------------------------------------------------------------

#' Diagnóstico de conexión (Soporta modo local autónomo)
supabase_ping <- function() {
  modo <- supabase_detect_mode()
  
  if (modo %in% c("offline", "local")) {
    return(list(
      conectado = FALSE,
      es_local = TRUE,
      modo = "local",
      mensaje = "Modo Local Autónomo (Shapefiles en data/ | Supabase deprecado)",
      latencia_ms = 0
    ))
  }
  
  t0 <- Sys.time()
  
  if (modo == "postgres") {
    con <- supabase_conectar_pg()
    if (!is.null(con)) {
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      latencia <- as.numeric(difftime(Sys.time(), t0, units = "secs")) * 1000
      return(list(
        conectado = TRUE,
        es_local = FALSE,
        modo = "postgres",
        mensaje = "Conectado a Supabase (PostgreSQL - DEPRECADO)",
        latencia_ms = round(latencia, 1)
      ))
    }
  }
  
  if (supabase_has_httr2()) {
    url <- Sys.getenv("SUPABASE_URL", "")
    key <- supabase_public_api_key()
    
    if (nzchar(url) && nzchar(key)) {
      tryCatch({
        req <- httr2::request(paste0(sub("/+$", "", url), "/rest/v1/")) |>
          httr2::req_headers(
            "apikey" = key,
            "Authorization" = paste("Bearer", key)
          ) |>
          httr2::req_timeout(3)
        
        resp <- httr2::req_perform(req)
        latencia <- as.numeric(difftime(Sys.time(), t0, units = "secs")) * 1000
        return(list(
          conectado = TRUE,
          es_local = FALSE,
          modo = "rest",
          mensaje = "Conectado a Supabase (REST API - DEPRECADO)",
          latencia_ms = round(latencia, 1)
        ))
      }, error = function(e) NULL)
    }
  }
  
  list(
    conectado = FALSE,
    es_local = FALSE,
    modo = modo,
    mensaje = "No fue posible comunicarse con Supabase (Deprecado)",
    latencia_ms = NA_real_
  )
}

# ------------------------------------------------------------------------------
# 6. REGISTRO DE AUDITORÍA DE CONSULTAS (consultas_pdu)
# ------------------------------------------------------------------------------

#' Registrar una consulta territorial (con emulación local segura)
supabase_registrar_consulta <- function(tipo_consulta,
                                        coordenadas_texto,
                                        distrito,
                                        en_ambito = TRUE,
                                        zona_principal = NA_character_,
                                        detalle_json = list()) {
  modo <- supabase_detect_mode()
  
  # Manejo en MODO LOCAL: Registro en archivo de log local
  if (modo %in% c("offline", "local")) {
    dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
    tryCatch({
      log_line <- sprintf(
        "[%s] Consulta: %s | Coord: %s | Distrito: %s | Zona: %s\n",
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        as.character(tipo_consulta),
        as.character(coordenadas_texto),
        as.character(distrito),
        ifelse(is.na(zona_principal), "SIN_ZONA", as.character(zona_principal))
      )
      cat(log_line, file = file.path("outputs", "consultas_local.log"), append = TRUE)
    }, error = function(e) NULL)
    return(invisible(TRUE))
  }
  
  meta_str <- tryCatch(jsonlite::toJSON(detalle_json, auto_unbox = TRUE), error = function(e) "{}")
  
  # 1. Vía Postgres
  if (modo == "postgres") {
    con <- supabase_conectar_pg()
    if (!is.null(con)) {
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      tryCatch({
        sql <- "INSERT INTO public.consultas_pdu (tipo_consulta, coordenadas, distrito, en_ambito, zona_principal, metadata) VALUES ($1, $2, $3, $4, $5, $6::jsonb)"
        DBI::dbExecute(con, sql, params = list(
          as.character(tipo_consulta),
          as.character(coordenadas_texto),
          as.character(distrito),
          as.logical(en_ambito),
          ifelse(is.na(zona_principal), "SIN_ZONA", as.character(zona_principal)),
          meta_str
        ))
        return(invisible(TRUE))
      }, error = function(e) NULL)
    }
  }
  
  # 2. Vía REST
  if (supabase_has_httr2()) {
    url <- sub("/+$", "", Sys.getenv("SUPABASE_URL", ""))
    key <- supabase_public_api_key()
    if (nzchar(url) && nzchar(key)) {
      tryCatch({
        payload <- list(
          tipo_consulta = as.character(tipo_consulta),
          coordenadas = as.character(coordenadas_texto),
          distrito = as.character(distrito),
          en_ambito = isTRUE(en_ambito),
          zona_principal = ifelse(is.na(zona_principal), "SIN_ZONA", as.character(zona_principal)),
          metadata = detalle_json
        )
        req <- httr2::request(paste0(url, "/rest/v1/consultas_pdu")) |>
          httr2::req_headers(
            "apikey" = key,
            "Authorization" = paste("Bearer", key),
            "Content-Type" = "application/json",
            "Prefer" = "return=minimal"
          ) |>
          httr2::req_body_json(payload) |>
          httr2::req_timeout(3)
        httr2::req_perform(req)
        return(invisible(TRUE))
      }, error = function(e) NULL)
    }
  }
  
  invisible(FALSE)
}

# ------------------------------------------------------------------------------
# 7. MÉTRICAS PÚBLICAS DEL GEOVISOR (CON GESTIÓN LOCAL EN outputs/)
# ------------------------------------------------------------------------------

supabase_metricas_vacias <- function() {
  list(visitas_total = 0, constancias_total = 0)
}

.local_metricas_file <- function() {
  dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
  file.path("outputs", "metricas_geovisor_local.json")
}

.local_metricas_leer <- function() {
  ruta <- .local_metricas_file()
  if (file.exists(ruta)) {
    tryCatch({
      m <- jsonlite::fromJSON(ruta)
      return(list(
        visitas_total = max(1, as.numeric(m$visitas_total %||% 1)),
        constancias_total = max(0, as.numeric(m$constancias_total %||% 0))
      ))
    }, error = function(e) NULL)
  }
  list(visitas_total = 1, constancias_total = 0)
}

.local_metricas_guardar <- function(m) {
  ruta <- .local_metricas_file()
  tryCatch({
    jsonlite::write_json(m, ruta, auto_unbox = TRUE, pretty = TRUE)
  }, error = function(e) NULL)
  m
}

supabase_normalizar_metricas <- function(x) {
  if (is.null(x) || length(x) == 0) return(supabase_metricas_vacias())
  if (is.data.frame(x)) {
    if (nrow(x) == 0) return(supabase_metricas_vacias())
    x <- as.list(x[1, , drop = FALSE])
  }
  list(
    visitas_total = suppressWarnings(as.numeric(x$visitas_total[[1]])),
    constancias_total = suppressWarnings(as.numeric(x$constancias_total[[1]]))
  )
}

supabase_rpc_metricas <- function(funcion, payload = NULL) {
  modo <- supabase_detect_mode()
  if (modo %in% c("offline", "local")) return(.local_metricas_leer())

  if (modo == "postgres") {
    con <- supabase_conectar_pg()
    if (!is.null(con)) {
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      resultado <- tryCatch({
        if (identical(funcion, "registrar_visita")) {
          DBI::dbGetQuery(con, "SELECT * FROM public.registrar_visita($1)", params = list(payload$p_visitante))
        } else if (identical(funcion, "registrar_constancia")) {
          DBI::dbGetQuery(con, "SELECT * FROM public.registrar_constancia()")
        } else {
          DBI::dbGetQuery(con, "SELECT * FROM public.get_metricas_geovisor()")
        }
      }, error = function(e) {
        warning("Error en RPC de métricas por PostgreSQL: ", conditionMessage(e), call. = FALSE)
        NULL
      })
      if (!is.null(resultado) && nrow(resultado) > 0) {
        return(supabase_normalizar_metricas(resultado))
      }
    }
  }

  if (supabase_has_httr2()) {
    url <- sub("/+$", "", Sys.getenv("SUPABASE_URL", ""))
    key <- supabase_public_api_key()
    if (nzchar(url) && nzchar(key)) {
      resultado <- tryCatch({
        req <- httr2::request(paste0(url, "/rest/v1/rpc/", funcion)) |>
          httr2::req_headers(
            "apikey" = key,
            "Authorization" = paste("Bearer", key),
            "Content-Type" = "application/json"
          ) |>
          httr2::req_body_json(if (is.null(payload)) list() else payload) |>
          httr2::req_timeout(4)
        resp <- httr2::req_perform(req)
        httr2::resp_body_json(resp, simplifyVector = TRUE)
      }, error = function(e) {
        warning("Error en RPC de métricas por REST: ", conditionMessage(e), call. = FALSE)
        NULL
      })
      if (!is.null(resultado)) return(supabase_normalizar_metricas(resultado))
    }
  }

  .local_metricas_leer()
}

#' Contabilizar visita (compatible con entorno local)
supabase_registrar_visita <- function(visitante_id) {
  modo <- supabase_detect_mode()
  if (modo %in% c("offline", "local")) {
    m <- .local_metricas_leer()
    m$visitas_total <- m$visitas_total + 1
    return(.local_metricas_guardar(m))
  }
  supabase_rpc_metricas(
    "registrar_visita",
    list(p_visitante = trimws(as.character(visitante_id)))
  )
}

#' Contabilizar una constancia (compatible con entorno local)
supabase_registrar_constancia <- function() {
  modo <- supabase_detect_mode()
  if (modo %in% c("offline", "local")) {
    m <- .local_metricas_leer()
    m$constancias_total <- m$constancias_total + 1
    return(.local_metricas_guardar(m))
  }
  supabase_rpc_metricas("registrar_constancia")
}

#' Obtener los contadores públicos
supabase_obtener_metricas <- function() {
  modo <- supabase_detect_mode()
  if (modo %in% c("offline", "local")) return(.local_metricas_leer())
  supabase_rpc_metricas("get_metricas_geovisor")
}

# ------------------------------------------------------------------------------
# 8. BUZÓN DE OBSERVACIONES CIUDADANAS (CON ALMACÉN LOCAL)
# ------------------------------------------------------------------------------

#' Guardar reporte u observación ciudadana (soporta almacenamiento local)
supabase_enviar_reporte_ciudadano <- function(nombre_ciudadano,
                                              contacto,
                                              tipo_observacion = "OBSERVACION",
                                              ubicacion_predio = "No especificada",
                                              mensaje = "",
                                              tipo = tipo_observacion,
                                              ubicacion = ubicacion_predio) {
  modo <- supabase_detect_mode()
  
  # Si opera en LOCAL, almacenar el reporte en archivo local
  if (modo %in% c("offline", "local")) {
    dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
    ruta_rep <- file.path("outputs", "buzon_ciudadano_local.json")
    
    nuevo_reporte <- list(
      ticket           = paste0("PDU-LOCAL-", format(Sys.time(), "%y%m%d%H%M%S")),
      fecha_hora       = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      nombre_ciudadano = trimws(as.character(nombre_ciudadano)),
      contacto         = trimws(as.character(contacto)),
      tipo             = as.character(tipo),
      ubicacion        = as.character(ubicacion),
      mensaje          = trimws(as.character(mensaje)),
      estado           = "REGISTRADO_LOCAL"
    )
    
    ok_write <- tryCatch({
      lista_existente <- if (file.exists(ruta_rep)) {
        jsonlite::fromJSON(ruta_rep, simplifyVector = FALSE)
      } else {
        list()
      }
      lista_existente[[length(lista_existente) + 1]] <- nuevo_reporte
      jsonlite::write_json(lista_existente, ruta_rep, auto_unbox = TRUE, pretty = TRUE)
      TRUE
    }, error = function(e) FALSE)
    
    if (ok_write) {
      return(list(ok = TRUE, ticket = nuevo_reporte$ticket, origen = "local"))
    }
    return(list(ok = FALSE, error = "No fue posible almacenar el reporte en modo local."))
  }
  
  # 1. Vía Postgres
  if (modo == "postgres") {
    con <- supabase_conectar_pg()
    if (!is.null(con)) {
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      res <- tryCatch({
        sql <- "INSERT INTO public.reportes_ciudadanos (nombre_ciudadano, contacto, tipo, ubicacion, mensaje, estado) VALUES ($1, $2, $3, $4, $5, 'PENDIENTE')"
        DBI::dbExecute(con, sql, params = list(
          trimws(as.character(nombre_ciudadano)),
          trimws(as.character(contacto)),
          as.character(tipo),
          as.character(ubicacion),
          trimws(as.character(mensaje))
        ))
        list(ok = TRUE)
      }, error = function(e) {
        list(ok = FALSE, error = e$message)
      })
      if (res$ok) return(res)
    }
  }
  
  # 2. Vía REST
  if (supabase_has_httr2()) {
    url <- sub("/+$", "", Sys.getenv("SUPABASE_URL", ""))
    key <- supabase_public_api_key()
    if (nzchar(url) && nzchar(key)) {
      res <- tryCatch({
        payload <- list(
          nombre_ciudadano = trimws(as.character(nombre_ciudadano)),
          contacto = trimws(as.character(contacto)),
          tipo = as.character(tipo),
          ubicacion = as.character(ubicacion),
          mensaje = trimws(as.character(mensaje)),
          estado = "PENDIENTE"
        )
        req <- httr2::request(paste0(url, "/rest/v1/reportes_ciudadanos")) |>
          httr2::req_headers(
            "apikey" = key,
            "Authorization" = paste("Bearer", key),
            "Content-Type" = "application/json",
            "Prefer" = "return=minimal"
          ) |>
          httr2::req_body_json(payload) |>
          httr2::req_timeout(4)
        httr2::req_perform(req)
        list(ok = TRUE)
      }, error = function(e) {
        list(ok = FALSE, error = e$message)
      })
      return(res)
    }
  }
  
  list(ok = FALSE, error = "No fue posible enviar el reporte.")
}

# ------------------------------------------------------------------------------
# 9. AVISOS MUNICIPALES DINÁMICOS (avisos_municipales)
# ------------------------------------------------------------------------------

#' Obtener avisos institucionales activos
supabase_obtener_avisos <- function(limite = 3) {
  modo <- supabase_detect_mode()
  if (modo %in% c("offline", "local")) return(data.frame())
  
  # 1. Vía Postgres
  if (modo == "postgres") {
    con <- supabase_conectar_pg()
    if (!is.null(con)) {
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      df <- tryCatch({
        DBI::dbGetQuery(
          con,
          "SELECT titulo, contenido, nivel, creado_en FROM public.avisos_municipales WHERE activo = true ORDER BY creado_en DESC LIMIT $1",
          params = list(as.integer(limite))
        )
      }, error = function(e) data.frame())
      if (nrow(df) > 0) return(df)
    }
  }
  
  data.frame()
}
