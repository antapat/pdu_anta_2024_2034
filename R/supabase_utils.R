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
  key <- Sys.getenv("SUPABASE_ANON_KEY", Sys.getenv("SUPABASE_KEY", ""))
  
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
# 3. VERIFICACIÓN DE ESTADO (PING / HEALTH CHECK)
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
    key <- Sys.getenv("SUPABASE_ANON_KEY", Sys.getenv("SUPABASE_KEY", ""))
    
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
# 4. REGISTRO DE AUDITORÍA DE CONSULTAS (consultas_pdu)
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
    key <- Sys.getenv("SUPABASE_ANON_KEY", Sys.getenv("SUPABASE_KEY", ""))
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
# 5. BUZÓN DE OBSERVACIONES CIUDADANAS (reportes_ciudadanos)
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
    key <- Sys.getenv("SUPABASE_ANON_KEY", Sys.getenv("SUPABASE_KEY", ""))
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
# 6. AVISOS MUNICIPALES DINÁMICOS (avisos_municipales)
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
