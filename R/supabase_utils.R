# ==============================================================================
# MODULO LOCAL DE REGISTRO Y METRICAS - GEOVISOR PDU ANTA (2024 - 2034)
# MODO: 100% LOCAL Y AUTONOMO (SIN CONEXIONES EXTERNAS NI DEPENDENCIAS CLOUD)
# GDUR - Municipalidad Provincial de Anta
# ==============================================================================

suppressPackageStartupMessages({
  if (requireNamespace("jsonlite", quietly = TRUE)) library(jsonlite)
})

# Cargar estilos territoriales desacoplados si existen
if (file.exists("R/estilos_territoriales.R")) {
  source("R/estilos_territoriales.R", local = TRUE)
}

# ------------------------------------------------------------------------------
# 1. DETECCION DE MODO (LOCAL AUTONOMO)
# ------------------------------------------------------------------------------

supabase_detect_mode <- function() {
  "local"
}

supabase_is_configured <- function() {
  FALSE
}

supabase_ping <- function() {
  list(
    conectado = FALSE,
    es_local = TRUE,
    modo = "local",
    mensaje = "Modo Local Autónomo (Sin dependencias externas)",
    latencia_ms = 0
  )
}

# ------------------------------------------------------------------------------
# 2. ENLACES A ESTILOS Y CATALOGOS TERRITORIALES
# ------------------------------------------------------------------------------

supabase_tablas_espaciales <- function() {
  c("ambito", "distritos", "zonificacion", "vias", "alta_tension",
    "alta_tension_buffer", "ferrocarril", "ferrocarril_buffer")
}

supabase_colores_zonas <- function() {
  pdu_colores_zonas()
}

supabase_colores_vias <- function() {
  pdu_colores_vias()
}

supabase_trazos_vias <- function() {
  pdu_trazos_vias()
}

supabase_paleta_desde_columnas <- function(col_nombres, col_hex) {
  pdu_paleta_desde_columnas(col_nombres, col_hex)
}

# ------------------------------------------------------------------------------
# 3. METRICAS LOCALES PERSISTENTES
# ------------------------------------------------------------------------------

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
        constancias_total = max(0, as.numeric(m$constancias_total %||% 0)),
        consultas_total = max(0, as.numeric(m$consultas_total %||% 0))
      ))
    }, error = function(e) NULL)
  }
  list(visitas_total = 1, constancias_total = 0, consultas_total = 0)
}

.local_metricas_guardar <- function(m) {
  ruta <- .local_metricas_file()
  tryCatch({
    jsonlite::write_json(m, ruta, auto_unbox = TRUE, pretty = TRUE)
  }, error = function(e) NULL)
  m
}

supabase_metricas_vacias <- function() {
  list(visitas_total = 0, constancias_total = 0, consultas_total = 0)
}

supabase_normalizar_metricas <- function(x) {
  if (is.null(x) || length(x) == 0) return(supabase_metricas_vacias())
  list(
    visitas_total = max(0, as.numeric(x$visitas_total %||% 0)),
    constancias_total = max(0, as.numeric(x$constancias_total %||% 0)),
    consultas_total = max(0, as.numeric(x$consultas_total %||% 0))
  )
}

supabase_obtener_metricas <- function() {
  .local_metricas_leer()
}

supabase_registrar_visita <- function(visitante_id = NULL) {
  m <- .local_metricas_leer()
  m$visitas_total <- m$visitas_total + 1
  .local_metricas_guardar(m)
}

supabase_registrar_constancia <- function() {
  m <- .local_metricas_leer()
  m$constancias_total <- m$constancias_total + 1
  .local_metricas_guardar(m)
}

# ------------------------------------------------------------------------------
# 4. REGISTRO LOCAL DE CONSULTAS ESPACIALES Y REPORTES CIUDADANOS
# ------------------------------------------------------------------------------

supabase_registrar_consulta <- function(tipo_consulta,
                                        coordenadas_texto,
                                        distrito,
                                        en_ambito = TRUE,
                                        zona_principal = NA_character_,
                                        area_consulta_m2 = NA_real_,
                                        resultado_resumen = list(),
                                        duracion_ms = NA_integer_,
                                        meta = list()) {
  m <- .local_metricas_leer()
  m$consultas_total <- m$consultas_total + 1
  .local_metricas_guardar(m)
  
  registro <- list(
    fecha = format(Sys.time(), "%Y-%m-%d %H:%M:%OS3"),
    tipo = tipo_consulta,
    coordenadas = coordenadas_texto,
    distrito = distrito,
    en_ambito = en_ambito,
    zona = zona_principal,
    area_m2 = area_consulta_m2,
    duracion_ms = duracion_ms
  )
  
  dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
  tryCatch({
    cat(jsonlite::toJSON(registro, auto_unbox = TRUE), "\n",
        file = file.path("outputs", "consultas_local.log"),
        append = TRUE)
  }, error = function(e) NULL)
  
  TRUE
}

supabase_obtener_avisos <- function(limite = 4) {
  data.frame()
}
