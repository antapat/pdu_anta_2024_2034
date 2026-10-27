# ==============================================================================
# MÓDULO: AVISO LEGAL, TÉRMINOS DE USO Y POLÍTICA DE PRIVACIDAD
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# Cumplimiento: Ley N° 29733 (Datos Personales), RATDUS (D.S. 012-2022)
# ==============================================================================

#' Construye y muestra la ventana modal del Aviso Legal y Privacidad
#' @param es_inicio Lógico. Si es TRUE, el modal actúa como bienvenida bloqueante.
mostrar_modal_privacidad <- function(es_inicio = FALSE) {
  showModal(modalDialog(
    title = div(
      class = "w-100 text-center py-1",
      div(
        class = "d-flex align-items-center justify-content-center gap-2 text-dark",
        icon("shield-halved", class = "text-success fs-3"),
        tags$span(class = "fw-bold fs-5", "Aviso Legal, Términos de Uso y Política de Privacidad")
      ),
      tags$div(
        class = "text-muted small mt-1",
        "Plan de Desarrollo Urbano de Anta (2024 - 2034) — GDUR Municipalidad Provincial de Anta"
      )
    ),
    size = "l",
    easyClose = !es_inicio, # Al iniciar la app es modal de ingreso bloqueante
    fade = TRUE,
    footer = tagList(
      div(
        class = "d-flex justify-content-center align-items-center w-100 py-1",
        tags$button(
          type = "button",
          class = "btn-consent-action btn-consent-accept px-4 py-2",
          style = "background-color: #174A3A !important; color: #FFFFFF !important; font-weight: 700 !important; border: 2px solid #0E3529 !important; border-radius: 8px;",
          onclick = "aceptarConsentimientoPDU();",
          icon("circle-check"), " Aceptar y Entrar al GeoVisor"
        )
      )
    ),

    div(
      class = "privacy-modal-body p-2",
      style = "text-align: justify;",

      # Alerta de Carácter Informativo y Legal
      div(
        class = "p-3 mb-3 rounded-2 border",
        style = "background-color: #FEF3C7; border-color: #F59E0B !important; color: #92400E;",
        div(class = "fw-bold small d-flex align-items-center gap-2", icon("triangle-exclamation"), "Aviso Legal y Carácter Informativo:"),
        tags$p(class = "small mb-0 mt-1",
          "La información cartográfica, zonificación, secciones viales y parámetros contenidos en esta plataforma son de carácter ", tags$b("exclusivamente informativo y referencial"), ". ",
          "No constituye certificado oficial ni genera derechos urbanísticos o de edificación. ",
          "Cualquier trámite formal de habilitación urbana o licencias de edificación debe tramitarse ante la ",
          tags$b("Gerencia de Desarrollo Urbano y Rural (GDUR)"), " de la Municipalidad Provincial de Anta."
        )
      ),

      div(
        class = "alert alert-success border-0 py-2 px-3 mb-3 d-flex align-items-center gap-2",
        icon("certificate"),
        tags$span(class = "small", tags$b("Marco Normativo: "), "Ley N° 29733 (Ley de Protección de Datos Personales del Perú), D.S. 003-2013-JUS, Ley N° 27972 (Ley Orgánica de Municipalidades), D.S. N° 012-2022-VIVIENDA (RATPUDUS) y D.Leg. N° 1674.")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("landmark"), " 1. Entidad Responsable y Titularidad"),
     # tags$p(class = "small text-secondary mb-3",
     #    "Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR). ",
     #   "[Municipalidad Provincial de Anta](https://www.gob.pe/munianta)"
     #  ),
     tags$p(
       class = "small text-secondary mb-3",
       "Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR). ",
       tags$a(
         href = "https://www.gob.pe/munianta",
         "Municipalidad Provincial de Anta",
         target = "_blank",
         rel = "noopener noreferrer"
       )
     ),

      tags$h6(class = "fw-bold text-success mb-1", icon("database"), " 2. Finalidad del Tratamiento de Información y Cartografía Oficial"),
      tags$p(class = "small text-secondary mb-3",
        "La plataforma tiene fines estrictamente públicos, informativos y de transparencia en el marco de la vigencia del Plan de Desarrollo Urbano de Anta (2024 - 2034) aprobado formalmente mediante Ordenanza Municipal Nº 04-2025-A-MPA/C el 11 de abril de 2025 y actualizado mediante Ordenanza Municipal N° 008-2026-A-MPA-C el 04 de septiembre del 2026. ",
        "La información cartográfica, zonificación y secciones viales se ponen a disposición de la ciudadanía en ejercicio de las funciones normadas por la Ley Orgánica de Municipalidades (Ley N° 27972) y el D.S. N° 012-2022-VIVIENDA (RATPUDUS)."
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("user-shield"), " 3. Principio de Minimización y Anonimización Técnica (Ley N° 29733)"),
      tags$ul(class = "small text-secondary mb-3",
        tags$li(tags$b("Sin Dirección IP: "), "El servidor y la infraestructura de base de datos institucional NO almacenan direcciones IP ni identificadores de red de los visitantes."),
        tags$li(tags$b("Sin Cookies Comerciales ni Terceros: "), "No se emplean cookies de seguimiento comercial, publicitario o de redes sociales (sin Google Analytics, Meta Pixel ni rastreadores externos)."),
        tags$li(tags$b("Telemetría con Hash Criptográfico: "), "Al aceptar el ingreso, se genera un identificador aleatorio de sesión disociado con el único propósito de cuantificar visitas agregadas por día con fines estadísticos y de transparencia municipal."),
        tags$li(tags$b("Consultas de Predios Seguras: "), "Los puntos geográficos o polígonos consultados por los ciudadanos se procesan en memoria volátil de sesión y se descartan al cerrar la consulta; no se vinculan a la identidad personal del usuario.")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("location-dot"), " 4. Función de Geolocalización (GPS Móvil)"),
      tags$p(class = "small text-secondary mb-3",
        "La geolocalización es estrictamente voluntaria y bajo demanda (Opt-In). La función solo se activa cuando el ciudadano presiona manualmente el botón de GPS en la interfaz, requiriendo la autorización nativa del navegador. Las coordenadas recibidas se usan únicamente para situar el marcador temporal en el mapa y nunca son registradas."
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("sliders"), " 5. Control de Consentimiento y Acceso"),
      tags$p(class = "small text-secondary mb-0",
        "Para ingresar a los paneles del GeoVisor, presione de forma obligatoria el botón ", tags$b("«Aceptar y Entrar al GeoVisor»"), ". La plataforma garantiza el acceso pleno a la cartografía, zonificación e instrumentos normativos del PDU Anta 2024 - 2034."
      )
    )
  ))
}

#' Elemento UI para el menú desplegable que enlaza al modal de privacidad
mod_privacidad_link_ui <- function() {
  nav_item(
    tags$a(
      href = "#",
      class = "dropdown-item",
      onclick = "reabrirModalPrivacidad(); return false;",
      icon("shield-halved"), " Política de Privacidad y Términos de Uso"
    )
  )
}

#' Lógica de servidor para el control del modal de privacidad
#' @param input Objeto input de Shiny
#' @param output Objeto output de Shiny
#' @param session Objeto session de Shiny
mod_privacidad_server <- function(input, output, session) {
  # Apertura obligatoria al iniciar la aplicación
  session$onFlushed(function() {
    mostrar_modal_privacidad(es_inicio = TRUE)
  }, once = TRUE)

  # Apertura bajo demanda desde menú o botones de la app
  observeEvent(input$abrir_modal_privacidad, {
    mostrar_modal_privacidad(es_inicio = FALSE)
  })

  # Cierre explícito desde JS
  observeEvent(input$cerrar_modal_privacidad, {
    removeModal()
  })
}
