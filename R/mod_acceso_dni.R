# ==============================================================================
# MÓDULO DE CONTROL DE ACCESO CIUDADANO (ESTILO SUNARP BGR)
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# Regla: Máximo 2 periodos de 10 minutos por DNI por día.
# Cumplimiento: Ley N° 29733 (Protección de Datos Personales)
# ==============================================================================

suppressPackageStartupMessages({
  if (requireNamespace("shiny", quietly = TRUE)) library(shiny)
  if (requireNamespace("htmltools", quietly = TRUE)) library(htmltools)
})

# ------------------------------------------------------------------------------
# 1. BASE DE DATOS Y GESTIÓN DE CUOTAS LOCALES
# ------------------------------------------------------------------------------

.pdu_acceso_db_path <- function() {
  dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
  file.path("outputs", "control_acceso_sesiones.rds")
}

#' Sal criptográfica institucional fija por entorno para evitar ataques de tablas rainbow
.pdu_salt_secreto <- function() {
  salt_env <- Sys.getenv("PDU_PEPPER_KEY", "")
  if (nzchar(salt_env)) return(salt_env)
  "ANTA_PDU_GDUR_2024_2034_SECURE_SALT_v1"
}

#' Enmascara el DNI para logs y auditoría según directiva ANPD (R.D. 019-2013-JUS/DGPDP)
#' @param dni Cadena de DNI
#' @return Cadena enmascarada (ej. '47****15')
.pdu_enmascarar_dni <- function(dni) {
  d <- trimws(as.character(dni %||% ""))
  if (!nzchar(d)) return("********")
  if (nchar(d) <= 4) return("****")
  paste0(substr(d, 1, 2), paste(rep("*", max(0, nchar(d) - 4)), collapse = ""), substr(d, nchar(d) - 1, nchar(d)))
}

#' Genera un identificador seudonimizado irreversible para el DNI (Principio de Minimización - Ley 29733)
#' @param dni Cadena de 8 dígitos
#' @return Hash SHA-256 o MD5 con sal criptográfica institucional
.pdu_pseudonimizar_dni <- function(dni) {
  dni_limpio <- trimws(as.character(dni %||% ""))
  cadena <- paste0(.pdu_salt_secreto(), "_DNI_", dni_limpio)
  
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(cadena, algo = "sha256"))
  }
  if (requireNamespace("openssl", quietly = TRUE)) {
    return(as.character(openssl::sha256(cadena)))
  }
  # Fallback nativo Base R
  tf <- tempfile()
  on.exit(unlink(tf), add = TRUE)
  cat(cadena, file = tf)
  unname(tools::md5sum(tf))
}

#' Purga automática de registros antiguos para cumplir el Principio de Limitación del Plazo (Art. 6 Ley 29733 y Art. 5 RGPD)
#' @param df Data frame de sesiones
#' @param dias_retencion Número de días a conservar (por defecto 7 días de auditoría mínima)
.pdu_purgar_registros_antiguos <- function(df, dias_retencion = 7L) {
  if (is.null(df) || nrow(df) == 0) return(df)
  limite_fecha <- as.character(Sys.Date() - dias_retencion)
  df[df$fecha >= limite_fecha, , drop = FALSE]
}

pdu_acceso_leer_bd <- function(ruta_db = .pdu_acceso_db_path()) {
  df_base <- data.frame(
    id = character(),
    id_dni_hash = character(),
    fecha = character(),
    hora_inicio = character(),
    duracion_min = integer(),
    ip_origen = character(),
    stringsAsFactors = FALSE
  )
  
  if (file.exists(ruta_db)) {
    tryCatch({
      df <- readRDS(ruta_db)
      if (is.data.frame(df) && nrow(df) > 0) {
        # Migración segura: si existen columnas legacy 'dni' en texto plano, convertirlas a hash irreversible
        if ("dni" %in% names(df) && !"id_dni_hash" %in% names(df)) {
          df$id_dni_hash <- sapply(df$dni, .pdu_pseudonimizar_dni)
          df$dni <- NULL
        } else if ("dni" %in% names(df) && "id_dni_hash" %in% names(df)) {
          df$dni <- NULL
        }
        if ("hash_emision" %in% names(df)) {
          df$hash_emision <- NULL # Descartar datos no requeridos para la finalidad (Minimización)
        }
        # Aplicar política de retención temporal (purgar registros > 7 días)
        df <- .pdu_purgar_registros_antiguos(df, dias_retencion = 7L)
        return(df)
      } else if (is.data.frame(df)) {
        return(df)
      }
    }, error = function(e) NULL)
  }
  df_base
}

pdu_acceso_guardar_bd <- function(df, ruta_db = .pdu_acceso_db_path()) {
  tryCatch({
    df_limpio <- .pdu_purgar_registros_antiguos(df, dias_retencion = 7L)
    saveRDS(df_limpio, ruta_db)
    TRUE
  }, error = function(e) FALSE)
}

#' Consulta cuántas sesiones ha consumido un DNI en la fecha actual
#' @param dni Cadena de 8 dígitos
#' @return Lista con status, total_hoy, restantes y mensaje
pdu_acceso_consultar_cuota <- function(dni, ruta_db = .pdu_acceso_db_path()) {
  dni_limpio <- trimws(as.character(dni))
  if (!grepl("^[0-9]{8}$", dni_limpio)) {
    return(list(permitido = FALSE, total_hoy = 0, restantes = 0, mensaje = "DNI no válido."))
  }
  
  bd <- pdu_acceso_leer_bd(ruta_db = ruta_db)
  hoy <- as.character(Sys.Date())
  hash_dni <- .pdu_pseudonimizar_dni(dni_limpio)
  dni_mascara <- .pdu_enmascarar_dni(dni_limpio)
  
  col_busqueda <- if ("id_dni_hash" %in% names(bd)) "id_dni_hash" else if ("dni" %in% names(bd)) "dni" else NULL
  
  if (is.null(col_busqueda) || nrow(bd) == 0) {
    total <- 0L
  } else if (col_busqueda == "id_dni_hash") {
    sesiones_hoy <- bd[bd$id_dni_hash == hash_dni & bd$fecha == hoy, , drop = FALSE]
    total <- nrow(sesiones_hoy)
  } else {
    sesiones_hoy <- bd[bd$dni == dni_limpio & bd$fecha == hoy, , drop = FALSE]
    total <- nrow(sesiones_hoy)
  }
  
  restantes <- max(0L, 2L - total)
  
  if (total >= 2L) {
    list(
      permitido = FALSE,
      total_hoy = total,
      restantes = 0L,
      mensaje = paste0(
        "Estimado(a) ciudadano(a), ha alcanzado el límite diario permitido ",
        "(máximo 2 periodos de 10 minutos por día para el DNI ", dni_mascara, "). ",
        "Por equidad de acceso al servicio, podrá ingresar nuevamente mañana a partir de las 00:00 hrs."
      )
    )
  } else {
    list(
      permitido = TRUE,
      total_hoy = total,
      restantes = restantes,
      mensaje = sprintf("Acceso permitido. Le quedan %d de 2 sesiones para hoy.", restantes)
    )
  }
}

#' Registra el inicio de una nueva sesión de 10 minutos de forma seudonimizada
pdu_acceso_registrar_sesion <- function(dni, fecha_emision_str = NULL, duracion_min = 10L, ip = "local", ruta_db = .pdu_acceso_db_path()) {
  bd <- pdu_acceso_leer_bd(ruta_db = ruta_db)
  hoy <- as.character(Sys.Date())
  ahora <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  dni_limpio <- trimws(as.character(dni))
  hash_dni <- .pdu_pseudonimizar_dni(dni_limpio)
  dni_mascara <- .pdu_enmascarar_dni(dni_limpio)
  
  nuevo <- data.frame(
    id = paste0("SES-", format(Sys.time(), "%y%m%d%H%M%S-"), sample(1000:9999, 1)),
    id_dni_hash = hash_dni,
    fecha = hoy,
    hora_inicio = ahora,
    duracion_min = as.integer(duracion_min),
    ip_origen = ip,
    stringsAsFactors = FALSE
  )
  
  bd_nueva <- rbind(bd, nuevo)
  pdu_acceso_guardar_bd(bd_nueva, ruta_db = ruta_db)
  
  # Log de auditoría con enmascaramiento estricto de PII (Directiva ANPD R.D. 019-2013-JUS/DGPDP)
  tryCatch({
    cat(
      sprintf("[%s] INGRESO_VALIDADO DNI_ENMASCARADO=%s ID_SESION=%s FECHA=%s\n", 
              ahora, dni_mascara, nuevo$id, hoy),
      file = file.path("outputs", "control_acceso.log"),
      append = TRUE
    )
  }, error = function(e) NULL)
  
  nuevo$id
}

#' Genera un código de captcha de 5 caracteres
pdu_acceso_generar_captcha <- function() {
  chars <- c("2", "3", "4", "5", "6", "7", "8", "9",
             "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "M", "N",
             "P", "Q", "R", "T", "U", "V", "W", "X", "Y", "Z")
  paste0(sample(chars, 5, replace = TRUE), collapse = "")
}

# ------------------------------------------------------------------------------
# 2. MODAL DE VALIDACIÓN DE DATOS (ESTILO SUNARP)
# ------------------------------------------------------------------------------

#' Muestra el modal bloqueante de validación de identidad ciudadana
mostrar_modal_validacion_dni <- function(captcha_val, error_msg = NULL, cuota_bloqueada = FALSE, dni_previo = "") {
  showModal(modalDialog(
    size = "m",
    easyClose = FALSE,
    fade = TRUE,
    footer = NULL,
    
    div(
      class = "pdu-validar-datos-wrap p-2 p-md-3",
      
      # Cabecera institucional
      div(
        class = "text-center mb-3",
        div(
          class = "d-flex align-items-center justify-content-center gap-2 mb-1",
          tags$img(src = "escudo_muni_anta.png", height = "46px", alt = "Escudo Anta", onerror = "this.style.display='none'"),
          div(
            class = "text-start",
            div(class = "fw-bold text-dark fs-5 text-uppercase", style = "letter-spacing: 0.5px;", "Municipalidad Provincial de Anta"),
            div(class = "text-muted small", "Gerencia de Desarrollo Urbano y Rural · GeoVisor PDU (2024 - 2034)")
          )
        ),
        
        # Título estilo SUNARP con barra multicolor
        div(
          class = "mt-3 position-relative",
          tags$h3(class = "fw-bold text-dark mb-1", style = "letter-spacing: -0.5px;", "Validar datos"),
          div(
            class = "sunarp-multibar mx-auto mb-2",
            style = "height: 4px; width: 140px; border-radius: 2px; background: linear-gradient(to right, #00A896 25%, #028090 25% 50%, #F4A261 50% 75%, #E63946 75%);"
          ),
          div(
            class = "pdu-stepper-container d-inline-flex align-items-center gap-2 px-3 py-1 rounded-pill bg-light border mb-2",
            tags$a(
              href = "#",
              class = "badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2 py-1 text-decoration-none",
              onclick = "Shiny.setInputValue('abrir_modal_privacidad_desde_login', Math.random()); return false;",
              icon("circle-check"), " Paso 1: Términos Aceptados (Ver)"
            ),
            icon("chevron-right", class = "text-muted small"),
            span(class = "badge bg-success rounded-pill px-2 py-1 text-white shadow-xs", icon("id-card"), " Paso 2 de 2: Validación con DNI")
          )
        )
      ),
      
      # Mensaje de error o bloqueo de cuota si corresponde
      if (!is.null(error_msg)) {
        div(
          class = if (cuota_bloqueada) "alert alert-danger py-2 px-3 mb-3 d-flex align-items-center gap-2" else "alert alert-warning py-2 px-3 mb-3 d-flex align-items-center gap-2",
          icon(if (cuota_bloqueada) "ban" else "circle-exclamation"),
          tags$span(class = "small fw-semibold", error_msg)
        )
      },
      
      # Cuerpo del Formulario Centrado (sin ilustraciones de DNI)
      div(
        class = "mx-auto px-1 px-sm-2",
        style = "max-width: 440px;",
        
        # Campo: DNI
        div(
          class = "mb-3",
          tags$label(class = "form-label fw-bold text-dark small mb-1", tags$span(class = "text-danger", "* "), "Número de DNI"),
          div(
            class = "input-group",
            tags$span(class = "input-group-text bg-white text-muted border-end-0", icon("id-card")),
            tags$input(
              id = "in_valida_dni",
              type = "text",
              class = "form-control border-start-0",
              placeholder = "DNI (8 dígitos)",
              maxlength = "8",
              value = dni_previo,
              inputmode = "numeric",
              oninput = "this.value = this.value.replace(/[^0-9]/g, '');"
            )
          )
        ),
        
        # Campo: Fecha de Emisión
        div(
          class = "mb-3",
          tags$label(class = "form-label fw-bold text-dark small mb-1", tags$span(class = "text-danger", "* "), "Fecha de emisión (dd/mm/aaaa)"),
          div(
            class = "input-group",
            tags$span(class = "input-group-text bg-white text-muted border-end-0", icon("calendar-days")),
            tags$input(
              id = "in_valida_fecha_emision",
              type = "text",
              class = "form-control border-start-0",
              placeholder = "dd/mm/aaaa",
              maxlength = "10"
            )
          ),
          tags$span(class = "text-muted", style = "font-size: 11px;", "Ingrese en formato día/mes/año (ejemplo: 15/08/2021)")
        ),
        
        # Campo: Captcha de seguridad
        div(
          class = "mb-3",
          tags$label(class = "form-label fw-bold text-dark small mb-1", tags$span(class = "text-danger", "* "), "Código de seguridad"),
          div(
            class = "d-flex gap-2 align-items-center mb-1",
            # Caja de captcha con estilo visual
            div(
              class = "captcha-box px-3 py-2 rounded-2 text-center user-select-none",
              style = "background: #212529; color: #48CAE4; font-family: 'Courier New', monospace; font-size: 20px; font-weight: bold; letter-spacing: 6px; text-decoration: line-through; border: 1px solid #495057;",
              captcha_val
            ),
            # Botón refrescar
            actionButton(
              "btn_refrescar_captcha",
              label = NULL,
              icon = icon("rotate"),
              class = "btn btn-outline-secondary",
              title = "Generar nuevo código"
            ),
            # Input para escribir captcha
            tags$input(
              id = "in_valida_captcha",
              type = "text",
              class = "form-control text-uppercase text-center fw-bold",
              placeholder = "Código",
              maxlength = "5",
              style = "max-width: 110px; letter-spacing: 2px;"
            )
          )
        ),
        
        # Botón Validar (Estilo SUNARP)
        div(
          class = "d-grid gap-2 mt-4",
          tags$button(
            id = "btn_validar_acceso",
            type = "button",
            class = "btn btn-lg fw-bold text-white shadow-sm action-button",
            style = "background-color: #174A3A; border-color: #0E3529; border-radius: 8px;",
            icon("check"), " Validar e Ingresar"
          )
        ),
        
        # Aviso legal de aceptación y términos
        div(
          class = "mt-3 text-muted text-center",
          style = "font-size: 11.5px; line-height: 1.4;",
          "Al continuar con el uso del servicio usted está aceptando que conoce y está de acuerdo con los ",
          tags$a(
            href = "#",
            class = "text-decoration-underline text-success fw-bold",
            onclick = "Shiny.setInputValue('abrir_modal_privacidad_desde_login', Math.random()); return false;",
            "Términos y condiciones"
          ),
          " del servicio gratuito del GeoVisor PDU Anta (Ley N° 29733)."
        )
      ),
      
      # Pie de soporte institucional
      div(
        class = "mt-4 pt-3 border-top text-center text-muted",
        style = "font-size: 11.5px;",
        div("Gerencia de Desarrollo Urbano y Rural — Municipalidad Provincial de Anta"),
        div("Consultas técnicas: ", tags$b("gdur@munidistritoanta.gob.pe"), " · Plaza de Armas s/n, Anta, Cusco")
      )
    )
  ))
}

#' Muestra el modal de expiración de sesión (10 minutos concluidos)
mostrar_modal_sesion_expirada <- function(dni) {
  cuota <- pdu_acceso_consultar_cuota(dni)
  showModal(modalDialog(
    title = div(
      class = "text-center w-100",
      icon("hourglass-end", class = "text-warning fs-1 mb-2"),
      tags$h4(class = "fw-bold text-dark mb-0", "Tiempo de consulta finalizado")
    ),
    size = "m",
    easyClose = FALSE,
    footer = div(
      class = "w-100 text-center",
      if (cuota$permitido) {
        actionButton(
          "btn_reingresar_sesion",
          label = "Iniciar Nueva Consulta (1 restante hoy)",
          icon = icon("arrow-rotate-right"),
          class = "btn btn-success fw-bold px-4 py-2"
        )
      } else {
        tags$button(
          type = "button",
          class = "btn btn-secondary px-4 py-2",
          onclick = "window.location.reload();",
          icon("door-closed"), " Cerrar Visor"
        )
      }
    ),
    div(
      class = "text-center p-2",
      tags$p(
        class = "mb-2",
        "Su periodo de consulta de ", tags$b("10 minutos"), " ha concluido conforme a las políticas de acceso equitativo del GeoVisor PDU Anta."
      ),
      if (cuota$permitido) {
        div(
          class = "alert alert-info py-2 px-3 small",
          icon("info-circle"), " Aún le queda ", tags$b(sprintf("%d sesión de 10 minutos", cuota$restantes)), " para el día de hoy."
        )
      } else {
        div(
          class = "alert alert-warning py-2 px-3 small",
          icon("triangle-exclamation"), " Ha alcanzado el límite diario permitido (2 sesiones por día). Podrá realizar nuevas consultas mañana a partir de las 00:00 horas."
        )
      }
    )
  ))
}

# ------------------------------------------------------------------------------
# 4. COMPONENTE UI DEL TEMPORIZADOR EN NAVBAR
# ------------------------------------------------------------------------------

#' Renderiza la insignia del reloj en la barra de navegación
ui_temporizador_sesion <- function(id = "ui_temporizador_sesion") {
  uiOutput(id, inline = TRUE)
}

# ------------------------------------------------------------------------------
# 5. MÓDULO SERVIDOR DE ACCESO Y CONTROL TEMPORAL
# ------------------------------------------------------------------------------

mod_acceso_dni_server <- function(id = "acceso", input, output, session, on_login_success = NULL) {
  ns <- session$ns
  
  # Estados reactivos de sesión
  sesion_activa <- reactiveVal(FALSE)
  dni_actual <- reactiveVal("")
  segundos_restantes <- reactiveVal(600L) # 10 minutos = 600 segundos
  captcha_actual <- reactiveVal(pdu_acceso_generar_captcha())
  
  # Control de tasa de intentos y protección anti-fuerza bruta (OWASP / NIST SP 800-63B)
  intentos_fallidos <- reactiveVal(0L)
  bloqueado_hasta <- reactiveVal(Sys.time() - 1)
  
  # 1. Al iniciar la app, desplegar primero el Aviso Legal y Términos de Uso (Paso 1)
  # Se usa isolate() porque session$onFlushed se ejecuta fuera del contexto reactivo
  session$onFlushed(function() {
    mostrar_modal_privacidad(es_inicio = TRUE)
  }, once = TRUE)
  
  # 2. Cuando el usuario acepta los términos y condiciones, proceder a la Validación de DNI (Paso 2)
  observeEvent(input$proceder_a_validacion_dni, {
    mostrar_modal_validacion_dni(
      captcha_val = isolate(captcha_actual()),
      dni_previo = isolate(input$in_valida_dni %||% "")
    )
  })
  
  # 3. Si el usuario desea releer los términos desde el modal de DNI (clic en Paso 1 o enlace inferior)
  observeEvent(input$abrir_modal_privacidad_desde_login, {
    mostrar_modal_privacidad(es_inicio = TRUE)
  })
  
  # Evento: Refrescar Captcha
  observeEvent(input$btn_refrescar_captcha, {
    nuevo_c <- pdu_acceso_generar_captcha()
    captcha_actual(nuevo_c)
    mostrar_modal_validacion_dni(captcha_val = nuevo_c, dni_previo = input$in_valida_dni %||% "")
  })
  
  # Si el usuario abrió el modal de términos y privacidad desde el login y vuelve, restaurar el modal de DNI
  observeEvent(input$cerrar_modal_privacidad, {
    if (!isTRUE(isolate(sesion_activa()))) {
      mostrar_modal_validacion_dni(
        captcha_val = isolate(captcha_actual()),
        dni_previo = isolate(input$in_valida_dni %||% "")
      )
    }
  })
  
  # Evento: Validar Credenciales (DNI + Fecha Emisión + Captcha)
  observeEvent(input$btn_validar_acceso, {
    dni_in <- trimws(as.character(input$in_valida_dni %||% ""))
    fecha_in <- trimws(as.character(input$in_valida_fecha_emision %||% ""))
    captcha_in <- toupper(trimws(as.character(input$in_valida_captcha %||% "")))
    
    # 0. Verificar si la sesión está en enfriamiento por intentos fallidos
    ahora_t <- Sys.time()
    if (ahora_t < bloqueado_hasta()) {
      seg_restantes <- ceiling(as.numeric(difftime(bloqueado_hasta(), ahora_t, units = "secs")))
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(
        captcha_val = nuevo_c,
        error_msg = sprintf("Por motivos de seguridad ante múltiples intentos fallidos, el acceso está pausado temporalmente. Reintente en %d segundos.", seg_restantes),
        dni_previo = dni_in
      )
      return()
    }
    
    manejar_error <- function(msg, cuota_bloqueada = FALSE) {
      nuevos_intentos <- intentos_fallidos() + 1L
      intentos_fallidos(nuevos_intentos)
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      
      if (nuevos_intentos >= 5L && !cuota_bloqueada) {
        bloqueado_hasta(Sys.time() + 30) # Enfriamiento de 30 segundos
        intentos_fallidos(0L)
        mostrar_modal_validacion_dni(
          captcha_val = nuevo_c,
          error_msg = "Superó el límite de intentos consecutivos erróneos (5). Por seguridad institucional, espere 30 segundos antes de volver a intentar.",
          dni_previo = dni_in
        )
      } else {
        mostrar_modal_validacion_dni(
          captcha_val = nuevo_c,
          error_msg = msg,
          cuota_bloqueada = cuota_bloqueada,
          dni_previo = dni_in
        )
      }
    }
    
    # 1. Validar Captcha
    if (!nzchar(captcha_in) || captcha_in != captcha_actual()) {
      manejar_error("Código de seguridad incorrecto. Ingrese los caracteres mostrados en el recuadro.")
      return()
    }
    
    # 2. Validar DNI (exactamente 8 dígitos)
    if (!grepl("^[0-9]{8}$", dni_in)) {
      manejar_error("El número de DNI debe contener exactamente 8 dígitos numéricos.")
      return()
    }
    
    # 3. Validar Fecha de Emisión (formato dd/mm/aaaa)
    fecha_limpia <- gsub("[^0-9/\\-]", "", fecha_in)
    partes <- strsplit(fecha_limpia, "[/\\-]")[[1]]
    fecha_valida <- FALSE
    
    if (length(partes) == 3) {
      d <- as.integer(partes[1])
      m <- as.integer(partes[2])
      y <- as.integer(partes[3])
      if (!is.na(d) && !is.na(m) && !is.na(y)) {
        if (d >= 1 && d <= 31 && m >= 1 && m <= 12 && y >= 1990 && y <= as.integer(format(Sys.Date(), "%Y"))) {
          fecha_valida <- TRUE
        }
      }
    }
    
    if (!fecha_valida) {
      manejar_error("Fecha de emisión no válida. Ingrese una fecha en formato dd/mm/aaaa (ejemplo: 12/04/2021).")
      return()
    }
    
    # 4. Validar Cuota Diaria (Máximo 2 sesiones de 10 min por día)
    cuota <- pdu_acceso_consultar_cuota(dni_in)
    if (!cuota$permitido) {
      manejar_error(cuota$mensaje, cuota_bloqueada = TRUE)
      return()
    }
    
    # REGISTRO EXITOSO: Resetear intentos fallidos, guardar sesión y activar temporizador
    intentos_fallidos(0L)
    pdu_acceso_registrar_sesion(dni = dni_in, fecha_emision_str = fecha_in, duracion_min = 10L)
    dni_actual(dni_in)
    segundos_restantes(600L) # Reiniciar a 10 minutos (600s)
    sesion_activa(TRUE)
    
    # Cerrar modal de validación y desbloquear cortina del visor
    removeModal()
    session$sendCustomMessage("pdu_desbloquear_visor", list())
    
    # Notificación de bienvenida informando tiempo
    showNotification(
      tags$div(
        icon("clock"), tags$b(" Sesión iniciada: "),
        sprintf("Dispone de 10 minutos para sus consultas. (Sesión %d de 2 hoy)", 3L - cuota$restantes)
      ),
      type = "message",
      duration = 8
    )
    
    if (is.function(on_login_success)) {
      on_login_success(dni_in)
    }
  })
  
  # Si no hay callback externo (uso autónomo del módulo), gestionar reloj y renderUI internamente.
  # Cuando se provee on_login_success, la app principal administra el temporizador y desconexión activa.
  if (is.null(on_login_success)) {
    # Reloj reactivo: decrementa cada 1 segundo si la sesión está activa
    observe({
      if (!sesion_activa()) return()
      invalidateLater(1000, session)
      
      isolate({
        actual <- segundos_restantes()
        if (actual > 1L) {
          segundos_restantes(actual - 1L)
          
          # Alerta preventiva a los 2 minutos (120 segundos)
          if (actual - 1L == 120L) {
            showNotification(
              tags$div(
                icon("triangle-exclamation"), tags$b(" Atención: "),
                "Le restan 2 minutos para concluir su tiempo de consulta."
              ),
              type = "warning",
              duration = 6
            )
          }
        } else {
          # Tiempo agotado (0 segundos)
          segundos_restantes(0L)
          sesion_activa(FALSE)
          mostrar_modal_sesion_expirada(dni_actual())
        }
      })
    })
    
    # Reingreso tras sesión expirada (si aún tiene saldo diario)
    observeEvent(input$btn_reingresar_sesion, {
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(captcha_val = nuevo_c, dni_previo = isolate(dni_actual()))
    })
    
    # Renderizar temporizador en el navbar
    output$ui_temporizador_sesion <- renderUI({
      if (!sesion_activa()) return(NULL)
      
      seg <- segundos_restantes()
      minutos <- seg %/% 60L
      segundos <- seg %% 60L
      tiempo_fmt <- sprintf("%02d:%02d", minutos, segundos)
      
      clase_badge <- if (seg <= 120L) "bg-danger animate-pulse" else if (seg <= 300L) "bg-warning text-dark" else "bg-success"
      
      tags$div(
        class = "d-inline-flex align-items-center gap-1 mx-2",
        tags$span(
          class = paste("badge d-flex align-items-center gap-1 px-2 py-1 fs-6 shadow-sm", clase_badge),
          style = "border-radius: 6px; font-variant-numeric: tabular-nums;",
          icon("clock"),
          tags$span(class = "fw-bold", tiempo_fmt),
          tags$span(class = "small opacity-75 d-none d-lg-inline", "(Límite 10 min)")
        )
      )
    })
  }
  
  list(
    sesion_activa = sesion_activa,
    dni_actual = dni_actual,
    segundos_restantes = segundos_restantes
  )
}
