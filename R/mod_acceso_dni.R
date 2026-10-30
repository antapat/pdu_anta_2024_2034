# ==============================================================================
# MÓDULO DE CONTROL DE ACCESO CIUDADANO (ESTILO SUNARP BGR)
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# Regla: Máximo 2 periodos de 10 minutos por DNI por día.
# Cumplimiento: Ley N° 29733 (Protección de Datos Personales)
# ==============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(htmltools)
})

# ------------------------------------------------------------------------------
# 1. BASE DE DATOS Y GESTIÓN DE CUOTAS LOCALES
# ------------------------------------------------------------------------------

.pdu_acceso_db_path <- function() {
  dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
  file.path("outputs", "control_acceso_sesiones.rds")
}

pdu_acceso_leer_bd <- function(ruta_db = .pdu_acceso_db_path()) {
  if (file.exists(ruta_db)) {
    tryCatch({
      df <- readRDS(ruta_db)
      if (is.data.frame(df)) return(df)
    }, error = function(e) NULL)
  }
  data.frame(
    id = character(),
    dni = character(),
    fecha = character(),
    hora_inicio = character(),
    duracion_min = integer(),
    hash_emision = character(),
    ip_origen = character(),
    stringsAsFactors = FALSE
  )
}

pdu_acceso_guardar_bd <- function(df, ruta_db = .pdu_acceso_db_path()) {
  tryCatch({
    saveRDS(df, ruta_db)
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
  
  sesiones_hoy <- bd[bd$dni == dni_limpio & bd$fecha == hoy, , drop = FALSE]
  total <- nrow(sesiones_hoy)
  restantes <- max(0L, 2L - total)
  
  if (total >= 2L) {
    list(
      permitido = FALSE,
      total_hoy = total,
      restantes = 0L,
      mensaje = paste0(
        "Estimado(a) ciudadano(a), ha alcanzado el límite diario permitido ",
        "(máximo 2 periodos de 10 minutos por día para el DNI ", dni_limpio, "). ",
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

#' Registra el inicio de una nueva sesión de 10 minutos
pdu_acceso_registrar_sesion <- function(dni, fecha_emision_str, duracion_min = 10L, ip = "local", ruta_db = .pdu_acceso_db_path()) {
  bd <- pdu_acceso_leer_bd(ruta_db = ruta_db)
  hoy <- as.character(Sys.Date())
  ahora <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  
  # Hasheamos la fecha de emisión para no almacenar datos sensibles en texto plano (Ley 29733)
  hash_emision <- if (requireNamespace("digest", quietly = TRUE)) {
    digest::digest(paste0("anta_", dni, "_", fecha_emision_str), algo = "sha256")
  } else {
    paste0("h_", nchar(fecha_emision_str))
  }
  
  nuevo <- data.frame(
    id = paste0("SES-", format(Sys.time(), "%y%m%d%H%M%S-"), sample(1000:9999, 1)),
    dni = trimws(as.character(dni)),
    fecha = hoy,
    hora_inicio = ahora,
    duracion_min = as.integer(duracion_min),
    hash_emision = hash_emision,
    ip_origen = ip,
    stringsAsFactors = FALSE
  )
  
  bd_nueva <- rbind(bd, nuevo)
  pdu_acceso_guardar_bd(bd_nueva, ruta_db = ruta_db)
  
  # Log de auditoría
  tryCatch({
    cat(
      sprintf("[%s] INGRESO_VALIDADO DNI=%s SESION=%s FECHA=%s\n", ahora, nuevo$dni, nuevo$id, hoy),
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
# 2. COMPONENTES VISUALES: ILUSTRACIONES DNI AZUL Y DNI ELECTRÓNICO
# ------------------------------------------------------------------------------

.render_ilustracion_dnis <- function() {
  div(
    class = "d-flex flex-column gap-3 w-100",
    
    # 1. Tarjeta DNI Azul
    div(
      class = "dni-card-guide dni-azul-box p-2 rounded-3 border shadow-sm position-relative",
      style = "background: linear-gradient(135deg, #74C0C0 0%, #52A7A7 100%); color: #073B3A; font-family: Arial, sans-serif; height: 135px; overflow: hidden;",
      div(
        class = "d-flex justify-content-between align-items-start border-bottom pb-1 mb-1",
        div(
          div(style = "font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px; line-height: 1;", "REPÚBLICA DEL PERÚ"),
          div(style = "font-size: 7px; font-weight: 600; opacity: 0.9; line-height: 1;", "DOCUMENTO NACIONAL DE IDENTIDAD")
        ),
        div(
          class = "dni-num-highlight",
          style = "font-size: 8px; font-weight: bold; border: 1.5px dashed #D90429; padding: 1px 4px; border-radius: 8px; background: rgba(255,255,255,0.7);",
          "DNI (XXXXXXXX)-X"
        )
      ),
      div(
        class = "d-flex gap-2 align-items-center mt-1",
        # Foto placeholder
        div(
          class = "bg-light rounded-1 d-flex align-items-center justify-content-center",
          style = "width: 40px; height: 50px; border: 1px solid rgba(0,0,0,0.15);",
          icon("user", class = "text-secondary", style = "font-size: 22px;")
        ),
        # Datos simulados y óvalo de fecha de emisión
        div(
          class = "flex-grow-1",
          div(style = "height: 4px; background: rgba(255,255,255,0.7); border-radius: 2px; width: 85%; margin-bottom: 5px;"),
          div(style = "height: 4px; background: rgba(255,255,255,0.7); border-radius: 2px; width: 65%; margin-bottom: 5px;"),
          div(
            class = "text-end mt-1",
            div(
              style = "display: inline-block; border: 2px solid #D90429; background: rgba(255,255,255,0.9); border-radius: 12px; padding: 2px 6px; text-align: center;",
              div(style = "font-size: 7.5px; font-weight: 900; color: #D90429; line-height: 1;", "Fecha de"),
              div(style = "font-size: 7.5px; font-weight: 900; color: #D90429; line-height: 1;", "emisión")
            )
          )
        )
      ),
      # Chevrons inferiores
      div(
        style = "font-size: 7px; letter-spacing: 2px; opacity: 0.6; font-family: monospace; position: absolute; bottom: 3px; left: 8px;",
        "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
      )
    ),
    
    # 2. Tarjeta DNI Electrónico (DNIe)
    div(
      class = "dni-card-guide dni-elec-box p-2 rounded-3 border shadow-sm position-relative",
      style = "background: linear-gradient(135deg, #F8F9FA 0%, #E9ECEF 100%); color: #212529; font-family: Arial, sans-serif; height: 135px; overflow: hidden; border: 1px solid #CED4DA !important;",
      div(
        class = "d-flex justify-content-between align-items-start border-bottom pb-1 mb-1",
        div(
          div(style = "font-size: 8.5px; font-weight: 800; letter-spacing: 0.5px; line-height: 1;", "REPÚBLICA DEL PERÚ"),
          div(style = "font-size: 7px; font-weight: 600; color: #495057; line-height: 1;", "DOCUMENTO NACIONAL DE IDENTIDAD DNIe")
        ),
        div(
          style = "font-size: 8px; font-weight: bold; border: 1.5px dashed #D90429; padding: 1px 4px; border-radius: 8px; background: #FFF;",
          "XXXXXXXX-X"
        )
      ),
      div(
        class = "d-flex gap-2 align-items-center mt-1",
        # Chip dorado inteligente
        div(
          style = "width: 32px; height: 26px; background: linear-gradient(135deg, #FFD166 0%, #F4A261 100%); border-radius: 4px; border: 1px solid #D4A373; display: flex; align-items: center; justify-content: center;",
          icon("microchip", style = "font-size: 14px; color: #78350F;")
        ),
        # Óvalo de Fecha de emisión al centro
        div(
          class = "flex-grow-1 text-center",
          div(
            style = "display: inline-block; border: 2px solid #D90429; background: #FFF; border-radius: 12px; padding: 2px 7px; text-align: center;",
            div(style = "font-size: 7.5px; font-weight: 900; color: #D90429; line-height: 1;", "Fecha de"),
            div(style = "font-size: 7.5px; font-weight: 900; color: #D90429; line-height: 1;", "emisión")
          )
        ),
        # Foto placeholder a la derecha
        div(
          class = "bg-white rounded-1 d-flex align-items-center justify-content-center",
          style = "width: 38px; height: 48px; border: 1px solid #CED4DA;",
          icon("user", class = "text-muted", style = "font-size: 20px;")
        )
      ),
      div(
        style = "font-size: 7px; letter-spacing: 2px; opacity: 0.5; font-family: monospace; position: absolute; bottom: 3px; left: 8px;",
        "IDPER12345678<<<<<<<<<<<<<<<<<<<<"
      )
    )
  )
}

# ------------------------------------------------------------------------------
# 3. MODAL DE VALIDACIÓN DE DATOS (ESTILO SUNARP)
# ------------------------------------------------------------------------------

#' Muestra el modal bloqueante de validación de identidad ciudadana
mostrar_modal_validacion_dni <- function(captcha_val, error_msg = NULL, cuota_bloqueada = FALSE, dni_previo = "") {
  showModal(modalDialog(
    size = "l",
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
            class = "sunarp-multibar mx-auto mb-3",
            style = "height: 4px; width: 140px; border-radius: 2px; background: linear-gradient(to right, #00A896 25%, #028090 25% 50%, #F4A261 50% 75%, #E63946 75%);"
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
      
      # Cuerpo en dos columnas (Formulario a la izquierda, Ayuda DNI a la derecha)
      div(
        class = "row g-4 align-items-center",
        
        # Columna Izquierda: Formulario
        div(
          class = "col-12 col-md-6 border-end-md pe-md-4",
          
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
              onclick = "Shiny.setInputValue('abrir_modal_privacidad', Math.random()); return false;",
              "Términos y condiciones"
            ),
            " del servicio gratuito del GeoVisor PDU Anta (Ley N° 29733)."
          )
        ),
        
        # Columna Derecha: Ilustración de ayuda visual de DNI
        div(
          class = "col-12 col-md-6 ps-md-4",
          div(class = "text-muted small fw-bold mb-2 text-center text-md-start", "Guía para ubicar su Fecha de Emisión:"),
          .render_ilustracion_dnis()
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
  
  # Mostrar el modal de bienvenida y validación de DNI al abrir la app
  session$onFlushed(function() {
    mostrar_modal_validacion_dni(captcha_val = captcha_actual())
  }, once = TRUE)
  
  # Evento: Refrescar Captcha
  observeEvent(input$btn_refrescar_captcha, {
    nuevo_c <- pdu_acceso_generar_captcha()
    captcha_actual(nuevo_c)
    mostrar_modal_validacion_dni(captcha_val = nuevo_c, dni_previo = input$in_valida_dni %||% "")
  })
  
  # Evento: Validar Credenciales (DNI + Fecha Emisión + Captcha)
  observeEvent(input$btn_validar_acceso, {
    dni_in <- trimws(as.character(input$in_valida_dni %||% ""))
    fecha_in <- trimws(as.character(input$in_valida_fecha_emision %||% ""))
    captcha_in <- toupper(trimws(as.character(input$in_valida_captcha %||% "")))
    
    # 1. Validar Captcha
    if (!nzchar(captcha_in) || captcha_in != captcha_actual()) {
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(
        captcha_val = nuevo_c,
        error_msg = "Código de seguridad incorrecto. Ingrese los caracteres mostrados en el recuadro.",
        dni_previo = dni_in
      )
      return()
    }
    
    # 2. Validar DNI (exactamente 8 dígitos)
    if (!grepl("^[0-9]{8}$", dni_in)) {
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(
        captcha_val = nuevo_c,
        error_msg = "El número de DNI debe contener exactamente 8 dígitos numéricos.",
        dni_previo = dni_in
      )
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
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(
        captcha_val = nuevo_c,
        error_msg = "Fecha de emisión no válida. Ingrese una fecha en formato dd/mm/aaaa (ejemplo: 12/04/2021).",
        dni_previo = dni_in
      )
      return()
    }
    
    # 4. Validar Cuota Diaria (Máximo 2 sesiones de 10 min por día)
    cuota <- pdu_acceso_consultar_cuota(dni_in)
    if (!cuota$permitido) {
      nuevo_c <- pdu_acceso_generar_captcha()
      captcha_actual(nuevo_c)
      mostrar_modal_validacion_dni(
        captcha_val = nuevo_c,
        error_msg = cuota$mensaje,
        cuota_bloqueada = TRUE,
        dni_previo = dni_in
      )
      return()
    }
    
    # REGISTRO EXITOSO: Guardar sesión y activar temporizador
    pdu_acceso_registrar_sesion(dni = dni_in, fecha_emision_str = fecha_in, duracion_min = 10L)
    dni_actual(dni_in)
    segundos_restantes(600L) # Reiniciar a 10 minutos (600s)
    sesion_activa(TRUE)
    
    # Cerrar modal de validación
    removeModal()
    
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
    mostrar_modal_validacion_dni(captcha_val = nuevo_c, dni_previo = dni_actual())
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
  
  list(
    sesion_activa = sesion_activa,
    dni_actual = dni_actual,
    segundos_restantes = segundos_restantes
  )
}
