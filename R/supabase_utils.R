# ==============================================================================
# MÓDULO DE INTEGRACIÓN CON SUPABASE - GEOVISOR PDU ANTA (2024 - 2034)
# Conexión dual (PostgreSQL nativo / REST API) con tolerancia a fallos
# Compatible con Posit Connect Cloud, RStudio Desktop y despliegues Linux
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

# Carga condicional de clientes
supabase_has_rpostgres <- function() {
  requireNamespace("DBI", quietly = TRUE) && requireNamespace("RPostgres", quietly = TRUE)
}

supabase_has_httr2 <- function() {
  requireNamespace("httr2", quietly = TRUE)
}

# Clave pública para llamadas REST desde la aplicación. Supabase renombró las
# claves `anon` como `publishable`; se mantienen los nombres antiguos por
# compatibilidad. La clave secreta nunca debe usarse en el cliente público.
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
#' @return "postgres", "rest" o "offline"
supabase_detect_mode <- function() {
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
supabase_is_configured <- function() {
  supabase_detect_mode() != "offline"
}

# ------------------------------------------------------------------------------
# 2. CONEXIÓN POSTGRESQL NATIVA (RPostgres)
# ------------------------------------------------------------------------------

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
# 3. LECTURA DE INFORMACIÓN ESPACIAL DESDE POSTGIS
# ------------------------------------------------------------------------------

supabase_tablas_espaciales <- function() {
  c(
    "ambito", "distritos", "zonificacion", "vias", "alta_tension",
    "alta_tension_buffer", "ferrocarril", "ferrocarril_buffer"
  )
}

supabase_colores_zonas <- function() {
  c(
    ZDA = "#C86868", ZDM = "#F67777", ZDB = "#F2964C", ZDMB = "#E5E64B",
    ZI = "#B2AECB", `ZSPC-E` = "#A9CEEC", `ZSPC-S` = "#99D5D2",
    ZRP = "#BEDB92", ZOU = "#BCBDBE", ZA = "#EFF6D3", ZPA = "#80C880",
    ZRE = "#CB7B9E", ZM = "#DDD4CE"
  )
}

supabase_paleta_desde_columnas <- function(datos, codigo, color) {
  if (!all(c(codigo, color) %in% names(datos))) return(character())
  pares <- unique(sf::st_drop_geometry(datos)[, c(codigo, color), drop = FALSE])
  pares <- pares[!is.na(pares[[codigo]]) & !is.na(pares[[color]]) &
                   nzchar(as.character(pares[[codigo]])) & nzchar(as.character(pares[[color]])), , drop = FALSE]
  stats::setNames(as.character(pares[[color]]), as.character(pares[[codigo]]))
}

#' Leer todas las capas oficiales del PDU directamente desde Supabase/PostGIS.
#'
#' Esta función no usa archivos RDS. La aplicación falla de forma explícita si
#' la conexión o alguna tabla requerida no está disponible.
supabase_cargar_datos_espaciales <- function() {
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
  capas$colores_vias <- supabase_paleta_desde_columnas(
    capas$vias, "SIS_VIAL", "COLOR_VIA"
  )

  list(
    capas = capas,
    parametros = parametros,
    origen = "Supabase/PostGIS",
    conteos = stats::setNames(as.numeric(conteos$filas), conteos$tabla)
  )
}

# ------------------------------------------------------------------------------
# 4. VERIFICACIÓN DE ESTADO (PING / HEALTH CHECK)
# ------------------------------------------------------------------------------

#' Diagnóstico de conexión a Supabase
supabase_ping <- function() {
  modo <- supabase_detect_mode()
  
  if (modo == "offline") {
    return(list(
      conectado = FALSE,
      modo = "offline",
      mensaje = "Modo local (Sin credenciales de Supabase en entorno)",
      latencia_ms = NA_real_
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
        modo = "postgres",
        mensaje = "Conectado a Supabase (PostgreSQL)",
        latencia_ms = round(latencia, 1)
      ))
    }
  }
  
  # Intento REST si Postgres no funcionó o si el modo es REST
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
          modo = "rest",
          mensaje = "Conectado a Supabase (REST API)",
          latencia_ms = round(latencia, 1)
        ))
      }, error = function(e) NULL)
    }
  }
  
  list(
    conectado = FALSE,
    modo = modo,
    mensaje = "No fue posible comunicarse con Supabase",
    latencia_ms = NA_real_
  )
}

# ------------------------------------------------------------------------------
# 5. REGISTRO DE AUDITORÍA DE CONSULTAS (consultas_pdu)
# ------------------------------------------------------------------------------

#' Registrar una consulta territorial en Supabase
supabase_registrar_consulta <- function(tipo_consulta,
                                        coordenadas_texto,
                                        distrito,
                                        en_ambito = TRUE,
                                        zona_principal = NA_character_,
                                        detalle_json = list()) {
  modo <- supabase_detect_mode()
  if (modo == "offline") return(invisible(FALSE))
  
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
# 6. MÉTRICAS PÚBLICAS DEL GEOVISOR
# ------------------------------------------------------------------------------

supabase_metricas_vacias <- function() {
  list(visitas_total = NA_real_, constancias_total = NA_real_)
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
  if (modo == "offline") return(supabase_metricas_vacias())

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
      }, error = function(e) NULL)
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
      }, error = function(e) NULL)
      if (!is.null(resultado)) return(supabase_normalizar_metricas(resultado))
    }
  }

  supabase_metricas_vacias()
}

#' Contabilizar como máximo una visita por navegador y día.
supabase_registrar_visita <- function(visitante_id) {
  supabase_rpc_metricas(
    "registrar_visita",
    list(p_visitante = trimws(as.character(visitante_id)))
  )
}

#' Contabilizar una constancia únicamente después de generarla correctamente.
supabase_registrar_constancia <- function() {
  supabase_rpc_metricas("registrar_constancia")
}

#' Obtener los contadores públicos sin exponer las tablas de eventos.
supabase_obtener_metricas <- function() {
  supabase_rpc_metricas("get_metricas_geovisor")
}

# ------------------------------------------------------------------------------
# 7. BUZÓN DE OBSERVACIONES CIUDADANAS (LEGADO, SIN INTERFAZ PÚBLICA)
# ------------------------------------------------------------------------------

#' Guardar reporte u observación ciudadana
supabase_enviar_reporte_ciudadano <- function(nombre_ciudadano,
                                              contacto,
                                              tipo,
                                              ubicacion,
                                              mensaje) {
  modo <- supabase_detect_mode()
  if (modo == "offline") {
    return(list(ok = FALSE, error = "El módulo en la nube de Supabase no está conectado actualmente."))
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
# 8. AVISOS MUNICIPALES DINÁMICOS (avisos_municipales)
# ------------------------------------------------------------------------------

#' Obtener avisos institucionales activos
supabase_obtener_avisos <- function(limite = 3) {
  modo <- supabase_detect_mode()
  if (modo == "offline") return(data.frame())
  
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
